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
CILIUM_RESTARTED=0

ensure_istioctl() {
  if ! command -v istioctl &>/dev/null; then
    echo "失败: 未找到 istioctl"
    exit 1
  fi
}

ensure_cilium_waypoint_prereq() {
  if ! kubectl -n kube-system get cm cilium-config &>/dev/null; then
    return
  fi

  local kube_proxy_replacement
  kube_proxy_replacement="$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.kube-proxy-replacement}')"
  if [[ "${kube_proxy_replacement}" != "true" ]]; then
    return
  fi

  local hostns_only
  hostns_only="$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.bpf-lb-sock-hostns-only}')"
  if [[ "${hostns_only}" == "true" ]]; then
    echo "Cilium waypoint 前置项已满足: socket LB 仅在 host namespace 生效"
    return
  fi

  echo "修正 Cilium waypoint 前置项: 开启 bpf-lb-sock-hostns-only=true"
  kubectl -n kube-system patch cm cilium-config --type merge \
    -p '{"data":{"bpf-lb-sock-hostns-only":"true"}}'
  kubectl -n kube-system rollout restart ds/cilium
  kubectl -n kube-system rollout status ds/cilium --timeout=600s
  CILIUM_RESTARTED=1
}

restart_mesh_demo_workloads_if_needed() {
  if [[ "${CILIUM_RESTARTED}" != "1" ]]; then
    return
  fi

  echo "重启 mesh-demo 相关工作负载，确保数据面切换到新的 Cilium / ambient 状态"
  kubectl -n mesh-demo rollout restart \
    deploy/curl-trusted \
    deploy/curl-untrusted \
    deploy/public-whoami \
    deploy/httpbin \
    deploy/helloworld-v1 \
    deploy/helloworld-v2

  kubectl -n mesh-demo rollout status deploy/curl-trusted --timeout=180s
  kubectl -n mesh-demo rollout status deploy/curl-untrusted --timeout=180s
  kubectl -n mesh-demo rollout status deploy/public-whoami --timeout=180s
  kubectl -n mesh-demo rollout status deploy/httpbin --timeout=180s
  kubectl -n mesh-demo rollout status deploy/helloworld-v1 --timeout=180s
  kubectl -n mesh-demo rollout status deploy/helloworld-v2 --timeout=180s
}

generate_jwt_materials() {
  python3 "${JWT_GENERATOR}"
}

deploy_waypoint() {
  istioctl waypoint apply --namespace mesh-demo --enroll-namespace --for service --overwrite --wait
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

  echo "[0/6] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/6] 检查 istioctl"
  ensure_istioctl

  echo "[2/6] 检查 Cilium waypoint 前置项"
  ensure_cilium_waypoint_prereq

  echo "[2.5/6] 如有需要，重启 mesh-demo 工作负载"
  restart_mesh_demo_workloads_if_needed

  echo "[3/6] 生成 JWT 演示材料"
  generate_jwt_materials

  echo "[4/6] 为 mesh-demo 部署 waypoint"
  deploy_waypoint

  echo "[5/6] 应用 JWT、mTLS 与 L7 授权策略"
  apply_security_objects

  echo "[6/6] 查看安全对象"
  kubectl get requestauthentication,authorizationpolicy,peerauthentication -A

  echo "OK: 第五章 JWT、mTLS 与授权策略已启用"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
