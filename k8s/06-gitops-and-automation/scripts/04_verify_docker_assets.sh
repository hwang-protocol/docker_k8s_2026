#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：04_verify_docker_assets.sh
# 适用场景：验证 QYTANG NetDevOps Docker 化素材
# 执行位置：ops 节点
# ==============================================================================

APP_DIR="/docker_k8s_2026/apps/qytang-netdevops"

main() {
  echo "========================================================="
  echo "验证 Docker 化素材"
  echo "========================================================="

  echo "[1/3] 查看 Docker 目录"
  ls -la "${APP_DIR}/deploy/docker"

  echo "[2/3] 查看 Dockerfile"
  ls -la "${APP_DIR}/deploy/docker/frontend/Dockerfile"
  ls -la "${APP_DIR}/deploy/docker/device-service/Dockerfile"
  ls -la "${APP_DIR}/deploy/docker/resource-service/Dockerfile"
  ls -la "${APP_DIR}/deploy/docker/audit-service/Dockerfile"

  echo "[3/3] 查看 docker compose"
  ls -la "${APP_DIR}/deploy/docker/docker-compose.yaml"

  echo "OK: Docker 化素材已就绪"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
