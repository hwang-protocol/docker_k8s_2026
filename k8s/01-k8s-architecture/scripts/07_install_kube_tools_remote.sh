#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：07_install_kube_tools_remote.sh
# 适用场景：第一章第 7 步，安装 kubeadm / kubelet / kubectl
# 执行位置：ops 节点
# 说明：
# 1. K8s 节点安装 kubelet、kubeadm、kubectl
# 2. ops 本机安装 kubectl，方便后续课程在 ops 上管理集群
# 3. 版本固定为 Kubernetes v1.33.9
# ==============================================================================

K8S_NODES=(
  "cp01" "cp02" "cp03"
  "wk-app01" "wk-app02" "wk-edge01" "wk-obs01"
)

K8S_REPO_MINOR="v1.33"
K8S_PACKAGE_VERSION="1.33.9-1.1"
K8S_REPO_LINE="deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /"

REMOTE_SCRIPT=$(cat <<'EOF'
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes

cat >/etc/apt/sources.list.d/kubernetes.list <<'INNER'
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /
INNER

apt-get update -y

candidate_version=$(apt-cache madison kubeadm | awk 'NR==1 {print $3}')
if [[ "${candidate_version}" != "1.33.9-1.1" ]]; then
  echo "仓库候选版本不是 1.33.9-1.1，而是：${candidate_version}"
  exit 1
fi

apt-get install -y \
  kubelet=1.33.9-1.1 \
  kubeadm=1.33.9-1.1 \
  kubectl=1.33.9-1.1

apt-mark hold kubelet kubeadm kubectl

kubeadm version -o short
kubectl version --client
systemctl is-enabled kubelet
echo "OK"
EOF
)

install_on_ops() {
  mkdir -p /etc/apt/keyrings
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key" \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes

  cat >/etc/apt/sources.list.d/kubernetes.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /
EOF

  apt-get update -y

  local candidate_version
  candidate_version=$(apt-cache madison kubectl | awk 'NR==1 {print $3}')
  if [[ "${candidate_version}" != "${K8S_PACKAGE_VERSION}" ]]; then
    echo "ops 本机 kubectl 候选版本不是 ${K8S_PACKAGE_VERSION}，而是：${candidate_version}"
    exit 1
  fi

  apt-get install -y "kubectl=${K8S_PACKAGE_VERSION}"
  apt-mark hold kubectl

  kubectl version --client
}

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

  echo "========================================================="
  echo "先在 ops 本机安装 kubectl ${K8S_PACKAGE_VERSION}"
  echo "========================================================="
  install_on_ops
  echo

  for node in "${K8S_NODES[@]}"; do
    run_remote "${node}"
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
