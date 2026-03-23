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
# - 这些节点都是第一章当前需要初始化的 Ubuntu 节点（含 ops）。
# - 这里列出的都是 Linux 节点；Windows 节点不参与本脚本。
ALL_NODES=(
  "ops"
  "lb01" "lb02"
  "cp01" "cp02" "cp03"
  "wk-app01" "wk-app02" "wk-edge01" "wk-obs01"
  "harbor" "git"
)

# 远程脚本说明：
# - 这里使用 heredoc 组装要发到远端执行的 Bash 代码。
# - 学员可以直接阅读这一段，理解“ops 通过 ssh 批量下发命令”的思路。
# - REMOTE_SCRIPT 本质上是一段完整的 Bash 程序，后面会通过 ssh 直接喂给远端 shell。
REMOTE_SCRIPT=$(cat <<'EOF'
set -euo pipefail

# 避免 apt 在非交互环境下弹出界面阻塞脚本。
export DEBIAN_FRONTEND=noninteractive

# 课程环境经常会遇到 Ubuntu 后台自动更新占用 apt/dpkg 锁。
# 这个函数会循环等待；如果超过上限仍未释放，就尝试结束相关后台进程。
# 这样做的目的不是“暴力修机器”，而是保证课堂初始化过程可继续推进。
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

# update 和 install 分开封装，便于分别重试。
# 每次失败后会尝试修复半完成的 dpkg 状态，再继续等待锁释放。
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

# 这里只安装“基础运行环境”需要的包，不安装 kubeadm、kubelet、kubectl。
# 课程把系统初始化和 Kubernetes 组件安装拆成两个步骤，便于定位问题。
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

# 第 1 步：把默认启动目标切到纯 CLI，减少图形相关服务带来的启动等待。
# 同时禁用一些课程环境不需要的后台服务，让开机更快、状态更稳定。
echo "[1/10] 优化启动速度"
systemctl set-default multi-user.target 2>/dev/null || true
systemctl mask e2scrub_reap.service 2>/dev/null || true
systemctl disable snapd.service snapd.socket snapd.seeded 2>/dev/null || true
systemctl disable update-notifier-download.service apport.service 2>/dev/null || true

# 第 2 步：Kubernetes 默认要求关闭 swap。
# 这里既关闭当前 swap，也注释 /etc/fstab，避免重启后又自动挂回去。
echo "[2/10] 关闭 swap"
swapoff -a || true
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

# 第 3 步：提前加载容器网络和 overlay 文件系统依赖模块。
# 写入 modules-load.d 是为了让节点重启后还能自动加载。
echo "[3/10] 加载内核模块"
cat >/etc/modules-load.d/k8s.conf <<'INNER'
overlay
br_netfilter
INNER
modprobe overlay || true
modprobe br_netfilter || true

# 第 4 步：配置 Kubernetes 网络常用内核参数。
# 其中 ip_forward 是后续 Pod 网络转发的基础条件。
echo "[4/10] 配置 sysctl"
cat >/etc/sysctl.d/99-kubernetes.conf <<'INNER'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
INNER
sysctl --system >/dev/null

# 第 5 步：统一课程环境时区，避免日志时间、排错时间不一致。
echo "[5/10] 设置时区"
timedatectl set-timezone Asia/Shanghai

# 第 6 步：关闭 sshd 的 UseDNS，减少 SSH 登录时的反向解析等待。
# 这对课堂环境和批量脚本执行都很重要，否则每次 ssh 都可能“卡一下”。
echo "[6/10] 优化 SSH 登录"
if grep -qE '^[#[:space:]]*UseDNS' /etc/ssh/sshd_config; then
  sed -ri 's/^[#[:space:]]*UseDNS.*/UseDNS no/' /etc/ssh/sshd_config
else
  echo 'UseDNS no' >>/etc/ssh/sshd_config
fi
systemctl restart ssh

# 第 7 步：课程环境默认不使用 UFW，避免主机级防火墙干扰后续通信。
echo "[7/10] 关闭 UFW"
systemctl disable --now ufw >/dev/null 2>&1 || true

# 第 8 步：主动关闭自动更新相关服务，避免后续安装过程持续抢锁。
# 这一步配合 wait_for_apt_lock 使用，目标是让 apt 进入“可控状态”。
echo "[8/10] 关闭自动更新，避免 apt 锁冲突"
systemctl disable --now unattended-upgrades.service >/dev/null 2>&1 || true
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true
systemctl stop unattended-upgrades.service apt-daily.service apt-daily-upgrade.service >/dev/null 2>&1 || true
systemctl mask unattended-upgrades.service >/dev/null 2>&1 || true
wait_for_apt_lock

# 第 9 步：安装基础工具和后续章节会用到的公共依赖。
echo "[9/10] 安装基础工具"
run_apt_update
run_apt_install

# 第 10 步：提前启动 Longhorn 依赖服务，避免后面再补环境。
echo "[10/10] 启动 Longhorn 依赖服务"
systemctl enable --now iscsid >/dev/null 2>&1 || true

# 最后输出几项关键状态，方便从脚本日志快速判断当前节点是否达标。
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
# - 若为 ops（当前机），则本地执行；否则通过 ssh 登录远端
# - 在目标上执行系统初始化脚本
# - 这里统一打印分隔线，便于课堂演示时按节点阅读输出结果。
run_remote() {
  local node="$1"

  echo "========================================================="
  echo "节点：${node}"
  echo "========================================================="
  # ops 节点本机直接执行，避免自己 ssh 自己。
  if [[ "${node}" == "ops" ]] && [[ "$(hostname)" == "ops" ]]; then
    bash -s <<<"${REMOTE_SCRIPT}"
  else
    # 其他节点统一走 root 免密 SSH。
    # StrictHostKeyChecking=no 是为了避免第一次连接时卡在主机指纹确认。
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${node}" "bash -s" <<<"${REMOTE_SCRIPT}"
  fi
  echo
}

# 主函数作用：
# - 依次遍历所有节点
# - 逐台执行系统初始化
# - 如果传了参数，就只处理指定节点，便于单机补跑。
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
