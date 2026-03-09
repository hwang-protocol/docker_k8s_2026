#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：00_check_and_recover_cluster.sh
# 适用场景：第二章第 0 步，快照恢复后的集群连通性检查与自动恢复
# 执行位置：ops 节点
# 说明：
# 1. 快照恢复后，API Server（经 lb01/lb02 VIP）可能尚未就绪
# 2. 本脚本先尝试 kubectl 连通，超时则触发 lb + cp 节点服务重启
# 3. 通过后再继续执行后续章节脚本
# ==============================================================================

LB_NODES=("lb01" "lb02")
CP_NODES=("cp01" "cp02" "cp03")
INITIAL_WAIT_ATTEMPTS=30
INITIAL_WAIT_INTERVAL=10
RECOVERY_RETRIES=3
RECOVERY_WAIT=45

api_ok() {
  kubectl get nodes --request-timeout=5 &>/dev/null
}

do_recovery() {
  echo "========================================================="
  echo "触发集群恢复：重启 lb 与 cp 节点上的关键服务"
  echo "========================================================="

  for node in "${LB_NODES[@]}"; do
    echo "  [${node}] 重启 haproxy keepalived"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${node}" \
      "systemctl restart haproxy keepalived 2>/dev/null || true" || true
  done
  sleep 5

  for node in "${CP_NODES[@]}"; do
    echo "  [${node}] 重启 kubelet"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${node}" \
      "systemctl restart kubelet 2>/dev/null || true" || true
  done

  echo "等待 ${RECOVERY_WAIT}s 让服务就绪 …"
  sleep "${RECOVERY_WAIT}"
}

show_diagnostics() {
  echo "========================================================="
  echo "诊断信息"
  echo "========================================================="
  echo "[lb 节点]"
  for node in "${LB_NODES[@]}"; do
    echo "  ${node}:"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${node}" \
      "systemctl is-active haproxy keepalived 2>/dev/null; ip addr show ens160 2>/dev/null | grep -o '10\.1\.1\.10' || true" 2>/dev/null || echo "    无法连接"
  done
  echo "[cp 节点]"
  for node in "${CP_NODES[@]}"; do
    echo "  ${node}:"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${node}" \
      "systemctl is-active kubelet 2>/dev/null" 2>/dev/null || echo "    无法连接"
  done
  echo "[API]"
  echo "  curl -k -s -o /dev/null -w '%{http_code}' https://api.qytk8s.com:6443/healthz"
  curl -k -s -o /dev/null -w "%{http_code}\n" https://api.qytk8s.com:6443/healthz 2>/dev/null || echo "  连接失败"
}

main() {
  echo "========================================================="
  echo "第二章前置：集群连通性检查与恢复"
  echo "========================================================="

  if api_ok; then
    echo "API 已就绪，跳过恢复"
    kubectl get nodes -o wide
    echo "OK: 集群可连通"
    return 0
  fi

  echo "API 暂不可达，等待 ${INITIAL_WAIT_ATTEMPTS} 次 × ${INITIAL_WAIT_INTERVAL}s …"
  local attempt
  for attempt in $(seq 1 "${INITIAL_WAIT_ATTEMPTS}"); do
    if api_ok; then
      echo "API 已就绪（第 ${attempt} 次尝试）"
      kubectl get nodes -o wide
      echo "OK: 集群可连通"
      return 0
    fi
    printf "  尝试 %d/%d …\n" "${attempt}" "${INITIAL_WAIT_ATTEMPTS}"
    sleep "${INITIAL_WAIT_INTERVAL}"
  done

  echo "初始等待超时，开始恢复 …"
  local r
  for r in $(seq 1 "${RECOVERY_RETRIES}"); do
    do_recovery
    if api_ok; then
      echo "恢复成功"
      kubectl get nodes -o wide
      echo "OK: 集群可连通"
      return 0
    fi
    echo "第 ${r}/${RECOVERY_RETRIES} 轮恢复后 API 仍不可达"
  done

  show_diagnostics
  echo "失败: 集群 API 仍不可达，请检查 lb01/lb02/cp01~03 节点与网络"
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
  exit $?
fi
