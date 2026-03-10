# 第 4 步：安装 Longhorn

## 本步目标

完成 `Longhorn` 安装，并把下面 3 个节点初始化为首批存储节点：

- `wk-app01`
- `wk-app02`
- `wk-obs01`

## 为什么这一步先只纳入 3 个节点

这一章不是一开始就讲扩容，而是先把主线跑稳：

- `StorageClass`
- `PVC`
- 动态供给
- 3 副本
- Pod 重建后数据仍保留

所以安装阶段先固定 3 个节点，后面再把 `wk-edge01` 作为第 4 个节点加入。

## 本步脚本

- `k8s/04-storage-and-stateful/scripts/03_install_longhorn.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/03_install_longhorn.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/03_install_longhorn.sh
```

## 这一步做了什么

脚本会按下面顺序执行：

1. 自动检查并恢复集群连通性
2. 安装 `Helm`
3. 创建并标记 `longhorn-system`
4. 给 `wk-app01`、`wk-app02`、`wk-obs01` 打上 Longhorn 默认磁盘标签与注解
5. 使用本地 Chart 安装 `Longhorn 1.11.0`
6. 等待 Longhorn 核心组件就绪
7. 查看 `StorageClass` 和 Longhorn 节点状态

## 关键机制说明

这一章不是在 Longhorn UI 里手工点盘，而是提前通过 Kubernetes 节点：

- `label`
- `annotation`

告诉 Longhorn：

- 哪些节点现在就要创建默认磁盘
- 默认磁盘路径就是 `/var/lib/longhorn`

这样更适合课堂复现，也更利于后面讲第 4 个节点怎么加入。

## 执行后的检查

```bash
kubectl -n longhorn-system get pods -o wide
```

```bash
kubectl get sc
```

```bash
kubectl -n longhorn-system get nodes.longhorn.io
```

预期：

- `longhorn-manager` 正常
- `longhorn-driver-deployer` 正常
- `longhorn-ui` 正常
- 存在 `longhorn` StorageClass
- Longhorn 节点里至少能看到首批 3 个存储节点已经可用

## 本步完成标准

- Longhorn 核心 Pod 均正常
- `longhorn` StorageClass 已出现
- `wk-app01`、`wk-app02`、`wk-obs01` 已被 Longhorn 正常识别

## 下一步

进入第 5 步，验证 PVC 动态供给与数据保留：

- `docs/06_default_storageclass_and_test_pvc.md`
