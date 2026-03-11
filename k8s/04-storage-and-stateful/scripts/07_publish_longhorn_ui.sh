#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：07_publish_longhorn_ui.sh
# 适用场景：第四章补充步骤，把 Longhorn UI 通过 win2019 + HTTPS + 域名方式发布
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/04-storage-and-stateful"
PKI_DIR="${CHAPTER_DIR}/pki"
MANIFEST_URL="http://ops:9000/04-storage-and-stateful/manifests/21_gateway_longhorn_ui.yaml"

DOMAIN="longhorn.qytk8s.com"
SECRET_NAME="longhorn-qytk8s-com-tls"
SECRET_NAMESPACE="gateway-demo"
VIP="10.1.1.60"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
CA_KEY="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.key"
GATEWAY_SERVICE="cilium-gateway-app-gateway"

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
    echo "需要文件：${CA_KEY} 和 ${CA_CERT}"
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
  kubectl create namespace "${SECRET_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "${SECRET_NAMESPACE}" create secret tls "${SECRET_NAME}" \
    --cert "${SERVER_CERT}" \
    --key "${SERVER_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

label_gateway_endpointslice() {
  local attempts=30
  local slice_name=""
  local i

  for i in $(seq 1 "${attempts}"); do
    slice_name=$(kubectl -n gateway-demo get endpointslice -l io.cilium.gateway/owning-gateway=app-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -n "${slice_name}" ]]; then
      kubectl -n gateway-demo label endpointslice "${slice_name}" \
        kubernetes.io/service-name="${GATEWAY_SERVICE}" --overwrite
      echo "已为 EndpointSlice ${slice_name} 补充 kubernetes.io/service-name label"
      return 0
    fi
    echo "等待 Gateway EndpointSlice 生成（第 ${i}/${attempts} 次）…"
    sleep 3
  done

  echo "失败: 未找到 Gateway 对应的 EndpointSlice"
  kubectl get endpointslice -n gateway-demo || true
  return 1
}

wait_for_gateway_address() {
  local attempts=30
  local current=""
  local i

  for i in $(seq 1 "${attempts}"); do
    current=$(kubectl get svc -n gateway-demo "${GATEWAY_SERVICE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    if [[ -z "${current}" ]]; then
      current=$(kubectl get gateway -n gateway-demo app-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)
    fi
    if [[ "${current}" == "${VIP}" ]]; then
      echo "Gateway 地址已就绪：${current}"
      return 0
    fi
    echo "等待 Gateway 获取 VIP（第 ${i}/${attempts} 次）… 当前值：${current:-<空>}"
    sleep 5
  done

  echo "失败: Gateway 未在预期时间内拿到 VIP ${VIP}"
  kubectl get gateway -n gateway-demo app-gateway -o yaml || true
  kubectl get svc -n gateway-demo || true
  return 1
}

reconcile_gateway_listeners() {
  python3 - <<'PY'
import json
import subprocess
import sys

allowed = {"http", "https", "longhorn-http", "longhorn-https"}

raw = subprocess.check_output(
    ["kubectl", "get", "gateway", "-n", "gateway-demo", "app-gateway", "-o", "json"],
    text=True,
)
obj = json.loads(raw)
listeners = obj["spec"].get("listeners", [])
filtered = [item for item in listeners if item.get("name") in allowed]

if len(filtered) == len(listeners):
    print("Gateway listeners 已符合第四章范围，无需收口")
    sys.exit(0)

obj["spec"]["listeners"] = filtered
meta = obj["metadata"]
for key in ["creationTimestamp", "generation", "resourceVersion", "uid", "managedFields", "annotations"]:
    meta.pop(key, None)
obj.pop("status", None)

subprocess.run(
    ["kubectl", "replace", "-f", "-"],
    input=json.dumps(obj),
    text=True,
    check=True,
)
print("已将 app-gateway 收口为第四章所需 listeners: http https longhorn-http longhorn-https")
PY
}

main() {
  echo "========================================================="
  echo "开始发布 Longhorn UI"
  echo "域名：${DOMAIN}"
  echo "VIP：${VIP}"
  echo "========================================================="

  echo "[0/8] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/8] 准备本地 PKI 目录"
  prepare_local_dirs

  echo "[2/8] 使用 Harbor CA 签发 Longhorn UI 证书"
  generate_server_cert

  echo "[3/8] 创建/更新 Kubernetes TLS Secret"
  create_tls_secret

  echo "[4/8] 应用 Longhorn UI Gateway/HTTPRoute/ReferenceGrant 清单"
  kubectl apply -f "${MANIFEST_URL}"

  echo "[4.5/8] 收口 app-gateway listeners，确保只保留第四章范围"
  reconcile_gateway_listeners

  echo "[5/8] 处理 Cilium Gateway 与 MetalLB 的 EndpointSlice 兼容标签"
  label_gateway_endpointslice

  echo "[6/8] 等待 Gateway 获取 MetalLB VIP"
  wait_for_gateway_address

  echo "[7/8] 查看网关与路由状态"
  kubectl get gateway,httproute -n gateway-demo
  kubectl -n longhorn-system get referencegrant

  echo "[8/8] 本机验证 Longhorn UI 的 HTTP 跳转与 HTTPS 页面"
  curl -I --resolve "${DOMAIN}:80:${VIP}" "http://${DOMAIN}/"
  curl --resolve "${DOMAIN}:443:${VIP}" --cacert "${CA_CERT}" -I "https://${DOMAIN}/"

  echo "OK: Longhorn UI 已可通过 https://${DOMAIN} 访问"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
