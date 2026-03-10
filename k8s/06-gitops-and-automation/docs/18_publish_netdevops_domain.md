# 第 17 步：发布 QYT NetDevOps 正式域名

## 本步目标

将业务入口从临时 `LoadBalancer VIP` 收口为正式域名：

- `https://netdevops.qytk8s.com`

并固定映射到：

- `10.1.1.60`

## 为什么这里要复用第三章 Gateway

这一步特别适合课堂讲“架构复用”。

不是每个应用都要自己再申请一个外部 VIP。

更合理的方式通常是：

- 业务入口统一挂在北向网关上
- 每个应用只申请自己的域名和证书
- 集群内部仍然保持 `ClusterIP`

## 当前设计结论

- `netdevops.qytk8s.com -> 10.1.1.60`
- `frontend Service` 改为 `ClusterIP`
- 由 `Gateway API` + `HTTPS` 对外暴露

## 本步脚本

- `scripts/14_publish_netdevops_https_domain.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/14_publish_netdevops_https_domain.sh
```

```bash
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/14_publish_netdevops_https_domain.sh
```

## 本步会做什么

1. 复用 Harbor CA 为 `netdevops.qytk8s.com` 签发证书
2. 在 `gateway-demo` 创建 `TLS Secret`
3. 把 `HTTPRoute` 指向 `qytang-netdevops/frontend`
4. 让浏览器通过统一网关访问业务应用

## 验证命令

```bash
curl -I --resolve netdevops.qytk8s.com:80:10.1.1.60 http://netdevops.qytk8s.com/
```

```bash
curl --resolve netdevops.qytk8s.com:443:10.1.1.60 --cacert /docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt https://netdevops.qytk8s.com/api/device/healthz
```

## 课堂要点

- 最终发布入口看域名，不看 Pod IP
- 业务应用不再直接暴露临时 VIP
- `Gateway API` 是第六章和第三章之间最自然的衔接点

## 下一步

继续为 Argo CD 配正式域名和证书：

- `docs/19_configure_argocd_domain.md`
