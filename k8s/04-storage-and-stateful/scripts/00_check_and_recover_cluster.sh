#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：00_check_and_recover_cluster.sh
# 适用场景：第四章第 0 步，快照恢复或加盘重启后的集群连通性检查与自动恢复
# 执行位置：ops 节点
# 说明：
# 1. 第四章开始前，工作节点刚做过加盘，容易出现 kubelet 心跳延迟
# 2. 本脚本除了检查 API，也会检查所有节点是否全部 Ready
# 3. 如有异常，会自动重启 lb / cp / 工作节点上的关键服务
# ==============================================================================

LB_NODES=("lb01" "lb02")
CP_NODES=("cp01" "cp02" "cp03")
WK_NODES=("wk-app01" "wk-app02" "wk-edge01" "wk-obs01")
K8S_NODES=("cp01" "cp02" "cp03" "wk-app01" "wk-app02" "wk-edge01" "wk-obs01")

INITIAL_WAIT_ATTEMPTS=18
INITIAL_WAIT_INTERVAL=10
RECOVERY_RETRIES=3
RECOVERY_WAIT=30

remote_bash() {
  local node="$1"
  local script="$2"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${node}" \
    "env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin bash --noprofile --norc -s" <<<"${script}"
}

api_ok() {
  kubectl get nodes --request-timeout=5s &>/dev/null
}

get_not_ready_nodes() {
  kubectl get nodes --no-headers 2>/dev/null | awk '$2 !~ /^Ready/ {print $1}'
}

all_nodes_ready() {
  [[ -z "$(get_not_ready_nodes)" ]]
}

restart_lb_services() {
  local node
  for node in "${LB_NODES[@]}"; do
    echo "  [${node}] 重启 haproxy keepalived"
    remote_bash "${node}" 'systemctl restart haproxy keepalived 2>/dev/null || true' || true
  done
}

restart_kubelet_on_nodes() {
  local nodes=("$@")
  local node

  for node in "${nodes[@]}"; do
    echo "  [${node}] 重启 kubelet"
    remote_bash "${node}" 'systemctl restart kubelet 2>/dev/null || true' || true
  done
}

show_diagnostics() {
  echo "========================================================="
  echo "诊断信息"
  echo "========================================================="
  echo "[nodes]"
  kubectl get nodes -o wide || true
  echo
  echo "[pods]"
  kubectl get pods -A -o wide || true
  echo
  echo "[api]"
  curl -k -s -o /dev/null -w "%{http_code}\n" https://api.qytk8s.com:6443/healthz 2>/dev/null || echo "连接失败"
}

recover_when_api_down() {
  local round
  for round in $(seq 1 "${RECOVERY_RETRIES}"); do
    echo "========================================================="
    echo "第 ${round}/${RECOVERY_RETRIES} 轮恢复：API 暂不可达"
    echo "========================================================="
    restart_lb_services
    sleep 5
    restart_kubelet_on_nodes "${CP_NODES[@]}"
    echo "等待 ${RECOVERY_WAIT}s 让服务收敛 …"
    sleep "${RECOVERY_WAIT}"
    if api_ok; then
      return 0
    fi
  done
  return 1
}

recover_not_ready_nodes() {
  local not_ready=()
  local attempt

  mapfile -t not_ready < <(get_not_ready_nodes)
  if (( ${#not_ready[@]} == 0 )); then
    return 0
  fi

  echo "发现 NotReady 节点：${not_ready[*]}"

  for attempt in 1 2 3; do
    echo "第 ${attempt}/3 次处理 NotReady 节点"
    restart_kubelet_on_nodes "${not_ready[@]}"
    sleep 20
    if all_nodes_ready; then
      return 0
    fi
    mapfile -t not_ready < <(get_not_ready_nodes)
    echo "仍未恢复的节点：${not_ready[*]}"
  done

  return 1
}

main() {
  local attempt

  echo "========================================================="
  echo "第四章前置：集群连通性检查与恢复"
  echo "========================================================="

  if api_ok; then
    echo "API 已就绪"
  else
    echo "API 暂不可达，先等待 ${INITIAL_WAIT_ATTEMPTS} 次 × ${INITIAL_WAIT_INTERVAL}s …"
    for attempt in $(seq 1 "${INITIAL_WAIT_ATTEMPTS}"); do
      if api_ok; then
        echo "API 已恢复（第 ${attempt} 次尝试）"
        break
      fi
      printf "  尝试 %d/%d …\n" "${attempt}" "${INITIAL_WAIT_ATTEMPTS}"
      sleep "${INITIAL_WAIT_INTERVAL}"
    done
  fi

  if ! api_ok; then
    echo "初始等待后 API 仍不可达，开始执行恢复"
    recover_when_api_down || {
      show_diagnostics
      echo "失败: 集群 API 仍不可达"
      return 1
    }
  fi

  if ! all_nodes_ready; then
    recover_not_ready_nodes || {
      show_diagnostics
      echo "失败: 仍有节点不是 Ready"
      return 1
    }
  fi

  kubectl get nodes -o wide
  echo "OK: 集群可连通，且所有节点均为 Ready"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
