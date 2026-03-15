# 第 18 步：配置 Argo CD 正式域名与证书

> 历史说明：本页属于旧版细分页。当前主线教材中，`argocd.qytk8s.com` 的正式证书已经并入 `scripts/12_install_argocd_and_sync.sh` 处理，请优先以 `docs/01_chapter_guide.md` 和 `docs/04_harbor_argocd_and_e2e_verification.md` 为准。

## 本步目标

把 Argo CD 的访问方式从：

- `https://10.1.1.50`

收口为：

- `https://argocd.qytk8s.com`

并固定映射到：

- `10.1.1.50`

## 为什么这一步必须做

如果继续用 `IP` 访问 HTTPS 服务，浏览器一定容易报：

- 域名不匹配
- 证书不受信任

所以更贴近真实企业环境的方式是：

- 给 Argo CD 单独配域名
- 用企业内部 CA 为域名签证书
- 浏览器导入统一根证书

## 本步脚本

- `scripts/15_configure_argocd_domain.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/15_configure_argocd_domain.sh
```

```bash
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/15_configure_argocd_domain.sh
```

## 脚本会做什么

1. 使用 Harbor CA 为 `argocd.qytk8s.com` 签发证书
2. 创建 `argocd-server-tls` Secret
3. 固定 `argocd-server` 的 VIP 为 `10.1.1.50`
4. 重启 `argocd-server` 使正式证书生效

## 验证命令

```bash
curl --resolve argocd.qytk8s.com:443:10.1.1.50 --cacert /docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt https://argocd.qytk8s.com/healthz
```

## 课堂要点

- Git 服务和交付控制面都应该有自己的独立域名
- 统一 CA 能显著降低课堂和企业环境里的证书复杂度
- 控制面域名应该和业务域名分离

## 当前登录信息

- 地址：`https://argocd.qytk8s.com`
- 用户名：`admin`
- 默认密码：`Cisc0123`

## 下一步

回到端到端验收，确认最终是“域名 + HTTPS + GitOps 自动更新”：

- `docs/17_verify_gitops_e2e.md`
