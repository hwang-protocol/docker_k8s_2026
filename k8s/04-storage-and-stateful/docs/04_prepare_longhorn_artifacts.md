# 第 3 步：准备 Longhorn Chart 与 Harbor 镜像

## 本步目标

在正式安装 `Longhorn` 前，先把第四章所需关键制品准备到本地：

- `Longhorn Helm Chart`
- Longhorn 安装渲染清单
- Longhorn 所需镜像
- 有状态演示镜像

## 为什么要先做这一步

第四章继续坚持一个原则：

> 后续真正执行安装时，尽量不再依赖公网临时拉取。

这样有 3 个好处：

1. 快照恢复后可重复执行
2. 上课时更稳，不容易受外网抖动影响
3. Chart、YAML、镜像来源都清晰，便于讲解

## 本步脚本

- `k8s/04-storage-and-stateful/scripts/02_prepare_longhorn_artifacts.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/02_prepare_longhorn_artifacts.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/02_prepare_longhorn_artifacts.sh
```

## 这一步做了什么

脚本会按下面顺序执行：

1. 自动检查并恢复集群连通性
2. 创建第四章 `artifacts/` 目录
3. 安装 `Helm`
4. 在 Harbor 中创建 `longhornio` 与 `storage` 项目
5. 下载 `Longhorn 1.11.0` Chart 到本地
6. 从 Chart 中抽取镜像列表
7. 将镜像拉到 `harbor` 节点并推送到 `Harbor`
8. 在所有 Kubernetes 节点预拉镜像

## 执行后的检查

```bash
ls -lh /docker_k8s_2026/k8s/04-storage-and-stateful/artifacts/
```

```bash
curl -I http://ops:9000/04-storage-and-stateful/artifacts/longhorn-1.11.0.tgz
```

```bash
curl -I http://ops:9000/04-storage-and-stateful/artifacts/longhorn-rendered-1.11.0.yaml
```

预期：

- 本地存在 `longhorn-1.11.0.tgz`
- 本地存在 `longhorn-rendered-1.11.0.yaml`
- 本地存在镜像清单文件
- 通过 `ops:9000` 可以访问这些制品

## 本步完成标准

- Harbor 项目 `longhornio` 已就绪
- Harbor 项目 `storage` 已就绪
- Longhorn Chart 已落地到本地 `artifacts/`
- 所有节点都已预拉第四章所需镜像

## 下一步

进入第 4 步，安装 Longhorn：

- `docs/05_install_longhorn.md`
