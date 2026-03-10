# 第四章总览：存储与有状态服务

## 本章目标

第四章的目标，是把前 3 章已经具备网络、入口和 HTTPS 能力的集群，推进到 **具备有状态工作负载承载能力** 的状态。

本章结束后，应达到下面状态：

- 4 个工作节点都已经挂好独立数据盘
- `Longhorn` 已安装完成
- 首批 3 个节点已作为 Longhorn 存储节点工作
- 应用可以通过 `PVC` 动态申请卷
- Pod 删除重建后，卷内数据仍保留
- `wk-edge01` 可以在后续步骤中作为第 4 个 Longhorn 节点加入
- `Longhorn UI` 可以通过 `win2019 + HTTPS + 域名` 访问

## 本章学习方式

这一章继续采用“文档主导 + 小脚本辅助 + 清单独立发布”的方式：

1. 登录 `ops`
2. 先看文档，再执行脚本
3. 所有 YAML 与 Chart 继续通过 `http://ops:9000/` 提供
4. 所有镜像继续统一走 `harbor.qytk8s.com`

## 课前理论导读

正式操作前，建议先阅读：

- `docs/00_storage_theory.md`

它负责先把第四章最容易混淆的几个点讲清楚：

- `PV / PVC / StorageClass`
- `Longhorn` 到底解决什么
- 为什么本章不先用 `Ceph`
- 为什么它也不同于传统 `iSCSI`
- 为什么这章采用“先 3 节点、再加第 4 节点”的节奏

## 本章重点边界

第四章只聚焦：

- `PVC`
- `StorageClass`
- `Longhorn`
- 有状态卷
- Pod 重建后的数据保留
- Longhorn 节点扩容

还不展开：

- 备份到外部对象存储
- 灾备演练
- 存储性能压测
- `Ceph` 的完整实施

这些内容放到后续增强章节或补充实验。

## 本章脚本执行矩阵

| 步骤 | 文档 | 脚本 | 执行标记 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| 0 | `00_storage_theory.md` | 无 | 建议先读 | Longhorn、Ceph、传统 iSCSI 理论对比 |
| 1 | `02_add_vmware_disks.md` | 无 | 人工前置 | 先在 VMware 中加 4 块数据盘 |
| 2 | `03_prepare_longhorn_disks.md` | `scripts/01_prepare_longhorn_disks.sh` | 必须执行 | 在 Linux 内初始化并挂载数据盘 |
| 3 | `04_prepare_longhorn_artifacts.md` | `scripts/02_prepare_longhorn_artifacts.sh` | 必须执行 | 固化 Longhorn Chart，推送镜像到 Harbor |
| 4 | `05_install_longhorn.md` | `scripts/03_install_longhorn.sh` | 必须执行 | 安装 Longhorn，初始化首批 3 个存储节点 |
| 5 | `06_default_storageclass_and_test_pvc.md` | `scripts/04_deploy_stateful_demo.sh` | 必须执行 | 验证 PVC 动态供给与数据保留 |
| 6 | `07_expand_longhorn_node.md` | `scripts/05_expand_longhorn_node.sh` | 必须执行 | 将 `wk-edge01` 作为第 4 个 Longhorn 节点加入 |
| 7 | `07a_publish_longhorn_ui.md` | `scripts/07_publish_longhorn_ui.sh` | 必须执行 | 把 Longhorn UI 正式发布为 `https://longhorn.qytk8s.com` |
| 8 | `08_verify.md` | `scripts/06_verify_storage.sh` | 只读验收 | 第四章最终验收 |

## 本章执行顺序

请严格按下面顺序执行：

0. `00_storage_theory.md`
1. `02_add_vmware_disks.md`
2. `03_prepare_longhorn_disks.md`
3. `04_prepare_longhorn_artifacts.md`
4. `05_install_longhorn.md`
5. `06_default_storageclass_and_test_pvc.md`
6. `07_expand_longhorn_node.md`
7. `07a_publish_longhorn_ui.md`
8. `08_verify.md`

## 从第三章快照恢复后的贴贴贴顺序

如果你是从“第三章结束”快照重新开始第四章，并且已经满足：

- `ops` 不恢复
- `harbor` 不恢复
- 4 个工作节点新增数据盘仍然保留为 `/dev/sdb`

那么在 `ops` 上按下面顺序直接执行即可：

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/01_prepare_longhorn_disks.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/02_prepare_longhorn_artifacts.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/03_install_longhorn.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/04_deploy_stateful_demo.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/05_expand_longhorn_node.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/07_publish_longhorn_ui.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/06_verify_storage.sh
```

说明：

- 第 4 步 `04_deploy_stateful_demo.sh` 第一次跑时，`CSI` 相关 Pod 可能需要几十秒到几分钟收敛，这是正常现象，只要脚本还在执行就不要手工打断
- 如果 Longhorn UI 里看到 `nfs-common` 相关告警，这不影响本章 `RWO` 的 PVC、数据保留、GUI 发布和最终验收

## 第四章起点状态

第四章开始前，默认你已经完成第三章，并满足下面这些条件：

- 所有节点均为 `Ready`
- 第三章最终验收已经通过
- `ops` 已具备 `kubectl`、`helm`
- `ops` 已提供 `http://ops:9000/`
- `Harbor` 仍然保留，不做快照恢复
- 你已经在 `VMware` 中给 4 个工作节点都加好了独立数据盘
- `win2019 DNS` 后续可为 `longhorn.qytk8s.com` 指向 `10.1.1.60`

## 快照恢复说明

| 节点 | 是否恢复快照 | 说明 |
| :--- | :--- | :--- |
| `ops` | **不恢复** | 保留文档、脚本、Chart 与制品 |
| `cp01` / `cp02` / `cp03` | 恢复 | 恢复到第三章结束状态 |
| `wk-app01` / `wk-app02` / `wk-edge01` / `wk-obs01` | 恢复 | 恢复到第三章结束状态，并保留新增数据盘 |
| `harbor` | **不恢复** | Harbor 数据与镜像保留 |
| `VyOS` | 保持 | 本章不继续改动 `VyOS` |

## 版本冻结

- Kubernetes：`v1.33.9`
- Longhorn：`1.11.0`
- 数据盘设备：`/dev/sdb`
- 数据盘挂载点：`/var/lib/longhorn`
- Longhorn UI 服务类型：`ClusterIP`

## 关键设计冻结

- 第四章主线选 `Longhorn`，不切到 `Ceph`
- 首批 Longhorn 节点固定为 `wk-app01`、`wk-app02`、`wk-obs01`
- `wk-edge01` 不在安装时直接纳入，而是单独作为扩容演示节点
- 新增数据盘统一固定为 `/dev/sdb`
- Longhorn 数据路径统一固定为 `/var/lib/longhorn`
- Longhorn UI 统一通过第三章已经建立的 `Gateway API + HTTPS + Harbor CA` 方式向 `win2019` 发布

## 下一步

先进入第 1 步，确认 VMware 加盘清单：

- `docs/02_add_vmware_disks.md`
