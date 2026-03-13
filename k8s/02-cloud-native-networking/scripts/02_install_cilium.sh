#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：02_install_cilium.sh
# 适用场景：第二章第 2 步，安装启用 eBPF kube-proxy replacement 的 Cilium
# 执行位置：ops 节点
# 说明：
# 1. 第一章 kubeadm 已安装 kube-proxy，本脚本会先清理 kube-proxy 与相关 iptables 规则
# 2. 本脚本使用本地 Helm chart 和本地 values 文件安装 Cilium
# 3. Cilium 采用 native routing + kube-proxy replacement + Hubble
# ==============================================================================

K8S_NODES=(
  "cp01" "cp02" "cp03"
  "wk-app01" "wk-app02" "wk-edge01" "wk-obs01"
)

CHAPTER_DIR="/docker_k8s_2026/k8s/02-cloud-native-networking"
CHART_FILE="${CHAPTER_DIR}/artifacts/cilium-1.19.1.tgz"
VALUES_FILE="${CHAPTER_DIR}/manifests/cilium-values.yaml"

cleanup_kube_proxy() {
  echo "[1/5] 删除 kube-proxy DaemonSet 与 ConfigMap"
  kubectl -n kube-system delete ds kube-proxy --ignore-not-found
  kubectl -n kube-system delete cm kube-proxy --ignore-not-found
}

cleanup_iptables_on_node() {
  local node="$1"

  echo "========================================================="
  echo "节点：${node}"
  echo "========================================================="

  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${node}" "bash -s" <<'EOF'
set -euo pipefail

echo "[iptables 1/2] 清理 IPv4 中的 KUBE 规则"
iptables-save | grep -v 'KUBE' | iptables-restore

echo "[iptables 2/2] 清理 IPv6 中的 KUBE 规则"
ip6tables-save | grep -v 'KUBE' | ip6tables-restore || true

echo "OK"
EOF

  echo
}

cleanup_all_nodes() {
  local node

  echo "[2/5] 在所有 Kubernetes 节点清理 KUBE iptables 规则"
  for node in "${K8S_NODES[@]}"; do
    cleanup_iptables_on_node "${node}"
  done
}

install_cilium() {
  echo "[3/5] 通过 Helm 安装 Cilium"
  helm upgrade --install cilium "${CHART_FILE}" \
    --namespace kube-system \
    --values "${VALUES_FILE}"
}

wait_for_cilium() {
  echo "[4/5] 等待 Cilium 组件就绪"
  kubectl -n kube-system rollout status ds/cilium --timeout=10m
  kubectl -n kube-system rollout status deploy/cilium-operator --timeout=10m
  kubectl -n kube-system rollout status deploy/hubble-relay --timeout=10m
  kubectl -n kube-system rollout status deploy/hubble-ui --timeout=10m
  cilium status --wait
}

verify_basic_state() {
  echo "[5/5] 查看节点与 kube-system 组件状态"
  kubectl get nodes -o wide
  kubectl get pods -n kube-system -o wide
}

main() {
  if [[ ! -f "${CHART_FILE}" ]]; then
    echo "缺少 Helm chart：${CHART_FILE}"
    exit 1
  fi

  if [[ ! -f "${VALUES_FILE}" ]]; then
    echo "缺少 values 文件：${VALUES_FILE}"
    exit 1
  fi

  echo "========================================================="
  echo "开始安装 Cilium 1.19.1"
  echo "模式：native routing + eBPF kube-proxy replacement"
  echo "========================================================="

  cleanup_kube_proxy
  cleanup_all_nodes
  install_cilium
  wait_for_cilium
  verify_basic_state

  echo "OK: Cilium 安装完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
