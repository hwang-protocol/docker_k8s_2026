#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：12_install_argocd_and_sync.sh
# 适用场景：安装 Argo CD、信任 Gitea CA 并同步应用
# 执行位置：ops 节点
# ==============================================================================

ARGOCD_NS="argocd"
APP_NS="qytang-netdevops"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
APP_FILE="/docker_k8s_2026/apps/qytang-netdevops/deploy/gitops/lab/application.yaml"
INSTALL_URL="https://raw.githubusercontent.com/argoproj/argo-cd/v3.3.3/manifests/install.yaml"
ARGOCD_ADMIN_PASSWORD="${ARGOCD_ADMIN_PASSWORD:-Cisc0123}"

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
  echo "安装 Argo CD 并同步 QYTANG NetDevOps"
  echo "========================================================="

  echo "[1/7] 安装 Argo CD"
  kubectl create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n "${ARGOCD_NS}" --server-side --force-conflicts -f "${INSTALL_URL}"

  echo "[2/7] 配置 Gitea CA 信任"
  kubectl -n "${ARGOCD_NS}" create configmap argocd-tls-certs-cm \
    --from-file=git.qytk8s.com="${CA_CERT}" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "[3/7] 等待 Argo CD 控制面 ready"
  kubectl rollout status deployment/argocd-server -n "${ARGOCD_NS}" --timeout=300s
  kubectl rollout status deployment/argocd-repo-server -n "${ARGOCD_NS}" --timeout=300s
  kubectl rollout status statefulset/argocd-application-controller -n "${ARGOCD_NS}" --timeout=300s

  echo "[4/7] 暴露 argocd-server"
  kubectl -n "${ARGOCD_NS}" patch svc argocd-server -p '{"spec":{"type":"LoadBalancer"}}'

  echo "[5/7] 设置固定管理员密码"
  set_admin_password

  echo "[6/7] 创建 Application"
  kubectl apply -f "${APP_FILE}"

  echo "[7/7] 等待应用同步完成"
  wait_for_app

  echo
  echo "Argo CD VIP:"
  kubectl -n "${ARGOCD_NS}" get svc argocd-server -o wide
  echo
  echo "QYT NetDevOps frontend Service:"
  kubectl -n "${APP_NS}" get svc frontend -o wide
  echo
  echo "Argo CD 默认密码:"
  echo "${ARGOCD_ADMIN_PASSWORD}"
  echo
  echo "OK: Argo CD 与应用同步完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
