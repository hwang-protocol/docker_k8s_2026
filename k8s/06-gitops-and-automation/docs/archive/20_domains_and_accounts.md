# 第 19 步：域名、IP 与账户一览

## 名称说明

为了保持课堂演示效果和仓库路径稳定，当前有两套名称：

- 前端显示名：`QYT NetDevOps`
- 仓库目录名：`apps/qytang-netdevops`
- Gitea 仓库名：`qytang-netdevops.git`
- Harbor 项目名：`qytang-netdevops`

课堂上建议这样讲：

> 页面品牌名已经调整为 `QYT NetDevOps`，但工程目录和仓库名为了保持 GitOps 链路稳定，仍然沿用 `qytang-netdevops`。

## 域名与 IP 映射

- `harbor.qytk8s.com -> 10.1.1.203`
- `git.qytk8s.com -> 10.1.1.202`
- `netdevops.qytk8s.com -> 10.1.1.60`
- `argocd.qytk8s.com -> 10.1.1.50`
- `app.qytk8s.com -> 10.1.1.60`
- `longhorn.qytk8s.com -> 10.1.1.60`
- `secure-app.qytk8s.com -> 10.1.1.61`

## 需要登录的系统

- `https://harbor.qytk8s.com`
  - 用户名：`admin`
  - 密码：`Harbor12345`
- `https://git.qytk8s.com`
  - 用户名：`gitadmin`
  - 密码：`Gitea12345`
- `https://argocd.qytk8s.com`
  - 用户名：`admin`
  - 密码：`Cisc0123`

## win2019 需要做的事

- 导入 `harbor-ca.crt`
- 配置 DNS 或 hosts
- 使用域名访问，不建议直接访问 IP

## 当前课堂最终访问入口

- 业务入口：`https://netdevops.qytk8s.com`
- Git 服务：`https://git.qytk8s.com`
- GitOps 控制面：`https://argocd.qytk8s.com`
