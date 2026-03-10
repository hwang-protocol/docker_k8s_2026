#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：16_release_frontend_gitops.sh
# 适用场景：课堂演示“改代码 -> 构建镜像 -> GitOps 自动发布”
# 执行位置：ops 节点
# 说明：
# 1. 先手工修改 apps/qytang-netdevops 下的前端代码
# 2. 再修改下面 VERSION 变量
# 3. 执行本脚本即可完成源码提交、镜像构建推送、values 回写、Argo CD 观察
# ==============================================================================

APP_DIR="/docker_k8s_2026/apps/qytang-netdevops"
ROOT_DIR="/docker_k8s_2026"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
ARGOCD_NS="argocd"
APP_NS="qytang-netdevops"
APP_NAME="qytang-netdevops"
SITE_DOMAIN="netdevops.qytk8s.com"
SITE_IP="10.1.1.60"
source "/docker_k8s_2026/k8s/06-gitops-and-automation/scripts/lib_sync_qytang_netdevops_to_gitea.sh"

# 课堂上只需要改这里
VERSION="${VERSION:-v0.1.6}"
SOURCE_COMMIT_SUBJECT="${SOURCE_COMMIT_SUBJECT:-feat(ui): 发布课堂演示代码}"
SOURCE_COMMIT_BODY="${SOURCE_COMMIT_BODY:-更新前端页面内容，用于验证 GitOps 自动发布效果。}"
VERIFY_TEXT="${VERIFY_TEXT:-}"

require_changes() {
  if [[ -z "$(git -C "${ROOT_DIR}" status --porcelain -- "apps/qytang-netdevops")" ]]; then
    echo "ERROR: 当前没有检测到代码变更。请先修改应用代码，再执行脚本。"
    exit 1
  fi
}

commit_source_changes() {
  echo "[1/7] 提交源码变更到 Gitea"
  sync_app_repo_to_gitea "${SOURCE_COMMIT_SUBJECT}" "${SOURCE_COMMIT_BODY}"
}

build_and_push_image() {
  echo "[2/7] 在 git 节点构建并推送前端镜像 ${VERSION}"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@git \
    "rm -rf /opt/qytang-netdevops-src && \
     GIT_SSL_CAINFO=/root/harbor-ca.crt git clone https://git.qytk8s.com/gitadmin/qytang-netdevops.git /opt/qytang-netdevops-src && \
     cd /opt/qytang-netdevops-src && \
     docker build -f deploy/docker/frontend/Dockerfile -t harbor.qytk8s.com/qytang-netdevops/frontend:${VERSION} . && \
     docker push harbor.qytk8s.com/qytang-netdevops/frontend:${VERSION}"
}

update_values_files() {
  echo "[3/7] 回写 GitOps tag 到 values"
  VERSION="${VERSION}" python3 - <<'PY'
from pathlib import Path
import os

version = os.environ["VERSION"]
targets = [
    Path("/docker_k8s_2026/apps/qytang-netdevops/deploy/helm/qytang-netdevops/values.yaml"),
    Path("/docker_k8s_2026/apps/qytang-netdevops/deploy/helm/qytang-netdevops/values-lab.yaml"),
    Path("/docker_k8s_2026/apps/qytang-netdevops/deploy/gitops/lab/values-lab.yaml"),
]

for path in targets:
    lines = path.read_text(encoding="utf-8").splitlines()
    in_frontend = False
    updated = []
    for line in lines:
        stripped = line.strip()
        if stripped == "frontend:":
            in_frontend = True
            updated.append(line)
            continue
        if in_frontend and stripped.endswith(":") and stripped != "image:":
            in_frontend = False
        if in_frontend and stripped.startswith("tag:"):
            indent = line[: len(line) - len(line.lstrip())]
            updated.append(f"{indent}tag: {version}")
            continue
        updated.append(line)
    path.write_text("\n".join(updated) + "\n", encoding="utf-8")
PY
}

commit_values_changes() {
  echo "[4/7] 提交新的 GitOps tag"
  sync_app_repo_to_gitea \
    "feat(gitops): 发布前端镜像${VERSION}" \
    "将前端镜像标签切换到 ${VERSION}，用于验证课堂演示改动的自动发布效果。"
}

wait_for_argocd() {
  echo "[5/7] 触发并观察 Argo CD 同步"
  kubectl -n "${ARGOCD_NS}" annotate application "${APP_NAME}" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
  for _ in $(seq 1 30); do
    sync_status="$(kubectl -n "${ARGOCD_NS}" get application "${APP_NAME}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health_status="$(kubectl -n "${ARGOCD_NS}" get application "${APP_NAME}" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    current_image="$(kubectl -n "${APP_NS}" get deploy frontend -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
    echo "sync=${sync_status:-unknown} health=${health_status:-unknown} image=${current_image:-unknown}"
    if [[ "${sync_status}" == "Synced" && "${health_status}" == "Healthy" && "${current_image}" == *":${VERSION}" ]]; then
      return 0
    fi
    sleep 10
  done
  echo "ERROR: 等待 Argo CD 同步超时"
  exit 1
}

show_result() {
  echo "[6/7] 输出观察命令"
  echo "Argo CD: https://argocd.qytk8s.com"
  echo "应用地址: https://${SITE_DOMAIN}"
  echo "Argo CD 账号: admin / Cisc0123"
  echo
  kubectl -n "${ARGOCD_NS}" get application "${APP_NAME}" -o wide
  echo
  kubectl -n "${APP_NS}" get deploy frontend -o wide
}

verify_page() {
  echo "[7/7] 验证页面"
  if [[ -n "${VERIFY_TEXT}" ]]; then
    local html
    html="$(curl --resolve "${SITE_DOMAIN}:443:${SITE_IP}" --cacert "${CA_CERT}" -s "https://${SITE_DOMAIN}/")"
    if [[ "${html}" == *"${VERIFY_TEXT}"* ]]; then
      echo "OK: 页面中已检测到文本: ${VERIFY_TEXT}"
    else
      echo "WARNING: 页面中未检测到文本: ${VERIFY_TEXT}"
    fi
  else
    curl --resolve "${SITE_DOMAIN}:443:${SITE_IP}" --cacert "${CA_CERT}" -I -s "https://${SITE_DOMAIN}/" | sed -n '1,5p'
  fi
}

main() {
  echo "========================================================="
  echo "课堂 GitOps 演示：改代码发布"
  echo "目标版本：${VERSION}"
  echo "========================================================="
  require_changes
  commit_source_changes
  build_and_push_image
  update_values_files
  commit_values_changes
  wait_for_argocd
  show_result
  verify_page
  echo "OK: 代码变更已通过 GitOps 发布完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
