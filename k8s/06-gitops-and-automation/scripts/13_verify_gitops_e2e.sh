#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：13_verify_gitops_e2e.sh
# 适用场景：验证 Git -> Harbor -> Argo CD -> K8s 全链路
# 执行位置：ops 节点
# ==============================================================================

CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
GITEA_URL="https://git.qytk8s.com"
HARBOR_URL="https://harbor.qytk8s.com"
ARGOCD_NS="argocd"
APP_NS="qytang-netdevops"
NETDEVOPS_DOMAIN="netdevops.qytk8s.com"
NETDEVOPS_IP="10.1.1.60"
ARGOCD_DOMAIN="argocd.qytk8s.com"
ARGOCD_IP="10.1.1.50"

main() {
  echo "========================================================="
  echo "验证第六章 GitOps 端到端链路"
  echo "========================================================="

  echo "[1/6] 查看 Gitea 仓库"
  curl --cacert "${CA_CERT}" -s "${GITEA_URL}/api/v1/repos/gitadmin/qytang-netdevops"
  echo
  echo

  echo "[2/6] 查看 Harbor 项目与制品"
  curl -k -s -u 'admin:Harbor12345' "${HARBOR_URL}/api/v2.0/projects/qytang-netdevops/repositories?page_size=20"
  echo
  echo

  echo "[3/6] 查看 Argo CD 应用状态"
  kubectl -n "${ARGOCD_NS}" get application qytang-netdevops -o wide

  echo "[4/6] 查看业务命名空间资源"
  kubectl -n "${APP_NS}" get pods,svc -o wide

  echo "[5/6] 访问正式业务入口"
  echo "业务域名: ${NETDEVOPS_DOMAIN} -> ${NETDEVOPS_IP}"
  curl --resolve "${NETDEVOPS_DOMAIN}:443:${NETDEVOPS_IP}" \
    --cacert "${CA_CERT}" \
    -s "https://${NETDEVOPS_DOMAIN}/api/device/api/v1/dashboard/summary"
  echo

  echo "[6/6] 输出 Argo CD 登录信息"
  echo "Argo CD 域名: ${ARGOCD_DOMAIN} -> ${ARGOCD_IP}"
  curl --resolve "${ARGOCD_DOMAIN}:443:${ARGOCD_IP}" \
    --cacert "${CA_CERT}" \
    -I -s "https://${ARGOCD_DOMAIN}/healthz" | sed -n '1,3p'
  printf 'admin '
  printf 'Cisc0123'
  echo

  echo "OK: GitOps 端到端验证通过"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
