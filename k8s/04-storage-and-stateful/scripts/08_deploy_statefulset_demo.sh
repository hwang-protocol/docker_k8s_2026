#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：08_deploy_statefulset_demo.sh
# 适用场景：第四章第 7 步，使用 Helm 部署 MongoDB ReplicaSet，作为真实 StatefulSet 案例
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/04-storage-and-stateful"
NAMESPACE="qytang-mongodb-demo"
RELEASE_NAME="qytang-mongodb-demo"
FULLNAME="qytang-statefulset-mongodb-demo"
POD_0="${FULLNAME}-0"
CHART_URL="http://ops:9000/04-storage-and-stateful/artifacts/mongodb-15.6.0.tgz"
VALUES_FILE="${CHAPTER_DIR}/manifests/07_mongodb_values.yaml"

main() {
  echo "========================================================="
  echo "开始部署第四章 MongoDB ReplicaSet 演示"
  echo "========================================================="

  echo "[0/5] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/5] 清理旧的 MongoDB 演示环境"
  helm uninstall "${RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1 || true
  kubectl delete ns "${NAMESPACE}" --ignore-not-found=true --wait=true

  echo "[2/5] 使用本地 Chart 与 Harbor 镜像安装 MongoDB ReplicaSet"
  helm upgrade --install "${RELEASE_NAME}" "${CHART_URL}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    -f "${VALUES_FILE}" \
    --wait \
    --timeout 15m

  echo "[3/5] 等待 StatefulSet 就绪"
  kubectl -n "${NAMESPACE}" rollout status "statefulset/${FULLNAME}" --timeout=900s

  echo "[4/5] 查看 Pod、PVC 与 Service"
  kubectl -n "${NAMESPACE}" get pods -o wide
  kubectl -n "${NAMESPACE}" get pvc
  kubectl -n "${NAMESPACE}" get svc

  echo "[5/5] 查看副本集初始状态"
  MONGO_ROOT_PASSWORD="$(kubectl -n "${NAMESPACE}" get secret "${FULLNAME}" -o jsonpath='{.data.mongodb-root-password}' | base64 -d)"
  kubectl -n "${NAMESPACE}" exec "pod/${POD_0}" -- \
    mongosh admin -u root -p "${MONGO_ROOT_PASSWORD}" --quiet \
    --eval 'rs.status().members.map(function(m){return {name:m.name,stateStr:m.stateStr}})'

  echo "OK: MongoDB ReplicaSet 已部署完成，后续请按文档执行手工 show 与删除恢复验证"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
