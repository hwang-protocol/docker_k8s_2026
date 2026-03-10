#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：11_build_and_push_images_remote.sh
# 适用场景：在 git 节点构建并推送 QYTANG NetDevOps 镜像
# 执行位置：ops 节点
# ==============================================================================

IMAGE_TAG="${IMAGE_TAG:-v0.1.0}"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
HARBOR_URL="https://harbor.qytk8s.com"
HARBOR_PROJECT="qytang-netdevops"
GITEA_REPO_URL="https://git.qytk8s.com/gitadmin/qytang-netdevops.git"


wait_for_gitea_on_git_node() {
  echo "[3/5] 等待 git 节点上的 Gitea 与仓库接口就绪"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@git \
    "for i in \$(seq 1 30); do \
       if curl -k -s --connect-timeout 3 https://git.qytk8s.com/api/v1/version >/dev/null 2>&1 && \
          curl -k -s -u 'gitadmin:Gitea12345' --connect-timeout 3 https://git.qytk8s.com/api/v1/repos/gitadmin/qytang-netdevops >/dev/null 2>&1; then \
         echo '  Gitea 与仓库接口已就绪'; \
         exit 0; \
       fi; \
       sleep 3; \
     done; \
     echo 'ERROR: 等待 Gitea 或仓库接口超时'; \
     exit 1"
}


clone_latest_repo_on_git_node() {
  echo "[4/5] 拉取最新仓库"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@git \
    "rm -rf /opt/qytang-netdevops-src && \
     for i in \$(seq 1 10); do \
       GIT_SSL_CAINFO=/root/harbor-ca.crt git clone ${GITEA_REPO_URL} /opt/qytang-netdevops-src && exit 0; \
       echo '  git clone 失败，等待 3 秒后重试'; \
       rm -rf /opt/qytang-netdevops-src; \
       sleep 3; \
     done; \
     echo 'ERROR: 多次重试后仍无法从 Gitea 拉取仓库'; \
     exit 1"
}

main() {
  echo "========================================================="
  echo "构建并推送 QYTANG NetDevOps 镜像"
  echo "========================================================="

  echo "[1/4] 确保 Harbor 项目存在"
  local http_code
  http_code="$(
    curl -k -s -o /tmp/qytang_netdevops_project.json -w '%{http_code}' \
      -u 'admin:Harbor12345' \
      -H 'Content-Type: application/json' \
      -X POST "${HARBOR_URL}/api/v2.0/projects" \
      -d "{\"project_name\":\"${HARBOR_PROJECT}\",\"public\":true}"
  )"
  if [[ "${http_code}" != "201" && "${http_code}" != "409" ]]; then
    echo "ERROR: 创建 Harbor 项目失败，HTTP ${http_code}"
    exit 1
  fi

  echo "[2/4] 准备 git 节点上的 Docker 信任与登录"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@git \
    "mkdir -p /etc/docker/certs.d/harbor.qytk8s.com && \
     cp /root/harbor-ca.crt /etc/docker/certs.d/harbor.qytk8s.com/ca.crt && \
     systemctl restart docker && \
     docker login harbor.qytk8s.com -u admin -p Harbor12345"

  wait_for_gitea_on_git_node
  clone_latest_repo_on_git_node

  echo "[5/5] 构建并推送四个镜像"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@git \
    "cd /opt/qytang-netdevops-src && \
     docker build -f deploy/docker/frontend/Dockerfile -t harbor.qytk8s.com/qytang-netdevops/frontend:${IMAGE_TAG} . && \
     docker build -f deploy/docker/device-service/Dockerfile -t harbor.qytk8s.com/qytang-netdevops/device-service:${IMAGE_TAG} . && \
     docker build -f deploy/docker/resource-service/Dockerfile -t harbor.qytk8s.com/qytang-netdevops/resource-service:${IMAGE_TAG} . && \
     docker build -f deploy/docker/audit-service/Dockerfile -t harbor.qytk8s.com/qytang-netdevops/audit-service:${IMAGE_TAG} . && \
     docker push harbor.qytk8s.com/qytang-netdevops/frontend:${IMAGE_TAG} && \
     docker push harbor.qytk8s.com/qytang-netdevops/device-service:${IMAGE_TAG} && \
     docker push harbor.qytk8s.com/qytang-netdevops/resource-service:${IMAGE_TAG} && \
     docker push harbor.qytk8s.com/qytang-netdevops/audit-service:${IMAGE_TAG}"

  echo "OK: 四个镜像已推送到 Harbor，标签为 ${IMAGE_TAG}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
