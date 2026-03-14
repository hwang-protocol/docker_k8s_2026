#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：07_verify_istio_security.sh
# 适用场景：第五章最终验收
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/05-security-and-zero-trust"
DOMAIN="secure-app.qytk8s.com"
VIP="10.1.1.62"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"

main() {
  echo "========================================================="
  echo "开始验收第五章 Istio 安全与零信任主线"
  echo "========================================================="

  echo "[1/7] 查看 Kubernetes 节点"
  kubectl get nodes -o wide

  echo "[2/7] 查看 Istio 组件"
  kubectl -n istio-system get pods -o wide
  kubectl -n istio-ingress get pods,svc -o wide

  echo "[3/7] 验证 public HTTPS 访问"
  curl -s -o /tmp/ch5_verify_public_body.txt -w 'HTTP Code: %{http_code}\n' \
    --resolve "${DOMAIN}:443:${VIP}" --cacert "${CA_CERT}" "https://${DOMAIN}/public"
  sed -n '1,20p' /tmp/ch5_verify_public_body.txt

  echo "[4/7] 查看演示工作负载"
  kubectl -n mesh-demo get pods,svc

  echo "[5/7] 查看安全对象"
  kubectl get requestauthentication,authorizationpolicy,peerauthentication -A

  echo "[6/7] 执行 JWT 手动测试"
  bash "${CHAPTER_DIR}/manual_tests/02_test_jwt_auth.sh"

  echo "[7/7] 执行网格授权手动测试"
  bash "${CHAPTER_DIR}/manual_tests/03_test_mesh_authz.sh"

  echo "OK: 第五章验收通过"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
