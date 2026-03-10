#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：01_prepare_longhorn_disks.sh
# 适用场景：第四章第 1 步，在 4 个工作节点上初始化 Longhorn 数据盘
# 执行位置：ops 节点
# 设计约束：
# 1. 课程中固定使用新增数据盘 /dev/sdb
# 2. 固定挂载到 /var/lib/longhorn
# 3. 脚本需幂等，可重复执行
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/04-storage-and-stateful"
WORKER_NODES=("wk-app01" "wk-app02" "wk-obs01" "wk-edge01")

remote_bash() {
  local node="$1"
  local script="$2"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${node}" \
    "env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin bash --noprofile --norc -s" <<<"${script}"
}

prepare_disk_on_node() {
  local node="$1"
  local remote_script

  read -r -d '' remote_script <<'EOF' || true
set -euo pipefail

DEVICE="/dev/sdb"
PARTITION="/dev/sdb1"
MOUNT_POINT="/var/lib/longhorn"

echo "hostname=$(hostname)"

echo "补齐 Longhorn 宿主机前提"
if ! dpkg-query -W -f='${Status}\n' nfs-common 2>/dev/null | awk '/install ok installed/ {found=1} END{exit found ? 0 : 1}'; then
  echo "提示: 当前节点未安装 nfs-common，Longhorn 会保留 RWX 相关前置告警，但不影响本章 RWO 演示"
fi
systemctl disable --now multipathd.service multipathd.socket >/dev/null 2>&1 || true
modprobe dm_crypt >/dev/null 2>&1 || true

if [[ ! -b "${DEVICE}" ]]; then
  echo "失败: 未发现 ${DEVICE}，请先在 VMware 中确认数据盘是否已添加"
  exit 1
fi

mkdir -p "${MOUNT_POINT}"

if [[ ! -b "${PARTITION}" ]]; then
  echo "创建 ${DEVICE} 分区表与主分区"
  wipefs -a "${DEVICE}" >/dev/null 2>&1 || true
  printf ',,L\n' | sfdisk "${DEVICE}" >/dev/null
  partprobe "${DEVICE}" >/dev/null 2>&1 || true
  udevadm settle >/dev/null 2>&1 || true
  sleep 2
fi

fs_type="$(lsblk -no FSTYPE "${PARTITION}" 2>/dev/null || true)"
if [[ -z "${fs_type}" ]]; then
  echo "格式化 ${PARTITION} 为 ext4"
  mkfs.ext4 -F -L LONGHORN "${PARTITION}" >/dev/null
  udevadm settle >/dev/null 2>&1 || true
  sleep 2
fi

uuid="$(blkid -s UUID -o value "${PARTITION}")"
if [[ -z "${uuid}" ]]; then
  echo "失败: 无法获取 ${PARTITION} 的 UUID"
  exit 1
fi

fstab_line="UUID=${uuid} ${MOUNT_POINT} ext4 defaults 0 2"

if ! grep -q "UUID=${uuid} ${MOUNT_POINT} " /etc/fstab; then
  echo "写入 /etc/fstab"
  echo "${fstab_line}" >> /etc/fstab
fi

if ! mountpoint -q "${MOUNT_POINT}"; then
  echo "挂载 ${MOUNT_POINT}"
  mount "${PARTITION}" "${MOUNT_POINT}"
fi

systemctl enable --now iscsid >/dev/null 2>&1 || true

echo "--- lsblk ---"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE
echo "--- df ---"
df -h "${MOUNT_POINT}"
echo "OK"
EOF

  echo "========================================================="
  echo "节点：${node}"
  echo "========================================================="
  remote_bash "${node}" "${remote_script}"
  echo
}

main() {
  local node

  echo "========================================================="
  echo "开始初始化第四章 Longhorn 数据盘"
  echo "固定设备：/dev/sdb"
  echo "固定挂载点：/var/lib/longhorn"
  echo "========================================================="

  echo "[0/2] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/2] 在 4 个工作节点上准备 Longhorn 数据盘"
  for node in "${WORKER_NODES[@]}"; do
    prepare_disk_on_node "${node}"
  done

  echo "[2/2] 提示后续 Longhorn 节点策略"
  echo "首批 Longhorn 节点：wk-app01 wk-app02 wk-obs01"
  echo "后续扩容节点：wk-edge01"
  echo "OK: Longhorn 数据盘已准备完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
