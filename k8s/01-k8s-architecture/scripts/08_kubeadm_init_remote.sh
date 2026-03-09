#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：08_kubeadm_init_remote.sh
# 适用场景：第一章第 8 步，在 cp01 初始化第一个控制平面
# 执行位置：ops 节点
# ==============================================================================

BASE_DIR="/docker_k8s_2026/k8s/01-k8s-architecture"
TMP_DIR="${BASE_DIR}/tmp"
CONFIG_FILE="${TMP_DIR}/kubeadm-init-cp01.yaml"

mkdir -p "${TMP_DIR}"

cat >"${CONFIG_FILE}" <<'EOF'
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 10.1.1.101
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  name: cp01
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v1.33.9
controlPlaneEndpoint: api.qytk8s.com:6443
imageRepository: harbor.qytk8s.com/k8s
networking:
  serviceSubnet: 10.96.0.0/12
  podSubnet: 10.244.0.0/16
  dnsDomain: cluster.local
apiServer:
  certSANs:
    - api.qytk8s.com
    - 10.1.1.10
    - cp01
    - cp02
    - cp03
    - 10.1.1.101
    - 10.1.1.102
    - 10.1.1.103
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF

scp -o StrictHostKeyChecking=no "${CONFIG_FILE}" root@cp01:/root/kubeadm-init.yaml

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

mkdir -p /root/.kube
scp -o StrictHostKeyChecking=no root@cp01:/etc/kubernetes/admin.conf /root/.kube/config
chmod 600 /root/.kube/config

kubectl get nodes -o wide
