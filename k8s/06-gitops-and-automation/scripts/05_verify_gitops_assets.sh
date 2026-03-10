#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：05_verify_gitops_assets.sh
# 适用场景：验证 Helm 与 GitOps 素材
# 执行位置：ops 节点
# ==============================================================================

APP_DIR="/docker_k8s_2026/apps/qytang-netdevops"

main() {
  echo "========================================================="
  echo "验证 Helm 与 GitOps 素材"
  echo "========================================================="

  echo "[1/4] 查看 Helm Chart"
  ls -la "${APP_DIR}/deploy/helm/qytang-netdevops"

  echo "[2/4] 查看 Helm 模板"
  ls -la "${APP_DIR}/deploy/helm/qytang-netdevops/templates"

  echo "[3/4] 查看 GitOps 目录"
  ls -la "${APP_DIR}/deploy/gitops/lab"

  echo "[4/4] 查看 Argo CD Application"
  sed -n '1,80p' "${APP_DIR}/deploy/gitops/lab/application.yaml"

  echo "OK: Helm 与 GitOps 素材已就绪"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
