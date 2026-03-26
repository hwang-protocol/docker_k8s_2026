#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：03_test_mesh_authz.sh
# 适用场景：课堂手动测试，演示 waypoint 上的 L7 授权
# 执行位置：ops 节点
# ==============================================================================

run_code() {
  local deployment="$1"
  shift
  local output
  if output="$(kubectl -n mesh-demo exec "deploy/${deployment}" -- curl -s -o /dev/null -w '%{http_code}' "$@" 2>/dev/null)"; then
    printf '%s\n' "${output}"
  else
    printf 'DENIED\n'
  fi
}

trusted_code() {
  run_code curl-trusted "http://httpbin.mesh-demo:8000/$1"
}

trusted_post_code() {
  run_code curl-trusted -X POST "http://httpbin.mesh-demo:8000/post"
}

untrusted_code() {
  run_code curl-untrusted "http://httpbin.mesh-demo:8000/get"
}

main() {
  echo "========================================================="
  echo "手动测试：waypoint 上的 L7 授权"
  echo "========================================================="

  echo "[1/3] trusted-client GET /get"
  echo "HTTP Code: $(trusted_code "get")"

  echo "[2/3] trusted-client POST /post"
  echo "HTTP Code: $(trusted_post_code)"

  echo "[3/3] untrusted-client GET /get"
  echo "HTTP Code: $(untrusted_code)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
