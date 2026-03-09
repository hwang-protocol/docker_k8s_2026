# 第 5 步：发布 Gateway API HTTPS 演示应用

## 本步目标

把演示应用正式通过：

- `MetalLB VIP`
- `Gateway API`
- `app.qytk8s.com`
- `HTTPS`

发布给集群外部访问。

## 本步脚本

- `k8s/03-north-south-traffic/scripts/05_publish_gateway_demo.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/03-north-south-traffic/scripts/05_publish_gateway_demo.sh
```

```bash
bash /docker_k8s_2026/k8s/03-north-south-traffic/scripts/05_publish_gateway_demo.sh
```

## 这一步做了什么

脚本会：

1. 创建 `gateway-demo` 命名空间
2. 部署 `whoami` 演示应用
3. 创建 `Gateway`
4. 创建 `HTTPRoute`
5. 为 `Cilium Gateway` 生成的 `EndpointSlice` 补充 `MetalLB` 识别所需 label
6. 让 `Gateway` 生成 `LoadBalancer Service`
7. 通过 `MetalLB` 给它分配固定 VIP：`10.1.1.60`
8. 本机验证 `HTTP -> HTTPS` 跳转和 `HTTPS` 访问

## 关键教学点

这一节上课时建议强调这三句话：

1. `MetalLB` 负责把 `LoadBalancer Service` 变成真正可达的 VIP
2. `Gateway` 负责监听 `80/443`
3. `HTTPRoute` 负责按域名和路径把流量送到后端 `Service`

## 当前版本兼容说明

在本实验版本组合里：

- `Cilium 1.19.1`
- `MetalLB 0.15.3`

`Gateway` 自动生成的 `EndpointSlice` 需要补上：

```text
kubernetes.io/service-name=cilium-gateway-app-gateway
```

脚本已经自动处理这一步，所以课堂执行时不需要手工补。

## 执行后的检查

```bash
kubectl get gateway,httproute -n gateway-demo
```

```bash
kubectl get svc -n gateway-demo
```

```bash
kubectl get gateway -n gateway-demo app-gateway -o yaml
```

预期：

- `Gateway` 存在
- `HTTPRoute` 存在
- 生成的 `LoadBalancer Service` 获得 `10.1.1.60`

## DNS 配置

在 `win2019 DNS` 中新增：

```text
app.qytk8s.com  ->  10.1.1.60
```

## 外部验证

完成 DNS 和根证书导入后，从 `win2019` 浏览器访问：

```text
https://app.qytk8s.com
```

预期：

- 浏览器不再报根证书不受信任
- 页面能看到 whoami 返回内容

## 本步完成标准

- `app.qytk8s.com` 已能从集群外通过 HTTPS 访问
- HTTP 访问会自动跳转到 HTTPS

## 下一步

进入第三章最终验收：

- `docs/07_verify.md`
