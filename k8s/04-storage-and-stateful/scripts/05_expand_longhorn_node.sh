#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：05_expand_longhorn_node.sh
# 适用场景：第四章第 6 步，把 wk-edge01 初始化为第 4 个 Longhorn 存储节点
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/04-storage-and-stateful"
TARGET_NODE="wk-edge01"
DISK_CONFIG='[{"path":"/var/lib/longhorn","allowScheduling":true}]'

wait_for_longhorn_disk() {
  local attempts=36
  local i
  local disk_path=""

  for i in $(seq 1 "${attempts}"); do
    disk_path="$(kubectl -n longhorn-system get nodes.longhorn.io "${TARGET_NODE}" -o yaml 2>/dev/null \
      | awk '/path: /{print $2; exit}')"
    if [[ "${disk_path}" == "/var/lib/longhorn" ]]; then
      echo "Longhorn 已识别 ${TARGET_NODE} 的数据盘：${disk_path}"
      return 0
    fi
    echo "等待 Longhorn 识别 ${TARGET_NODE} 的数据盘（第 ${i}/${attempts} 次）…"
    sleep 5
  done

  return 1
}

fallback_patch_longhorn_node() {
  echo "自动识别超时，改用 Longhorn Node CR 补丁方式初始化节点数据盘"
  kubectl -n longhorn-system patch nodes.longhorn.io "${TARGET_NODE}" --type merge -p '{
    "spec": {
      "allowScheduling": true,
      "disks": {
        "disk-sdb": {
          "allowScheduling": true,
          "diskDriver": "",
          "diskType": "filesystem",
          "evictionRequested": false,
          "path": "/var/lib/longhorn",
          "storageReserved": 0,
          "tags": []
        }
      }
    }
  }'
}

main() {
  echo "========================================================="
  echo "开始把 ${TARGET_NODE} 初始化为 Longhorn 存储节点"
  echo "========================================================="

  echo "[0/4] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/4] 为 ${TARGET_NODE} 打 Longhorn 默认磁盘标签与注解"
  kubectl label node "${TARGET_NODE}" node.longhorn.io/create-default-disk=config --overwrite
  kubectl annotate node "${TARGET_NODE}" node.longhorn.io/default-disks-config="${DISK_CONFIG}" --overwrite

  echo "[2/4] 等待 Longhorn 自动识别 ${TARGET_NODE} 的默认数据盘"
  if ! wait_for_longhorn_disk; then
    fallback_patch_longhorn_node
    wait_for_longhorn_disk
  fi

  echo "[3/4] 查看 Longhorn 节点状态"
  kubectl -n longhorn-system get nodes.longhorn.io

  echo "[4/4] 查看 ${TARGET_NODE} 详情"
  kubectl -n longhorn-system get nodes.longhorn.io "${TARGET_NODE}" -o yaml

  echo "OK: 已把 ${TARGET_NODE} 初始化为第 4 个 Longhorn 存储节点"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
