#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：04_enable_hubble.sh
# 适用场景：第二章第 4 步，使用 Hubble 观察东西向流量
# 执行位置：ops 节点
# ==============================================================================

PORT_FORWARD_PID=""

cleanup() {
  if [[ -n "${PORT_FORWARD_PID}" ]] && kill -0 "${PORT_FORWARD_PID}" 2>/dev/null; then
    kill "${PORT_FORWARD_PID}" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

wait_for_hubble_relay() {
  local attempt

  for attempt in $(seq 1 10); do
    if hubble status --server localhost:4245 >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  echo "等待 Hubble Relay 端口转发就绪超时"
  return 1
}

print_key_flows() {
  local output

  output="$(hubble observe --server localhost:4245 --since 20s --last 100 2>/dev/null || true)"

  printf '%s\n' "${output}" | awk '
    /net-demo\/client-.*kube-system\/coredns-.*:53/ && !dns++ { print; next }
    /net-demo\/client-.*<> net-demo\/whoami:80/ && !svc++ { print; next }
    /net-demo\/client-.*-> net-demo\/whoami-[^ ]*:80/ && !backend++ { print; next }
    /net-demo\/client-.*<- net-demo\/whoami-[^ ]*:80/ && !reply++ { print; next }
  '
}

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
  wait_for_hubble_relay
  hubble status --server localhost:4245

  echo
  echo "========================================================="
  echo "[3/4] 生成演示流量"
  echo "========================================================="
  kubectl exec -n net-demo deployment/client -- sh -c 'for i in 1 2 3; do curl -sS http://whoami >/dev/null; sleep 1; done'

  echo
  echo "========================================================="
  echo "[4/4] 输出关键 Hubble 观测记录"
  echo "========================================================="
  print_key_flows

  echo
  echo "OK: Hubble 观测演示完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
