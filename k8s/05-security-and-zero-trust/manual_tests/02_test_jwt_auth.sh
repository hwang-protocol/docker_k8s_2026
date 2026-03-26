#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：02_test_jwt_auth.sh
# 适用场景：课堂手动测试，演示 JWT 认证前后差异
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/05-security-and-zero-trust"
DOMAIN="secure-app.qytk8s.com"
VIP="10.1.1.62"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
USER_TOKEN_FILE="${CHAPTER_DIR}/pki/user.jwt"
ADMIN_TOKEN_FILE="${CHAPTER_DIR}/pki/admin.jwt"

request_code() {
  local path="$1"
  local auth_header="$2"
  if [[ -n "${auth_header}" ]]; then
    curl -s -o /tmp/ch5_jwt_body.txt -w '%{http_code}' \
      --resolve "${DOMAIN}:443:${VIP}" \
      --cacert "${CA_CERT}" \
      -H "Authorization: Bearer ${auth_header}" \
      "https://${DOMAIN}${path}"
  else
    curl -s -o /tmp/ch5_jwt_body.txt -w '%{http_code}' \
      --resolve "${DOMAIN}:443:${VIP}" \
      --cacert "${CA_CERT}" \
      "https://${DOMAIN}${path}"
  fi
}

main() {
  local code
  local user_token
  local admin_token

  echo "========================================================="
  echo "手动测试：JWT 认证"
  echo "========================================================="

  if [[ ! -f "${USER_TOKEN_FILE}" || ! -f "${ADMIN_TOKEN_FILE}" ]]; then
    echo "失败: 未找到 JWT 演示材料"
    echo "请先执行 scripts/04_enable_jwt_and_mesh_security.sh"
    exit 1
  fi

  user_token="$(tr -d '\n' < "${USER_TOKEN_FILE}")"
  admin_token="$(tr -d '\n' < "${ADMIN_TOKEN_FILE}")"

  echo "[1/6] 不带 JWT 访问 /public"
  code="$(request_code "/public" "")"
  echo "HTTP Code: ${code}"

  echo "[2/6] 不带 JWT 访问 /hello"
  code="$(request_code "/hello" "")"
  echo "HTTP Code: ${code}"

  echo "[3/6] 带错误 JWT 访问 /hello"
  code="$(request_code "/hello" "bad.token.value")"
  echo "HTTP Code: ${code}"

  echo "[4/6] 带 user JWT 访问 /hello"
  code="$(request_code "/hello" "${user_token}")"
  echo "HTTP Code: ${code}"
  echo "返回内容示例:"
  sed -n '1,20p' /tmp/ch5_jwt_body.txt

  echo "[5/6] 带 user JWT 访问 /headers"
  code="$(request_code "/headers" "${user_token}")"
  echo "HTTP Code: ${code}"

  echo "[6/6] 带 admin JWT 访问 /headers"
  code="$(request_code "/headers" "${admin_token}")"
  echo "HTTP Code: ${code}"
  echo "返回内容示例:"
  sed -n '1,20p' /tmp/ch5_jwt_body.txt
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
