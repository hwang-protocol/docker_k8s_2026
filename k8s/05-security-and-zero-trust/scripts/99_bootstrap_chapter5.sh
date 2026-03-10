#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：99_bootstrap_chapter5.sh
# 适用场景：第五章一把梭铺好课堂基线环境
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/05-security-and-zero-trust"

main() {
  echo "========================================================="
  echo "开始一把梭铺好第五章课堂基线环境"
  echo "========================================================="

  bash "${CHAPTER_DIR}/scripts/01_prepare_istio_artifacts.sh"
  bash "${CHAPTER_DIR}/scripts/02_install_istio_ambient.sh"
  bash "${CHAPTER_DIR}/scripts/03_publish_istio_ingress_demo.sh"
  bash "${CHAPTER_DIR}/scripts/04_enable_jwt_and_mesh_security.sh"
  bash "${CHAPTER_DIR}/scripts/05_apply_traffic_management.sh"
  bash "${CHAPTER_DIR}/scripts/07_verify_istio_security.sh"

  echo "OK: 第五章课堂基线环境已就绪"
  echo "接下来请使用 manual_tests/ 下的脚本做课堂演示。"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
