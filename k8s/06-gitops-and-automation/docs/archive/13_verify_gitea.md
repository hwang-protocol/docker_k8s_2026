# 第 12 步：验证 Gitea

## 本步目标

只读验证：

- Gitea 是否正常
- Git 服务入口是否可访问
- 仓库基础环境是否具备

## 本步脚本

- `k8s/06-gitops-and-automation/scripts/09_verify_gitea.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/09_verify_gitea.sh
```

```bash
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/09_verify_gitea.sh
```

## 验收顺序

1. 首页可访问
2. API 版本接口可访问
3. git 节点容器状态正常

## 通过标准

- `https://git.qytk8s.com` 正常
- `/api/v1/version` 可返回版本
- `gitea` 与 `gitea-postgres` 正常运行

## 下一步

后续就可以继续进入：

- 镜像构建与推送 Harbor
- Argo CD 安装
- GitOps 同步与验收
