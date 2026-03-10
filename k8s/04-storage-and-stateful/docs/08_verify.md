# 第 7 步：第四章最终验收

## 本步目标

只读验收第四章，确认这条主线已经闭环：

- `Longhorn` 正常
- `StorageClass` 正常
- `PVC` 动态供给正常
- Pod 重建后数据仍保留
- 第 4 个 Longhorn 节点已加入

## 验收顺序

1. Kubernetes 节点
2. Longhorn 组件
3. Longhorn 节点与磁盘
4. `StorageClass / PVC / PV`
5. Longhorn 卷
6. 有状态数据

## 本步脚本

- `k8s/04-storage-and-stateful/scripts/06_verify_storage.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/06_verify_storage.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/06_verify_storage.sh
```

## 验证 1：Kubernetes 节点

```bash
kubectl get nodes -o wide
```

预期：

- 所有节点为 `Ready`

## 验证 2：Longhorn 组件

```bash
kubectl -n longhorn-system get pods -o wide
```

预期：

- `longhorn-manager` 正常
- `longhorn-driver-deployer` 正常
- `longhorn-ui` 正常
- CSI 相关组件正常

## 验证 3：Longhorn 节点与磁盘

```bash
kubectl -n longhorn-system get nodes.longhorn.io
```

预期：

- 能看到 4 个 Longhorn 节点
- `wk-edge01` 已被纳入

## 验证 4：StorageClass、PVC、PV

```bash
kubectl get sc
```

```bash
kubectl -n stateful-demo get pvc
```

```bash
kubectl get pv
```

预期：

- 存在 `longhorn` StorageClass
- `demo-pvc` 为 `Bound`
- 存在与之对应的 `PV`

## 验证 5：Longhorn 卷

```bash
kubectl -n longhorn-system get volumes.longhorn.io
```

预期：

- 能看到由 `demo-pvc` 触发创建的 Longhorn 卷

## 验证 6：有状态数据

```bash
kubectl -n stateful-demo exec deploy/volume-demo -- sh -c 'cat /data/hello.txt'
```

预期：

- 仍能读到之前写入的测试内容

## 第四章通过标准

满足下面条件后，第四章即可视为完成：

- Longhorn 已成功安装
- 首批 3 节点 Longhorn 存储池已可用
- `PVC` 动态供给已成功
- Pod 删除重建后数据仍保留
- 第 4 个 Longhorn 节点已成功加入
