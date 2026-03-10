#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：03_publish_istio_ingress_demo.sh
# 适用场景：第五章第 3 步，安装 Istio Ingress Gateway 并发布演示应用
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/05-security-and-zero-trust"
ARTIFACTS_DIR="${CHAPTER_DIR}/artifacts"
PKI_DIR="${CHAPTER_DIR}/pki"

INGRESS_VALUES="${CHAPTER_DIR}/manifests/91_ingress_gateway_values.yaml"
NAMESPACE_URL="http://ops:9000/05-security-and-zero-trust/manifests/00_mesh_demo_namespace.yaml"
CLIENTS_URL="http://ops:9000/05-security-and-zero-trust/manifests/01_mesh_clients.yaml"
HELLOWORLD_URL="http://ops:9000/05-security-and-zero-trust/manifests/10_helloworld.yaml"
HTTPBIN_URL="http://ops:9000/05-security-and-zero-trust/manifests/11_httpbin.yaml"
PUBLIC_WHOAMI_URL="http://ops:9000/05-security-and-zero-trust/manifests/12_public_whoami.yaml"
GATEWAY_URL="http://ops:9000/05-security-and-zero-trust/manifests/20_secure_app_gateway.yaml"
VIRTUALSERVICE_URL="http://ops:9000/05-security-and-zero-trust/manifests/21_virtualservice_baseline.yaml"

DOMAIN="secure-app.qytk8s.com"
SECRET_NAME="secure-app-qytk8s-com-tls"
SECRET_NAMESPACE="istio-ingress"
VIP="10.1.1.61"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
CA_KEY="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.key"

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
  kubectl create namespace "${SECRET_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "${SECRET_NAMESPACE}" create secret tls "${SECRET_NAME}" \
    --cert "${SERVER_CERT}" \
    --key "${SERVER_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

install_ingress_gateway() {
  local chart_dir="${ARTIFACTS_DIR}/istio-1.29.0/manifests/charts/gateway"

  if [[ ! -d "${chart_dir}" ]]; then
    echo "失败: 未找到 Gateway Chart，先执行 01_prepare_istio_artifacts.sh"
    exit 1
  fi

  helm upgrade --install istio-ingressgateway "${chart_dir}" \
    -n istio-ingress \
    --create-namespace \
    -f "${INGRESS_VALUES}" \
    --wait
}

deploy_demo_workloads() {
  kubectl apply -f "${NAMESPACE_URL}"
  kubectl apply -f "${CLIENTS_URL}"
  kubectl apply -f "${HELLOWORLD_URL}"
  kubectl apply -f "${HTTPBIN_URL}"
  kubectl apply -f "${PUBLIC_WHOAMI_URL}"

  kubectl -n mesh-demo rollout status deploy/curl-trusted --timeout=180s
  kubectl -n mesh-demo rollout status deploy/curl-untrusted --timeout=180s
  kubectl -n mesh-demo rollout status deploy/helloworld-v1 --timeout=180s
  kubectl -n mesh-demo rollout status deploy/helloworld-v2 --timeout=180s
  kubectl -n mesh-demo rollout status deploy/httpbin --timeout=180s
  kubectl -n mesh-demo rollout status deploy/public-whoami --timeout=180s
}

apply_gateway_and_route() {
  kubectl apply -f "${GATEWAY_URL}"
  kubectl apply -f "${VIRTUALSERVICE_URL}"
}

wait_for_ingress_vip() {
  local attempts=30
  local current=""
  local i

  for i in $(seq 1 "${attempts}"); do
    current=$(kubectl get svc -n istio-ingress istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    if [[ "${current}" == "${VIP}" ]]; then
      echo "Istio Ingress VIP 已就绪：${current}"
      return 0
    fi
    echo "等待 Ingress Gateway 获取 VIP（第 ${i}/${attempts} 次）… 当前值：${current:-<空>}"
    sleep 5
  done

  echo "失败: Ingress Gateway 未在预期时间内拿到 VIP ${VIP}"
  kubectl -n istio-ingress get svc
  return 1
}

main() {
  echo "========================================================="
  echo "开始发布第五章 Istio Ingress Gateway 演示环境"
  echo "域名：${DOMAIN}"
  echo "VIP：${VIP}"
  echo "========================================================="

  echo "[0/8] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/8] 准备本地 PKI 目录"
  prepare_local_dirs

  echo "[2/8] 生成入口 HTTPS 证书"
  generate_server_cert

  echo "[3/8] 创建 TLS Secret"
  create_tls_secret

  echo "[4/8] 安装 Istio Ingress Gateway"
  install_ingress_gateway

  echo "[5/8] 部署演示工作负载"
  deploy_demo_workloads

  echo "[6/8] 应用 Gateway 与基础路由"
  apply_gateway_and_route

  echo "[7/8] 等待 Ingress Gateway 获取 VIP"
  wait_for_ingress_vip

  echo "[8/8] 本机验证 HTTP 跳转与 HTTPS 访问"
  curl -I --resolve "${DOMAIN}:80:${VIP}" "http://${DOMAIN}/public"
  curl -s -o /tmp/ch5_public_body.txt -w 'HTTPS HTTP Code: %{http_code}\n' \
    --resolve "${DOMAIN}:443:${VIP}" --cacert "${CA_CERT}" "https://${DOMAIN}/public"
  sed -n '1,20p' /tmp/ch5_public_body.txt

  echo "OK: 第五章北向入口与演示应用已发布"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
