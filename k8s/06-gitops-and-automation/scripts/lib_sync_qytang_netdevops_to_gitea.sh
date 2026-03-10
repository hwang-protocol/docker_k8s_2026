#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：lib_sync_qytang_netdevops_to_gitea.sh
# 适用场景：把主仓中的 apps/qytang-netdevops 导出并同步到 Gitea
# 说明：本脚本供 10/16/17 等脚本 source 使用，不直接单独执行
# ==============================================================================

APP_DIR="/docker_k8s_2026/apps/qytang-netdevops"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
REPO_URL="https://git.qytk8s.com/gitadmin/qytang-netdevops.git"
PUSH_URL="https://gitadmin:Gitea12345@git.qytk8s.com/gitadmin/qytang-netdevops.git"
TMP_REPO_DIR="/tmp/qytang-netdevops-publish"


prepare_temp_repo() {
  rm -rf "${TMP_REPO_DIR}"
  if git -c http.sslCAInfo="${CA_CERT}" ls-remote "${REPO_URL}" >/dev/null 2>&1; then
    git -c http.sslCAInfo="${CA_CERT}" clone "${PUSH_URL}" "${TMP_REPO_DIR}" >/dev/null 2>&1
  else
    mkdir -p "${TMP_REPO_DIR}"
    git -C "${TMP_REPO_DIR}" init -b main >/dev/null
    git -C "${TMP_REPO_DIR}" remote add origin "${REPO_URL}"
  fi
}


clean_export_tree() {
  python3 - <<'PY'
from pathlib import Path
import shutil

repo = Path("/tmp/qytang-netdevops-publish")
for child in repo.iterdir():
    if child.name == ".git":
        continue
    if child.is_dir():
        shutil.rmtree(child)
    else:
        child.unlink()
PY
}


copy_app_tree() {
  python3 - <<'PY'
from pathlib import Path
import shutil

source = Path("/docker_k8s_2026/apps/qytang-netdevops")
target = Path("/tmp/qytang-netdevops-publish")
ignore_names = {".git", ".venv", "__pycache__", "data"}
ignore_suffixes = {".pyc", ".db", ".sqlite3", ".log"}

for item in source.rglob("*"):
    relative = item.relative_to(source)
    if any(part in ignore_names for part in relative.parts):
        continue
    if item.is_file() and item.suffix in ignore_suffixes:
        continue
    destination = target / relative
    if item.is_dir():
        destination.mkdir(parents=True, exist_ok=True)
        continue
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(item, destination)
PY
}


sync_app_repo_to_gitea() {
  local commit_subject="$1"
  local commit_body="$2"

  prepare_temp_repo
  clean_export_tree
  copy_app_tree

  git -C "${TMP_REPO_DIR}" add .
  if [[ -n "$(git -C "${TMP_REPO_DIR}" status --porcelain)" ]]; then
    git -C "${TMP_REPO_DIR}" commit -m "$(cat <<EOF
${commit_subject}

${commit_body}
EOF
)"
    git -C "${TMP_REPO_DIR}" -c http.sslCAInfo="${CA_CERT}" push -u "${PUSH_URL}" main
    echo "OK: 已同步最新应用内容到 ${REPO_URL}"
  else
    echo "没有新的应用变更需要同步到 Gitea"
  fi
}
