#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：99_bootstrap_chapter7.sh
# 适用场景：第七章一把梭铺好可观测基线环境
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/07-observability-and-tracing"

main() {
  bash "${CHAPTER_DIR}/scripts/01_prepare_observability_assets.sh"
  bash "${CHAPTER_DIR}/scripts/02_install_observability_stack.sh"
  bash "${CHAPTER_DIR}/scripts/03_verify_observability.sh"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
