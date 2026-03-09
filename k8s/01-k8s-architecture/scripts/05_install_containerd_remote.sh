#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：05_install_containerd_remote.sh
# 适用场景：第一章第 5 步，在所有 K8s 节点安装 containerd
# 执行位置：ops 节点
# ==============================================================================

K8S_NODES=(
  "cp01" "cp02" "cp03"
  "wk-app01" "wk-app02" "wk-edge01" "wk-obs01"
)

REMOTE_SCRIPT=$(cat <<'EOF'
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "[1/4] 安装 containerd"
apt-get update -y
apt-get install -y containerd

echo "[2/4] 生成默认配置文件"
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml

echo "[3/4] 设置 SystemdCgroup = true"
sed -ri 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

echo "[4/4] 启动 containerd 并设置开机自启"
systemctl enable --now containerd
systemctl restart containerd

containerd --version
containerd config dump | grep SystemdCgroup | head -n1
systemctl is-active containerd
echo "OK"
EOF
)

run_remote() {
  local node="$1"

  echo "========================================================="
  echo "节点：${node}"
  echo "========================================================="
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${node}" "bash -s" <<<"${REMOTE_SCRIPT}"
  echo
}

main() {
  local node

  for node in "${K8S_NODES[@]}"; do
    run_remote "${node}"
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
