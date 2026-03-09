#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：05_enable_hubble.sh
# 适用场景：第二章第 5 步，使用 Hubble 观察东西向流量
# 执行位置：ops 节点
# ==============================================================================

PORT_FORWARD_PID=""

cleanup() {
  if [[ -n "${PORT_FORWARD_PID}" ]] && kill -0 "${PORT_FORWARD_PID}" 2>/dev/null; then
    kill "${PORT_FORWARD_PID}" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

main() {
  echo "========================================================="
  echo "[1/4] 检查 Hubble Relay"
  echo "========================================================="
  kubectl get pods -n kube-system -l k8s-app=hubble-relay -o wide

  echo
  echo "========================================================="
  echo "[2/4] 建立本地端口转发"
  echo "========================================================="
  kubectl -n kube-system port-forward svc/hubble-relay 4245:80 >/tmp/hubble-port-forward.log 2>&1 &
  PORT_FORWARD_PID=$!
  sleep 3
  hubble status --server localhost:4245

  echo
  echo "========================================================="
  echo "[3/4] 生成演示流量"
  echo "========================================================="
  kubectl exec -n net-demo deployment/client -- sh -c 'for i in 1 2 3; do curl -sS http://whoami >/dev/null; sleep 1; done'

  echo
  echo "========================================================="
  echo "[4/4] 观察 net-demo 流量"
  echo "========================================================="
  hubble observe --server localhost:4245 --last 50 | grep -E 'net-demo/(client|whoami)'

  echo
  echo "OK: Hubble 观测演示完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
