# 第 9 步：第六章第二阶段验收

## 本步目标

只读验收第六章第二阶段，确认课程已经从“本地联调”顺利推进到“容器化 + Helm + GitOps 骨架”。

## 本步脚本

- `k8s/06-gitops-and-automation/scripts/06_verify_phase2_assets.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/06_verify_phase2_assets.sh
```

```bash
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/06_verify_phase2_assets.sh
```

## 验收顺序

1. Docker 目录
2. Dockerfile
3. `docker compose`
4. Helm Chart
5. GitOps 目录
6. Argo CD Application

## 通过标准

满足下面条件后，第六章第二阶段即可视为完成：

- 样板应用已具备镜像化素材
- 已具备 `docker compose` 教学入口
- 已具备 Helm Chart 基础结构
- 已具备 GitOps 环境目录
- 已具备 Argo CD Application 样板

## 下一步

下一阶段就可以继续做真正的：

- Gitea 安装与仓库创建
- 镜像构建与推送 Harbor
- Helm 参数化深化
- Argo CD 正式安装与同步
