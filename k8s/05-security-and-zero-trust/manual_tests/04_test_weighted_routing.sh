#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：04_test_weighted_routing.sh
# 适用场景：课堂手动测试，演示 50/50 与 90/10 权重路由
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/05-security-and-zero-trust"
DOMAIN="secure-app.qytk8s.com"
VIP="10.1.1.62"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
TOKEN_FILE="${CHAPTER_DIR}/pki/user.jwt"

run_distribution_test() {
  local manifest_url="$1"
  local title="$2"
  local token
  local result
  local v1_count=0
  local v2_count=0
  local i

  token="$(tr -d '\n' < "${TOKEN_FILE}")"
  kubectl apply -f "${manifest_url}" >/dev/null

  echo "---------------------------------------------------------"
  echo "${title}"
  echo "---------------------------------------------------------"

  for i in $(seq 1 20); do
    result=$(curl -s --resolve "${DOMAIN}:443:${VIP}" --cacert "${CA_CERT}" \
      -H "Authorization: Bearer ${token}" "https://${DOMAIN}/hello")
    if [[ "${result}" == *"version: v1"* ]]; then
      v1_count=$((v1_count + 1))
    elif [[ "${result}" == *"version: v2"* ]]; then
      v2_count=$((v2_count + 1))
    fi
  done

  echo "v1 次数: ${v1_count}"
  echo "v2 次数: ${v2_count}"
}

main() {
  if [[ ! -f "${TOKEN_FILE}" ]]; then
    echo "失败: 未找到 ${TOKEN_FILE}"
    exit 1
  fi

  run_distribution_test \
    "${CHAPTER_DIR}/manifests/42_virtualservice_weight_50_50.yaml" \
    "50/50 权重路由"

  run_distribution_test \
    "${CHAPTER_DIR}/manifests/43_virtualservice_weight_90_10.yaml" \
    "90/10 金丝雀发布"

  echo "提示: 讲解完毕后可执行 manual_tests/99_reset_baseline.sh 恢复基线。"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
