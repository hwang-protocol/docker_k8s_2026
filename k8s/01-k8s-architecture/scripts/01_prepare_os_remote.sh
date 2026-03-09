#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：01_prepare_os_remote.sh
# 适用场景：第一章第 1 步，批量初始化所有 Ubuntu 节点的系统基础环境
# 执行位置：ops 节点
# 设计原则：
# 1. 只使用主机名，不写 IP
# 2. 只做系统初始化，不安装 K8s 组件
# 3. 可以重复执行，尽量保持幂等
# ==============================================================================

# 说明：
# - 本脚本故意把主机名直接写死，方便课堂演示和学员复现。
# - 这些节点都是第一章当前需要初始化的 Ubuntu 节点。
ALL_NODES=(
  "lb01" "lb02"
  "cp01" "cp02" "cp03"
  "wk-app01" "wk-app02" "wk-edge01" "wk-obs01"
  "harbor" "git"
)

# 远程脚本说明：
# - 这里使用 heredoc 组装要发到远端执行的 Bash 代码。
# - 学员可以直接阅读这一段，理解“ops 通过 ssh 批量下发命令”的思路。
REMOTE_SCRIPT=$(cat <<'EOF'
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

wait_for_apt_lock() {
  local max_wait_seconds=180
  local waited=0

  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
     || fuser /var/lib/dpkg/lock >/dev/null 2>&1 \
     || fuser /var/cache/apt/archives/lock >/dev/null 2>&1 \
     || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    if (( waited >= max_wait_seconds )); then
      echo "apt/dpkg 锁等待超时，尝试终止自动更新相关进程..."
      pkill -f unattended-upgr >/dev/null 2>&1 || true
      pkill -f apt-daily >/dev/null 2>&1 || true
      pkill -f apt-get >/dev/null 2>&1 || true
      sleep 5
      break
    fi

    echo "等待 apt/dpkg 锁释放... (${waited}s/${max_wait_seconds}s)"
    sleep 3
    waited=$((waited + 3))
  done
}

run_apt_update() {
  local try

  for try in 1 2 3; do
    if apt-get -o DPkg::Lock::Timeout=600 -o Acquire::Retries=3 update -y; then
      return 0
    fi

    echo "apt-get update 第 ${try} 次失败，准备重试..."
    sleep 5
    dpkg --configure -a >/dev/null 2>&1 || true
    apt-get -f install -y >/dev/null 2>&1 || true
    wait_for_apt_lock
  done

  return 1
}

run_apt_install() {
  local try

  for try in 1 2 3; do
    if apt-get -o DPkg::Lock::Timeout=600 -o Acquire::Retries=3 install -y \
      apt-transport-https \
      ca-certificates \
      conntrack \
      curl \
      gpg \
      iproute2 \
      ipset \
      jq \
      multipath-tools \
      netcat-openbsd \
      open-iscsi \
      socat \
      tar \
      vim \
      wget; then
      return 0
    fi

    echo "apt-get install 第 ${try} 次失败，准备重试..."
    sleep 5
    dpkg --configure -a >/dev/null 2>&1 || true
    apt-get -f install -y >/dev/null 2>&1 || true
    wait_for_apt_lock
  done

  return 1
}

echo "[1/9] 关闭 swap"
swapoff -a || true
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

echo "[2/9] 加载内核模块"
cat >/etc/modules-load.d/k8s.conf <<'INNER'
overlay
br_netfilter
INNER
modprobe overlay || true
modprobe br_netfilter || true

echo "[3/9] 配置 sysctl"
cat >/etc/sysctl.d/99-kubernetes.conf <<'INNER'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
INNER
sysctl --system >/dev/null

echo "[4/9] 设置时区"
timedatectl set-timezone Asia/Shanghai

echo "[5/9] 优化 SSH 登录"
if grep -qE '^[#[:space:]]*UseDNS' /etc/ssh/sshd_config; then
  sed -ri 's/^[#[:space:]]*UseDNS.*/UseDNS no/' /etc/ssh/sshd_config
else
  echo 'UseDNS no' >>/etc/ssh/sshd_config
fi
systemctl restart ssh

echo "[6/9] 关闭 UFW"
systemctl disable --now ufw >/dev/null 2>&1 || true

echo "[7/9] 关闭自动更新，避免 apt 锁冲突"
systemctl disable --now unattended-upgrades.service >/dev/null 2>&1 || true
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true
systemctl stop unattended-upgrades.service apt-daily.service apt-daily-upgrade.service >/dev/null 2>&1 || true
systemctl mask unattended-upgrades.service >/dev/null 2>&1 || true
wait_for_apt_lock

echo "[8/9] 安装基础工具"
run_apt_update
run_apt_install

echo "[9/9] 启动 Longhorn 依赖服务"
systemctl enable --now iscsid >/dev/null 2>&1 || true

echo "hostname=$(hostname)"
echo "swap_status=$(swapon --show | wc -l)"
echo "timezone=$(timedatectl show --property=Timezone --value)"
echo "dns=$(resolvectl dns ens160 | awk '{print $NF}')"
echo "gateway=$(ip route show default | awk '/default/ {print $3}' | head -n1)"
echo "OK"
EOF
)

# 函数作用：
# - 接收一个主机名
# - 通过 ssh 登录远端
# - 在远端执行上面的系统初始化脚本
run_remote() {
  local node="$1"

  echo "========================================================="
  echo "节点：${node}"
  echo "========================================================="
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${node}" "bash -s" <<<"${REMOTE_SCRIPT}"
  echo
}

# 主函数作用：
# - 依次遍历所有节点
# - 逐台执行系统初始化
main() {
  local node
  local target_nodes=()

  if (( $# > 0 )); then
    target_nodes=("$@")
  else
    target_nodes=("${ALL_NODES[@]}")
  fi

  for node in "${target_nodes[@]}"; do
    run_remote "${node}"
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
