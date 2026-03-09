# 第 10 步：加入 Worker 节点

## 本步目标

把四台 Worker 节点加入集群，并提前打好课程后续要使用的节点标签。

本步完成后，希望达到下面的状态：

- `wk-app01`
- `wk-app02`
- `wk-edge01`
- `wk-obs01`

都已经加入集群。

同时，它们还会带上下面这些标签：

- `wk-app01` -> `node-role=app`
- `wk-app02` -> `node-role=app`
- `wk-edge01` -> `node-role=edge`
- `wk-obs01` -> `node-role=observability`

## 为什么这里要先打标签

因为后面课程会按角色来调度组件：

- 业务应用优先去 `app` 节点
- 入口组件优先去 `edge` 节点
- 监控组件优先去 `observability` 节点

如果现在就把标签打好，后面章节里的调度逻辑会更直观。

## 对应脚本

本步对应脚本：

- `k8s/01-k8s-architecture/scripts/10_join_workers_remote.sh`

这个脚本会完成：

1. 从 `cp01` 读取 Worker join 命令
2. 依次让 4 台 Worker 节点加入集群
3. 在 `ops` 上通过 `kubectl label node` 给节点打标签

## 执行命令

先给脚本增加执行权限：

```bash
chmod +x /docker_k8s_2026/k8s/01-k8s-architecture/scripts/10_join_workers_remote.sh
```

然后执行：

```bash
bash /docker_k8s_2026/k8s/01-k8s-architecture/scripts/10_join_workers_remote.sh
```

## 执行后的验证

### 验证 1：查看节点列表

```bash
kubectl get nodes -o wide
```

预期：

- 所有 7 台 Kubernetes 节点都已经出现

### 验证 2：查看标签

```bash
kubectl get nodes --show-labels
```

预期：

- `wk-app01`、`wk-app02` 带有 `node-role=app`
- `wk-edge01` 带有 `node-role=edge`
- `wk-obs01` 带有 `node-role=observability`

## 本步完成标准

只要满足下面条件，就可以进入下一步：

- 四台 Worker 已加入集群
- 节点标签已正确写入
- `kubectl get nodes` 已经能看到完整节点列表

## 下一步

下一步进入本章总验收：

- `docs/12_verify.md`
