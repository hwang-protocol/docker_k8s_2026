#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：10_join_workers_remote.sh
# 适用场景：第一章第 10 步，将所有 Worker 节点加入集群并打标签
# 执行位置：ops 节点
# ==============================================================================

WORKERS=(
  "wk-app01"
  "wk-app02"
  "wk-edge01"
  "wk-obs01"
)

JOIN_COMMAND="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@cp01 'cat /root/kubeadm-join-worker.sh')"

run_join() {
  local node="$1"

  echo "========================================================="
  echo "节点：${node}"
  echo "========================================================="

  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${node}" "bash -s" <<EOF
set -euo pipefail

if [[ -f /etc/kubernetes/kubelet.conf ]]; then
  kubeadm reset -f
  rm -rf /etc/cni/net.d /etc/kubernetes /var/lib/etcd /root/.kube
fi

${JOIN_COMMAND}
EOF

  echo
}

apply_labels() {
  kubectl label node wk-app01 node-role=app --overwrite
  kubectl label node wk-app02 node-role=app --overwrite
  kubectl label node wk-edge01 node-role=edge --overwrite
  kubectl label node wk-obs01 node-role=observability --overwrite
}

main() {
  local node

  echo "========================================================="
  echo "开始加入 Worker 节点并打标签"
  echo "========================================================="

  echo "[1/3] 依次加入 Worker 节点"
  for node in "${WORKERS[@]}"; do
    run_join "${node}"
  done

  echo "[2/3] 为 Worker 节点打角色标签"
  apply_labels

  echo "[3/3] 查看当前节点列表与标签"
  kubectl get nodes --show-labels
  echo "OK: Worker 加入与标签完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
