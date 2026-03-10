#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：99_bootstrap_chapter6.sh
# 适用场景：第六章当前阶段一把梭铺环境
# 执行位置：ops 节点
# ==============================================================================

BASE_DIR="/docker_k8s_2026/k8s/06-gitops-and-automation/scripts"

main() {
  echo "========================================================="
  echo "第六章一把梭：QYT NetDevOps + Gitea + Harbor + Argo CD"
  echo "========================================================="

  bash "${BASE_DIR}/00_check_and_recover_cluster.sh"
  bash "${BASE_DIR}/01_run_local_preview.sh"
  bash "${BASE_DIR}/02_verify_local_preview.sh"
  bash "${BASE_DIR}/03_verify_chapter6.sh"
  bash "${BASE_DIR}/04_verify_docker_assets.sh"
  bash "${BASE_DIR}/05_verify_gitops_assets.sh"
  bash "${BASE_DIR}/06_verify_phase2_assets.sh"
  bash "${BASE_DIR}/07_install_gitea_remote.sh"
  bash "${BASE_DIR}/08_create_gitea_repo.sh"
  bash "${BASE_DIR}/09_verify_gitea.sh"
  bash "${BASE_DIR}/10_push_qytang_netdevops_repo.sh"
  bash "${BASE_DIR}/11_build_and_push_images_remote.sh"
  bash "${BASE_DIR}/12_install_argocd_and_sync.sh"
  bash "${BASE_DIR}/13_verify_gitops_e2e.sh"
  bash "${BASE_DIR}/14_publish_netdevops_https_domain.sh"
  bash "${BASE_DIR}/15_configure_argocd_domain.sh"

  echo "OK: 第六章 GitOps 链路已铺好"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
