#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：06_configure_bgp_rr.sh
# 适用场景：第二章第 6 步，接入 VyOS Route Reflector 与 Cilium BGP
# 执行位置：ops 节点
# ==============================================================================

BASE_URL="http://ops:9000/02-cloud-native-networking/manifests"
VYOS_HOST="10.1.1.254"
VYOS_USER="vyos"
VYOS_PASS="vyos"
VYOS_ROUTER_ID="10.1.1.254"
LOCAL_ASN="65001"
WORKER_NODES=(
  "wk-app01:10.1.1.1"
  "wk-app02:10.1.1.2"
  "wk-edge01:10.1.1.3"
  "wk-obs01:10.1.1.4"
)

run_vyos_commands() {
  local mode="$1"
  local command_blob="$2"

  MODE="${mode}" \
  COMMAND_BLOB="${command_blob}" \
  VYOS_HOST="${VYOS_HOST}" \
  VYOS_USER="${VYOS_USER}" \
  VYOS_PASS="${VYOS_PASS}" \
  python3 - <<'PY'
import os
import pexpect
import sys

mode = os.environ["MODE"]
command_blob = os.environ["COMMAND_BLOB"]
host = os.environ["VYOS_HOST"]
user = os.environ["VYOS_USER"]
password = os.environ["VYOS_PASS"]
shell_prompt = r"vyos@[^\r\n]*\$ "
config_prompt = r"vyos@[^\r\n]*# "

child = pexpect.spawn(
    f"ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {user}@{host}",
    encoding="utf-8",
    timeout=30,
)
child.logfile_read = sys.stdout

child.expect("password:")
child.sendline(password)

while True:
    idx = child.expect([r"Press RETURN to continue", shell_prompt, pexpect.TIMEOUT, pexpect.EOF], timeout=30)
    if idx == 0:
        child.sendline("")
        continue
    if idx == 1:
        break
    raise RuntimeError(f"VyOS login failed: idx={idx}, before={child.before!r}")

child.sendline("set terminal length 0")
while True:
    idx = child.expect([r"Press RETURN to continue", shell_prompt], timeout=30)
    if idx == 0:
        child.sendline("")
        continue
    break

if mode == "configure":
    child.sendline("configure")
    while True:
        idx = child.expect([r"Press RETURN to continue", config_prompt], timeout=30)
        if idx == 0:
            child.sendline("")
            continue
        break

for raw_line in command_blob.splitlines():
    line = raw_line.strip()
    if not line:
        continue
    child.sendline(line)
    while True:
        expect_list = [r"Press RETURN to continue", config_prompt if mode == "configure" else shell_prompt]
        idx = child.expect(expect_list, timeout=30)
        if idx == 0:
            child.sendline("")
            continue
        break

if mode == "configure":
    child.sendline("commit")
    while True:
        idx = child.expect([r"Press RETURN to continue", r"Commit failed", config_prompt], timeout=60)
        if idx == 0:
            child.sendline("")
            continue
        if idx == 1:
            raise RuntimeError(f"VyOS commit failed: {child.before}")
        break

    child.sendline("save")
    while True:
        idx = child.expect([r"Press RETURN to continue", config_prompt], timeout=60)
        if idx == 0:
            child.sendline("")
            continue
        break

    child.sendline("exit")
    while True:
        idx = child.expect([r"Press RETURN to continue", shell_prompt], timeout=30)
        if idx == 0:
            child.sendline("")
            continue
        break

child.sendline("exit")
child.expect(pexpect.EOF, timeout=20)
PY
}

configure_vyos_rr() {
  local commands=()
  local entry node_name node_ip

  commands+=("set protocols bgp system-as '${LOCAL_ASN}'")
  commands+=("set protocols bgp parameters router-id '${VYOS_ROUTER_ID}'")
  commands+=("set protocols bgp parameters cluster-id '${VYOS_ROUTER_ID}'")
  commands+=("delete protocols bgp peer-group 'CILIUM'")
  commands+=("set protocols bgp peer-group 'CILIUM' remote-as '${LOCAL_ASN}'")
  commands+=("set protocols bgp peer-group 'CILIUM' address-family ipv4-unicast")
  commands+=("set protocols bgp peer-group 'CILIUM' address-family ipv4-unicast route-reflector-client")

  for entry in "${WORKER_NODES[@]}"; do
    node_name="${entry%%:*}"
    node_ip="${entry##*:}"
    commands+=("delete protocols bgp neighbor '${node_ip}'")
    commands+=("set protocols bgp neighbor '${node_ip}' description 'cilium-${node_name}'")
    commands+=("set protocols bgp neighbor '${node_ip}' peer-group 'CILIUM'")
  done

  run_vyos_commands "configure" "$(printf '%s\n' "${commands[@]}")"
}

show_vyos_bgp_state() {
  run_vyos_commands "show" $'show configuration commands | match protocols bgp\nshow ip bgp summary\nshow ip route bgp'
}

apply_cilium_bgp_manifests() {
  kubectl apply -f "${BASE_URL}/40_cilium_bgp_peer_config.yaml"
  kubectl apply -f "${BASE_URL}/41_cilium_bgp_advertisement_podcidr.yaml"
  kubectl apply -f "${BASE_URL}/42_cilium_bgp_cluster_config_rr.yaml"
}

wait_for_bgp_sessions() {
  local attempt output established_count

  for attempt in $(seq 1 24); do
    output="$(cilium bgp peers --output summary || true)"
    echo "${output}"
    established_count="$(
      printf '%s\n' "${output}" | awk '/10\.1\.1\.254/ && /established/ {count++} END {print count+0}'
    )"
    if [[ "${established_count}" -eq 4 ]]; then
      echo "已确认 4 个 Worker 与 VyOS 建立 BGP 邻居"
      return 0
    fi
    echo "当前仅发现 ${established_count}/4 个已建立邻居，5 秒后重试"
    sleep 5
  done

  echo "等待 BGP 邻居建立超时"
  return 1
}

main() {
  echo "========================================================="
  echo "[1/5] 配置 VyOS 为 Route Reflector"
  echo "========================================================="
  configure_vyos_rr

  echo
  echo "========================================================="
  echo "[2/5] 应用 Cilium BGP 清单"
  echo "========================================================="
  apply_cilium_bgp_manifests

  echo
  echo "========================================================="
  echo "[3/5] 等待 4 台 Worker 建立 BGP 邻居"
  echo "========================================================="
  wait_for_bgp_sessions

  echo
  echo "========================================================="
  echo "[4/5] 查看 Cilium BGP 对象"
  echo "========================================================="
  kubectl get cbgppeer,cbgpadvert,cbgpcluster
  kubectl get cbgpnode

  echo
  echo "========================================================="
  echo "[5/5] 查看 VyOS BGP 状态"
  echo "========================================================="
  show_vyos_bgp_state

  echo
  echo "OK: VyOS RR 与 Cilium BGP Control Plane 演示完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
