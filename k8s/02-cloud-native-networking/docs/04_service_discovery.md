# 第 3 步：演示 Pod、Service、DNS 与 Service Discovery

## 本步目标

在第二章前半段网络恢复之后，用一个最小化应用演示下面四件事已经打通：

- Pod 已经可以正常创建
- Service 已经可以正常分发
- 集群内 DNS 已经可以解析 Service 名称
- 业务 Pod 可以通过 Service 名称访问目标服务

## 演示拓扑

本步使用两个工作负载：

- `whoami`：提供 HTTP 响应
- `client`：在 Pod 内发起访问请求

命名空间统一使用：

- `net-demo`

## 对应清单

- `manifests/00_net-demo_namespace.yaml`
- `manifests/10_whoami.yaml`
- `manifests/20_client.yaml`

## 对应脚本

- `k8s/02-cloud-native-networking/scripts/03_apply_service_discovery_demo.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/03_apply_service_discovery_demo.sh
```

```bash
bash /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/03_apply_service_discovery_demo.sh
```

## 脚本做了什么

脚本会完成下面 4 个动作：

1. 通过 `HTTP manifests` 创建 `net-demo`、`whoami`、`client`
2. 等待两个 Deployment 就绪
3. 查看 Pod 与 Service
4. 从 `client` Pod 中访问 `whoami` 与 `whoami.net-demo.svc.cluster.local`

## 你会看到什么

脚本成功时，应看到下面这些关键信息：

- `whoami` Deployment `successfully rolled out`
- `client` Deployment `successfully rolled out`
- `kubectl get svc -n net-demo` 中出现 `whoami`
- `curl http://whoami` 返回 `whoami` 服务输出
- `curl http://whoami.net-demo.svc.cluster.local` 返回同样的服务输出

最后应看到：

```text
OK: Service Discovery 演示完成
```

## 单项验证

### 验证 1：查看演示 Pod

```bash
kubectl get pods -n net-demo -o wide
```

预期：

- `whoami` Pod 为 `Running`
- `client` Pod 为 `Running`

### 验证 2：查看演示 Service

```bash
kubectl get svc -n net-demo
```

预期：

- 出现 `whoami` Service
- `CLUSTER-IP` 已分配

### 验证 3：通过短名访问

```bash
kubectl exec -n net-demo deployment/client -- curl -sS http://whoami
```

预期：

- 返回 `whoami` 服务的 HTTP 输出

### 验证 4：通过 FQDN 访问

```bash
kubectl exec -n net-demo deployment/client -- curl -sS http://whoami.net-demo.svc.cluster.local
```

预期：

- 返回与短名访问一致的 HTTP 输出

## 本步完成标准

满足下面条件后，可进入下一步：

- Pod 创建正常
- Service 创建正常
- DNS 解析正常
- 业务 Pod 可通过 Service 名称访问服务

## 下一步

下一步进入 Hubble 可观测性演示：

- `docs/05_enable_hubble.md`
