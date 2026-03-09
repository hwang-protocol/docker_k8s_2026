#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：03_push_k8s_images_remote.sh
# 适用场景：第一章第 3 步，将 Kubernetes v1.33.9 核心镜像推送到 Harbor
# 执行位置：ops 节点
# 说明：
# 1. 本脚本只处理第一章需要的 K8s 基础镜像
# 2. 所有版本已经固定写死，保证快照恢复后重复执行结果一致
# 3. 目标 Harbor 项目为 k8s
# ==============================================================================

HARBOR_NODE="harbor"
HARBOR_DOMAIN="harbor.qytk8s.com"
HARBOR_PROJECT="k8s"
HARBOR_USERNAME="admin"
HARBOR_PASSWORD="Harbor12345"

create_harbor_project() {
  local http_code

  http_code=$(curl -k -s -o /tmp/harbor_project_create.json -w '%{http_code}' \
    -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
    -H 'Content-Type: application/json' \
    -X POST \
    "https://${HARBOR_DOMAIN}/api/v2.0/projects" \
    -d "{\"project_name\":\"${HARBOR_PROJECT}\",\"public\":true}")

  if [[ "${http_code}" == "201" || "${http_code}" == "409" ]]; then
    echo "Harbor 项目 ${HARBOR_PROJECT} 已就绪"
  else
    echo "创建 Harbor 项目失败，HTTP 状态码：${http_code}"
    cat /tmp/harbor_project_create.json || true
    exit 1
  fi
}

push_images_on_remote() {
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@${HARBOR_NODE}" "bash -s" <<'EOF'
set -euo pipefail

HARBOR_DOMAIN="harbor.qytk8s.com"
HARBOR_PROJECT="k8s"
HARBOR_USERNAME="admin"
HARBOR_PASSWORD="Harbor12345"

SOURCE_IMAGES=(
  "registry.k8s.io/kube-apiserver:v1.33.9"
  "registry.k8s.io/kube-controller-manager:v1.33.9"
  "registry.k8s.io/kube-scheduler:v1.33.9"
  "registry.k8s.io/kube-proxy:v1.33.9"
  "registry.k8s.io/pause:3.10"
  "registry.k8s.io/etcd:3.5.24-0"
  "registry.k8s.io/coredns/coredns:v1.12.0"
)

TARGET_IMAGES=(
  "harbor.qytk8s.com/k8s/kube-apiserver:v1.33.9"
  "harbor.qytk8s.com/k8s/kube-controller-manager:v1.33.9"
  "harbor.qytk8s.com/k8s/kube-scheduler:v1.33.9"
  "harbor.qytk8s.com/k8s/kube-proxy:v1.33.9"
  "harbor.qytk8s.com/k8s/pause:3.10"
  "harbor.qytk8s.com/k8s/etcd:3.5.24-0"
  "harbor.qytk8s.com/k8s/coredns:v1.12.0"
)

echo "${HARBOR_PASSWORD}" | docker login "${HARBOR_DOMAIN}" -u "${HARBOR_USERNAME}" --password-stdin

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

main() {
  echo "========================================================="
  echo "开始预热 Kubernetes v1.33.9 核心镜像"
  echo "目标 Harbor：${HARBOR_DOMAIN}/${HARBOR_PROJECT}"
  echo "========================================================="

  echo "[1/2] 创建 Harbor 项目"
  create_harbor_project

  echo "[2/2] 在 harbor 节点拉取并推送核心镜像"
  push_images_on_remote

  echo "OK: Kubernetes 核心镜像已推送到 Harbor"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
