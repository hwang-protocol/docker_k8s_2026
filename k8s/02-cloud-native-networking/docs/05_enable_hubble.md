# 第 4 步：使用 Hubble 观察东西向流量

## 本步目标

在 `Cilium` 已经接管网络平面后，通过 `Hubble` 直接观察集群中的东西向流量。

本步重点不是“看一个界面”，而是让你看到：

- Pod 到 Pod 的访问路径
- `client -> whoami` 的实际流量
- `Cilium + eBPF` 已经能够对业务流量做可视化观察

## 对应脚本

- `k8s/02-cloud-native-networking/scripts/04_enable_hubble.sh`

## 前提

执行本步前，应先完成：

- `docs/03_install_cilium.md`
- `docs/04_service_discovery.md`

也就是说，`net-demo/client` 与 `net-demo/whoami` 已经存在。

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/04_enable_hubble.sh
```

```bash
bash /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/04_enable_hubble.sh
```

## 脚本做了什么

脚本会完成下面 4 个动作：

1. 检查 `hubble-relay` Pod
2. 在本地建立 `4245 -> hubble-relay` 端口转发
3. 再次从 `client` 向 `whoami` 生成 HTTP 流量
4. 通过 `hubble observe` 观察 `net-demo` 命名空间中的流量

## 你会看到什么

脚本输出中会出现：

- `Hubble Relay` 健康状态
- `net-demo/client`
- `net-demo/whoami`
- 流量方向
- `FORWARDED`

> 说明：当前 `hubble CLI` 为 `v1.18.6`，连接 `hubble-relay v1.19.1` 时可能打印版本告警，但不影响本实验观察流量。

最后应看到：

```text
OK: Hubble 观测演示完成
```

## 单项验证

### 验证方式：请明确打开 3 个终端

<span style="color:red"><strong>终端一：端口转发窗口，必须保持不退出</strong></span>

```bash
kubectl -n kube-system port-forward svc/hubble-relay 4245:80
```

预期：

- 终端持续占用
- 不要关闭

<span style="color:red"><strong>终端二：状态检查与实时观察窗口</strong></span>

先执行状态检查：

```bash
hubble status --server localhost:4245
```

预期：

- `Healthcheck: Ok`
- `Connected Nodes` 显示为已连接

然后继续执行实时观察：

```bash
hubble observe --server localhost:4245 --namespace net-demo --follow
```

预期：

- 终端进入持续输出状态
- 暂时没有新流量时可能先不打印业务记录

<span style="color:red"><strong>终端三：专门用来制造演示流量</strong></span>

```bash
kubectl exec -n net-demo deployment/client -- sh -c 'for i in 1 2 3; do curl -sS http://whoami >/dev/null; sleep 1; done'
```

预期：

- `client` 能成功访问 `whoami`
- 终端二里会刷出 `net-demo/client`
- 终端二里会刷出 `net-demo/whoami`
- 终端二里会刷出 `FORWARDED`

## Hubble UI 补充说明

第二章主线聚焦**东西向流量观测**，因此本章以 `hubble status` 和 `hubble observe` 为准，`Hubble UI` 不作为第二章验收项。

不过，考虑到当前实验环境的 GUI 主要通过 `win2019` 这类外部终端访问，课堂上如果需要临时看图形界面，可以在 `ops` 上执行下面命令，把 `Hubble UI` 暂时绑定到宿主机地址：

```bash
kubectl -n kube-system port-forward --address 0.0.0.0 svc/hubble-ui 12000:80
```

然后从 `win2019` 浏览器访问：

```text
http://10.1.1.201:12000
```

课堂演示效果示例：

![Hubble UI net-demo 演示截图](images/05_hubble_ui_net_demo.png)

说明：

- 这是**临时课堂演示方式**
- 目的只是让外部终端临时看到 `Hubble UI`
- 它不属于第二章主线验收
- 严格来说，这已经是“临时北向访问”，不是标准生产入口

如果未来第三章已经完成标准北向入口，可以再通过正式域名统一访问 `Hubble UI` 或其他可视化组件。那时再讲：

- 通过 `Ingress` / `Gateway API` 暴露服务
- 通过标准域名访问 Web UI
- 通过证书与 DNS 提供统一入口体验

## 本步完成标准

满足下面条件后，就可以进入下一步：

- `hubble status` 正常
- 能看到 `net-demo/client -> whoami` 的流量记录

## 下一步

下一步进入 `L3/L4` 与 `L7` 策略演示：

- `docs/06_l7_policy.md`
