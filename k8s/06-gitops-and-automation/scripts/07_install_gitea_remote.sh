#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：07_install_gitea_remote.sh
# 适用场景：第六章安装 Gitea，提供 git.qytk8s.com 代码仓库
# 执行位置：ops 节点
# ==============================================================================

GIT_NODE="git"
GIT_DOMAIN="git.qytk8s.com"
GIT_IP="10.1.1.202"
GITEA_VERSION="1.25.4"
GITEA_ADMIN_USER="gitadmin"
GITEA_ADMIN_PASSWORD="Gitea12345"
GITEA_ADMIN_EMAIL="gitadmin@qytk8s.com"
POSTGRES_PASSWORD="GiteaPg12345"
POSTGRES_IMAGE="harbor.qytk8s.com/library/postgres:17"
GITEA_IMAGE="harbor.qytk8s.com/library/gitea:${GITEA_VERSION}"

CHAPTER_DIR="/docker_k8s_2026/k8s/06-gitops-and-automation"
PKI_DIR="${CHAPTER_DIR}/pki/git"
TMP_DIR="${CHAPTER_DIR}/tmp"

CA_KEY="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.key"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
SERVER_KEY="${PKI_DIR}/${GIT_DOMAIN}.key"
SERVER_CSR="${PKI_DIR}/${GIT_DOMAIN}.csr"
SERVER_CERT="${PKI_DIR}/${GIT_DOMAIN}.crt"
SERVER_EXT="${PKI_DIR}/${GIT_DOMAIN}.ext"
REMOTE_COMPOSE="/root/docker-compose-gitea.yaml"

prepare_local_dirs() {
  mkdir -p "${PKI_DIR}" "${TMP_DIR}"
}

check_ca_files() {
  if [[ ! -f "${CA_KEY}" || ! -f "${CA_CERT}" ]]; then
    echo "失败: 未找到 Harbor CA 证书或私钥"
    echo "期望文件:"
    echo "  ${CA_KEY}"
    echo "  ${CA_CERT}"
    return 1
  fi
}

generate_git_server_cert() {
  cat >"${SERVER_EXT}" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${GIT_DOMAIN}
DNS.2 = git
IP.1 = ${GIT_IP}
EOF

  openssl genrsa -out "${SERVER_KEY}" 4096
  openssl req -new -sha256 \
    -key "${SERVER_KEY}" \
    -out "${SERVER_CSR}" \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=QYT/OU=K8S/CN=${GIT_DOMAIN}"

  openssl x509 -req -sha256 \
    -in "${SERVER_CSR}" \
    -CA "${CA_CERT}" \
    -CAkey "${CA_KEY}" \
    -CAcreateserial \
    -out "${SERVER_CERT}" \
    -days 3650 \
    -extfile "${SERVER_EXT}"
}

write_local_compose_file() {
  cat >"${TMP_DIR}/docker-compose-gitea.yaml" <<EOF
services:
  postgres:
    image: ${POSTGRES_IMAGE}
    container_name: gitea-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: gitea
      POSTGRES_USER: gitea
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - /data/gitea/postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U gitea -d gitea"]
      interval: 5s
      timeout: 3s
      retries: 20

  gitea:
    image: ${GITEA_IMAGE}
    container_name: gitea
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      USER_UID: "1000"
      USER_GID: "1000"
      GITEA__database__DB_TYPE: postgres
      GITEA__database__HOST: postgres:5432
      GITEA__database__NAME: gitea
      GITEA__database__USER: gitea
      GITEA__database__PASSWD: ${POSTGRES_PASSWORD}
      GITEA__server__DOMAIN: ${GIT_DOMAIN}
      GITEA__server__ROOT_URL: https://${GIT_DOMAIN}/
      GITEA__server__PROTOCOL: https
      GITEA__server__HTTP_PORT: "3000"
      GITEA__server__CERT_FILE: /certs/${GIT_DOMAIN}.crt
      GITEA__server__KEY_FILE: /certs/${GIT_DOMAIN}.key
      GITEA__service__DISABLE_REGISTRATION: "true"
      GITEA__service__REQUIRE_SIGNIN_VIEW: "false"
      GITEA__security__INSTALL_LOCK: "true"
      GITEA__repository__DEFAULT_BRANCH: main
    ports:
      - "443:3000"
      - "2222:22"
    volumes:
      - /data/gitea/data:/data
      - /data/gitea/cert:/certs:ro
EOF
}

copy_files_to_remote() {
  scp -o StrictHostKeyChecking=no "${CA_CERT}" "root@${GIT_NODE}:/root/harbor-ca.crt"
  scp -o StrictHostKeyChecking=no "${SERVER_CERT}" "root@${GIT_NODE}:/root/${GIT_DOMAIN}.crt"
  scp -o StrictHostKeyChecking=no "${SERVER_KEY}" "root@${GIT_NODE}:/root/${GIT_DOMAIN}.key"
  scp -o StrictHostKeyChecking=no "${TMP_DIR}/docker-compose-gitea.yaml" "root@${GIT_NODE}:${REMOTE_COMPOSE}"
}

install_gitea_on_remote() {
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${GIT_NODE}" "bash -s" <<EOF
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "[git 1/6] 安装 Docker 与 docker compose"
apt-get update -y
apt-get install -y docker.io docker-compose-v2
systemctl enable --now docker

echo "[git 2/6] 准备 Docker Harbor 信任、数据目录与证书目录"
mkdir -p /etc/docker/certs.d/harbor.qytk8s.com
cp /root/harbor-ca.crt /etc/docker/certs.d/harbor.qytk8s.com/ca.crt
systemctl restart docker
docker login harbor.qytk8s.com -u admin -p Harbor12345 >/dev/null 2>&1
mkdir -p /data/gitea/postgres /data/gitea/data /data/gitea/cert
cp /root/${GIT_DOMAIN}.crt /data/gitea/cert/${GIT_DOMAIN}.crt
cp /root/${GIT_DOMAIN}.key /data/gitea/cert/${GIT_DOMAIN}.key

echo "[git 3/6] 启动 Gitea 与 Postgres"
cd /root
docker pull ${POSTGRES_IMAGE}
docker pull ${GITEA_IMAGE}
docker compose -f ${REMOTE_COMPOSE} up -d

echo "[git 4/6] 等待 Gitea 就绪"
for i in \$(seq 1 60); do
  if curl -k -s https://${GIT_DOMAIN}/ >/dev/null 2>&1; then
    echo "  Gitea Web 已就绪"
    break
  fi
  sleep 5
done

echo "[git 5/6] 创建管理员用户"
docker exec -u git gitea sh -c "gitea admin user list | awk '{print \\\$2}' | grep -qx '${GITEA_ADMIN_USER}' || gitea admin user create --admin --username ${GITEA_ADMIN_USER} --password ${GITEA_ADMIN_PASSWORD} --email ${GITEA_ADMIN_EMAIL} --must-change-password=false"

echo "[git 6/6] 查看容器状态"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
EOF
}

verify_gitea() {
  echo "[verify] 访问 Gitea 首页"
  curl -k -I "https://${GIT_DOMAIN}" | sed -n '1,5p'
}

main() {
  echo "========================================================="
  echo "开始安装 Gitea"
  echo "域名：${GIT_DOMAIN}"
  echo "版本：${GITEA_VERSION}"
  echo "========================================================="

  echo "[1/6] 准备本地目录"
  prepare_local_dirs

  echo "[2/6] 检查 Harbor CA"
  check_ca_files

  echo "[3/6] 生成 Git 服务端证书"
  generate_git_server_cert

  echo "[4/6] 生成 Gitea docker compose"
  write_local_compose_file

  echo "[5/6] 下发证书与 compose 文件"
  copy_files_to_remote

  echo "[6/6] 在 git 节点安装 Gitea"
  install_gitea_on_remote

  verify_gitea
  echo "OK: Gitea 部署完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
