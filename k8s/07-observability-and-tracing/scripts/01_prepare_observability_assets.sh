#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：01_prepare_observability_assets.sh
# 适用场景：第七章第 1 步，准备可观测组件所需本地资产
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/07-observability-and-tracing"
ARTIFACTS_DIR="${CHAPTER_DIR}/artifacts"
GRAFANA_DIR="${ARTIFACTS_DIR}/grafana"

main() {
  echo "========================================================="
  echo "准备第七章可观测性资产"
  echo "========================================================="

  echo "[0/4] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/4] 检查 Grafana provisioning 目录"
  ls -ld "${GRAFANA_DIR}" \
    "${GRAFANA_DIR}/dashboards" \
    "${GRAFANA_DIR}/provisioning" \
    "${GRAFANA_DIR}/provisioning/datasources" \
    "${GRAFANA_DIR}/provisioning/dashboards"

  echo "[2/4] 检查第七章主线文档"
  ls -1 "${CHAPTER_DIR}/docs"

  echo "[3/4] 检查第七章脚本"
  ls -1 "${CHAPTER_DIR}/scripts"

  echo "[4/4] 输出后续执行入口"
  echo "bash ${CHAPTER_DIR}/scripts/02_install_observability_stack.sh"
  echo "OK: 第七章资产目录已就绪"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
