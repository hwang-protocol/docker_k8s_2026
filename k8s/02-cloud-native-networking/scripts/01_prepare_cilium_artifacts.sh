#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：01_prepare_cilium_artifacts.sh
# 适用场景：第二章第 1 步，预热 Cilium / Hubble / Helm chart / 镜像
# 执行位置：ops 节点
# 说明：
# 1. 本脚本会在 ops 上安装 Helm、cilium CLI、hubble CLI
# 2. 本脚本会在 Harbor 中创建 cilium 项目并推送相关镜像
# 3. 第二章后续所有镜像统一优先从 harbor.qytk8s.com 拉取
# 4. 在所有 Kubernetes 节点预拉镜像，避免安装时网络抖动
#
# Harbor 说明：
#   Harbor 节点不做快照恢复，镜像推送步骤是幂等操作（已存在则秒跳过）。
#   保留该步骤的目的是完整记录如何将上游镜像搬运到私有仓库，供教学演示。
# ==============================================================================

HARBOR_NODE="harbor"
HARBOR_DOMAIN="harbor.qytk8s.com"
HARBOR_PROJECT="cilium"
HARBOR_USERNAME="admin"
HARBOR_PASSWORD="Harbor12345"

CHAPTER_DIR="/docker_k8s_2026/k8s/02-cloud-native-networking"
ARTIFACTS_DIR="${CHAPTER_DIR}/artifacts"
TMP_DIR="${CHAPTER_DIR}/tmp"

CILIUM_VERSION="1.19.1"
CILIUM_CLI_VERSION="v0.19.1"
HUBBLE_CLI_VERSION="v1.18.6"
ARCH="amd64"

K8S_NODES=(
  "cp01" "cp02" "cp03"
  "wk-app01" "wk-app02" "wk-edge01" "wk-obs01"
)

install_helm() {
  if command -v helm &>/dev/null; then
    echo "Helm 已安装: $(helm version --short)"
    return 0
  fi
  echo "正在安装 Helm …"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  helm version --short
}

create_harbor_project() {
  local http_code

  http_code=$(curl -k -s -o /tmp/harbor_cilium_project_create.json -w '%{http_code}' \
    -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
    -H 'Content-Type: application/json' \
    -X POST \
    "https://${HARBOR_DOMAIN}/api/v2.0/projects" \
    -d "{\"project_name\":\"${HARBOR_PROJECT}\",\"public\":true}")

  if [[ "${http_code}" == "201" || "${http_code}" == "409" ]]; then
    echo "Harbor 项目 ${HARBOR_PROJECT} 已就绪"
  else
    echo "创建 Harbor 项目失败，HTTP 状态码：${http_code}"
    sed -n '1,120p' /tmp/harbor_cilium_project_create.json || true
    exit 1
  fi
}

prepare_local_dirs() {
  mkdir -p "${ARTIFACTS_DIR}" "${TMP_DIR}" "${ARTIFACTS_DIR}/bin"
}

download_helm_chart() {
  if [[ ! -f "${ARTIFACTS_DIR}/cilium-${CILIUM_VERSION}.tgz" ]]; then
    helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
    helm repo update >/dev/null
    helm pull cilium/cilium --version "${CILIUM_VERSION}" --destination "${ARTIFACTS_DIR}"
  fi
}

install_cilium_cli() {
  if [[ ! -x /usr/local/bin/cilium ]]; then
    curl -fsSL \
      "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz" \
      -o "${ARTIFACTS_DIR}/bin/cilium-linux-${ARCH}.tar.gz"
    tar -xzf "${ARTIFACTS_DIR}/bin/cilium-linux-${ARCH}.tar.gz" -C "${ARTIFACTS_DIR}/bin" cilium
    install -m 0755 "${ARTIFACTS_DIR}/bin/cilium" /usr/local/bin/cilium
  fi
}

install_hubble_cli() {
  if [[ ! -x /usr/local/bin/hubble ]]; then
    curl -fsSL \
      "https://github.com/cilium/hubble/releases/download/${HUBBLE_CLI_VERSION}/hubble-linux-${ARCH}.tar.gz" \
      -o "${ARTIFACTS_DIR}/bin/hubble-linux-${ARCH}.tar.gz"
    tar -xzf "${ARTIFACTS_DIR}/bin/hubble-linux-${ARCH}.tar.gz" -C "${ARTIFACTS_DIR}/bin" hubble
    install -m 0755 "${ARTIFACTS_DIR}/bin/hubble" /usr/local/bin/hubble
  fi
}

push_images_on_harbor() {
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${HARBOR_NODE}" "bash -s" <<'EOF'
set -euo pipefail

HARBOR_DOMAIN="harbor.qytk8s.com"
HARBOR_PROJECT="cilium"
HARBOR_USERNAME="admin"
HARBOR_PASSWORD="Harbor12345"

SOURCE_IMAGES=(
  "quay.io/cilium/cilium:v1.19.1"
  "quay.io/cilium/operator-generic:v1.19.1"
  "quay.io/cilium/hubble-relay:v1.19.1"
  "quay.io/cilium/hubble-ui-backend:v0.13.3"
  "quay.io/cilium/hubble-ui:v0.13.3"
  "quay.io/cilium/certgen:v0.3.2"
  "docker.io/traefik/whoami:v1.10.3"
  "docker.io/curlimages/curl:8.12.1"
)

TARGET_IMAGES=(
  "harbor.qytk8s.com/cilium/cilium:v1.19.1"
  "harbor.qytk8s.com/cilium/operator-generic:v1.19.1"
  "harbor.qytk8s.com/cilium/hubble-relay:v1.19.1"
  "harbor.qytk8s.com/cilium/hubble-ui-backend:v0.13.3"
  "harbor.qytk8s.com/cilium/hubble-ui:v0.13.3"
  "harbor.qytk8s.com/cilium/certgen:v0.3.2"
  "harbor.qytk8s.com/cilium/whoami:v1.10.3"
  "harbor.qytk8s.com/cilium/curl:8.12.1"
)

echo "${HARBOR_PASSWORD}" | docker login "${HARBOR_DOMAIN}" -u "${HARBOR_USERNAME}" --password-stdin >/dev/null

for index in "${!SOURCE_IMAGES[@]}"; do
  src="${SOURCE_IMAGES[$index]}"
  dst="${TARGET_IMAGES[$index]}"

  echo "========================================================="
  echo "源镜像：${src}"
  echo "目标镜像：${dst}"
  echo "========================================================="

  docker pull "${src}"
  docker tag "${src}" "${dst}"
  docker push "${dst}"
done
EOF
}

pre_pull_images_on_nodes() {
  local node

  for node in "${K8S_NODES[@]}"; do
    echo "========================================================="
    echo "节点：${node}"
    echo "========================================================="

    ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${node}" "bash -s" <<'EOF'
set -euo pipefail

IMAGES=(
  "harbor.qytk8s.com/cilium/cilium:v1.19.1"
  "harbor.qytk8s.com/cilium/operator-generic:v1.19.1"
  "harbor.qytk8s.com/cilium/hubble-relay:v1.19.1"
  "harbor.qytk8s.com/cilium/hubble-ui-backend:v0.13.3"
  "harbor.qytk8s.com/cilium/hubble-ui:v0.13.3"
  "harbor.qytk8s.com/cilium/certgen:v0.3.2"
  "harbor.qytk8s.com/cilium/whoami:v1.10.3"
  "harbor.qytk8s.com/cilium/curl:8.12.1"
)

for image in "${IMAGES[@]}"; do
  echo "预拉镜像：${image}"
  crictl --runtime-endpoint unix:///run/containerd/containerd.sock pull "${image}"
done
EOF

    echo
  done
}

verify_local_artifacts() {
  ls -lh "${ARTIFACTS_DIR}/cilium-${CILIUM_VERSION}.tgz"
  cilium version --client
  hubble version
}

main() {
  echo "========================================================="
  echo "开始预热第二章 Cilium 制品"
  echo "Cilium 版本：${CILIUM_VERSION}"
  echo "Harbor 项目：${HARBOR_DOMAIN}/${HARBOR_PROJECT}"
  echo "========================================================="

  echo "[0/9] 集群连通性检查与恢复（快照恢复后 API 可能暂不可达）"
  bash "$(dirname "${BASH_SOURCE[0]}")/00_check_and_recover_cluster.sh"

  echo "[1/9] 准备本地目录"
  prepare_local_dirs

  echo "[2/9] 安装 Helm"
  install_helm

  echo "[3/9] 创建 Harbor 项目"
  create_harbor_project

  echo "[4/9] 下载 Helm chart"
  download_helm_chart

  echo "[5/9] 安装 cilium CLI"
  install_cilium_cli

  echo "[6/9] 安装 hubble CLI"
  install_hubble_cli

  echo "[7/9] 在 harbor 节点拉取并推送镜像"
  push_images_on_harbor

  echo "[8/9] 在所有 Kubernetes 节点预拉镜像"
  pre_pull_images_on_nodes

  echo "========================================================="
  echo "本地制品检查"
  echo "========================================================="
  verify_local_artifacts

  echo "OK: 第二章 Cilium 制品预热完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
