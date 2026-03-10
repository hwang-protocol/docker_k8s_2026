#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：04_deploy_stateful_demo.sh
# 适用场景：第四章第 4 步，部署有状态演示并验证 Pod 重建后数据仍保留
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/04-storage-and-stateful"
NAMESPACE_URL="http://ops:9000/04-storage-and-stateful/manifests/00_stateful_demo_namespace.yaml"
PVC_URL="http://ops:9000/04-storage-and-stateful/manifests/02_demo_pvc.yaml"
APP_URL="http://ops:9000/04-storage-and-stateful/manifests/03_demo_app.yaml"

wait_for_pod_name() {
  local pod_name=""
  local attempts=60
  local i

  for i in $(seq 1 "${attempts}"); do
    pod_name=$(kubectl -n stateful-demo get pod -l app=volume-demo \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -n "${pod_name}" ]]; then
      echo "${pod_name}"
      return 0
    fi
    sleep 2
  done

  return 1
}

wait_for_new_pod_name() {
  local old_name="$1"
  local pod_name=""
  local attempts=90
  local i

  for i in $(seq 1 "${attempts}"); do
    pod_name=$(kubectl -n stateful-demo get pod -l app=volume-demo \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -n "${pod_name}" && "${pod_name}" != "${old_name}" ]]; then
      echo "${pod_name}"
      return 0
    fi
    sleep 2
  done

  return 1
}

main() {
  local first_pod second_pod marker_text

  marker_text="hello-from-longhorn-$(date +%F-%H%M%S)"

  echo "========================================================="
  echo "开始部署第四章有状态演示"
  echo "========================================================="

  echo "[0/7] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/7] 创建演示命名空间与 PVC"
  kubectl apply -f "${NAMESPACE_URL}"
  kubectl apply -f "${PVC_URL}"
  kubectl -n stateful-demo wait --for=jsonpath='{.status.phase}'=Bound pvc/demo-pvc --timeout=300s

  echo "[2/7] 部署有状态演示应用"
  kubectl apply -f "${APP_URL}"
  kubectl -n stateful-demo rollout status deploy/volume-demo --timeout=300s

  echo "[3/7] 写入演示数据"
  first_pod="$(wait_for_pod_name)"
  kubectl -n stateful-demo exec "${first_pod}" -- sh -c \
    "echo '${marker_text}' > /data/hello.txt && sync && cat /data/hello.txt"

  echo "[4/7] 删除 Pod，模拟工作负载重建"
  kubectl -n stateful-demo delete pod "${first_pod}" --wait=true
  kubectl -n stateful-demo rollout status deploy/volume-demo --timeout=300s

  echo "[5/7] 获取新 Pod 并验证数据仍存在"
  second_pod="$(wait_for_new_pod_name "${first_pod}")"
  kubectl -n stateful-demo exec "${second_pod}" -- sh -c "cat /data/hello.txt"

  echo "[6/7] 查看 PVC 与 PV"
  kubectl -n stateful-demo get pvc
  kubectl get pv

  echo "[7/7] 查看演示工作负载状态"
  kubectl -n stateful-demo get pods -o wide
  echo "OK: 已验证 Pod 重建后 Longhorn 卷内数据仍保留"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
