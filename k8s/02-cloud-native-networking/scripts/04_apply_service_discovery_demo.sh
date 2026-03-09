#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：04_apply_service_discovery_demo.sh
# 适用场景：第二章第 4 步，演示 Pod / Service / DNS / Service Discovery
# 执行位置：ops 节点
# ==============================================================================

BASE_URL="http://ops:9000/02-cloud-native-networking/manifests"

main() {
  echo "========================================================="
  echo "[1/4] 创建演示命名空间与工作负载"
  echo "========================================================="
  kubectl apply -f "${BASE_URL}/00_net-demo_namespace.yaml"
  kubectl apply -f "${BASE_URL}/10_whoami.yaml"
  kubectl apply -f "${BASE_URL}/20_client.yaml"

  echo
  echo "========================================================="
  echo "[2/4] 等待 whoami 与 client 就绪"
  echo "========================================================="
  kubectl rollout status deployment/whoami -n net-demo --timeout=5m
  kubectl rollout status deployment/client -n net-demo --timeout=5m

  echo
  echo "========================================================="
  echo "[3/4] 查看 Pod 与 Service"
  echo "========================================================="
  kubectl get pods -n net-demo -o wide
  kubectl get svc -n net-demo

  echo
  echo "========================================================="
  echo "[4/4] 从 client 演示 Service Discovery"
  echo "========================================================="
  kubectl exec -n net-demo deployment/client -- curl -sS http://whoami
  echo
  kubectl exec -n net-demo deployment/client -- curl -sS http://whoami.net-demo.svc.cluster.local
  echo
  kubectl exec -n net-demo deployment/client -- sh -c 'echo "Service IP:" && getent hosts whoami | head -n 1'

  echo
  echo "OK: Service Discovery 演示完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
