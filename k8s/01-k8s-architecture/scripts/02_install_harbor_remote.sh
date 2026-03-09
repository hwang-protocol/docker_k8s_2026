#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：02_install_harbor_remote.sh
# 适用场景：第一章第 2 步，在 harbor 节点部署 Harbor 私有镜像仓库
# 执行位置：ops 节点
# 说明：
# 1. 本脚本只负责 Harbor 部署，不处理 Kubernetes 安装
# 2. 本脚本会在 ops 本机生成 Harbor CA 和服务端证书
# 3. 本脚本会通过 SSH 将证书与安装文件下发到 harbor 节点
# ==============================================================================

HARBOR_NODE="harbor"
HARBOR_DOMAIN="harbor.qytk8s.com"
HARBOR_VERSION="v2.13.0"
HARBOR_ADMIN_PASSWORD="Harbor12345"

BASE_DIR="/docker_k8s_2026/k8s/01-k8s-architecture"
PKI_DIR="${BASE_DIR}/pki/harbor"
TMP_DIR="${BASE_DIR}/tmp"

CA_KEY="${PKI_DIR}/harbor-ca.key"
CA_CERT="${PKI_DIR}/harbor-ca.crt"
SERVER_KEY="${PKI_DIR}/harbor.qytk8s.com.key"
SERVER_CSR="${PKI_DIR}/harbor.qytk8s.com.csr"
SERVER_CERT="${PKI_DIR}/harbor.qytk8s.com.crt"
SERVER_EXT="${PKI_DIR}/harbor.qytk8s.com.ext"
INSTALLER_FILE="${TMP_DIR}/harbor-offline-installer-${HARBOR_VERSION}.tgz"

prepare_local_dirs() {
  mkdir -p "${PKI_DIR}" "${TMP_DIR}"
}

generate_ca_and_server_cert() {
  if [[ ! -f "${CA_KEY}" || ! -f "${CA_CERT}" ]]; then
    openssl genrsa -out "${CA_KEY}" 4096
    openssl req -x509 -new -nodes -sha256 \
      -key "${CA_KEY}" \
      -days 3650 \
      -out "${CA_CERT}" \
      -subj "/C=CN/ST=Beijing/L=Beijing/O=QYT/OU=K8S/CN=QYT-Harbor-CA"
  fi

  cat >"${SERVER_EXT}" <<'EOF'
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = harbor.qytk8s.com
DNS.2 = harbor
IP.1 = 10.1.1.203
EOF

  openssl genrsa -out "${SERVER_KEY}" 4096
  openssl req -new -sha256 \
    -key "${SERVER_KEY}" \
    -out "${SERVER_CSR}" \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=QYT/OU=K8S/CN=${HARBOR_DOMAIN}"

  openssl x509 -req -sha256 \
    -in "${SERVER_CSR}" \
    -CA "${CA_CERT}" \
    -CAkey "${CA_KEY}" \
    -CAcreateserial \
    -out "${SERVER_CERT}" \
    -days 3650 \
    -extfile "${SERVER_EXT}"
}

download_harbor_installer() {
  if [[ ! -f "${INSTALLER_FILE}" ]]; then
    curl -L \
      "https://github.com/goharbor/harbor/releases/download/${HARBOR_VERSION}/harbor-offline-installer-${HARBOR_VERSION}.tgz" \
      -o "${INSTALLER_FILE}"
  fi
}

install_harbor_on_remote() {
  scp -o StrictHostKeyChecking=no "${CA_CERT}" "root@${HARBOR_NODE}:/root/harbor-ca.crt"
  scp -o StrictHostKeyChecking=no "${SERVER_CERT}" "root@${HARBOR_NODE}:/root/harbor.qytk8s.com.crt"
  scp -o StrictHostKeyChecking=no "${SERVER_KEY}" "root@${HARBOR_NODE}:/root/harbor.qytk8s.com.key"
  scp -o StrictHostKeyChecking=no "${INSTALLER_FILE}" "root@${HARBOR_NODE}:/root/harbor-offline-installer.tgz"

  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${HARBOR_NODE}" "bash -s" <<EOF
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "[harbor 1/7] 安装 Docker"
apt-get update -y
apt-get install -y docker.io docker-compose-v2
systemctl enable --now docker

echo "[harbor 2/7] 配置 Docker 信任 Harbor CA"
mkdir -p /etc/docker/certs.d/${HARBOR_DOMAIN}
cp /root/harbor-ca.crt /etc/docker/certs.d/${HARBOR_DOMAIN}/ca.crt

echo "[harbor 3/7] 解压 Harbor 离线安装包"
mkdir -p /opt/harbor-install
tar -xf /root/harbor-offline-installer.tgz -C /opt/harbor-install --strip-components=1

echo "[harbor 4/7] 分发证书到 Harbor 数据目录"
mkdir -p /data /data/cert
cp /root/harbor.qytk8s.com.crt /data/cert/
cp /root/harbor.qytk8s.com.key /data/cert/

echo "[harbor 5/7] 生成 harbor.yml 配置"
cp /opt/harbor-install/harbor.yml.tmpl /opt/harbor-install/harbor.yml

sed -i 's/^hostname: .*/hostname: ${HARBOR_DOMAIN}/' /opt/harbor-install/harbor.yml
sed -i 's|^  certificate: .*|  certificate: /data/cert/harbor.qytk8s.com.crt|' /opt/harbor-install/harbor.yml
sed -i 's|^  private_key: .*|  private_key: /data/cert/harbor.qytk8s.com.key|' /opt/harbor-install/harbor.yml
sed -i 's/^harbor_admin_password: .*/harbor_admin_password: ${HARBOR_ADMIN_PASSWORD}/' /opt/harbor-install/harbor.yml

echo "[harbor 6/7] 执行 Harbor 安装"
cd /opt/harbor-install
./install.sh --with-trivy

echo "[harbor 7/7] 查看 Harbor 容器列表"
docker ps --format '{{.Names}}' | sort
EOF
}

main() {
  echo "========================================================="
  echo "开始部署 Harbor"
  echo "域名：${HARBOR_DOMAIN}"
  echo "版本：${HARBOR_VERSION}"
  echo "========================================================="

  echo "[1/4] 准备本地目录"
  prepare_local_dirs

  echo "[2/4] 生成 Harbor CA 与服务端证书"
  generate_ca_and_server_cert

  echo "[3/4] 下载 Harbor Offline Installer"
  download_harbor_installer

  echo "[4/4] 在 harbor 节点安装 Harbor"
  install_harbor_on_remote

  echo "OK: Harbor 部署完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
