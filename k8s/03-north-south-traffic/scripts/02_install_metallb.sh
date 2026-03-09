#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：02_install_metallb.sh
# 适用场景：第三章第 2 步，安装 MetalLB 并配置业务 VIP 地址池
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/03-north-south-traffic"
METALLB_MANIFEST_URL="http://ops:9000/03-north-south-traffic/artifacts/metallb-native-v0.15.3.yaml"
POOL_URL="http://ops:9000/03-north-south-traffic/manifests/01_metallb_ipaddresspool.yaml"
ADV_URL="http://ops:9000/03-north-south-traffic/manifests/02_metallb_l2advertisement.yaml"

main() {
  echo "========================================================="
  echo "开始安装 MetalLB"
  echo "========================================================="

  echo "[0/6] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/6] 预创建并标记 metallb-system 命名空间"
  kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -
  kubectl label namespace metallb-system \
    pod-security.kubernetes.io/enforce=privileged \
    pod-security.kubernetes.io/audit=privileged \
    pod-security.kubernetes.io/warn=privileged \
    --overwrite

  echo "[2/6] 安装 MetalLB 原始组件"
  kubectl apply -f "${METALLB_MANIFEST_URL}"

  echo "[3/6] 等待 MetalLB 控制器与 Speaker 就绪"
  kubectl -n metallb-system rollout status deploy/controller --timeout=180s
  kubectl -n metallb-system rollout status ds/speaker --timeout=180s

  echo "[4/6] 应用业务 VIP 地址池"
  kubectl apply -f "${POOL_URL}"

  echo "[5/6] 应用 L2Advertisement（仅由 wk-edge01 对外通告）"
  kubectl apply -f "${ADV_URL}"

  echo "[6/6] 查看 MetalLB 状态"
  kubectl get pods -n metallb-system -o wide
  kubectl get ipaddresspool,l2advertisement -n metallb-system

  echo "OK: MetalLB 已安装并完成地址池配置"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
