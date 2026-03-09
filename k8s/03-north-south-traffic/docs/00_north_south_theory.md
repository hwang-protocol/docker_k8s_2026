# 第三章理论导读：南北向入口、MetalLB 与 Gateway API

## 这一章到底要解决什么

第二章解决的是 **东西向**：

- Pod 到 Pod
- Pod 到 Service
- eBPF 数据平面
- Hubble 可观测
- Network Policy

第三章解决的是 **南北向**：

- 集群外部用户如何访问集群内服务
- 为什么裸机 Kubernetes 不能天然获得云厂商的 LoadBalancer
- `MetalLB` 在这里到底补了哪一层
- 为什么我们要用 `Gateway API`，而不是继续只停留在 `NodePort`
- 为什么从这一章开始要统一走 `域名 + HTTPS`

## 为什么这章主线选 `MetalLB`

如果站在传统网络工程师视角，最容易想到的是：

`PC -> 独立 LB -> Ingress -> Service`

这个思路没有问题，而且在很多企业网络里仍然常见。

但这门课第三章故意先选：

`PC -> MetalLB VIP -> Gateway API -> Service`

原因是它更适合讲清 Kubernetes 自己的北向暴露模型。

### `MetalLB` 的教学价值

`MetalLB` 不是入口网关，它解决的是：

- 裸机场景下 `LoadBalancer Service` 没有人给你分配 VIP
- 没有人替你把这个 VIP 在二层网络里通告出去

所以它更像是在补上“云厂商 LoadBalancer 能力缺位”的那一环。

一句话讲给学员听：

> `MetalLB` 不是七层网关，它是裸机 Kubernetes 的 VIP 分配器和对外通告器。

## 为什么这章主线选 `Gateway API`

如果你只讲 `Ingress`，当然也能完成发布。

但这门课既然前面已经选了 `Cilium`，第三章就更适合顺着讲到 `Gateway API`，因为它更现代，也更容易和后面的安全治理衔接。

### `Gateway API` 比 `Ingress` 更适合讲什么

- 角色更清晰：`GatewayClass`、`Gateway`、`HTTPRoute`
- 模型更清楚：谁负责入口设施，谁负责路由规则
- 后续扩展更顺：TLS、流量治理、策略控制更自然

一句话讲给学员听：

> `Ingress` 更像“老一代通用入口对象”，`Gateway API` 更像“新一代可扩展入口模型”。

## 第三章里的 HTTPS 到底放在哪

这次我们明确前移，不再等到后面的安全章才碰 HTTPS。

第三章先解决：

- 域名
- 证书
- 北向 HTTPS

后面的安全章再解决：

- JWT
- 服务身份
- `mTLS`
- 更细粒度的授权

这样课程节奏会更自然，因为现实里“先能安全进入，再谈更细安全控制”更符合工程顺序。

## 为什么复用 Harbor 的 CA

第一章已经为 `harbor.qytk8s.com` 生成了：

- `harbor-ca.key`
- `harbor-ca.crt`

这说明实验环境里已经有一套内部 CA。

第三章继续复用它，能带来三个好处：

1. 不重新造一套证书体系，减少课程分叉
2. 学员更容易理解“内部 CA 可以给多个内部域名签证书”
3. 后续 `app.qytk8s.com`、`grafana.qytk8s.com`、`argocd.qytk8s.com` 都能继续复用

## 第三章最终要让学员看到什么

这一章结束后，学员应该能在 `win2019` 浏览器里直接访问：

```text
https://app.qytk8s.com
```

并且能够解释清楚这条链路：

```text
PC / win2019
  -> DNS 解析到 MetalLB VIP
  -> Gateway API 监听 443
  -> TLS 终止
  -> HTTPRoute 转发到后端 Service
  -> Pod 返回结果
```

## 课堂上一句收束总结

- 第二章是：把集群内部网络打通并看清楚
- 第三章是：把集群内服务正式发布给外部用户
