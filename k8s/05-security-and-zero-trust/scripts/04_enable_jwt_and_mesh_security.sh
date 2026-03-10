#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：04_enable_jwt_and_mesh_security.sh
# 适用场景：第五章第 4 步，开启 JWT、mTLS、waypoint 与 L7 授权
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/05-security-and-zero-trust"
REQUEST_AUTH_URL="http://ops:9000/05-security-and-zero-trust/manifests/30_requestauthentication_ingress.yaml"
INGRESS_AUTHZ_URL="http://ops:9000/05-security-and-zero-trust/manifests/31_authorizationpolicy_ingress_jwt.yaml"
PEER_AUTH_URL="http://ops:9000/05-security-and-zero-trust/manifests/32_peerauthentication_mesh_demo.yaml"
HTTPBIN_AUTHZ_URL="http://ops:9000/05-security-and-zero-trust/manifests/33_authorizationpolicy_httpbin_waypoint.yaml"
JWT_GENERATOR="${CHAPTER_DIR}/scripts/98_generate_demo_jwt.py"

ensure_istioctl() {
  if ! command -v istioctl &>/dev/null; then
    echo "失败: 未找到 istioctl"
    exit 1
  fi
}

generate_jwt_materials() {
  python3 "${JWT_GENERATOR}"
}

deploy_waypoint() {
  istioctl waypoint apply --namespace mesh-demo --enroll-namespace --wait
}

apply_security_objects() {
  kubectl apply -f "${REQUEST_AUTH_URL}"
  kubectl apply -f "${INGRESS_AUTHZ_URL}"
  kubectl apply -f "${PEER_AUTH_URL}"
  kubectl apply -f "${HTTPBIN_AUTHZ_URL}"
}

main() {
  echo "========================================================="
  echo "开始开启第五章 JWT 与 Mesh 安全能力"
  echo "========================================================="

  echo "[0/5] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/5] 检查 istioctl"
  ensure_istioctl

  echo "[2/5] 生成 JWT 演示材料"
  generate_jwt_materials

  echo "[3/5] 为 mesh-demo 部署 waypoint"
  deploy_waypoint

  echo "[4/5] 应用 JWT、mTLS 与 L7 授权策略"
  apply_security_objects

  echo "[5/5] 查看安全对象"
  kubectl get requestauthentication,authorizationpolicy,peerauthentication -A

  echo "OK: 第五章 JWT、mTLS 与授权策略已启用"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
