#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：09_verify_gitea.sh
# 适用场景：只读验证 Gitea 与仓库状态
# 执行位置：ops 节点
# ==============================================================================

GITEA_URL="https://git.qytk8s.com"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"

main() {
  echo "========================================================="
  echo "验证 Gitea"
  echo "========================================================="

  echo "[1/3] 访问首页"
  curl --cacert "${CA_CERT}" -I -s "${GITEA_URL}" | sed -n '1,5p'

  echo "[2/3] 查看版本接口"
  curl --cacert "${CA_CERT}" -s "${GITEA_URL}/api/v1/version"
  echo

  echo "[3/3] 查看 git 节点上的容器"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@git "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

  echo "[bonus] 查看 Gitea 用户"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@git "docker exec -u git gitea gitea admin user list 2>/dev/null | sed -n '1,20p'"

  echo "OK: Gitea 验证通过"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
