#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：99_reset_baseline.sh
# 适用场景：课堂演示后恢复第五章稳定基线
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/05-security-and-zero-trust"
BASELINE_VS_URL="${CHAPTER_DIR}/manifests/41_virtualservice_weight_100_v1.yaml"
DESTINATIONRULE_URL="${CHAPTER_DIR}/manifests/40_destinationrule_helloworld.yaml"

main() {
  echo "恢复第五章流量治理基线 …"
  kubectl apply -f "${DESTINATIONRULE_URL}"
  kubectl apply -f "${BASELINE_VS_URL}"
  kubectl -n mesh-demo get virtualservice,destinationrule
  echo "OK: 已恢复到 100% -> v1 的稳定基线"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
