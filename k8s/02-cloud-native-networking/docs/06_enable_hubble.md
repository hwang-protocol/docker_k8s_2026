# 第 5 步：使用 Hubble 观察东西向流量

## 本步目标

在 `Cilium` 已经接管网络平面后，通过 `Hubble` 直接观察集群中的东西向流量。

本步重点不是“看一个界面”，而是让你看到：

- Pod 到 Pod 的访问路径
- `client -> whoami` 的实际流量
- `Cilium + eBPF` 已经能够对业务流量做可视化观察

## 对应脚本

- `k8s/02-cloud-native-networking/scripts/05_enable_hubble.sh`

## 前提

执行本步前，应先完成：

- `docs/04_verify_network_ready.md`
- `docs/05_service_discovery.md`

也就是说，`net-demo/client` 与 `net-demo/whoami` 已经存在。

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/05_enable_hubble.sh
```

```bash
bash /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/05_enable_hubble.sh
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

最后应看到：

```text
OK: Hubble 观测演示完成
```

## 单项验证

### 验证 1：Hubble Relay 状态

```bash
hubble status --server localhost:4245
```

预期：

- `Healthcheck: Ok`
- `Connected Nodes` 显示为已连接

### 验证 2：观察最近流量

```bash
hubble observe --server localhost:4245 --last 50 | grep -E 'net-demo/(client|whoami)'
```

预期：

- 能看到 `net-demo/client`
- 能看到 `net-demo/whoami`
- 能看到 `FORWARDED`

## Hubble UI 演示方式

如果课堂上需要图形化展示，可以单独执行：

```bash
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
```

然后在浏览器访问：

```text
http://127.0.0.1:12000
```

## 本步完成标准

满足下面条件后，就可以进入下一步：

- `hubble status` 正常
- 能看到 `net-demo/client -> whoami` 的流量记录

## 下一步

下一步进入 `L3/L4` 与 `L7` 策略演示：

- `docs/07_l7_policy.md`
