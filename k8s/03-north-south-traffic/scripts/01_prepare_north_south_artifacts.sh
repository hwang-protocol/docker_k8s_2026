#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：01_prepare_north_south_artifacts.sh
# 适用场景：第三章第 1 步，预热 MetalLB / Gateway API / 演示镜像
# 执行位置：ops 节点
# 说明：
# 1. 本脚本会在 ops 上安装 Helm（如未安装）
# 2. 本脚本会把 MetalLB 镜像与演示镜像推送到 Harbor
# 3. 本脚本会把 MetalLB 与 Gateway API 上游 YAML 固化到本地 artifacts 目录
# 4. 第三章后续所有 YAML 继续通过 ops HTTP 服务发布
# ==============================================================================

HARBOR_NODE="harbor"
HARBOR_DOMAIN="harbor.qytk8s.com"
HARBOR_PROJECT="northsouth"
HARBOR_USERNAME="admin"
HARBOR_PASSWORD="Harbor12345"

CHAPTER_DIR="/docker_k8s_2026/k8s/03-north-south-traffic"
ARTIFACTS_DIR="${CHAPTER_DIR}/artifacts"
TMP_DIR="${CHAPTER_DIR}/tmp"

METALLB_VERSION="v0.15.3"
GATEWAY_API_VERSION="v1.4.1"

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

  http_code=$(curl -k -s -o /tmp/harbor_northsouth_project_create.json -w '%{http_code}' \
    -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
    -H 'Content-Type: application/json' \
    -X POST \
    "https://${HARBOR_DOMAIN}/api/v2.0/projects" \
    -d "{\"project_name\":\"${HARBOR_PROJECT}\",\"public\":true}")

  if [[ "${http_code}" == "201" || "${http_code}" == "409" ]]; then
    echo "Harbor 项目 ${HARBOR_PROJECT} 已就绪"
  else
    echo "创建 Harbor 项目失败，HTTP 状态码：${http_code}"
    sed -n '1,120p' /tmp/harbor_northsouth_project_create.json || true
    exit 1
  fi
}

prepare_local_dirs() {
  mkdir -p "${ARTIFACTS_DIR}" "${TMP_DIR}"
}

download_metallb_manifest() {
  local src="${TMP_DIR}/metallb-native-${METALLB_VERSION}.yaml"
  local dst="${ARTIFACTS_DIR}/metallb-native-${METALLB_VERSION}.yaml"

  curl -fsSL \
    "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml" \
    -o "${src}"

  sed \
    -e "s#quay.io/metallb/controller:${METALLB_VERSION}#${HARBOR_DOMAIN}/${HARBOR_PROJECT}/metallb-controller:${METALLB_VERSION}#g" \
    -e "s#quay.io/metallb/speaker:${METALLB_VERSION}#${HARBOR_DOMAIN}/${HARBOR_PROJECT}/metallb-speaker:${METALLB_VERSION}#g" \
    "${src}" >"${dst}"

  perl -0pi -e 's/nodeSelector:\n        kubernetes\.io\/os: linux\n      serviceAccountName: speaker/nodeSelector:\n        kubernetes.io\/os: linux\n        qytk8s.com\/node-role: edge\n      serviceAccountName: speaker/' "${dst}"
}

download_gateway_api_standard_install() {
  local dst="${ARTIFACTS_DIR}/gateway-api-standard-install-${GATEWAY_API_VERSION}.yaml"

  if curl -fsSL \
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml" \
    -o "${dst}"; then
    return 0
  fi

  echo "release 资产下载失败，改用 raw CRD 拼接标准安装文件 …"
  : >"${dst}"

  for file in \
    gateway.networking.k8s.io_gatewayclasses.yaml \
    gateway.networking.k8s.io_gateways.yaml \
    gateway.networking.k8s.io_httproutes.yaml \
    gateway.networking.k8s.io_referencegrants.yaml \
    gateway.networking.k8s.io_grpcroutes.yaml; do
    curl -fsSL \
      "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_API_VERSION}/config/crd/standard/${file}" \
      >>"${dst}"
    printf '\n---\n' >>"${dst}"
  done
}

push_images_on_harbor() {
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${HARBOR_NODE}" "bash -s" <<'EOF'
set -euo pipefail

HARBOR_DOMAIN="harbor.qytk8s.com"
HARBOR_PROJECT="northsouth"
HARBOR_USERNAME="admin"
HARBOR_PASSWORD="Harbor12345"

SOURCE_IMAGES=(
  "quay.io/metallb/controller:v0.15.3"
  "quay.io/metallb/speaker:v0.15.3"
  "docker.io/traefik/whoami:v1.10.3"
)

TARGET_IMAGES=(
  "harbor.qytk8s.com/northsouth/metallb-controller:v0.15.3"
  "harbor.qytk8s.com/northsouth/metallb-speaker:v0.15.3"
  "harbor.qytk8s.com/northsouth/whoami:v1.10.3"
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
  "harbor.qytk8s.com/northsouth/metallb-controller:v0.15.3"
  "harbor.qytk8s.com/northsouth/metallb-speaker:v0.15.3"
  "harbor.qytk8s.com/northsouth/whoami:v1.10.3"
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
  ls -lh "${ARTIFACTS_DIR}/metallb-native-${METALLB_VERSION}.yaml"
  ls -lh "${ARTIFACTS_DIR}/gateway-api-standard-install-${GATEWAY_API_VERSION}.yaml"
}

main() {
  echo "========================================================="
  echo "开始预热第三章北向入口制品"
  echo "MetalLB 版本：${METALLB_VERSION}"
  echo "Gateway API 版本：${GATEWAY_API_VERSION}"
  echo "Harbor 项目：${HARBOR_DOMAIN}/${HARBOR_PROJECT}"
  echo "========================================================="

  echo "[0/8] 集群连通性检查与恢复"
  bash "$(dirname "${BASH_SOURCE[0]}")/00_check_and_recover_cluster.sh"

  echo "[1/8] 准备本地目录"
  prepare_local_dirs

  echo "[2/8] 安装 Helm"
  install_helm

  echo "[3/8] 创建 Harbor 项目"
  create_harbor_project

  echo "[4/8] 下载并固化 MetalLB 原始清单"
  download_metallb_manifest

  echo "[5/8] 下载并固化 Gateway API 标准 CRD"
  download_gateway_api_standard_install

  echo "[6/8] 在 harbor 节点拉取并推送镜像"
  push_images_on_harbor

  echo "[7/8] 在所有 Kubernetes 节点预拉镜像"
  pre_pull_images_on_nodes

  echo "[8/8] 本地制品检查"
  verify_local_artifacts

  echo "OK: 第三章北向入口制品预热完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
