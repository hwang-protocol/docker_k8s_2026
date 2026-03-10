#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：03_install_longhorn.sh
# 适用场景：第四章第 3 步，安装 Longhorn 并初始化首批 3 个存储节点
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/04-storage-and-stateful"
CHART_URL="http://ops:9000/04-storage-and-stateful/artifacts/longhorn-1.11.0.tgz"
VALUES_FILE="${CHAPTER_DIR}/manifests/01_longhorn_values.yaml"
INITIAL_NODES=("wk-app01" "wk-app02" "wk-obs01")
DISK_CONFIG='[{"path":"/var/lib/longhorn","allowScheduling":true}]'

kubectl_retry() {
  local max_retries=5
  local try

  for try in $(seq 1 "${max_retries}"); do
    if kubectl "$@"; then
      return 0
    fi
    echo "kubectl 命令失败，${try}/${max_retries} 次重试后继续 …"
    sleep 3
  done

  kubectl "$@"
}

install_helm() {
  if command -v helm &>/dev/null; then
    echo "Helm 已安装: $(helm version --short)"
    return 0
  fi

  echo "正在安装 Helm …"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  helm version --short
}

label_initial_storage_nodes() {
  local node
  for node in "${INITIAL_NODES[@]}"; do
    echo "标记 Longhorn 初始存储节点：${node}"
    kubectl_retry label node "${node}" node.longhorn.io/create-default-disk=config --overwrite
    kubectl_retry annotate node "${node}" node.longhorn.io/default-disks-config="${DISK_CONFIG}" --overwrite
  done
}

main() {
  echo "========================================================="
  echo "开始安装 Longhorn"
  echo "首批存储节点：${INITIAL_NODES[*]}"
  echo "========================================================="

  echo "[0/6] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/6] 安装 Helm（如未安装）"
  install_helm

  echo "[2/6] 预创建并标记 longhorn-system 命名空间"
  kubectl create namespace longhorn-system --dry-run=client -o yaml | kubectl_retry apply -f -
  kubectl_retry label namespace longhorn-system \
    pod-security.kubernetes.io/enforce=privileged \
    pod-security.kubernetes.io/audit=privileged \
    pod-security.kubernetes.io/warn=privileged \
    --overwrite

  echo "[3/6] 标记首批 Longhorn 存储节点"
  label_initial_storage_nodes

  echo "[4/6] Helm 安装 Longhorn"
  helm upgrade --install longhorn "${CHART_URL}" \
    --namespace longhorn-system \
    --create-namespace \
    -f "${VALUES_FILE}"

  echo "[5/6] 等待 Longhorn 核心组件就绪"
  kubectl -n longhorn-system rollout status ds/longhorn-manager --timeout=600s
  kubectl -n longhorn-system rollout status deploy/longhorn-driver-deployer --timeout=600s
  kubectl -n longhorn-system rollout status deploy/longhorn-ui --timeout=600s
  kubectl -n longhorn-system wait --for=condition=Ready pod --all --timeout=600s

  echo "[6/6] 查看 Longhorn 初始状态"
  kubectl get sc
  kubectl -n longhorn-system get pods -o wide
  kubectl -n longhorn-system get nodes.longhorn.io

  echo "OK: Longhorn 已安装，首批 3 个存储节点已初始化"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
