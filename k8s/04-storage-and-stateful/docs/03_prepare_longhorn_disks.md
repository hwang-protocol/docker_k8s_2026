# 第 2 步：在 Linux 内初始化 Longhorn 数据盘

## 本步目标

把 4 个工作节点上的新数据盘统一初始化为：

- 设备：`/dev/sdb`
- 分区：`/dev/sdb1`
- 文件系统：`ext4`
- 挂载点：`/var/lib/longhorn`

## 为什么要先做这一步

`Longhorn` 不会替你在宿主机里自动分区和格式化磁盘。

所以在安装 Longhorn 之前，必须先把宿主机的真实存储路径准备好。

本章固定采用：

```text
/var/lib/longhorn
```

这样后面 Longhorn 节点标签、默认磁盘配置和课堂讲解都能保持一致。

## 本步脚本

- `k8s/04-storage-and-stateful/scripts/01_prepare_longhorn_disks.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/01_prepare_longhorn_disks.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/01_prepare_longhorn_disks.sh
```

## 这一步做了什么

脚本会按下面顺序执行：

1. 自动检查并恢复集群连通性
2. 依次登录 `wk-app01`、`wk-app02`、`wk-obs01`、`wk-edge01`
3. 检查 `/dev/sdb` 是否存在
4. 创建 `/dev/sdb1`
5. 将其格式化为 `ext4`
6. 写入 `/etc/fstab`
7. 挂载到 `/var/lib/longhorn`
8. 检查 `nfs-common` 是否存在
9. 关闭 `multipathd`
10. 加载 `dm_crypt`
11. 确保 `iscsid` 服务仍然为 `active`

## 执行后的检查

建议至少抽查 `wk-app01` 和 `wk-obs01`。

```bash
ssh root@wk-app01 'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin bash --noprofile --norc -c "lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE"'
```

```bash
ssh root@wk-obs01 'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin bash --noprofile --norc -c "df -h /var/lib/longhorn"'
```

预期：

- 能看到 `sdb1`
- `sdb1` 文件系统为 `ext4`
- `/var/lib/longhorn` 已挂载
- `multipathd` 不再运行

说明：

- 如果 `nfs-common` 缺失，Longhorn 可能仍会显示宿主机告警
- 但这 **不影响本章基于 `RWO` 的 PVC 与数据保留演示**

## 本步完成标准

- 4 个工作节点都已存在 `/var/lib/longhorn`
- 新增数据盘都已挂载成功
- `iscsid` 仍为 `active`

## 下一步

进入第 3 步，准备 Longhorn Chart 和 Harbor 镜像：

- `docs/04_prepare_longhorn_artifacts.md`
