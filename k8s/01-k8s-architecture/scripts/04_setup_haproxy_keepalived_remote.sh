#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：04_setup_haproxy_keepalived_remote.sh
# 适用场景：第一章第 4 步，部署 API Server 高可用入口
# 执行位置：ops 节点
# ==============================================================================

VIP="10.1.1.10"
BASE_DIR="/docker_k8s_2026/k8s/01-k8s-architecture"
CONFIGS_DIR="${BASE_DIR}/configs/loadbalancer"
HAPROXY_CFG="${CONFIGS_DIR}/haproxy.cfg"
CHECK_SCRIPT="${CONFIGS_DIR}/check_haproxy.sh"
KEEPALIVED_LB01="${CONFIGS_DIR}/keepalived-lb01.conf"
KEEPALIVED_LB02="${CONFIGS_DIR}/keepalived-lb02.conf"

require_local_files() {
  local file
  for file in \
    "${HAPROXY_CFG}" \
    "${CHECK_SCRIPT}" \
    "${KEEPALIVED_LB01}" \
    "${KEEPALIVED_LB02}"; do
    if [[ ! -f "${file}" ]]; then
      echo "ERROR: 缺少配置文件: ${file}"
      exit 1
    fi
  done
}

install_packages() {
  local node="$1"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${node}" "bash -s" <<'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y haproxy keepalived
mkdir -p /etc/haproxy /etc/keepalived
EOF
}

push_file() {
  local node="$1"
  local local_path="$2"
  local remote_path="$3"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${node}" "cat > ${remote_path}" < "${local_path}"
}

configure_node() {
  local node="$1"
  local keepalived_conf="$2"

  echo "[${node} 1/5] 安装 haproxy 和 keepalived"
  install_packages "${node}"

  echo "[${node} 2/5] 下发 haproxy.cfg"
  push_file "${node}" "${HAPROXY_CFG}" "/etc/haproxy/haproxy.cfg"

  echo "[${node} 3/5] 下发健康检查脚本"
  push_file "${node}" "${CHECK_SCRIPT}" "/etc/keepalived/check_haproxy.sh"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${node}" "chmod +x /etc/keepalived/check_haproxy.sh"

  echo "[${node} 4/5] 下发 keepalived.conf"
  push_file "${node}" "${keepalived_conf}" "/etc/keepalived/keepalived.conf"

  echo "[${node} 5/5] 启动 haproxy 和 keepalived"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${node}" "bash -s" <<'EOF'
set -euo pipefail
systemctl enable --now haproxy
systemctl enable --now keepalived
systemctl restart haproxy keepalived
systemctl is-active haproxy
systemctl is-active keepalived
EOF
}

main() {
  echo "========================================================="
  echo "开始部署 API Server 高可用入口"
  echo "VIP：${VIP}"
  echo "域名：api.qytk8s.com"
  echo "========================================================="

  require_local_files

  echo "[1/2] 配置 lb01"
  configure_node "lb01" "${KEEPALIVED_LB01}"

  echo "[2/2] 配置 lb02"
  configure_node "lb02" "${KEEPALIVED_LB02}"

  echo "OK: HAProxy + Keepalived 部署完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
