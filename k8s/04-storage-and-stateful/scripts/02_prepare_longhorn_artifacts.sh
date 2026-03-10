#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：02_prepare_longhorn_artifacts.sh
# 适用场景：第四章第 2 步，固化 Longhorn Chart 并把镜像推送到 Harbor
# 执行位置：ops 节点
# 说明：
# 1. Longhorn 安装继续采用“Chart 本地化 + 镜像 Harbor 化”
# 2. 所有后续安装都尽量不依赖课堂当下临时访问公网
# ==============================================================================

HARBOR_NODE="harbor"
HARBOR_DOMAIN="harbor.qytk8s.com"
HARBOR_USERNAME="admin"
HARBOR_PASSWORD="Harbor12345"

HARBOR_PROJECT_LONGHORN="longhornio"
HARBOR_PROJECT_DEMO="storage"

CHAPTER_DIR="/docker_k8s_2026/k8s/04-storage-and-stateful"
ARTIFACTS_DIR="${CHAPTER_DIR}/artifacts"
VALUES_FILE="${CHAPTER_DIR}/manifests/01_longhorn_values.yaml"

LONGHORN_VERSION="1.11.0"
CHART_PACKAGE="${ARTIFACTS_DIR}/longhorn-${LONGHORN_VERSION}.tgz"
RENDERED_MANIFEST="${ARTIFACTS_DIR}/longhorn-rendered-${LONGHORN_VERSION}.yaml"
SOURCE_IMAGE_LIST="${ARTIFACTS_DIR}/longhorn-source-images-${LONGHORN_VERSION}.txt"
TARGET_IMAGE_LIST="${ARTIFACTS_DIR}/longhorn-harbor-images-${LONGHORN_VERSION}.txt"

DEMO_SOURCE_IMAGE="docker.io/library/busybox:1.36.1"
DEMO_TARGET_IMAGE="${HARBOR_DOMAIN}/${HARBOR_PROJECT_DEMO}/busybox:1.36.1"

K8S_NODES=(
  "cp01" "cp02" "cp03"
  "wk-app01" "wk-app02" "wk-edge01" "wk-obs01"
)

remote_bash() {
  local node="$1"
  local script="$2"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${node}" \
    "env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin bash --noprofile --norc -s" <<<"${script}"
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

create_harbor_project() {
  local project_name="$1"
  local http_code

  http_code=$(curl -k -s -o "/tmp/harbor_${project_name}_create.json" -w '%{http_code}' \
    -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
    -H 'Content-Type: application/json' \
    -X POST \
    "https://${HARBOR_DOMAIN}/api/v2.0/projects" \
    -d "{\"project_name\":\"${project_name}\",\"public\":true}")

  if [[ "${http_code}" == "201" || "${http_code}" == "409" ]]; then
    echo "Harbor 项目 ${project_name} 已就绪"
  else
    echo "创建 Harbor 项目 ${project_name} 失败，HTTP 状态码：${http_code}"
    sed -n '1,120p' "/tmp/harbor_${project_name}_create.json" || true
    exit 1
  fi
}

prepare_local_dirs() {
  mkdir -p "${ARTIFACTS_DIR}"
}

download_longhorn_chart() {
  helm repo add longhorn https://charts.longhorn.io >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1
  rm -f "${CHART_PACKAGE}"
  helm pull longhorn/longhorn --version "${LONGHORN_VERSION}" --destination "${ARTIFACTS_DIR}"
}

extract_source_images() {
  tar -xOf "${CHART_PACKAGE}" longhorn/values.yaml \
    | awk '
        /^[[:space:]]*repository:/ {
          repo=$2
          gsub(/"/, "", repo)
        }
        /^[[:space:]]*tag:/ {
          tag=$2
          gsub(/"/, "", tag)
          if (repo != "" && repo != "~" && tag != "" && tag != "~") {
            print repo ":" tag
          }
          repo=""
          tag=""
        }
      ' \
    | sort -u > "${SOURCE_IMAGE_LIST}"

  echo "${DEMO_SOURCE_IMAGE}" >> "${SOURCE_IMAGE_LIST}"
  sort -u -o "${SOURCE_IMAGE_LIST}" "${SOURCE_IMAGE_LIST}"
}

render_longhorn_manifest() {
  helm template longhorn "${CHART_PACKAGE}" \
    --namespace longhorn-system \
    -f "${VALUES_FILE}" > "${RENDERED_MANIFEST}"
}

build_target_image_list() {
  : > "${TARGET_IMAGE_LIST}"
  while IFS= read -r image; do
    [[ -z "${image}" ]] && continue
    if [[ "${image}" == "${DEMO_SOURCE_IMAGE}" ]]; then
      echo "${DEMO_TARGET_IMAGE}" >> "${TARGET_IMAGE_LIST}"
      continue
    fi
    image="${image#docker.io/}"
    echo "${HARBOR_DOMAIN}/${image}" >> "${TARGET_IMAGE_LIST}"
  done < "${SOURCE_IMAGE_LIST}"
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

  remote_bash "${HARBOR_NODE}" "${remote_script}"
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
    remote_bash "${node}" "${remote_script}"
    echo
  done
}

verify_local_artifacts() {
  ls -lh "${CHART_PACKAGE}"
  ls -lh "${RENDERED_MANIFEST}"
  ls -lh "${SOURCE_IMAGE_LIST}"
  ls -lh "${TARGET_IMAGE_LIST}"
}

main() {
  echo "========================================================="
  echo "开始预热第四章存储制品"
  echo "Longhorn 版本：${LONGHORN_VERSION}"
  echo "Harbor 项目：${HARBOR_PROJECT_LONGHORN} / ${HARBOR_PROJECT_DEMO}"
  echo "========================================================="

  echo "[0/8] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/8] 准备本地目录"
  prepare_local_dirs

  echo "[2/8] 安装 Helm"
  install_helm

  echo "[3/8] 创建 Harbor 项目"
  create_harbor_project "${HARBOR_PROJECT_LONGHORN}"
  create_harbor_project "${HARBOR_PROJECT_DEMO}"

  echo "[4/8] 下载 Longhorn Chart"
  download_longhorn_chart

  echo "[5/8] 生成 Longhorn 镜像列表与离线渲染清单"
  extract_source_images
  render_longhorn_manifest
  build_target_image_list

  echo "[6/8] 在 harbor 节点拉取并推送镜像"
  push_images_on_harbor

  echo "[7/8] 在所有 Kubernetes 节点预拉镜像"
  pre_pull_images_on_nodes

  echo "[8/8] 本地制品检查"
  verify_local_artifacts

  echo "OK: 第四章存储制品预热完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
