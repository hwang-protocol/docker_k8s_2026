# 第 2 步：安装 Cilium 并启用 eBPF kube-proxy replacement

## 本步目标

将第一章尚未安装 CNI 的集群切换到 `Cilium`，并直接启用：

- `native routing`
- `eBPF kube-proxy replacement`
- `Hubble`
- `BGP Control Plane`

这一步完成后，希望达到下面的状态：

- `Cilium` 已在所有节点运行
- `kube-proxy` 已退出集群
- 节点开始从 `NotReady` 进入 `Ready`
- `CoreDNS` 开始从 `Pending` 进入 `Running`

## 为什么这一步必须先清理 kube-proxy

第一章的集群是通过 `kubeadm` 初始化的，因此默认已经安装了 `kube-proxy`。

第二章的目标不是继续沿用传统 `iptables/ipvs` 风格的 Service 转发，而是要让 `Cilium` 通过 `eBPF` 直接接管 Service 转发能力。

因此在安装 `Cilium` 之前，必须先完成下面两件事：

1. 删除 `kube-proxy` DaemonSet 与 ConfigMap
2. 清理各节点中遗留的 `KUBE-*` iptables 规则

## 为什么这里使用 native routing

第二章不仅要把 CNI 跑通，还要把：

- `Pod CIDR`
- `BGP`
- `Route Reflector`
- 东西向路由可达性

讲清楚。

因此本章不采用 tunnel 模式，而是采用：

```text
routingMode: native
```

这样后面讲 `VyOS Route Reflector` 和 `Cilium BGP Control Plane` 才有清晰的控制面主线。

## 为什么这里要显式指定 k8sServiceHost 和 k8sServicePort

启用 `kube-proxy replacement` 之后，`Cilium` 不再依赖 `kube-proxy` 提供 Kubernetes Service 访问路径。

因此必须显式指定：

- `k8sServiceHost: 10.1.1.10`
- `k8sServicePort: 6443`

也就是让 `Cilium` 直接通过 API VIP 去访问 Kubernetes API Server。

## 对应脚本

本步对应脚本：

- `k8s/02-cloud-native-networking/scripts/02_install_cilium.sh`

这个脚本会完成：

1. 删除 `kube-proxy` DaemonSet 与 ConfigMap
2. 批量清理所有 Kubernetes 节点上的 `KUBE-*` iptables 规则
3. 通过本地 Helm chart 与本地 values 文件安装 `Cilium`
4. 等待 `Cilium`、`operator`、`hubble-relay`、`hubble-ui` 就绪
5. 输出节点与 `kube-system` 状态

## 依赖文件

本步会直接使用下面两个本地文件：

- Helm chart：`artifacts/cilium-1.19.1.tgz`
- values 文件：`manifests/cilium-values.yaml`

## 执行命令

先给脚本增加执行权限：

```bash
chmod +x /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/02_install_cilium.sh
```

然后执行：

```bash
bash /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/02_install_cilium.sh
```

## 你会看到什么

脚本会分成 5 个阶段：

```text
[1/5] 删除 kube-proxy DaemonSet 与 ConfigMap
[2/5] 在所有 Kubernetes 节点清理 KUBE iptables 规则
[3/5] 通过 Helm 安装 Cilium
[4/5] 等待 Cilium 组件就绪
[5/5] 查看节点与 kube-system 组件状态
```

在清理阶段，每台节点都会打印主机名分隔线；在安装完成后，会看到：

```text
OK: Cilium 安装完成
```

## 执行后的验证

### 验证 1：查看 Cilium 状态

```bash
cilium status --wait
```

预期：

- `Cilium` 为 `OK`
- `Operator` 为 `OK`
- `Hubble Relay` 为 `OK`

### 验证 2：查看节点状态

```bash
kubectl get nodes -o wide
```

预期：

- 节点开始从 `NotReady` 进入 `Ready`

### 验证 3：查看 kube-system Pod

```bash
kubectl get pods -n kube-system -o wide
```

预期：

- `cilium` DaemonSet 已运行
- `cilium-operator` 已运行
- `hubble-relay` 已运行
- `hubble-ui` 已运行
- `coredns` 已从 `Pending` 进入 `Running`
- `kube-proxy` 已不再存在

## 本步完成标准

只要满足下面条件，就可以进入下一步：

- `Cilium` 已在所有节点成功运行
- `kube-proxy` 已从集群移除
- 节点开始进入 `Ready`
- `CoreDNS` 开始进入 `Running`

## 下一步

下一步进入网络平面恢复验证：

- `docs/04_verify_network_ready.md`
