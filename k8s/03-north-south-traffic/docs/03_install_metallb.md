# 第 2 步：安装 MetalLB 并配置业务 VIP 地址池

## 本步目标

为裸机 Kubernetes 集群补齐 `LoadBalancer VIP` 能力。

本步完成后，应达到下面状态：

- `MetalLB` 已安装
- 业务地址池 `10.1.1.50-10.1.1.79` 已创建
- 该地址池只允许 `wk-edge01` 对外通告

## 为什么这一步重要

如果没有 `MetalLB`，`LoadBalancer Service` 在裸机环境里通常会一直是：

```text
EXTERNAL-IP   <pending>
```

也就是说，集群知道你想对外暴露，但没有任何组件来给你分配 VIP 并在网络里把这个 VIP 宣告出去。

`MetalLB` 就是在补这一层。

## 本步脚本

- `k8s/03-north-south-traffic/scripts/02_install_metallb.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/03-north-south-traffic/scripts/02_install_metallb.sh
```

```bash
bash /docker_k8s_2026/k8s/03-north-south-traffic/scripts/02_install_metallb.sh
```

## 这一步做了什么

脚本会：

1. 自动检查集群连通性
2. 预创建并标记 `metallb-system` 命名空间
3. 安装 `MetalLB controller` 与 `speaker`
4. 应用 `IPAddressPool`
5. 应用 `L2Advertisement`

这里的关键设计是：

- 地址池：`10.1.1.50-10.1.1.79`
- 通告节点：只允许 `wk-edge01`

这有利于课堂上讲清楚“边缘入口节点”的概念。

## 执行后的检查

```bash
kubectl get pods -n metallb-system -o wide
```

```bash
kubectl get ipaddresspool,l2advertisement -n metallb-system
```

预期：

- `controller` 正常运行
- `speaker` 为 `DaemonSet` 正常运行
- `edge-pool` 存在
- `edge-pool-on-wk-edge01` 存在

## 本步完成标准

- `MetalLB` 正常运行
- 集群已经具备对 `LoadBalancer Service` 分配 VIP 的能力

## 下一步

进入第 3 步，为现有 `Cilium` 开启 `Gateway API`：

- `docs/04_enable_gateway_api.md`
