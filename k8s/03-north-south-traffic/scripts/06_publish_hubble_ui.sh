#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：06_publish_hubble_ui.sh
# 适用场景：第三章第 6 步，发布 Hubble UI 并为其准备 HTTPS 访问
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/03-north-south-traffic"
PKI_DIR="${CHAPTER_DIR}/pki"

DOMAIN="hubble.qytk8s.com"
VIP="10.1.1.61"
NAMESPACE="kube-system"
SECRET_NAME="hubble-qytk8s-com-tls"
GATEWAY_URL="http://ops:9000/03-north-south-traffic/manifests/21_hubble_ui_gateway.yaml"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
CA_KEY="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.key"
GATEWAY_SERVICE="cilium-gateway-hubble-ui-gateway"

SERVER_KEY="${PKI_DIR}/${DOMAIN}.key"
SERVER_CSR="${PKI_DIR}/${DOMAIN}.csr"
SERVER_CERT="${PKI_DIR}/${DOMAIN}.crt"
SERVER_EXT="${PKI_DIR}/${DOMAIN}.ext"

prepare_local_dirs() {
  mkdir -p "${PKI_DIR}"
}

generate_server_cert() {
  if [[ ! -f "${CA_KEY}" || ! -f "${CA_CERT}" ]]; then
    echo "失败: 未找到 Harbor CA 材料"
    exit 1
  fi

  cat >"${SERVER_EXT}" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
EOF

  openssl genrsa -out "${SERVER_KEY}" 4096
  openssl req -new -sha256 \
    -key "${SERVER_KEY}" \
    -out "${SERVER_CSR}" \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=QYT/OU=K8S/CN=${DOMAIN}"

  openssl x509 -req -sha256 \
    -in "${SERVER_CSR}" \
    -CA "${CA_CERT}" \
    -CAkey "${CA_KEY}" \
    -CAcreateserial \
    -out "${SERVER_CERT}" \
    -days 3650 \
    -extfile "${SERVER_EXT}"
}

create_tls_secret() {
  kubectl -n "${NAMESPACE}" create secret tls "${SECRET_NAME}" \
    --cert "${SERVER_CERT}" \
    --key "${SERVER_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

label_gateway_endpointslice() {
  local attempts=30
  local slice_name=""
  local i

  for i in $(seq 1 "${attempts}"); do
    slice_name="$(kubectl -n "${NAMESPACE}" get endpointslice -l io.cilium.gateway/owning-gateway=hubble-ui-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
    if [[ -n "${slice_name}" ]]; then
      kubectl -n "${NAMESPACE}" label endpointslice "${slice_name}" \
        kubernetes.io/service-name="${GATEWAY_SERVICE}" --overwrite
      echo "已为 EndpointSlice ${slice_name} 补充 kubernetes.io/service-name label"
      return 0
    fi
    echo "等待 Hubble UI Gateway EndpointSlice 生成（第 ${i}/${attempts} 次）…"
    sleep 3
  done

  echo "失败: 未找到 Hubble UI Gateway 对应的 EndpointSlice"
  kubectl get endpointslice -n "${NAMESPACE}" || true
  return 1
}

wait_for_gateway_address() {
  local attempts=30
  local current=""
  local i

  for i in $(seq 1 "${attempts}"); do
    current="$(kubectl get svc -n "${NAMESPACE}" "${GATEWAY_SERVICE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    if [[ -z "${current}" ]]; then
      current="$(kubectl get gateway -n "${NAMESPACE}" hubble-ui-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"
    fi
    if [[ "${current}" == "${VIP}" ]]; then
      echo "Hubble UI Gateway 地址已就绪：${current}"
      return 0
    fi
    echo "等待 Hubble UI Gateway 获取 VIP（第 ${i}/${attempts} 次）… 当前值：${current:-<空>}"
    sleep 5
  done

  echo "失败: Hubble UI Gateway 未在预期时间内拿到 VIP ${VIP}"
  kubectl get gateway -n "${NAMESPACE}" hubble-ui-gateway -o yaml || true
  kubectl get svc -n "${NAMESPACE}" || true
  return 1
}

main() {
  echo "========================================================="
  echo "开始发布 Hubble UI"
  echo "域名：${DOMAIN}"
  echo "VIP：${VIP}"
  echo "========================================================="

  echo "[0/7] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/7] 准备本地 PKI 目录"
  prepare_local_dirs

  echo "[2/7] 使用 Harbor CA 签发 Hubble UI 证书"
  generate_server_cert

  echo "[3/7] 创建/更新 Hubble UI TLS Secret"
  create_tls_secret

  echo "[4/7] 发布 Hubble UI Gateway 与 HTTPRoute"
  kubectl apply -f "${GATEWAY_URL}"

  echo "[5/7] 处理 Cilium Gateway 与 MetalLB 的 EndpointSlice 兼容标签"
  label_gateway_endpointslice

  echo "[6/7] 等待 Hubble UI Gateway 获取 VIP"
  wait_for_gateway_address

  echo "[7/7] 本机验证 Hubble UI HTTPS 访问"
  curl -I --resolve "${DOMAIN}:80:${VIP}" "http://${DOMAIN}/"
  curl -I --resolve "${DOMAIN}:443:${VIP}" --cacert "${CA_CERT}" "https://${DOMAIN}/"

  echo "OK: Hubble UI 已通过 HTTPS 发布"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
