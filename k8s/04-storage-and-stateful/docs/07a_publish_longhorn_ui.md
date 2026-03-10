# 第 7 步：发布 Longhorn UI

## 本步目标

把 `Longhorn UI` 正式纳入课程统一北向访问方式：

- `win2019`
- `HTTPS`
- 域名访问
- 复用第三章已经跑通的 `MetalLB + Gateway API`

本章固定访问地址：

```text
https://longhorn.qytk8s.com
```

## 为什么这一节必须补上

从你的课程风格来看，后续所有 GUI 都不能只停留在：

- `kubectl port-forward`
- `ClusterIP`
- 仅集群内访问

而是要统一落实为：

- 从 `win2019` 浏览器访问
- 使用业务域名
- 使用 `HTTPS`

Longhorn UI 也必须遵守这个规则。

## 本步脚本

- `k8s/04-storage-and-stateful/scripts/07_publish_longhorn_ui.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/07_publish_longhorn_ui.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/07_publish_longhorn_ui.sh
```

## 这一步做了什么

脚本会按下面顺序执行：

1. 自动检查并恢复集群连通性
2. 复用 Harbor CA 为 `longhorn.qytk8s.com` 签发服务端证书
3. 在 `gateway-demo` 命名空间中创建 TLS Secret
4. 扩展第三章已有的 `app-gateway`
5. 新增 Longhorn UI 对应的 `HTTPRoute`
6. 创建跨命名空间 `ReferenceGrant`
7. 检查并修正 `EndpointSlice` 标签
8. 验证 `HTTP -> HTTPS` 跳转和 `HTTPS` 页面响应

## 关键机制说明

这一节不是再单独搞一套新的 VIP，而是继续复用第三章已经建立的统一入口：

- VIP 仍然是 `10.1.1.60`
- Gateway 仍然是 `gateway-demo/app-gateway`
- Longhorn UI 后端仍然是 `longhorn-system/longhorn-frontend`

只是新增了：

- `longhorn.qytk8s.com`
- `longhorn-http` / `longhorn-https` 监听
- 对 `longhorn-frontend` 的转发规则

这样课程整体风格才统一。

## 执行后的检查

```bash
kubectl get gateway,httproute -n gateway-demo
```

```bash
kubectl -n longhorn-system get referencegrant
```

```bash
curl -I --resolve longhorn.qytk8s.com:80:10.1.1.60 http://longhorn.qytk8s.com/
```

```bash
curl -I --resolve longhorn.qytk8s.com:443:10.1.1.60 --cacert /docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt https://longhorn.qytk8s.com/
```

预期：

- `HTTP` 返回跳转到 `HTTPS`
- `HTTPS` 返回 `200 OK`
- `gateway-demo` 下出现 Longhorn 相关 `HTTPRoute`
- `longhorn-system` 下出现 `ReferenceGrant`

## win2019 侧要求

在 `win2019 DNS` 中新增：

```text
longhorn.qytk8s.com  ->  10.1.1.60
```

并确保把 Harbor CA 导入到：

```text
受信任的根证书颁发机构
```

之后即可从浏览器访问：

```text
https://longhorn.qytk8s.com
```

## 本步完成标准

- `longhorn.qytk8s.com` 已能通过 `HTTPS` 访问
- Longhorn UI 已可从 `win2019` 浏览器打开
- 本章 GUI 访问方式与第三章保持完全一致

## 下一步

进入第四章最终验收：

- `docs/08_verify.md`
