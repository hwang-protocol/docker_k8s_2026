# 第 2 步：在 Linux 内初始化 Longhorn 数据盘

## 本步目标

把 4 个工作节点上的新数据盘统一初始化为：

- 设备：`/dev/sdb`
- 分区：`/dev/sdb1`
- 文件系统：`ext4`
- 挂载点：`/var/lib/longhorn`

---

## 执行标记

- **执行标记：必须执行**

说明：

- 这是第四章真正进入宿主机存储准备的一步
- 本步完成后，Longhorn 才有可识别的宿主机数据路径

---

## 问题背景

`Longhorn` 不会替你在宿主机里自动分区和格式化磁盘。

所以在安装 Longhorn 之前，必须先把宿主机的真实存储路径准备好。

本章固定采用：

```text
/var/lib/longhorn
```

这样后面 Longhorn 节点标签、默认磁盘配置和课堂讲解都能保持一致。

---

## 理论说明

### 宿主机准备关系图

```mermaid
flowchart LR
  sdb[磁盘<br/>/dev/sdb]
  part[分区<br/>/dev/sdb1]
  fs[ext4]
  mount[挂载点<br/>/var/lib/longhorn]
  longhorn[Longhorn 默认数据盘]

  sdb --> part
  part --> fs
  fs --> mount
  mount --> longhorn
```

这张图说明：

- `Longhorn` 最终识别和使用的是宿主机上的数据目录 `/var/lib/longhorn`
- 它不是直接按裸盘名字本身来使用存储

### 为什么这一步会顺手处理 `nfs-common`、`iscsid`、`multipathd`

虽然第四章主线演示的是 `RWO` 卷，但 Longhorn 宿主机准备通常还会涉及几个系统前提：

- `nfs-common`
  - 主要影响 RWX 相关能力
- `iscsid`
  - Longhorn 数据面需要的基础宿主机服务
- `multipathd`
  - 本章不存在多路径存储那种“同一块 LUN 有多条链路”的场景；如果保持启用，反而可能把普通数据盘额外映射成 `dm/mapper` 设备，增加磁盘识别复杂度，因此本章禁用
- `dm_crypt`
  - `dm_crypt` 是 Linux 磁盘加密相关内核模块；本章并不展开加密，只是顺手补齐 Longhorn 常见宿主机前提

这一步的教学重点不是把这些组件讲到最深，而是让学员知道：

- Kubernetes 存储不只是一条 `kubectl apply`
- 底层宿主机准备同样是存储主线的一部分

---

## 对应脚本

本步对应脚本：

- `k8s/04-storage-and-stateful/scripts/01_prepare_longhorn_disks.sh`

---

## 脚本关键任务

### 关键任务 1：在每个工作节点上处理 `/dev/sdb`

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
DEVICE="/dev/sdb"
PARTITION="/dev/sdb1"
MOUNT_POINT="/var/lib/longhorn"
```

关键介绍：

- 第四章固定使用 `/dev/sdb`
- 挂载点统一固定为 `/var/lib/longhorn`

### 关键任务 2：创建分区、格式化并挂载

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
printf ',,L\n' | sfdisk "${DEVICE}" >/dev/null
mkfs.ext4 -F -L LONGHORN "${PARTITION}" >/dev/null
mount "${PARTITION}" "${MOUNT_POINT}"
```

关键介绍：

- 先把整块新盘切成 `sdb1`
- 再格式化成 `ext4`
- 最终挂载到 Longhorn 固定路径

### 关键任务 3：写入 `/etc/fstab`

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
uuid="$(blkid -s UUID -o value "${PARTITION}")"
fstab_line="UUID=${uuid} ${MOUNT_POINT} ext4 defaults 0 2"
```

关键介绍：

- 不是做一次性挂载
- 而是把这条挂载关系固化到宿主机

### 关键任务 4：补齐宿主机前提

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
systemctl disable --now multipathd.service multipathd.socket >/dev/null 2>&1 || true
modprobe dm_crypt >/dev/null 2>&1 || true
systemctl enable --now iscsid >/dev/null 2>&1 || true
```

关键介绍：

- 本章禁用不需要的 `multipathd`
- 确保 `dm_crypt` 模块与 `iscsid` 服务处于可用状态

---

## 执行命令

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选预处理命令</strong><br/>
如果脚本已具备执行权限，这一步可以跳过。
</div>

```bash
chmod +x /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/01_prepare_longhorn_disks.sh
```

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #ea4335; border-radius: 6px; background: rgba(234,67,53,0.10); margin: 8px 0;">
<strong>❗ 本步必须粘贴执行</strong><br/>
下面命令是本步主线必跑命令。
</div>

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/01_prepare_longhorn_disks.sh
```

---

## 验证方法

建议至少抽查 `wk-app01` 和 `wk-obs01`。

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于抽查宿主机磁盘、挂载点与服务状态。
</div>

```bash
ssh root@wk-app01 'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin bash --noprofile --norc -c "lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE"'
```

```bash
ssh root@wk-obs01 'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin bash --noprofile --norc -c "df -h /var/lib/longhorn"'
```

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于继续抽查宿主机服务状态。
</div>

```bash
ssh root@wk-app01 'systemctl is-active iscsid'
```

预期结果：

- 能看到 `sdb1`
- `sdb1` 文件系统为 `ext4`
- `/var/lib/longhorn` 已挂载
- `iscsid` 为 `active`

关键看点：

- 重点不是“分区命令有没有执行过”
- 而是最终宿主机上是否已经形成可重复识别的数据路径

---

## 通过标准

- 4 个工作节点都已存在 `/var/lib/longhorn`
- 新增数据盘都已挂载成功
- `iscsid` 仍为 `active`

---

## 下一步

进入第 3 步，准备 Longhorn、MongoDB Chart 与 Harbor 镜像：

- `docs/04_prepare_longhorn_artifacts.md`
