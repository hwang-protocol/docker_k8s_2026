#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：06_test_fault_injection.sh
# 适用场景：课堂手动测试，演示 delay 与 abort 故障注入
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/05-security-and-zero-trust"
DOMAIN="secure-app.qytk8s.com"
VIP="10.1.1.62"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
TOKEN_FILE="${CHAPTER_DIR}/pki/user.jwt"
DELAY_URL="${CHAPTER_DIR}/manifests/50_virtualservice_fault_delay.yaml"
ABORT_URL="${CHAPTER_DIR}/manifests/51_virtualservice_fault_abort.yaml"

request_with_timing() {
  local path="${1:-/hello}"
  local token
  token="$(tr -d '\n' < "${TOKEN_FILE}")"
  curl -s -o /tmp/ch5_fault_body.txt -w 'HTTP Code: %{http_code} | Total Time: %{time_total}s\n' \
    --resolve "${DOMAIN}:443:${VIP}" \
    --cacert "${CA_CERT}" \
    -H "Authorization: Bearer ${token}" \
    "https://${DOMAIN}${path}"
}

main() {
  echo "========================================================="
  echo "手动测试：故障注入"
  echo "========================================================="

  echo "[1/2] 注入 5 秒延迟"
  kubectl apply -f "${DELAY_URL}" >/dev/null
  sleep 5
  request_with_timing "/hello"

  echo "[2/2] 注入 503 中断"
  kubectl apply -f "${ABORT_URL}" >/dev/null
  sleep 5
  request_with_timing "/get"

  echo "提示: 讲解完毕后可执行 manual_tests/99_reset_baseline.sh 恢复基线。"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
