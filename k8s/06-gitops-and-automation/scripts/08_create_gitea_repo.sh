#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：08_create_gitea_repo.sh
# 适用场景：在 Gitea 中创建 QYTANG NetDevOps 仓库
# 执行位置：ops 节点
# ==============================================================================

GITEA_URL="https://git.qytk8s.com"
GITEA_USER="gitadmin"
GITEA_PASSWORD="Gitea12345"
REPO_OWNER="gitadmin"
REPO_NAME="qytang-netdevops"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"

main() {
  echo "========================================================="
  echo "在 Gitea 中创建仓库"
  echo "========================================================="

  http_code=$(curl --cacert "${CA_CERT}" -s -o /tmp/gitea_create_repo.json -w "%{http_code}" \
    -u "${GITEA_USER}:${GITEA_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST "${GITEA_URL}/api/v1/user/repos" \
    -d "{
      \"name\": \"${REPO_NAME}\",
      \"description\": \"QYTANG NetDevOps 教学样板工程\",
      \"private\": false,
      \"auto_init\": false,
      \"default_branch\": \"main\"
    }")

  if [[ "${http_code}" == "201" || "${http_code}" == "409" ]]; then
    echo "仓库创建成功或已存在"
  else
    echo "失败: 创建仓库返回 HTTP ${http_code}"
    sed -n '1,120p' /tmp/gitea_create_repo.json || true
    return 1
  fi

  echo "仓库地址：${GITEA_URL}/${REPO_OWNER}/${REPO_NAME}.git"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
