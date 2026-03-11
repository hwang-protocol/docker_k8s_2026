#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：01_test_https_ingress.sh
# 适用场景：课堂手动测试，演示第五章新入口、HTTP 跳转与 HTTPS 访问
# 执行位置：ops 节点
# ==============================================================================

DOMAIN="secure-app.qytk8s.com"
VIP="10.1.1.62"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"

main() {
  echo "========================================================="
  echo "手动测试：新入口与 HTTPS"
  echo "========================================================="

  echo "[1/2] HTTP -> HTTPS 跳转"
  curl -I --resolve "${DOMAIN}:80:${VIP}" "http://${DOMAIN}/public"

  echo "[2/2] HTTPS public 路径"
  curl -s -o /tmp/ch5_manual_https_body.txt -w 'HTTP Code: %{http_code}\n' \
    --resolve "${DOMAIN}:443:${VIP}" --cacert "${CA_CERT}" "https://${DOMAIN}/public"
  sed -n '1,20p' /tmp/ch5_manual_https_body.txt
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
