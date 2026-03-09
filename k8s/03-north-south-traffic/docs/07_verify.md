# 第 6 步：第三章最终验收

## 本步目标

只读验收第三章，确认这条主线已经闭环：

- `MetalLB` 正常
- `Gateway API` 正常
- `TLS` 正常
- `app.qytk8s.com` 可以通过 `HTTPS` 访问

## 验收顺序

1. `MetalLB`
2. `Gateway API`
3. 证书
4. 北向访问

## 验证 1：MetalLB

```bash
kubectl get pods -n metallb-system -o wide
```

```bash
kubectl get ipaddresspool,l2advertisement -n metallb-system
```

```bash
kubectl get servicel2statuses.metallb.io -n metallb-system
```

预期：

- `controller` 正常
- `speaker` 正常
- `edge-pool` 存在
- 能看到 `cilium-gateway-app-gateway` 对应的 `ServiceL2Status`

## 验证 2：Gateway API

```bash
kubectl get gatewayclass
```

```bash
kubectl get gateway,httproute -n gateway-demo
```

```bash
kubectl get svc -n gateway-demo
```

预期：

- 存在 `cilium` GatewayClass
- `app-gateway` 正常
- `app-http-redirect` 和 `app-https-backend` 正常
- Gateway 对应的 `LoadBalancer Service` 拿到 `10.1.1.60`

## 验证 3：HTTPS 证书

```bash
kubectl get secret -n gateway-demo app-qytk8s-com-tls
```

```bash
openssl x509 -in /docker_k8s_2026/k8s/03-north-south-traffic/pki/app.qytk8s.com.crt -noout -subject -issuer
```

预期：

- Secret 存在
- `subject` 为 `app.qytk8s.com`
- `issuer` 为 Harbor CA

## 验证 4：本机命令行验证

```bash
curl -I --resolve app.qytk8s.com:80:10.1.1.60 http://app.qytk8s.com/
```

```bash
curl --resolve app.qytk8s.com:443:10.1.1.60 --cacert /docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt https://app.qytk8s.com/
```

预期：

- HTTP 返回 `301`
- HTTPS 返回 whoami 页面内容

## 验证 5：win2019 浏览器验证

确保你已经：

- 在 `win2019 DNS` 中配置 `app.qytk8s.com -> 10.1.1.60`
- 在 `win2019` 中导入 Harbor CA 根证书

然后浏览器访问：

```text
https://app.qytk8s.com
```

预期：

- 能正常打开
- 证书链受信任

## 第三章通过标准

满足下面条件后，第三章即可视为完成：

- 裸机集群已经具备 `LoadBalancer VIP`
- `Gateway API` 能工作
- 域名和 HTTPS 已打通
- 外部浏览器可以访问第三章演示应用
