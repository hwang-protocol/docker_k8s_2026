# 第 3 步：验证网络平面已经恢复

## 本步目标

在 `Cilium` 完成安装后，确认第二章前半段已经真正达成：

- 全部节点为 `Ready`
- `CoreDNS` 已恢复
- `Cilium` 已在所有节点接管 CNI
- `Hubble Relay` 与 `Hubble UI` 已运行

## 对应脚本

- `k8s/02-cloud-native-networking/scripts/03_verify_network_ready.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/03_verify_network_ready.sh
```

```bash
bash /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/03_verify_network_ready.sh
```

## 你会看到什么

脚本会依次输出 4 组检查结果：

1. 节点状态
2. `kube-system` 关键 Pod
3. `Cilium` 状态
4. `Hubble` 服务

最后应看到：

```text
OK: 第二章网络平面恢复验证通过
```

## 单项验证说明

### 验证 1：节点状态

```bash
kubectl get nodes -o wide
```

预期：

- `cp01`、`cp02`、`cp03` 为 `Ready`
- `wk-app01`、`wk-app02`、`wk-edge01`、`wk-obs01` 为 `Ready`

### 验证 2：系统 Pod

```bash
kubectl get pods -n kube-system -o wide
```

预期：

- `cilium` DaemonSet 为 `Running`
- `cilium-operator` 为 `Running`
- `hubble-relay` 为 `Running`
- `hubble-ui` 为 `Running`
- `coredns` 为 `Running`
- `kube-proxy` 不再存在

### 验证 3：Cilium 总状态

```bash
cilium status --wait
```

预期：

- `Cilium: OK`
- `Operator: OK`
- `Hubble Relay: OK`

### 验证 4：Hubble 服务

```bash
kubectl get svc -n kube-system hubble-relay hubble-ui
```

预期：

- 可以看到 `hubble-relay`
- 可以看到 `hubble-ui`

## 本步完成标准

满足下面条件后，就可以进入下一步：

- 全部节点为 `Ready`
- `CoreDNS` 已恢复为 `Running`
- `Cilium` 与 `Hubble` 关键组件正常

## 下一步

下一步进入第二章第一个应用层演示：

- `docs/05_service_discovery.md`
