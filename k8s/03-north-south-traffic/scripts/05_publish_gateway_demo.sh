#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：05_publish_gateway_demo.sh
# 适用场景：第三章第 5 步，发布通过域名 + HTTPS 访问的 Gateway API 演示应用
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/03-north-south-traffic"
NAMESPACE_URL="http://ops:9000/03-north-south-traffic/manifests/00_gateway_demo_namespace.yaml"
WHOAMI_URL="http://ops:9000/03-north-south-traffic/manifests/10_demo_whoami.yaml"
GATEWAY_URL="http://ops:9000/03-north-south-traffic/manifests/20_gateway_https_demo.yaml"

DOMAIN="app.qytk8s.com"
VIP="10.1.1.60"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
GATEWAY_SERVICE="cilium-gateway-app-gateway"

label_gateway_endpointslice() {
  local attempts=30
  local slice_name=""
  local i

  for i in $(seq 1 "${attempts}"); do
    slice_name=$(kubectl -n gateway-demo get endpointslice -l io.cilium.gateway/owning-gateway=app-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -n "${slice_name}" ]]; then
      kubectl -n gateway-demo label endpointslice "${slice_name}" \
        kubernetes.io/service-name="${GATEWAY_SERVICE}" --overwrite
      echo "已为 EndpointSlice ${slice_name} 补充 kubernetes.io/service-name label"
      return 0
    fi
    echo "等待 Gateway EndpointSlice 生成（第 ${i}/${attempts} 次）…"
    sleep 3
  done

  echo "失败: 未找到 Gateway 对应的 EndpointSlice"
  kubectl get endpointslice -n gateway-demo || true
  return 1
}

wait_for_gateway_address() {
  local attempts=30
  local current=""
  local i

  for i in $(seq 1 "${attempts}"); do
    current=$(kubectl get svc -n gateway-demo "${GATEWAY_SERVICE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    if [[ -z "${current}" ]]; then
      current=$(kubectl get gateway -n gateway-demo app-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)
    fi
    if [[ "${current}" == "${VIP}" ]]; then
      echo "Gateway 地址已就绪：${current}"
      return 0
    fi
    echo "等待 Gateway 获取 VIP（第 ${i}/${attempts} 次）… 当前值：${current:-<空>}"
    sleep 5
  done

  echo "失败: Gateway 未在预期时间内拿到 VIP ${VIP}"
  kubectl get gateway -n gateway-demo app-gateway -o yaml || true
  kubectl get svc -n gateway-demo || true
  return 1
}

main() {
  echo "========================================================="
  echo "开始发布 Gateway API HTTPS 演示应用"
  echo "域名：${DOMAIN}"
  echo "VIP：${VIP}"
  echo "========================================================="

  echo "[0/7] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/7] 创建演示命名空间"
  kubectl apply -f "${NAMESPACE_URL}"

  echo "[2/7] 部署 whoami 演示应用"
  kubectl apply -f "${WHOAMI_URL}"
  kubectl -n gateway-demo rollout status deploy/whoami --timeout=180s

  echo "[3/7] 应用 Gateway 与 HTTPRoute"
  kubectl apply -f "${GATEWAY_URL}"

  echo "[4/8] 处理 Cilium Gateway 与 MetalLB 的 EndpointSlice 兼容标签"
  label_gateway_endpointslice

  echo "[5/8] 等待 Gateway 获取 MetalLB VIP"
  wait_for_gateway_address

  echo "[6/8] 查看 Gateway 与路由状态"
  kubectl get gateway,httproute -n gateway-demo
  kubectl get svc -n gateway-demo

  echo "[7/8] 本机验证 HTTP -> HTTPS 跳转"
  curl -I --resolve "${DOMAIN}:80:${VIP}" "http://${DOMAIN}/"

  echo "[8/8] 本机验证 HTTPS 访问"
  curl --resolve "${DOMAIN}:443:${VIP}" --cacert "${CA_CERT}" "https://${DOMAIN}/"

  echo "OK: Gateway API HTTPS 演示应用已发布"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
