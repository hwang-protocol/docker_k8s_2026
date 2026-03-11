#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：05_test_timeout_retry.sh
# 适用场景：课堂手动测试，演示超时与重试配置
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/05-security-and-zero-trust"
DOMAIN="secure-app.qytk8s.com"
VIP="10.1.1.62"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
TOKEN_FILE="${CHAPTER_DIR}/pki/user.jwt"
MANIFEST_URL="${CHAPTER_DIR}/manifests/44_virtualservice_timeout_retry.yaml"

request_with_timing() {
  local path="$1"
  local token
  token="$(tr -d '\n' < "${TOKEN_FILE}")"
  curl -s -o /tmp/ch5_timeout_body.txt -w 'HTTP Code: %{http_code} | Total Time: %{time_total}s\n' \
    --resolve "${DOMAIN}:443:${VIP}" \
    --cacert "${CA_CERT}" \
    -H "Authorization: Bearer ${token}" \
    "https://${DOMAIN}${path}"
}

main() {
  echo "========================================================="
  echo "手动测试：超时与重试"
  echo "========================================================="

  kubectl apply -f "${MANIFEST_URL}" >/dev/null
  sleep 5

  echo "[1/2] 访问 /delay/5，观察 timeout=2s 的效果"
  request_with_timing "/delay/5"

  echo "[2/2] 访问 /status/503，观察重试场景"
  request_with_timing "/status/503"

  echo "提示: 讲解完毕后可执行 manual_tests/99_reset_baseline.sh 恢复基线。"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
