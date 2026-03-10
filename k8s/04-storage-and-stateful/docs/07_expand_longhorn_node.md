# 第 6 步：把第 4 个节点加入 Longhorn

## 本步目标

把：

- `wk-edge01`

作为第 4 个 Longhorn 节点加入集群。

## 为什么这一节单独拿出来讲

如果一开始就把 4 个节点全部纳入 `Longhorn`，学员往往只能看到“装好了”。

但把第 4 个节点放到后面单独加入，会更容易讲清楚：

- Longhorn 节点不是一次性写死的
- 存储节点可以后续扩容
- Kubernetes 节点加入存储池，本质上是一个独立动作

这对理解生产中的“容量扩展”很重要。

## 本步脚本

- `k8s/04-storage-and-stateful/scripts/05_expand_longhorn_node.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/05_expand_longhorn_node.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/05_expand_longhorn_node.sh
```

## 这一步做了什么

脚本会按下面顺序执行：

1. 自动检查并恢复集群连通性
2. 给 `wk-edge01` 打上 Longhorn 默认磁盘标签
3. 给 `wk-edge01` 写入默认磁盘路径注解
4. 等待 Longhorn 自动识别 `/var/lib/longhorn`
5. 如自动识别超时，则补充 `Longhorn Node CR` 配置
6. 查看扩容后的 Longhorn 节点状态

## 关键机制说明

这一节最重要的不是“命令怎么敲”，而是理解：

- 前 3 个节点在安装前就已经被标记好了
- `wk-edge01` 是在 Longhorn 已运行之后，再动态加入的

这说明 Longhorn 的节点纳入不是只能发生在安装阶段。

## 执行后的检查

```bash
kubectl -n longhorn-system get nodes.longhorn.io
```

```bash
kubectl -n longhorn-system get nodes.longhorn.io wk-edge01 -o yaml
```

预期：

- `wk-edge01` 出现在 Longhorn 节点列表中
- Longhorn 能看到它的磁盘路径 `/var/lib/longhorn`
- 该节点允许调度

## 本步完成标准

- `wk-edge01` 已被 Longhorn 正常识别
- 集群中的 Longhorn 节点数达到 4

## 下一步

进入第 7 步，做第四章最终验收：

- `docs/08_verify.md`
