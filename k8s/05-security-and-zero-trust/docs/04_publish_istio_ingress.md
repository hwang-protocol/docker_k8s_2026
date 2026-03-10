# 第 3 步：发布 Istio Ingress Gateway 与演示应用

## 本步目标

新增第五章专用北向入口，并保持第三章入口不动。

本步完成后，应达到下面状态：

- 新域名：`secure-app.qytk8s.com`
- 新 VIP：`10.1.1.61`
- 新入口：`Istio Ingress Gateway`
- 演示命名空间：`mesh-demo`
- 演示应用：`helloworld`、`httpbin`、`curl-trusted`、`curl-untrusted`

## 为什么这一节要单独做

第三章已经讲清楚了“服务如何发布出去”，第五章不应该把重点放在迁移旧入口上。

因此这里采用：

- 第三章入口继续保留
- 第五章新增独立入口

这样你上课时就可以明确对比：

- `Cilium Gateway API`：基础发布
- `Istio Ingress Gateway`：安全与治理增强

## 本步脚本

- `k8s/05-security-and-zero-trust/scripts/03_publish_istio_ingress_demo.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/03_publish_istio_ingress_demo.sh
```

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/03_publish_istio_ingress_demo.sh
```

## 这一步做了什么

脚本会按下面顺序执行：

1. 自动检查并恢复集群连通性
2. 使用 Harbor CA 为 `secure-app.qytk8s.com` 签发证书
3. 安装 `Istio Ingress Gateway`
4. 在 `mesh-demo` 中部署演示应用和测试客户端
5. 创建 `Gateway`、`VirtualService` 和基线路由
6. 等待 `LoadBalancer VIP` 到位
7. 验证 `HTTP -> HTTPS` 跳转与基础 `HTTPS` 访问

## 执行后的检查

```bash
kubectl -n istio-ingress get pods,svc -o wide
```

```bash
kubectl -n mesh-demo get pods,svc
```

```bash
curl -I --resolve secure-app.qytk8s.com:80:10.1.1.61 http://secure-app.qytk8s.com/public
```

```bash
curl --resolve secure-app.qytk8s.com:443:10.1.1.61 --cacert /docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt https://secure-app.qytk8s.com/public
```

## 预期

- `istio-ingress` 命名空间中出现 `LoadBalancer` 类型 Service
- 该 Service 获得 `10.1.1.61`
- `HTTP` 能跳转到 `HTTPS`
- `HTTPS` 能访问 `public` 路径
- `public` 路径默认返回 `public-whoami` 的请求信息

## win2019 侧要求

在 `win2019 DNS` 中新增：

```text
secure-app.qytk8s.com  ->  10.1.1.61
```

并确保已经导入 Harbor CA 根证书。

## 理论讲解点

这一节建议你重点讲：

- 为什么第五章新增独立入口，而不是接管第三章入口
- `Gateway` 和 `VirtualService` 在 Istio 里的角色
- 为什么要单独保留一个 `public` 路径作为 JWT 前后的对照组

## 下一步

进入第 4 步，开启 `JWT` 与服务间安全：

- `docs/05_enable_jwt_and_mesh_security.md`
