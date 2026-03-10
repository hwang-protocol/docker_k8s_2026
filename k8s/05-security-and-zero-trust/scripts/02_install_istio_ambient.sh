#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：02_install_istio_ambient.sh
# 适用场景：第五章第 2 步，安装 Istio Ambient 基础能力
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/05-security-and-zero-trust"
PROFILE_FILE="${CHAPTER_DIR}/manifests/90_ambient_profile.yaml"

ensure_istioctl() {
  if ! command -v istioctl &>/dev/null; then
    echo "失败: 未找到 istioctl，请先执行 01_prepare_istio_artifacts.sh"
    exit 1
  fi
}

install_ambient() {
  kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
  istioctl install -f "${PROFILE_FILE}" -y
}

ensure_cilium_cni_shared() {
  local current
  current="$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.cni-exclusive}')"
  if [[ "${current}" == "false" ]]; then
    echo "Cilium cni-exclusive 已为 false"
    return 0
  fi

  echo "将 Cilium cni-exclusive 从 true 调整为 false"
  kubectl -n kube-system patch configmap cilium-config --type merge -p '{"data":{"cni-exclusive":"false"}}'
  kubectl -n kube-system rollout restart daemonset/cilium
  kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
}

wait_for_core_components() {
  kubectl -n istio-system rollout status deploy/istiod --timeout=300s
  kubectl -n istio-system rollout status daemonset/ztunnel --timeout=300s
  kubectl -n istio-system rollout status daemonset/istio-cni-node --timeout=300s
}

main() {
  echo "========================================================="
  echo "开始安装第五章 Istio Ambient"
  echo "========================================================="

  echo "[0/4] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/4] 检查 istioctl"
  ensure_istioctl

  echo "[2/5] 调整 Cilium CNI 共享模式"
  ensure_cilium_cni_shared

  echo "[3/5] 安装 Ambient Profile"
  install_ambient

  echo "[4/5] 等待核心组件就绪"
  wait_for_core_components

  echo "[5/5] 查看 Istio 组件状态"
  kubectl -n istio-system get pods -o wide

  echo "OK: Istio Ambient 已安装完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
