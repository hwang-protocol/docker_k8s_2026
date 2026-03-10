#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：03_verify_chapter6.sh
# 适用场景：第六章第一阶段最终验收
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/06-gitops-and-automation"
APP_DIR="/docker_k8s_2026/apps/qytang-netdevops"

main() {
  echo "========================================================="
  echo "开始验收第六章第一阶段：样板应用与本地联调"
  echo "========================================================="

  echo "[1/8] 检查 Kubernetes 节点"
  kubectl get nodes -o wide

  echo "[2/8] 检查第六章目录"
  ls -la "${CHAPTER_DIR}"

  echo "[3/8] 检查样板应用目录"
  ls -la "${APP_DIR}"

  echo "[4/8] 检查前端页面"
  curl -I -s http://127.0.0.1:8080 | sed -n '1p'

  echo "[5/8] 检查设备服务"
  curl -s http://127.0.0.1:8001/healthz
  echo

  echo "[6/8] 检查资源服务"
  curl -s http://127.0.0.1:8002/healthz
  echo

  echo "[7/8] 检查审计服务"
  curl -s http://127.0.0.1:8003/healthz
  echo

  echo "[8/8] 检查指标接口"
  curl -s http://127.0.0.1:8001/metrics | sed -n '1,12p'

  echo "OK: 第六章第一阶段验收通过"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
