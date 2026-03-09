#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：04_issue_tls_certs.sh
# 适用场景：第三章第 4 步，复用 Harbor CA 为北向域名签发证书
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/03-north-south-traffic"
PKI_DIR="${CHAPTER_DIR}/pki"
DOMAIN="app.qytk8s.com"
SECRET_NAME="app-qytk8s-com-tls"
NAMESPACE="gateway-demo"

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
  if [[ ! -f "${HARBOR_CA_KEY}" || ! -f "${HARBOR_CA_CERT}" ]]; then
    echo "失败: 未找到 Harbor CA 材料"
    echo "需要文件：${HARBOR_CA_KEY} 和 ${HARBOR_CA_CERT}"
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
    -CA "${HARBOR_CA_CERT}" \
    -CAkey "${HARBOR_CA_KEY}" \
    -CAcreateserial \
    -out "${SERVER_CERT}" \
    -days 3650 \
    -extfile "${SERVER_EXT}"
}

create_tls_secret() {
  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "${NAMESPACE}" create secret tls "${SECRET_NAME}" \
    --cert "${SERVER_CERT}" \
    --key "${SERVER_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

main() {
  echo "========================================================="
  echo "开始签发第三章北向 HTTPS 证书"
  echo "域名：${DOMAIN}"
  echo "========================================================="

  echo "[0/4] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/4] 准备本地 PKI 目录"
  prepare_local_dirs

  echo "[2/4] 使用 Harbor CA 签发服务端证书"
  generate_server_cert

  echo "[3/4] 创建/更新 Kubernetes TLS Secret"
  create_tls_secret

  echo "[4/4] 输出证书位置"
  ls -lh "${SERVER_CERT}" "${SERVER_KEY}" "${HARBOR_CA_CERT}"
  echo "请把 ${HARBOR_CA_CERT} 导入 win2019 的受信任根证书颁发机构"

  echo "OK: 第三章 TLS 证书已签发"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
