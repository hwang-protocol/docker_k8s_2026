#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：06_config_containerd_harbor_remote.sh
# 适用场景：第一章第 6 步，让所有 K8s 节点的 containerd 信任 Harbor
# 执行位置：ops 节点
# ==============================================================================

K8S_NODES=(
  "cp01" "cp02" "cp03"
  "wk-app01" "wk-app02" "wk-edge01" "wk-obs01"
)

HARBOR_DOMAIN="harbor.qytk8s.com"
HARBOR_CA_LOCAL="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
PAUSE_IMAGE="harbor.qytk8s.com/k8s/pause:3.10"

copy_ca() {
  local node="$1"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${node}" "mkdir -p /etc/containerd/certs.d/${HARBOR_DOMAIN}"
  scp -o StrictHostKeyChecking=no "${HARBOR_CA_LOCAL}" "root@${node}:/etc/containerd/certs.d/${HARBOR_DOMAIN}/ca.crt"
}

configure_remote() {
  local node="$1"

  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${node}" "bash -s" <<EOF
set -euo pipefail

mkdir -p /etc/containerd/certs.d/${HARBOR_DOMAIN}

cat >/etc/containerd/certs.d/${HARBOR_DOMAIN}/hosts.toml <<INNER
server = "https://${HARBOR_DOMAIN}"

[host."https://${HARBOR_DOMAIN}"]
  capabilities = ["pull", "resolve"]
  ca = "/etc/containerd/certs.d/${HARBOR_DOMAIN}/ca.crt"
INNER

sed -ri 's#config_path = ""#config_path = "/etc/containerd/certs.d"#' /etc/containerd/config.toml
sed -ri 's#sandbox_image = ".*"#sandbox_image = "${PAUSE_IMAGE}"#' /etc/containerd/config.toml

systemctl restart containerd

grep -n 'config_path = "/etc/containerd/certs.d"' /etc/containerd/config.toml
grep -n 'sandbox_image = "' /etc/containerd/config.toml | head -n1
systemctl is-active containerd
EOF
}

main() {
  local node

  if [[ ! -f "${HARBOR_CA_LOCAL}" ]]; then
    echo "缺少 Harbor CA 证书：${HARBOR_CA_LOCAL}"
    exit 1
  fi

  for node in "${K8S_NODES[@]}"; do
    echo "========================================================="
    echo "节点：${node}"
    echo "========================================================="
    copy_ca "${node}"
    configure_remote "${node}"
    echo
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
