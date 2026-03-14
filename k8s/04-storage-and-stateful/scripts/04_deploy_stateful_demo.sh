#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：04_deploy_stateful_demo.sh
# 适用场景：第四章第 5 步，部署 1 副本有状态演示并验证 Pod 自动重建后数据仍保留
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/04-storage-and-stateful"
NAMESPACE_URL="http://ops:9000/04-storage-and-stateful/manifests/00_stateful_demo_namespace.yaml"
PVC_URL="http://ops:9000/04-storage-and-stateful/manifests/02_demo_pvc.yaml"
APP_URL="http://ops:9000/04-storage-and-stateful/manifests/03_demo_app.yaml"
DEMO_NAMESPACE="qytang-stateful-demo"
DEMO_PVC="qytang-pvc-demo"
DEMO_LABEL="qytang-deployment-volume-demo"
DEMO_DEPLOY="qytang-deployment-volume-demo"

wait_for_pod_name() {
  local pod_name=""
  local attempts=60
  local i

  for i in $(seq 1 "${attempts}"); do
    pod_name=$(kubectl -n "${DEMO_NAMESPACE}" get pod -l app="${DEMO_LABEL}" \
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
    pod_name=$(kubectl -n "${DEMO_NAMESPACE}" get pod -l app="${DEMO_LABEL}" \
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
  local marker_text first_pod second_pod

  marker_text="hello-from-longhorn-$(date +%F-%H%M%S)"

  echo "========================================================="
  echo "开始部署第四章有状态演示"
  echo "========================================================="

  echo "[0/7] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/7] 创建演示命名空间与 PVC"
  kubectl apply -f "${NAMESPACE_URL}"
  kubectl apply -f "${PVC_URL}"
  kubectl -n "${DEMO_NAMESPACE}" wait --for=jsonpath='{.status.phase}'=Bound "pvc/${DEMO_PVC}" --timeout=300s

  echo "[2/7] 清理旧演示对象，确保本次从固定起点开始"
  kubectl -n "${DEMO_NAMESPACE}" delete deploy "${DEMO_DEPLOY}" --ignore-not-found=true --wait=true

  echo "[3/7] 部署 1 副本有状态演示工作负载"
  kubectl apply -f "${APP_URL}"
  kubectl -n "${DEMO_NAMESPACE}" rollout status "deploy/${DEMO_DEPLOY}" --timeout=300s
  first_pod="$(wait_for_pod_name)"
  kubectl -n "${DEMO_NAMESPACE}" get pods -o wide

  echo "[4/7] 写入演示数据"
  kubectl -n "${DEMO_NAMESPACE}" exec "deploy/${DEMO_DEPLOY}" -- sh -c \
    "echo '${marker_text}' > /data/hello.txt && sync && cat /data/hello.txt"

  echo "[5/7] 删除当前 Pod，验证 Deployment 自动重建"
  kubectl -n "${DEMO_NAMESPACE}" delete pod "${first_pod}" --wait=true
  kubectl -n "${DEMO_NAMESPACE}" rollout status "deploy/${DEMO_DEPLOY}" --timeout=300s
  second_pod="$(wait_for_new_pod_name "${first_pod}")"

  echo "[6/7] 在自动重建的新 Pod 中验证数据仍存在"
  echo "旧 Pod: ${first_pod}"
  echo "新 Pod: ${second_pod}"
  kubectl -n "${DEMO_NAMESPACE}" exec "deploy/${DEMO_DEPLOY}" -- sh -c "cat /data/hello.txt"

  echo "[7/7] 查看 PVC、PV 与当前运行状态"
  kubectl -n "${DEMO_NAMESPACE}" get pvc
  kubectl get pv
  kubectl -n "${DEMO_NAMESPACE}" get pods -o wide
  echo "OK: 已验证 Deployment 自动重建的新 Pod 继续挂载原 PVC 并读到原有数据"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
