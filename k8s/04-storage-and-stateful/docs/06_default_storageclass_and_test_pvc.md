# 第 5 步：验证 StorageClass、PVC 与数据保留

## 本步目标

通过一个最小有状态演示，把下面这条链路走通：

```text
PVC
  -> Longhorn 动态创建卷
  -> Pod 挂载卷
  -> 写入数据
  -> 删除 Pod
  -> 新 Pod 重新挂载同一卷
  -> 数据仍然存在
```

## 为什么这一步很关键

很多人安装完存储组件后，只看：

- Pod 是不是 Running
- StorageClass 在不在

但真正要验证的是：

- 卷有没有真正被动态供给
- 数据有没有真正落盘
- 工作负载重建后卷是不是还在

这一章的“有状态”闭环，就是在这一步完成的。

## 本步脚本

- `k8s/04-storage-and-stateful/scripts/04_deploy_stateful_demo.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/04_deploy_stateful_demo.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/04_deploy_stateful_demo.sh
```

## 这一步做了什么

脚本会按下面顺序执行：

1. 自动检查并恢复集群连通性
2. 创建 `stateful-demo` 命名空间
3. 创建 `demo-pvc`
4. 部署 `volume-demo`
5. 向 `/data/hello.txt` 写入测试内容
6. 删除当前 Pod，模拟工作负载重建
7. 等待新 Pod 启动
8. 在新 Pod 中再次读取 `/data/hello.txt`

## 执行后的检查

```bash
kubectl -n stateful-demo get pvc,pods
```

```bash
kubectl get pv
```

```bash
kubectl -n stateful-demo exec deploy/volume-demo -- sh -c 'cat /data/hello.txt'
```

预期：

- `PVC` 为 `Bound`
- 自动生成了 `PV`
- `volume-demo` 处于 `Running`
- `hello.txt` 内容在 Pod 删除重建后仍然存在

## 这一小节要给学员讲清楚什么

不是 Pod 自己保存了数据，而是：

- Pod 只是挂载了卷
- 数据真正保存在 Longhorn 卷里
- Pod 没了，卷还在

这就是 Kubernetes 有状态工作负载最关键的一层理解。

## 本步完成标准

- `PVC` 已成功绑定
- Pod 删除重建后数据仍存在
- 学员能解释清楚 `PVC / PV / Pod` 三者关系

## 下一步

进入第 6 步，把 `wk-edge01` 作为第 4 个 Longhorn 节点加入：

- `docs/07_expand_longhorn_node.md`
