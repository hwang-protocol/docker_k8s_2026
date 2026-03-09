#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：08_kubeadm_init_remote.sh
# 适用场景：第一章第 8 步，在 cp01 初始化第一个控制平面
# 执行位置：ops 节点
# 说明：
# 1. kubeadm 初始化配置文件存放在 manifests/kubeadm-init-cp01.yaml
# 2. cp01 通过 HTTP 从 ops 直接下载该配置文件
# 3. kubeadm init 完成后，admin.conf 会拷回 ops
# ==============================================================================

MANIFEST_URL="http://ops:9000/01-k8s-architecture/manifests/kubeadm-init-cp01.yaml"

echo "========================================================="
echo "开始初始化第一个控制平面 cp01"
echo "========================================================="

echo "[1/4] cp01 从 ops HTTP 服务下载 kubeadm 初始化配置"
ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@cp01 \
  "curl -fsSL ${MANIFEST_URL} -o /root/kubeadm-init.yaml"

echo "[2/4] 在 cp01 执行 kubeadm init"
ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@cp01 "bash -s" <<'EOF'
set -euo pipefail

if [[ -f /etc/kubernetes/admin.conf ]]; then
  kubeadm reset -f
  rm -rf /etc/cni/net.d /etc/kubernetes /var/lib/etcd /root/.kube
fi

kubeadm init \
  --config /root/kubeadm-init.yaml \
  --upload-certs

mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chmod 600 /root/.kube/config

kubeadm token create --print-join-command >/root/kubeadm-join-worker.sh
kubeadm token create --print-join-command --certificate-key "$(kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -n 1)" >/root/kubeadm-join-control-plane.sh

kubectl get nodes -o wide
EOF

echo "[3/4] 将 admin.conf 拷回 ops，配置 kubectl"
mkdir -p /root/.kube
scp -o StrictHostKeyChecking=no root@cp01:/etc/kubernetes/admin.conf /root/.kube/config
chmod 600 /root/.kube/config

echo "[4/4] 在 ops 验证 kubectl"
kubectl get nodes -o wide
echo "OK: cp01 初始化完成"
