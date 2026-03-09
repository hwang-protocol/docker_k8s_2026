#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：09_join_control_planes_remote.sh
# 适用场景：第一章第 9 步，将 cp02 和 cp03 加入控制平面
# 执行位置：ops 节点
# ==============================================================================

CONTROL_PLANES=("cp02" "cp03")

JOIN_COMMAND="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@cp01 'cat /root/kubeadm-join-control-plane.sh')"

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

main() {
  local node

  echo "========================================================="
  echo "开始加入额外控制平面节点"
  echo "========================================================="

  echo "[1/2] 依次加入 cp02、cp03"
  for node in "${CONTROL_PLANES[@]}"; do
    run_join "${node}"
  done

  echo "[2/2] 查看当前节点列表"
  kubectl get nodes -o wide
  echo "OK: 控制平面扩展完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
