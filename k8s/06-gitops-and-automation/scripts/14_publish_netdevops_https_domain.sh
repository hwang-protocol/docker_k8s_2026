#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：14_publish_netdevops_https_domain.sh
# 适用场景：为 QYTANG NetDevOps 配置 HTTPS 域名入口
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/06-gitops-and-automation"
PKI_DIR="${CHAPTER_DIR}/pki/netdevops"
DOMAIN="netdevops.qytk8s.com"
SECRET_NAME="netdevops-qytk8s-com-tls"
SECRET_NAMESPACE="gateway-demo"

HARBOR_CA_KEY="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.key"
HARBOR_CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
MANIFEST_FILE="/docker_k8s_2026/k8s/04-storage-and-stateful/manifests/21_gateway_longhorn_ui.yaml"

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
  kubectl -n "${SECRET_NAMESPACE}" create secret tls "${SECRET_NAME}" \
    --cert "${SERVER_CERT}" \
    --key "${SERVER_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

main() {
  echo "========================================================="
  echo "发布 QYTANG NetDevOps HTTPS 域名入口"
  echo "域名：${DOMAIN}"
  echo "========================================================="

  echo "[1/4] 生成域名证书"
  prepare_local_dirs
  generate_server_cert

  echo "[2/4] 创建 Gateway TLS Secret"
  create_tls_secret

  echo "[3/4] 应用 Gateway/HTTPRoute/ReferenceGrant"
  kubectl apply -f "${MANIFEST_FILE}"

  echo "[4/4] 输出验证命令"
  echo "curl -I --resolve ${DOMAIN}:80:10.1.1.60 http://${DOMAIN}/"
  echo "curl --resolve ${DOMAIN}:443:10.1.1.60 --cacert ${HARBOR_CA_CERT} https://${DOMAIN}/"
  echo "OK: ${DOMAIN} 已发布到 10.1.1.60"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
