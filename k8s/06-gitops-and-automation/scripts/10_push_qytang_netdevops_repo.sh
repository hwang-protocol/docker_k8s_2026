#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：10_push_qytang_netdevops_repo.sh
# 适用场景：把应用目录独立初始化并首推到 Gitea
# 执行位置：ops 节点
# ==============================================================================

APP_DIR="/docker_k8s_2026/apps/qytang-netdevops"
source "/docker_k8s_2026/k8s/06-gitops-and-automation/scripts/lib_sync_qytang_netdevops_to_gitea.sh"

main() {
  echo "========================================================="
  echo "首推 QYTANG NetDevOps 到 Gitea"
  echo "========================================================="

  if [[ ! -d "${APP_DIR}" ]]; then
    echo "ERROR: 应用目录不存在: ${APP_DIR}"
    exit 1
  fi
  echo "[1/1] 从主仓目录导出并同步到 Gitea"
  sync_app_repo_to_gitea \
    "feat(gitops): 推送QYTANG NetDevOps教学仓库" \
    "从主仓 apps/qytang-netdevops 导出完整源码、部署清单和 GitOps 素材，作为后续 Argo CD 同步事实源。"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
