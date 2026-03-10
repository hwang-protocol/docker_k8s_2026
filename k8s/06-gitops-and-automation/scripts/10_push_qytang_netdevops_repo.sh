#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：10_push_qytang_netdevops_repo.sh
# 适用场景：把应用目录独立初始化并首推到 Gitea
# 执行位置：ops 节点
# ==============================================================================

APP_DIR="/docker_k8s_2026/apps/qytang-netdevops"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
REPO_URL="https://git.qytk8s.com/gitadmin/qytang-netdevops.git"
PUSH_URL="https://gitadmin:Gitea12345@git.qytk8s.com/gitadmin/qytang-netdevops.git"

main() {
  echo "========================================================="
  echo "首推 QYTANG NetDevOps 到 Gitea"
  echo "========================================================="

  if [[ ! -d "${APP_DIR}/.git" ]]; then
    echo "[1/5] 初始化独立 Git 仓库"
    git -C "${APP_DIR}" init -b main
  else
    echo "[1/5] 独立 Git 仓库已存在"
  fi

  echo "[2/5] 配置 origin"
  git -C "${APP_DIR}" remote remove origin 2>/dev/null || true
  git -C "${APP_DIR}" remote add origin "${REPO_URL}"

  echo "[3/5] 加入版本控制"
  git -C "${APP_DIR}" add .

  echo "[4/5] 提交变更"
  if [[ -n "$(git -C "${APP_DIR}" status --porcelain)" ]]; then
    git -C "${APP_DIR}" commit -m "$(cat <<'EOF'
feat(gitops): 推送QYTANG NetDevOps教学仓库

补齐第六章样板工程源码、部署清单和 GitOps 素材，作为后续 Argo CD 同步事实源。
EOF
)"
  else
    echo "没有新的本地变更，跳过 commit"
  fi

  echo "[5/5] 推送到 Gitea"
  git -C "${APP_DIR}" -c http.sslCAInfo="${CA_CERT}" push -u "${PUSH_URL}" main

  echo "OK: 应用仓库已推送到 ${REPO_URL}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
