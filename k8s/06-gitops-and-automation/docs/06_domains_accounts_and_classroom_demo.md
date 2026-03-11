# 域名、账户与正式业务入口

## 本节目标

这一节是第六章的收口页之一，要把下面几件事放到同一张图里看清楚：

- 正式业务入口在哪里
- 当前有哪些域名与账户
- 当前 Git 备份边界是什么

## 正式业务入口为什么要单独收口

到上一节为止，应用已经在 Kubernetes 中跑起来，并完成了：

- 镜像构建
- `Argo CD` 同步
- 前端 Service 验证

但真正给课堂展示看的，应该是正式业务入口，而不是临时 `LoadBalancer` 或端口转发。

当前课程收口方式是：

- 正式业务入口：`https://netdevops.qytk8s.com`
- 固定映射：`10.1.1.60`
- 复用第三章已经准备好的 `Gateway API + HTTPS`

这一节当前也有一个明确边界：

- `netdevops.qytk8s.com` 的 listener、`HTTPRoute`、`ReferenceGrant` 只来自第六章自己的 manifests
- 不再跨章节复用第四章 Longhorn 的发布清单

## 当前域名与账户速查

### 域名与 IP

- `harbor.qytk8s.com -> 10.1.1.203`
- `git.qytk8s.com -> 10.1.1.202`
- `netdevops.qytk8s.com -> 10.1.1.60`
- `argocd.qytk8s.com -> 10.1.1.50`

### 需要登录的系统

- `https://harbor.qytk8s.com`
  - 用户名：`admin`
  - 密码：`Harbor12345`
- `https://git.qytk8s.com`
  - 用户名：`gitadmin`
  - 密码：`Gitea12345`
- `https://argocd.qytk8s.com`
  - 用户名：`admin`
  - 密码：`Cisc0123`

### 浏览器侧准备

在课堂浏览器环境中，应提前完成：

- 导入 `harbor-ca.crt`
- 配置 DNS 或 `hosts`
- 使用域名访问，不建议直接访问 IP

## 命名约定

当前有两套名称同时存在，但职责不同：

- 页面品牌名：`QYT NetDevOps`
- 工程目录名：`apps/qytang-netdevops`
- Gitea 仓库名：`qytang-netdevops`
- Harbor 项目名：`qytang-netdevops`

课堂上建议这样讲：

- 页面展示名已经调整为 `QYT NetDevOps`
- 但工程目录、仓库路径、镜像仓路径为了保持 GitOps 链路稳定，仍然沿用 `qytang-netdevops`

## 当前 Git 边界

这一页必须把“源码备份”和“GitOps 发布”讲清楚。

### 主仓负责什么

- 真实源码维护
- 课程全量素材备份

### `Gitea` 发布仓负责什么

- 作为第六章 GitOps 演示与发布目标
- 被 `Argo CD` 与构建节点拉取

所以当前正确理解是：

- 主仓 `git push` 成功，主仓内容才真正备份到你的远端
- `16` 和 `17` 脚本只是把 `apps/qytang-netdevops` 同步到 `Gitea`
- 它们不等于“替你自动把主仓也提交并推送到你的 Git 远端”

## 业务正式入口发布

这一节沿用第三章网关能力，不再给业务单独暴露临时入口。

```mermaid
flowchart LR
  browser[Browser]
  gateway[GatewayAPI]
  tls[TLSSecret]
  frontend[FrontendService]

  browser --> gateway
  tls --> gateway
  gateway --> frontend
```

这里要明确一个架构结论：

- 对外暴露的是统一网关入口
- 业务 `frontend` Service 回到 `ClusterIP`
- 域名、TLS、HTTP 跳转 HTTPS 都由网关层承载

## !!! 本节必刷脚本

### 发布正式业务入口

```bash
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/14_publish_netdevops_https_domain.sh
```

## 正式业务入口验证

```bash
curl -I --resolve netdevops.qytk8s.com:80:10.1.1.60 http://netdevops.qytk8s.com/
```

```bash
curl --resolve netdevops.qytk8s.com:443:10.1.1.60 --cacert /docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt https://netdevops.qytk8s.com/
```

```bash
curl --resolve netdevops.qytk8s.com:443:10.1.1.60 --cacert /docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt https://netdevops.qytk8s.com/api/device/healthz
```

## 本节完成标准

满足下面条件即可进入课堂测试与演示页：

- `https://netdevops.qytk8s.com` 可访问
- `https://netdevops.qytk8s.com/api/device/healthz` 返回正常
- `https://argocd.qytk8s.com` 可访问
- 已理解当前域名、账户与 Git 边界

## 常见误区

### 误区 1：运行 `16` 或 `17` 就等于主仓已经自动备份

不是。它们只是把应用目录同步到 `Gitea`，不等于替你自动 `commit/push` 主仓到你的远端。

## 下一步

进入单独的课堂测试与演示页：

- `docs/07_gitops_demo_and_testing.md`
