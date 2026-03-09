# 第 3 步：为现有 Cilium 开启 Gateway API

## 本步目标

在不重建集群的前提下，为当前已经运行的 `Cilium` 增加 `Gateway API` 能力。

本步完成后，应达到下面状态：

- `Gateway API` 标准 CRD 已安装
- `Cilium` 已启用 `gatewayAPI.enabled`
- 集群中能看到 `GatewayClass`

## 为什么这一步这样做

第三章不单独再装一套独立网关产品，而是直接复用第二章已经打好的 `Cilium` 网络底座。

这门课这样设计有两个好处：

1. 学员能理解“东西向底座”和“北向入口”是如何在同一体系里衔接的
2. 后续进入安全章节时，更容易从 `Gateway API` 继续过渡到认证、授权与服务治理

## 本步脚本

- `k8s/03-north-south-traffic/scripts/03_enable_gateway_api.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/03-north-south-traffic/scripts/03_enable_gateway_api.sh
```

```bash
bash /docker_k8s_2026/k8s/03-north-south-traffic/scripts/03_enable_gateway_api.sh
```

## 这一步做了什么

脚本会：

1. 自动检查集群连通性
2. 安装 `Gateway API` 标准 CRD
3. 基于第二章的 `cilium-values.yaml` 做一次 `helm upgrade`
4. 追加第三章的 `03_cilium_gateway_values.yaml`
5. 主动重启 `cilium` 与 `cilium-operator`，确保新配置真正生效
6. 等待 `Cilium` 滚动完成

## 执行后的检查

```bash
kubectl get crd | grep gateway.networking.k8s.io
```

```bash
kubectl get gatewayclass
```

```bash
cilium status --wait
```

预期：

- 可以看到 `gatewayclasses`、`gateways`、`httproutes`
- `gatewayclass` 中能看到 `cilium`
- `Cilium: OK`

## 本步完成标准

- `Gateway API` 已在当前集群中可用
- 后续已经可以创建 `Gateway` 和 `HTTPRoute`

## 下一步

进入第 4 步，为 `app.qytk8s.com` 签发 HTTPS 证书：

- `docs/05_issue_tls_certs.md`
