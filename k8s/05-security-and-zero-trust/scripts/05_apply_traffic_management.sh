#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：05_apply_traffic_management.sh
# 适用场景：第五章第 5 步，配置流量治理基线
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/05-security-and-zero-trust"
DESTINATIONRULE_URL="${CHAPTER_DIR}/manifests/40_destinationrule_helloworld.yaml"
BASELINE_VS_URL="${CHAPTER_DIR}/manifests/41_virtualservice_weight_100_v1.yaml"

main() {
  echo "========================================================="
  echo "开始配置第五章流量治理基线"
  echo "========================================================="

  echo "[0/4] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/4] 应用 DestinationRule"
  kubectl apply -f "${DESTINATIONRULE_URL}"

  echo "[2/4] 应用基线路由（100% -> v1）"
  kubectl apply -f "${BASELINE_VS_URL}"

  echo "[3/4] 查看流量治理对象"
  kubectl -n mesh-demo get destinationrule,virtualservice

  echo "[4/4] 提示"
  echo "如需演示 50/50、90/10、timeout、fault injection，请运行 manual_tests/ 下的脚本。"

  echo "OK: 第五章流量治理基线已配置"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
