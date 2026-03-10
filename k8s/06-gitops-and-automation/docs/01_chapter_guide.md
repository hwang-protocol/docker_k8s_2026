# 第六章导读：GitOps 与自动化主线

## 本章定位

第六章的目标不是单独安装某一个工具，而是把一条完整交付链路讲清楚：

- 应用设计
- 本地联调
- 容器化
- Git 事实源
- 镜像仓库
- Argo CD 同步
- 正式业务入口
- 课堂现场演示

这一章现在已经重构为少量主线文档，避免在课堂上来回切换 20 多页碎片说明。

## 教材使用方法

这一章建议始终按下面节奏学习：

1. 先看理论与流程图
2. 再执行 `!!! 必刷脚本`
3. 再做测试与校验
4. 最后用“完成标准”判断这一节是否真正刷通

## 第六章主线图

```mermaid
flowchart LR
  overview[总览与GitOps主线]
  preview[应用设计与本地联调]
  assets[容器化与GitOps资产]
  gitea[Gitea与仓库初始化]
  release[Harbor与ArgoCD发布]
  entry[域名账户与正式入口]
  demo[课堂测试与演示]

  overview --> preview
  preview --> assets
  assets --> gitea
  gitea --> release
  release --> entry
  entry --> demo
```

## 第六章主线目录

请按下面顺序阅读与执行：

1. `docs/02_overview_and_gitops_flow.md`
2. `docs/03_app_design_and_local_preview.md`
3. `docs/04_containerize_and_gitops_assets.md`
4. `docs/05_gitea_setup_and_repo_bootstrap.md`
5. `docs/06_harbor_argocd_and_e2e_verification.md`
6. `docs/07_domains_accounts_and_classroom_demo.md`
7. `docs/08_gitops_demo_and_testing.md`

## !!! 刷课顺序总览

如果你要从头到尾顺刷，第六章的最短主线就是：

```text
理论总览 -> 本地联调 -> 工程化资产 -> Gitea -> Harbor/Argo CD -> 正式入口 -> 课堂演示
```

## 主线说明

### 1. 总览与 GitOps 主线

这一节讲：

- 第六章到底解决什么问题
- GitOps 的核心概念
- 主仓、`Gitea`、`Harbor`、`Argo CD` 的角色边界

### 2. 应用设计与本地联调

这一节讲：

- `QYT NetDevOps` 为什么这样设计
- 微服务职责边界
- 本地联调与第一阶段验收

### 3. 容器化与 GitOps 资产准备

这一节讲：

- `Dockerfile`
- `docker compose`
- `Helm Chart`
- `values`
- `Argo CD Application`

### 4. Gitea 落地与仓库初始化

这一节讲：

- `git.qytk8s.com` 的安装与信任链
- 应用仓库创建
- 首次把应用目录同步到 `Gitea`

### 5. Harbor、Argo CD 与发布闭环

这一节讲：

- 远程构建镜像
- 推送到 `Harbor`
- 安装 `Argo CD`
- 同步应用
- 端到端验收

### 6. 域名、账户与正式入口

这一节讲：

- 正式业务入口
- 域名与账户速查
- Git 边界

### 7. GitOps 课堂测试与演示

这一节讲：

- 改代码发布
- 改 YAML 扩缩容
- 课堂现场观察点

这一节开始前要记住：

- `16_release_frontend_gitops.sh` 之前必须先手工改代码，再改 `VERSION`
- `17_scale_frontend_gitops.sh` 之前必须先手工改 `values-lab.yaml` 里的副本数

## !!! 主线必刷脚本

下面这组脚本就是当前第六章主线：

### 标记说明

- `P0`：必须执行，直接决定是否能继续往下刷
- `P1`：建议执行，用于补强验证或课堂演示

### 环境检查

```bash
# P0
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/00_check_and_recover_cluster.sh
```

### 本地联调与第一阶段验收

```bash
# P0
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/01_run_local_preview.sh
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/02_verify_local_preview.sh
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/03_verify_chapter6.sh
```

### 工程化资产准备

```bash
# P0
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/04_verify_docker_assets.sh
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/05_verify_gitops_assets.sh
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/06_verify_phase2_assets.sh
```

### Gitea 与应用仓初始化

```bash
# P0
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/07_install_gitea_remote.sh
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/08_create_gitea_repo.sh
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/09_verify_gitea.sh
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/10_push_qytang_netdevops_repo.sh
```

### 发布闭环

```bash
# P0
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/11_build_and_push_images_remote.sh
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/12_install_argocd_and_sync.sh
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/13_verify_gitops_e2e.sh
```

### 正式入口与课堂演示

```bash
# P0/P1
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/14_publish_netdevops_https_domain.sh
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/16_release_frontend_gitops.sh
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/17_scale_frontend_gitops.sh
```

说明：

- `14_publish_netdevops_https_domain.sh` 属于主线 `P0`
- `16_release_frontend_gitops.sh`、`17_scale_frontend_gitops.sh` 属于课堂演示 `P1`
- `scripts/15_configure_argocd_domain.sh` 现在是遗留补救脚本，不再作为当前主线步骤单独执行

## 当前教学事实

### 已经解决的事实

- `12_install_argocd_and_sync.sh` 已经直接处理 `argocd.qytk8s.com` 正式证书
- `13_verify_gitops_e2e.sh` 当前验证的是前端 Service，不提前验证正式业务域名
- `16_release_frontend_gitops.sh` 的课堂动作已收成：改代码、改 `VERSION`、执行脚本

### 必须讲清楚的边界

- 主仓才是真实源码维护与备份边界
- `Gitea` 仓库是第六章 GitOps 发布目标
- 当前是“脚本化拆解版 GitOps”
- 还不是“人只 push 一次 + CI 全自动”

## 历史细分页说明

旧的编号页仍然保留在 `docs/` 中，方便回溯历史内容，但它们不再是当前主线教材。

当前主线以本页列出的 7 篇大文档为准。

其中下面这页已经退出主线：

- `docs/archive/19_configure_argocd_domain.md`

原因是：

- 其核心内容已经并入 `scripts/12_install_argocd_and_sync.sh`

## 一把梭脚本说明

仓库里仍保留：

```bash
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/99_bootstrap_chapter6.sh
```

但这属于“快速铺环境”入口，不是当前主线教材推荐的授课方式。

正式教学建议仍按 7 篇主线文档顺刷，这样每一段的理论、图、脚本、测试和完成标准都更完整。

## 第六章起点状态

进入第六章前，默认满足下面条件：

- 第五章最终验收已通过
- 所有节点为 `Ready`
- `ops` 已具备 `kubectl`
- 当前工作目录可正常访问
- `apps/qytang-netdevops` 已存在
- 统一 CA 文件存在
- `root@git` 可 SSH
- 课堂域名解析或 `hosts` 已提前准备

## 下一步

从总览与 GitOps 主线开始：

- `docs/02_overview_and_gitops_flow.md`
