#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：12_install_argocd_and_sync.sh
# 适用场景：安装 Argo CD、信任 Gitea CA 并同步应用
# 执行位置：ops 节点
# ==============================================================================

ARGOCD_NS="argocd"
APP_NS="qytang-netdevops"
CHAPTER_DIR="/docker_k8s_2026/k8s/06-gitops-and-automation"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
CA_KEY="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.key"
APP_FILE="/docker_k8s_2026/apps/qytang-netdevops/deploy/gitops/lab/application.yaml"
INSTALL_URL="https://raw.githubusercontent.com/argoproj/argo-cd/v3.3.3/manifests/install.yaml"
ARGOCD_ADMIN_PASSWORD="${ARGOCD_ADMIN_PASSWORD:-Cisc0123}"
ARGOCD_DOMAIN="argocd.qytk8s.com"
ARGOCD_VIP="10.1.1.50"
TLS_SECRET_NAME="argocd-server-tls"
PKI_DIR="${CHAPTER_DIR}/pki/argocd"
CA_SERIAL="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.srl"
SERVER_KEY="${PKI_DIR}/${ARGOCD_DOMAIN}.key"
SERVER_CSR="${PKI_DIR}/${ARGOCD_DOMAIN}.csr"
SERVER_CERT="${PKI_DIR}/${ARGOCD_DOMAIN}.crt"
SERVER_EXT="${PKI_DIR}/${ARGOCD_DOMAIN}.ext"

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
DNS.1 = ${ARGOCD_DOMAIN}
EOF

  openssl genrsa -out "${SERVER_KEY}" 4096
  openssl req -new -sha256 \
    -key "${SERVER_KEY}" \
    -out "${SERVER_CSR}" \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=QYT/OU=K8S/CN=${ARGOCD_DOMAIN}"

  if [[ -f "${CA_SERIAL}" ]]; then
    openssl x509 -req -sha256 \
      -in "${SERVER_CSR}" \
      -CA "${CA_CERT}" \
      -CAkey "${CA_KEY}" \
      -CAserial "${CA_SERIAL}" \
      -out "${SERVER_CERT}" \
      -days 3650 \
      -extfile "${SERVER_EXT}"
  else
    openssl x509 -req -sha256 \
      -in "${SERVER_CSR}" \
      -CA "${CA_CERT}" \
      -CAkey "${CA_KEY}" \
      -CAcreateserial \
      -out "${SERVER_CERT}" \
      -days 3650 \
      -extfile "${SERVER_EXT}"
  fi
}

create_tls_secret() {
  kubectl -n "${ARGOCD_NS}" create secret tls "${TLS_SECRET_NAME}" \
    --cert "${SERVER_CERT}" \
    --key "${SERVER_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

configure_service() {
  kubectl -n "${ARGOCD_NS}" patch svc argocd-server --type merge -p "$(cat <<EOF
{
  "metadata": {
    "annotations": {
      "metallb.io/address-pool": "edge-pool",
      "metallb.io/loadBalancerIPs": "${ARGOCD_VIP}"
    }
  },
  "spec": {
    "type": "LoadBalancer"
  }
}
EOF
)"
}

wait_for_app() {
  local sync_status health_status
  for _ in $(seq 1 36); do
    sync_status="$(kubectl -n "${ARGOCD_NS}" get application qytang-netdevops -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health_status="$(kubectl -n "${ARGOCD_NS}" get application qytang-netdevops -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    echo "当前状态: sync=${sync_status:-unknown} health=${health_status:-unknown}"
    if [[ "${sync_status}" == "Synced" && "${health_status}" == "Healthy" ]]; then
      return 0
    fi
    sleep 10
  done
  return 1
}

set_admin_password() {
  local password_hash password_mtime
  password_hash="$(
    kubectl -n "${ARGOCD_NS}" exec deploy/argocd-server -- \
      argocd account bcrypt --password "${ARGOCD_ADMIN_PASSWORD}"
  )"
  password_mtime="$(date -u +%FT%TZ)"

  kubectl -n "${ARGOCD_NS}" patch secret argocd-secret --type merge -p "$(cat <<EOF
{
  "stringData": {
    "admin.password": "${password_hash}",
    "admin.passwordMtime": "${password_mtime}"
  }
}
EOF
)"

  kubectl -n "${ARGOCD_NS}" patch secret argocd-initial-admin-secret --type merge -p "$(cat <<EOF
{
  "stringData": {
    "password": "${ARGOCD_ADMIN_PASSWORD}"
  }
}
EOF
)"

  kubectl -n "${ARGOCD_NS}" rollout restart deployment/argocd-server
  kubectl -n "${ARGOCD_NS}" rollout status deployment/argocd-server --timeout=300s
}

main() {
  echo "========================================================="
  echo "安装 Argo CD、配置正式域名并同步 QYTANG NetDevOps"
  echo "========================================================="

  echo "[1/9] 安装 Argo CD"
  kubectl create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n "${ARGOCD_NS}" --server-side --force-conflicts -f "${INSTALL_URL}"

  echo "[2/9] 配置 Gitea CA 信任"
  kubectl -n "${ARGOCD_NS}" create configmap argocd-tls-certs-cm \
    --from-file=git.qytk8s.com="${CA_CERT}" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "[3/9] 等待 Argo CD 控制面 ready"
  kubectl rollout status deployment/argocd-server -n "${ARGOCD_NS}" --timeout=300s
  kubectl rollout status deployment/argocd-repo-server -n "${ARGOCD_NS}" --timeout=300s
  kubectl rollout status statefulset/argocd-application-controller -n "${ARGOCD_NS}" --timeout=300s

  echo "[4/9] 生成 Argo CD 正式域名证书"
  prepare_local_dirs
  generate_server_cert

  echo "[5/9] 配置 argocd-server 正式证书"
  create_tls_secret

  echo "[6/9] 固定 argocd-server VIP"
  configure_service

  echo "[7/9] 设置固定管理员密码并重启服务"
  set_admin_password

  echo "[8/9] 创建 Application"
  kubectl apply -f "${APP_FILE}"

  echo "[9/9] 等待应用同步完成"
  wait_for_app

  echo
  echo "Argo CD 正式入口:"
  echo "https://${ARGOCD_DOMAIN}"
  echo
  echo "Argo CD Service:"
  kubectl -n "${ARGOCD_NS}" get svc argocd-server -o wide
  echo
  echo "QYT NetDevOps frontend Service:"
  kubectl -n "${APP_NS}" get svc frontend -o wide
  echo
  echo "Argo CD 默认密码:"
  echo "${ARGOCD_ADMIN_PASSWORD}"
  echo
  echo "证书验证命令:"
  echo "curl --resolve ${ARGOCD_DOMAIN}:443:${ARGOCD_VIP} --cacert ${CA_CERT} https://${ARGOCD_DOMAIN}/healthz"
  echo
  echo "浏览器说明:"
  echo "如果 win2019 浏览器仍提示证书不受信任，请导入 ${CA_CERT} 到受信任的根证书颁发机构，然后再访问 https://${ARGOCD_DOMAIN}"
  echo
  echo "OK: Argo CD 与应用同步完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
