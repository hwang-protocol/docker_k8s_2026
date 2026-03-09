#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：05_apply_l7_policy_demo.sh
# 适用场景：第二章第 5 步，演示 L3/L4 与 L7 策略
# 执行位置：ops 节点
# ==============================================================================

BASE_URL="http://ops:9000/02-cloud-native-networking/manifests"

expect_success() {
  local title="$1"
  shift
  echo "---------------------------------------------------------"
  echo "${title}"
  echo "---------------------------------------------------------"
  "$@"
  echo
}

get_http_code() {
  local deployment="$1"
  local method="$2"
  local url="$3"
  local code

  code="$(
    kubectl exec -n net-demo "deployment/${deployment}" -- \
      sh -c "curl -sS -o /dev/null -w '%{http_code}' --max-time 5 -X ${method} ${url}" 2>/dev/null || true
  )"

  if [[ -z "${code}" ]]; then
    code="000"
  fi

  echo "${code}"
}

expect_http_code() {
  local title="$1"
  local expected_code="$2"
  local deployment="$3"
  local method="$4"
  local url="$5"
  local code

  echo "---------------------------------------------------------"
  echo "${title}"
  echo "---------------------------------------------------------"
  code="$(get_http_code "${deployment}" "${method}" "${url}")"
  echo "HTTP Code: ${code}"
  if [[ "${code}" != "${expected_code}" ]]; then
    echo "返回码不符合预期，期望：${expected_code}"
    exit 1
  fi
  echo
}

expect_http_code_not() {
  local title="$1"
  local unexpected_code="$2"
  local deployment="$3"
  local method="$4"
  local url="$5"
  local code

  echo "---------------------------------------------------------"
  echo "${title}"
  echo "---------------------------------------------------------"
  code="$(get_http_code "${deployment}" "${method}" "${url}")"
  echo "HTTP Code: ${code}"
  if [[ "${code}" == "${unexpected_code}" ]]; then
    echo "返回码不符合预期，不应为：${unexpected_code}"
    exit 1
  fi
  echo
}

main() {
  echo "========================================================="
  echo "[1/6] 准备 other Pod 与清理旧策略"
  echo "========================================================="
  kubectl apply -f "${BASE_URL}/21_other.yaml"
  kubectl delete cnp -n net-demo whoami-l3l4-allow-client --ignore-not-found
  kubectl delete cnp -n net-demo whoami-l7-allow-get --ignore-not-found
  kubectl rollout status deployment/other -n net-demo --timeout=5m

  echo
  echo "========================================================="
  echo "[2/6] 基线验证：client 与 other 都可访问 whoami"
  echo "========================================================="
  expect_success "client -> whoami (baseline)" \
    kubectl exec -n net-demo deployment/client -- curl -sS http://whoami
  expect_success "other -> whoami (baseline)" \
    kubectl exec -n net-demo deployment/other -- curl -sS http://whoami
  expect_http_code "client -> whoami HTTP 200 (baseline)" "200" "client" "GET" "http://whoami/"
  expect_http_code "other -> whoami HTTP 200 (baseline)" "200" "other" "GET" "http://whoami/"

  echo
  echo "========================================================="
  echo "[3/6] 应用 L3/L4 策略"
  echo "========================================================="
  kubectl apply -f "${BASE_URL}/30_cnp_l3l4_allow_client.yaml"
  sleep 5

  expect_http_code "client -> whoami (L3/L4 allow)" "200" "client" "GET" "http://whoami/"
  expect_http_code_not "other -> whoami (L3/L4 deny)" "200" "other" "GET" "http://whoami/"

  echo
  echo "========================================================="
  echo "[4/6] 切换到 L7 GET-only 策略"
  echo "========================================================="
  kubectl delete -f "${BASE_URL}/30_cnp_l3l4_allow_client.yaml"
  kubectl apply -f "${BASE_URL}/31_cnp_l7_allow_get.yaml"
  sleep 5

  expect_http_code "client GET / -> whoami (L7 allow)" "200" "client" "GET" "http://whoami/"
  expect_http_code_not "client POST / -> whoami (L7 deny)" "200" "client" "POST" "http://whoami/"

  echo
  echo "========================================================="
  echo "[5/6] 查看当前策略对象"
  echo "========================================================="
  kubectl get cnp -n net-demo

  echo
  echo "========================================================="
  echo "[6/6] 查看 whoami 端点身份"
  echo "========================================================="
  kubectl get cep -n net-demo

  echo
  echo "OK: L3/L4 与 L7 策略演示完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
