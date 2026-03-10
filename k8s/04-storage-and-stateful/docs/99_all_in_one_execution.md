# 第四章：一键“一把梭”执行清单

这份文档就是第四章的最终总入口。

如果你准备从“第三章结束”快照重新开始第四章，请先确认下面 4 个前提：

1. `cp01`、`cp02`、`cp03`、`wk-app01`、`wk-app02`、`wk-obs01`、`wk-edge01` 已恢复到第三章结束快照
2. `ops` 不恢复，继续保留本机上的第四章文档、脚本、YAML、Chart 和 `ops:9000` 发布目录
3. `harbor` 不恢复，继续保留第四章需要的 Harbor 项目和镜像缓存
4. VMware 中给 4 个工作节点新增的数据盘仍然保留，并且统一呈现为 `/dev/sdb`

上面 4 条满足后，你就可以直接在 `ops` 节点上，按顺序“贴贴贴”执行以下 6 条命令。

这些脚本已经内置了幂等性、重试机制和集群状态恢复逻辑，目标就是让你从第三章快照恢复后“一把过”。

## 执行前你只需要知道两件事

- 第 4 步 `04_deploy_stateful_demo.sh` 第一次跑时，`CSI` 相关 Pod 可能需要几十秒到几分钟收敛，这是正常现象，只要脚本还在跑就不要手工打断
- 如果 Longhorn UI 里看到 `nfs-common` 相关告警，这不影响本章 `RWO` 的 PVC、数据保留和最终验收；本章不是做 `RWX` 演示

## 1. 准备 Longhorn 宿主机磁盘

将 4 个工作节点的新增数据盘（`/dev/sdb`）格式化并挂载到 `/var/lib/longhorn`。

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/01_prepare_longhorn_disks.sh
```

## 2. 准备 Longhorn 制品与镜像

下载 Longhorn Chart，提取镜像列表，推送到本地 Harbor，并在所有节点预拉取镜像。

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/02_prepare_longhorn_artifacts.sh
```

## 3. 安装 Longhorn (初始 3 节点)

通过 Helm 安装 Longhorn，并将 `wk-app01`, `wk-app02`, `wk-obs01` 初始化为首批 3 个存储节点。

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/03_install_longhorn.sh
```

## 4. 验证 PVC 动态供给与数据保留

部署一个有状态的 busybox 应用，写入数据，然后删除 Pod 模拟故障重建，验证新 Pod 挂载卷后数据依然存在。

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/04_deploy_stateful_demo.sh
```

## 5. 扩容第 4 个 Longhorn 节点

将 `wk-edge01` 作为第 4 个存储节点动态加入到 Longhorn 集群中。

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/05_expand_longhorn_node.sh
```

## 6. 最终验收

执行最终验收脚本，确认节点状态、Longhorn 组件、StorageClass、PVC/PV 绑定状态以及演示数据。

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/06_verify_storage.sh
```

---

至此，第四章（存储与有状态服务）全部完成。

快照建议：

- 保留 `ops`
- 保留 `harbor`
- 对所有 `cp` 和 `wk` 节点制作第四章完成快照