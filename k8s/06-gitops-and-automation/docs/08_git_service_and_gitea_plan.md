# 第 7 步：Git 服务与 Gitea 规划

## 本步目标

把第六章后半段要用到的 Git 服务讲清楚：

- `git.qytk8s.com` 在课程里负责什么
- 为什么这里推荐 `Gitea`
- `QYTANG NetDevOps` 以后准备放到哪个仓库

## Git 服务在第六章中的作用

在 GitOps 模式里，Git 不只是代码存储位置，它还是“期望状态”的事实源。

这意味着 Git 服务要承载至少两类信息：

- 应用源码
- 声明式部署配置

## 为什么这里推荐 `Gitea`

当前课程环境里更适合用 `Gitea`，原因有 4 个：

- 足够轻量
- 部署快
- 界面直观，适合课堂投屏
- 对 GitOps 演示已经完全够用

## 当前课程中的固定入口

- Git 服务器：`10.1.1.202`
- 域名：`git.qytk8s.com`

## 建议仓库名

后续推荐直接使用：

- `qytang-netdevops.git`

推荐组织方式：

- `git.qytk8s.com/netdevops/qytang-netdevops.git`

## 为什么这里先用单仓

本课程当前更适合单仓方案：

- 源码、Dockerfile、Helm、GitOps 配置都在一起
- 学员第一次接触 GitOps 时更容易理解
- 课堂里讲“改代码”和“改 values”时切换成本更低

## 单仓结构示意

```text
qytang-netdevops/
├── frontend/
├── backend/
├── deploy/
│   ├── docker/
│   ├── helm/
│   └── gitops/
├── scripts/
└── docs/
```

## 为什么后续也可以再拆双仓

单仓不是唯一方案，只是教学阶段更友好。

如果你后面想更像生产，可以再拆成：

- 源码仓
- GitOps 配置仓

但这一步不急。

## 课堂讲解建议

你讲这一页时，可以重点强调：

- Git 仓库不是只存代码，还可以存部署状态
- GitOps 的本质是“让 Git 成为事实源”
- 这里先用单仓，是为了让学习曲线更平滑

## 下一步

继续看 Helm 和 Argo CD 目录关系：

- `docs/09_helm_and_argocd_layout.md`
