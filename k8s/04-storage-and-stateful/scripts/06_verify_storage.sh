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

main() {
  local pod_name

  echo "========================================================="
  echo "开始验收第四章存储与有状态能力"
  echo "========================================================="

  echo "[0/7] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/7] 查看 Kubernetes 节点"
  kubectl get nodes -o wide

  echo "[2/7] 查看 Longhorn 组件"
  kubectl -n longhorn-system get pods -o wide

  echo "[3/7] 查看 Longhorn 节点与磁盘"
  kubectl -n longhorn-system get nodes.longhorn.io

  echo "[4/7] 查看 StorageClass、PVC、PV"
  kubectl get sc
  kubectl -n stateful-demo get pvc
  kubectl get pv

  echo "[5/7] 查看 Longhorn 卷"
  kubectl -n longhorn-system get volumes.longhorn.io

  echo "[6/7] 查看有状态演示数据"
  pod_name="$(kubectl -n stateful-demo get pod -l app=volume-demo -o jsonpath='{.items[0].metadata.name}')"
  kubectl -n stateful-demo exec "${pod_name}" -- sh -c 'cat /data/hello.txt'

  echo "[7/7] 验证 Longhorn UI HTTPS 访问"
  curl -I --resolve "${LONGHORN_DOMAIN}:443:${VIP}" --cacert "${CA_CERT}" "https://${LONGHORN_DOMAIN}/"

  echo "OK: 第四章 Longhorn 与有状态演示验收通过"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
