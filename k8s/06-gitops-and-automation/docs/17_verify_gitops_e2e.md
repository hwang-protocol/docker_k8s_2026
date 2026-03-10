# 第 16 步：验证 GitOps 端到端链路

## 本步目标

确认下面链路已经闭环：

- `Gitea` 有仓库
- `Harbor` 有镜像
- `Argo CD` 能同步
- `Kubernetes` 里 Pod 正常
- 浏览器能打开 `QYT NetDevOps`

## 端到端关系图

```mermaid
flowchart LR
    source[GitSource] --> argo[ArgoCD]
    source --> build[ImageBuild]
    build --> harbor[Harbor]
    harbor --> k8s[Kubernetes]
    argo --> k8s
    k8s --> browser[BrowserAccess]
```

## 本步脚本

- `scripts/13_verify_gitops_e2e.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/13_verify_gitops_e2e.sh
```

```bash
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/13_verify_gitops_e2e.sh
```

## 当前环境验收结论

当前已经验证通过：

- `Application` 状态为 `Synced Healthy`
- `https://netdevops.qytk8s.com` 可访问业务页面
- `https://argocd.qytk8s.com` 可访问 Argo CD
- GitOps 演示版本已经升级到 `frontend:v0.1.2`

## Argo CD 当前登录信息

- 用户名：`admin`
- 默认密码：`Cisc0123`

## 当前域名与映射

- `git.qytk8s.com -> 10.1.1.202`
- `netdevops.qytk8s.com -> 10.1.1.60`
- `argocd.qytk8s.com -> 10.1.1.50`

## GitOps 变更演示结果

当前已经完成一次真实验证：

- 修改了前端页面文案
- 构建并推送了 `frontend:v0.1.2`
- 更新 Git 仓库中的 Helm values
- `Argo CD` 自动同步到最新 revision
- 页面显示名已经变为 `QYT NetDevOps`
- 页面已出现 `GitOps 验证版 v0.1.1`

## 当前闭环与后续推荐流程

这一页验证通过的，是第六章当前已落地的拆解版流程：

- 手工改代码
- 手工构建镜像
- 手工改 Git 中的镜像 tag
- `Argo CD` 自动同步

这说明当前环境已经具备完整 GitOps 教学基础。

后续更推荐的工程化表达是：

- 人只 `push` 一次
- `Git` 触发 `CI`
- `CI` 自动构建镜像并回写 `values`
- `Argo CD` 按 Git 最终状态发布

也就是说：

- 当前这一页证明“链路已经通了”
- 后续顺滑版只是把中间机械动作继续交给 `CI`

## 课堂建议

这一页非常适合收尾时强调一句：

> GitOps 的重点不是“把 YAML 放进 Git”，而是把源码、镜像、清单和集群状态真正打通。

## 下一步

第六章已经形成完整闭环，后续可以继续把它作为第七章可观测性的业务载体。

如果要做课堂现场改字、推镜像、观察 Argo 自动同步，请直接看：

- `docs/21_gitops_demo_playbook.md`
