#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：00_check_and_recover_cluster.sh
# 适用场景：第五章统一入口，复用第四章的集群检查与恢复逻辑
# 执行位置：ops 节点
# ==============================================================================

TARGET_SCRIPT="/docker_k8s_2026/k8s/04-storage-and-stateful/scripts/00_check_and_recover_cluster.sh"

main() {
  if [[ ! -f "${TARGET_SCRIPT}" ]]; then
    echo "失败: 未找到集群恢复脚本 ${TARGET_SCRIPT}"
    exit 1
  fi

  bash "${TARGET_SCRIPT}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
