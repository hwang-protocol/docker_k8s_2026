#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：06_verify_storage.sh
# 适用场景：第四章最终验收，检查 Longhorn 与有状态演示结果
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/04-storage-and-stateful"
LONGHORN_DOMAIN="longhorn.qytk8s.com"
VIP="10.1.1.60"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
MONGO_NAMESPACE="qytang-mongodb-demo"
MONGO_FULLNAME="qytang-statefulset-mongodb-demo"

main() {
  echo "========================================================="
  echo "开始验收第四章存储与有状态能力"
  echo "========================================================="

  echo "[0/8] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/8] 查看 Kubernetes 节点"
  kubectl get nodes -o wide

  echo "[2/8] 查看 Longhorn 组件"
  kubectl -n longhorn-system get pods -o wide

  echo "[3/8] 查看 Longhorn 节点与磁盘"
  kubectl -n longhorn-system get nodes.longhorn.io
  kubectl -n longhorn-system get nodes.longhorn.io wk-edge01 -o yaml | grep -n '/var/lib/longhorn'

  echo "[4/8] 查看 StorageClass、PVC、PV"
  kubectl get sc
  kubectl -n qytang-stateful-demo get pvc
  kubectl get pv

  echo "[5/8] 查看 Longhorn 卷"
  kubectl -n longhorn-system get volumes.longhorn.io

  echo "[6/8] 查看 Deployment 有状态数据"
  kubectl -n qytang-stateful-demo exec deploy/qytang-deployment-volume-demo -- sh -c 'cat /data/hello.txt'

  echo "[7/8] 查看 MongoDB ReplicaSet StatefulSet 实验"
  MONGO_ROOT_PASSWORD="$(kubectl -n "${MONGO_NAMESPACE}" get secret "${MONGO_FULLNAME}" -o jsonpath='{.data.mongodb-root-password}' | base64 -d)"
  kubectl -n "${MONGO_NAMESPACE}" get pods
  kubectl -n "${MONGO_NAMESPACE}" get pvc
  kubectl -n "${MONGO_NAMESPACE}" exec "pod/${MONGO_FULLNAME}-0" -- \
    mongosh admin -u root -p "${MONGO_ROOT_PASSWORD}" --quiet \
    --eval 'rs.status().members.map(function(m){return {name:m.name,stateStr:m.stateStr}})'
  kubectl -n "${MONGO_NAMESPACE}" exec "pod/${MONGO_FULLNAME}-0" -- \
    mongosh admin -u root -p "${MONGO_ROOT_PASSWORD}" --quiet \
    --eval 'db.getSiblingDB("qytang").demo.find({_id:"statefulset-ok"}).toArray()'

  echo "[8/8] 验证 Longhorn UI HTTPS 访问"
  curl -I --resolve "${LONGHORN_DOMAIN}:443:${VIP}" --cacert "${CA_CERT}" "https://${LONGHORN_DOMAIN}/"

  echo "OK: 第四章 Longhorn 与有状态演示验收通过"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
