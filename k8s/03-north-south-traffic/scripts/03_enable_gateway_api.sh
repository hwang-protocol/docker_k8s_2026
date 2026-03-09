#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：03_enable_gateway_api.sh
# 适用场景：第三章第 3 步，为现有 Cilium 开启 Gateway API
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/03-north-south-traffic"
CHAPTER2_DIR="/docker_k8s_2026/k8s/02-cloud-native-networking"
GATEWAY_API_CRD_URL="http://ops:9000/03-north-south-traffic/artifacts/gateway-api-standard-install-v1.4.1.yaml"
CILIUM_CHART="${CHAPTER2_DIR}/artifacts/cilium-1.19.1.tgz"
CILIUM_BASE_VALUES="${CHAPTER2_DIR}/manifests/cilium-values.yaml"
CILIUM_GATEWAY_VALUES="${CHAPTER_DIR}/manifests/03_cilium_gateway_values.yaml"

install_helm() {
  if command -v helm &>/dev/null; then
    echo "Helm 已安装: $(helm version --short)"
    return 0
  fi

  echo "正在安装 Helm …"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  helm version --short
}

main() {
  echo "========================================================="
  echo "开始为 Cilium 启用 Gateway API"
  echo "========================================================="

  echo "[0/7] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/7] 安装 Helm（如未安装）"
  install_helm

  echo "[2/7] 校验 Cilium Helm Chart"
  if [[ ! -f "${CILIUM_CHART}" ]]; then
    echo "失败: 未找到 ${CILIUM_CHART}"
    echo "请先完成第二章第 1 步，确保 cilium chart 已缓存到本地"
    exit 1
  fi

  echo "[3/7] 安装 Gateway API 标准 CRD"
  kubectl apply -f "${GATEWAY_API_CRD_URL}"

  echo "[4/7] 等待 Gateway API CRD 建立完成"
  kubectl wait --for=condition=Established crd/gatewayclasses.gateway.networking.k8s.io --timeout=120s
  kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io --timeout=120s
  kubectl wait --for=condition=Established crd/httproutes.gateway.networking.k8s.io --timeout=120s
  kubectl wait --for=condition=Established crd/referencegrants.gateway.networking.k8s.io --timeout=120s

  echo "[5/7] Helm 升级 Cilium，开启 Gateway API"
  helm upgrade cilium "${CILIUM_CHART}" \
    --namespace kube-system \
    -f "${CILIUM_BASE_VALUES}" \
    -f "${CILIUM_GATEWAY_VALUES}"

  echo "[6/7] 重启 Cilium 组件以加载新的 gateway 配置"
  kubectl -n kube-system rollout restart ds/cilium
  kubectl -n kube-system rollout restart deploy/cilium-operator
  kubectl -n kube-system rollout status ds/cilium --timeout=300s
  kubectl -n kube-system rollout status deploy/cilium-operator --timeout=300s

  echo "[7/7] 查看 Gateway API 状态"
  cilium status --wait
  kubectl get gatewayclass

  echo "OK: Cilium Gateway API 已启用"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
