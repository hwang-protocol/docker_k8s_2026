#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：00_check_and_recover_cluster.sh
# 适用场景：第六章开始前，检查集群是否处于可教学状态
# 执行位置：ops 节点
# ==============================================================================

main() {
  echo "========================================================="
  echo "第六章前置：集群连通性检查"
  echo "========================================================="

  echo "[1/2] 检查 Kubernetes API"
  kubectl get nodes -o wide

  echo "[2/2] 检查异常 Pod"
  kubectl get pods -A --field-selector=status.phase!=Running 2>/dev/null || true

  echo "OK: 第六章开始前，集群已可访问"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
