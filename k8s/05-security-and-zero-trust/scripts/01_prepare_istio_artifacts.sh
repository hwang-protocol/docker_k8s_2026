#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：01_prepare_istio_artifacts.sh
# 适用场景：第五章第 1 步，预热 Istio 安装包、CLI、镜像与演示制品
# 执行位置：ops 节点
# ==============================================================================

HARBOR_NODE="harbor"
HARBOR_DOMAIN="harbor.qytk8s.com"
HARBOR_PROJECT="istio"
HARBOR_USERNAME="admin"
HARBOR_PASSWORD="Harbor12345"

CHAPTER_DIR="/docker_k8s_2026/k8s/05-security-and-zero-trust"
ARTIFACTS_DIR="${CHAPTER_DIR}/artifacts"
TMP_DIR="${CHAPTER_DIR}/tmp"

ISTIO_VERSION="1.29.0"
ISTIO_TAR="istio-${ISTIO_VERSION}-linux-amd64.tar.gz"
ISTIO_URL="https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/${ISTIO_TAR}"
ISTIO_HOME="${ARTIFACTS_DIR}/istio-${ISTIO_VERSION}"
ISTIOCTL_BIN="${ISTIO_HOME}/bin/istioctl"
SOURCE_IMAGE_LIST="${ARTIFACTS_DIR}/istio-source-images-${ISTIO_VERSION}.txt"
TARGET_IMAGE_LIST="${ARTIFACTS_DIR}/istio-harbor-images-${ISTIO_VERSION}.txt"

K8S_NODES=(
  "cp01" "cp02" "cp03"
  "wk-app01" "wk-app02" "wk-edge01" "wk-obs01"
)

prepare_local_dirs() {
  mkdir -p "${ARTIFACTS_DIR}" "${TMP_DIR}"
}

install_helm() {
  if command -v helm &>/dev/null; then
    echo "Helm 已安装: $(helm version --short)"
    return 0
  fi

  echo "正在安装 Helm …"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  helm version --short
}

download_istio_release() {
  if [[ -x "${ISTIOCTL_BIN}" ]]; then
    echo "本地 Istio 离线包已存在: ${ISTIO_HOME}"
    return 0
  fi

  rm -rf "${ISTIO_HOME}"
  curl -fsSL "${ISTIO_URL}" -o "${TMP_DIR}/${ISTIO_TAR}"
  tar -xzf "${TMP_DIR}/${ISTIO_TAR}" -C "${ARTIFACTS_DIR}"
}

install_istioctl() {
  install -m 0755 "${ISTIOCTL_BIN}" /usr/local/bin/istioctl
  istioctl version --remote=false
}

create_harbor_project() {
  local http_code

  http_code=$(curl -k -s -o "/tmp/harbor_${HARBOR_PROJECT}_create.json" -w '%{http_code}' \
    -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
    -H 'Content-Type: application/json' \
    -X POST \
    "https://${HARBOR_DOMAIN}/api/v2.0/projects" \
    -d "{\"project_name\":\"${HARBOR_PROJECT}\",\"public\":true}")

  if [[ "${http_code}" == "201" || "${http_code}" == "409" ]]; then
    echo "Harbor 项目 ${HARBOR_PROJECT} 已就绪"
  else
    echo "创建 Harbor 项目失败，HTTP 状态码：${http_code}"
    sed -n '1,120p' "/tmp/harbor_${HARBOR_PROJECT}_create.json" || true
    exit 1
  fi
}

build_image_lists() {
  cat >"${SOURCE_IMAGE_LIST}" <<'EOF'
docker.io/istio/pilot:1.29.0-distroless
docker.io/istio/proxyv2:1.29.0-distroless
docker.io/istio/ztunnel:1.29.0-distroless
docker.io/istio/install-cni:1.29.0-distroless
docker.io/istio/examples-helloworld-v1:1.0
docker.io/istio/examples-helloworld-v2:1.0
docker.io/mccutchen/go-httpbin:v2.15.0
docker.io/curlimages/curl:8.12.1
EOF

  cat >"${TARGET_IMAGE_LIST}" <<'EOF'
harbor.qytk8s.com/istio/pilot:1.29.0-distroless
harbor.qytk8s.com/istio/proxyv2:1.29.0-distroless
harbor.qytk8s.com/istio/ztunnel:1.29.0-distroless
harbor.qytk8s.com/istio/install-cni:1.29.0-distroless
harbor.qytk8s.com/istio/helloworld-v1:1.0
harbor.qytk8s.com/istio/helloworld-v2:1.0
harbor.qytk8s.com/istio/httpbin:v2.15.0
harbor.qytk8s.com/istio/curl:8.12.1
EOF
}

push_images_on_harbor() {
  local source_lines target_lines remote_script
  source_lines="$(sed 's/^/  "/; s/$/"/' "${SOURCE_IMAGE_LIST}")"
  target_lines="$(sed 's/^/  "/; s/$/"/' "${TARGET_IMAGE_LIST}")"

  read -r -d '' remote_script <<EOF || true
set -euo pipefail

HARBOR_DOMAIN="${HARBOR_DOMAIN}"
HARBOR_USERNAME="${HARBOR_USERNAME}"
HARBOR_PASSWORD="${HARBOR_PASSWORD}"

SOURCE_IMAGES=(
${source_lines}
)

TARGET_IMAGES=(
${target_lines}
)

echo "\${HARBOR_PASSWORD}" | docker login "\${HARBOR_DOMAIN}" -u "\${HARBOR_USERNAME}" --password-stdin >/dev/null

for index in "\${!SOURCE_IMAGES[@]}"; do
  src="\${SOURCE_IMAGES[\$index]}"
  dst="\${TARGET_IMAGES[\$index]}"
  echo "========================================================="
  echo "源镜像：\${src}"
  echo "目标镜像：\${dst}"
  echo "========================================================="
  docker pull "\${src}"
  docker tag "\${src}" "\${dst}"
  docker push "\${dst}"
done
EOF

  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${HARBOR_NODE}" \
    "env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin bash --noprofile --norc -s" <<<"${remote_script}"
}

pre_pull_images_on_nodes() {
  local image_lines remote_script node
  image_lines="$(sed 's/^/  "/; s/$/"/' "${TARGET_IMAGE_LIST}")"

  read -r -d '' remote_script <<EOF || true
set -euo pipefail

IMAGES=(
${image_lines}
)

for image in "\${IMAGES[@]}"; do
  echo "预拉镜像：\${image}"
  crictl --runtime-endpoint unix:///run/containerd/containerd.sock pull "\${image}"
done
EOF

  for node in "${K8S_NODES[@]}"; do
    echo "========================================================="
    echo "节点：${node}"
    echo "========================================================="
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${node}" \
      "env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin bash --noprofile --norc -s" <<<"${remote_script}"
    echo
  done
}

verify_local_artifacts() {
  ls -lh "${ISTIO_HOME}"
  ls -lh "${SOURCE_IMAGE_LIST}"
  ls -lh "${TARGET_IMAGE_LIST}"
}

main() {
  echo "========================================================="
  echo "开始预热第五章 Istio 制品"
  echo "Istio 版本：${ISTIO_VERSION}"
  echo "Harbor 项目：${HARBOR_DOMAIN}/${HARBOR_PROJECT}"
  echo "========================================================="

  echo "[0/8] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/8] 准备本地目录"
  prepare_local_dirs

  echo "[2/8] 安装 Helm"
  install_helm

  echo "[3/8] 下载 Istio 离线安装包"
  download_istio_release

  echo "[4/8] 安装 istioctl"
  install_istioctl

  echo "[5/8] 创建 Harbor 项目"
  create_harbor_project

  echo "[6/8] 整理镜像列表并推送到 Harbor"
  build_image_lists
  push_images_on_harbor

  echo "[7/8] 在 Kubernetes 节点预拉镜像"
  pre_pull_images_on_nodes

  echo "[8/8] 本地制品检查"
  verify_local_artifacts

  echo "OK: 第五章 Istio 制品预热完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
