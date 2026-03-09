# 第 9 步：加入额外控制平面节点

## 本步目标

把 `cp02` 和 `cp03` 加入当前集群，使控制平面从单节点扩展为三节点高可用架构。

这一步完成后，希望达到下面的状态：

- `cp01`、`cp02`、`cp03` 都已经加入集群
- 三台节点都具备控制平面角色
- 控制平面统一入口仍然是 `api.qytk8s.com:6443`

## 为什么这一步要用 control-plane join 命令

控制平面节点和普通 Worker 节点不一样。

控制平面节点除了加入集群，还需要额外拿到：

- 控制平面证书
- API Server、Scheduler、Controller Manager 的相关配置
- etcd 成员相关配置

所以这里必须使用带下面参数的 join 命令：

- `--control-plane`
- `--certificate-key`

## 对应脚本

本步对应脚本：

- `k8s/01-k8s-architecture/scripts/09_join_control_planes_remote.sh`

这个脚本会完成：

1. 从 `cp01` 读取控制平面 join 命令
2. 依次在 `cp02`、`cp03` 上执行加入
3. 最后在 `ops` 上执行 `kubectl get nodes -o wide`

## 执行命令

先给脚本增加执行权限：

```bash
chmod +x /docker_k8s_2026/k8s/01-k8s-architecture/scripts/09_join_control_planes_remote.sh
```

然后执行：

```bash
bash /docker_k8s_2026/k8s/01-k8s-architecture/scripts/09_join_control_planes_remote.sh
```

## 执行后的验证

### 验证 1：查看节点列表

```bash
kubectl get nodes -o wide
```

预期：

- 能看到 `cp01`
- 能看到 `cp02`
- 能看到 `cp03`

### 验证 2：查看控制平面标签

```bash
kubectl get nodes --show-labels | grep control-plane
```

预期：

- 三台控制平面节点都带有 `node-role.kubernetes.io/control-plane`

## 本步完成标准

只要满足下面条件，就可以进入下一步：

- `cp02` 已加入集群
- `cp03` 已加入集群
- 节点列表中已出现 3 台控制平面节点

## 下一步

下一步进入 Worker 节点加入：

- `docs/11_join_workers.md`
