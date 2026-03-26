#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：00_check_and_recover_cluster.sh
# 适用场景：第五章前置检查，确认第 05 页主线依赖的集群能力是否可用
# 执行位置：ops 节点
# 说明：
# 1. 第五章主要依赖 API、Ingress、Istio 与工作节点上的演示工作负载
# 2. 如果 API 不可达、工作节点不 Ready，或可用控制平面不足，则回退到第 04 章严格恢复逻辑
# 3. 如果只是单个控制平面节点异常，但 API 和工作节点仍满足本章主线要求，则给出提示后继续
# ==============================================================================

TARGET_SCRIPT="/docker_k8s_2026/k8s/04-storage-and-stateful/scripts/00_check_and_recover_cluster.sh"

api_ok() {
  kubectl get nodes --request-timeout=5s &>/dev/null
}

get_not_ready_nodes() {
  kubectl get nodes --no-headers 2>/dev/null | awk '$2 !~ /^Ready/ {print $1}'
}

get_not_ready_workers() {
  kubectl get nodes -l '!node-role.kubernetes.io/control-plane' --no-headers 2>/dev/null | awk '$2 !~ /^Ready/ {print $1}'
}

count_ready_control_planes() {
  kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers 2>/dev/null | awk '$2 ~ /^Ready/ {c++} END {print c+0}'
}

run_strict_recovery() {
  if [[ ! -f "${TARGET_SCRIPT}" ]]; then
    echo "失败: 未找到集群恢复脚本 ${TARGET_SCRIPT}"
    exit 1
  fi

  bash "${TARGET_SCRIPT}"
}

main() {
  local ready_cp
  local not_ready_nodes=()
  local not_ready_workers=()

  echo "========================================================="
  echo "第五章前置：集群连通性检查"
  echo "========================================================="

  if ! api_ok; then
    echo "API 当前不可达，转入第 04 章严格恢复逻辑"
    run_strict_recovery
    return
  fi

  mapfile -t not_ready_workers < <(get_not_ready_workers)
  ready_cp="$(count_ready_control_planes)"

  if (( ${#not_ready_workers[@]} > 0 )); then
    echo "发现 NotReady 工作节点：${not_ready_workers[*]}"
    echo "转入第 04 章严格恢复逻辑"
    run_strict_recovery
    return
  fi

  if (( ready_cp < 2 )); then
    echo "可用控制平面节点不足：当前仅 ${ready_cp} 个 Ready"
    echo "转入第 04 章严格恢复逻辑"
    run_strict_recovery
    return
  fi

  mapfile -t not_ready_nodes < <(get_not_ready_nodes)
  if (( ${#not_ready_nodes[@]} > 0 )); then
    echo "提示: 当前仍有非关键 NotReady 节点：${not_ready_nodes[*]}"
    echo "本章主线继续执行，但建议课后单独修复该节点。"
  fi

  kubectl get nodes -o wide
  echo "OK: API 正常、工作节点全部 Ready、可用控制平面满足本章要求"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
