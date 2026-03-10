#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：17_scale_frontend_gitops.sh
# 适用场景：课堂演示“手工改 values，再用脚本 push 并观察 Argo CD”
# 执行位置：ops 节点
# 说明：
# 1. 先手工修改 values.yaml / values-lab.yaml 中的 replicaCount
# 2. 再执行本脚本
# ==============================================================================

APP_DIR="/docker_k8s_2026/apps/qytang-netdevops"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
PUSH_URL="https://gitadmin:Gitea12345@git.qytk8s.com/gitadmin/qytang-netdevops.git"
ARGOCD_NS="argocd"
APP_NS="qytang-netdevops"
APP_NAME="qytang-netdevops"

require_changes() {
  local status
  status="$(git -C "${APP_DIR}" status --porcelain -- \
    deploy/helm/qytang-netdevops/values.yaml \
    deploy/helm/qytang-netdevops/values-lab.yaml)"
  if [[ -z "${status}" ]]; then
    echo "ERROR: 没有检测到 values 变更。请先手工修改 replicaCount，再执行脚本。"
    exit 1
  fi
}

commit_and_push() {
  echo "[1/3] 提交并 push values 变更"
  git -C "${APP_DIR}" add \
    deploy/helm/qytang-netdevops/values.yaml \
    deploy/helm/qytang-netdevops/values-lab.yaml
  git -C "${APP_DIR}" commit -m "$(cat <<EOF
feat(gitops): 调整业务服务副本数

提交手工修改后的 values 文件，用于验证声明式扩缩容的 GitOps 同步效果。
EOF
)"
  git -C "${APP_DIR}" -c http.sslCAInfo="${CA_CERT}" push "${PUSH_URL}" main
}

wait_for_argocd() {
  echo "[2/3] 等待 Argo CD 收敛"
  kubectl -n "${ARGOCD_NS}" annotate application "${APP_NAME}" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
  for _ in $(seq 1 24); do
    sync_status="$(kubectl -n "${ARGOCD_NS}" get application "${APP_NAME}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health_status="$(kubectl -n "${ARGOCD_NS}" get application "${APP_NAME}" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    frontend_desired="$(kubectl -n "${APP_NS}" get deploy frontend -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
    frontend_available="$(kubectl -n "${APP_NS}" get deploy frontend -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)"
    echo "sync=${sync_status:-unknown} health=${health_status:-unknown} frontendDesired=${frontend_desired:-unknown} frontendAvailable=${frontend_available:-0}"
    if [[ "${sync_status}" == "Synced" && "${health_status}" == "Healthy" ]]; then
      return 0
    fi
    sleep 10
  done
  echo "ERROR: 等待 Argo CD 扩缩容超时"
  exit 1
}

show_result() {
  echo "[3/3] 输出观察结果"
  kubectl -n "${ARGOCD_NS}" get application "${APP_NAME}" -o wide
  echo
  kubectl -n "${APP_NS}" get deploy frontend
  echo
  kubectl -n "${APP_NS}" get deploy device-service
  echo
  kubectl -n "${APP_NS}" get deploy resource-service
  echo
  kubectl -n "${APP_NS}" get deploy audit-service
  echo
  kubectl -n "${APP_NS}" get pods -l app=frontend -o wide
  echo "OK: Git 中声明的副本数已提交，请结合上面的 Deployment 输出观察实际收敛结果"
}

main() {
  echo "========================================================="
  echo "课堂 GitOps 演示：手工改 values 后 push"
  echo "========================================================="
  require_changes
  commit_and_push
  wait_for_argocd
  show_result
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
