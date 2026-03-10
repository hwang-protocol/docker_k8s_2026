#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：06_verify_phase2_assets.sh
# 适用场景：第六章第二阶段只读验收
# 执行位置：ops 节点
# ==============================================================================

APP_DIR="/docker_k8s_2026/apps/qytang-netdevops"

main() {
  echo "========================================================="
  echo "开始验收第六章第二阶段：容器化、Helm 与 GitOps 骨架"
  echo "========================================================="

  echo "[1/6] 检查 Docker 目录"
  ls -la "${APP_DIR}/deploy/docker"

  echo "[2/6] 检查 docker compose"
  ls -la "${APP_DIR}/deploy/docker/docker-compose.yaml"

  echo "[3/6] 检查 Helm Chart"
  ls -la "${APP_DIR}/deploy/helm/qytang-netdevops"

  echo "[4/6] 检查 Helm 模板"
  ls -la "${APP_DIR}/deploy/helm/qytang-netdevops/templates"

  echo "[5/6] 检查 GitOps 目录"
  ls -la "${APP_DIR}/deploy/gitops/lab"

  echo "[6/6] 检查 Argo CD Application"
  sed -n '1,80p' "${APP_DIR}/deploy/gitops/lab/application.yaml"

  echo "OK: 第六章第二阶段验收通过"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
