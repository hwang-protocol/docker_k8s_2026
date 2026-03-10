#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：15_configure_argocd_domain.sh
# 适用场景：为 Argo CD 配置域名与正式证书
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/06-gitops-and-automation"
PKI_DIR="${CHAPTER_DIR}/pki/argocd"
DOMAIN="argocd.qytk8s.com"
SERVICE_IP="10.1.1.50"
NAMESPACE="argocd"
SECRET_NAME="argocd-server-tls"

HARBOR_CA_KEY="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.key"
HARBOR_CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"

SERVER_KEY="${PKI_DIR}/${DOMAIN}.key"
SERVER_CSR="${PKI_DIR}/${DOMAIN}.csr"
SERVER_CERT="${PKI_DIR}/${DOMAIN}.crt"
SERVER_EXT="${PKI_DIR}/${DOMAIN}.ext"

prepare_local_dirs() {
  mkdir -p "${PKI_DIR}"
}

generate_server_cert() {
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
    -CA "${HARBOR_CA_CERT}" \
    -CAkey "${HARBOR_CA_KEY}" \
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

configure_service_ip() {
  kubectl -n "${NAMESPACE}" patch svc argocd-server --type merge -p "$(cat <<EOF
{
  "metadata": {
    "annotations": {
      "metallb.io/address-pool": "edge-pool",
      "metallb.io/loadBalancerIPs": "${SERVICE_IP}"
    }
  },
  "spec": {
    "type": "LoadBalancer"
  }
}
EOF
)"
}

main() {
  echo "========================================================="
  echo "配置 Argo CD 正式域名入口"
  echo "域名：${DOMAIN}"
  echo "========================================================="

  echo "[1/4] 生成域名证书"
  prepare_local_dirs
  generate_server_cert

  echo "[2/4] 创建 argocd-server TLS Secret"
  create_tls_secret

  echo "[3/4] 固定 argocd-server VIP 并重启服务"
  configure_service_ip
  kubectl -n "${NAMESPACE}" rollout restart deployment/argocd-server
  kubectl -n "${NAMESPACE}" rollout status deployment/argocd-server --timeout=180s

  echo "[4/4] 输出验证命令"
  echo "curl --resolve ${DOMAIN}:443:${SERVICE_IP} --cacert ${HARBOR_CA_CERT} https://${DOMAIN}/healthz"
  echo "OK: ${DOMAIN} 已配置到 ${SERVICE_IP}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
