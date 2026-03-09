# 第 1 步：预热第三章北向入口制品

## 本步目标

在正式安装 `MetalLB` 和启用 `Gateway API` 之前，先把第三章需要的关键制品准备到本地：

- `MetalLB` 原始安装清单
- `Gateway API` 标准 CRD
- `MetalLB` 镜像
- 北向演示应用镜像

## 为什么要先做这一步

第三章继续坚持一个原则：

> 后续真正执行安装时，尽量不再依赖公网临时拉取。

这样有三个好处：

1. 快照恢复后可重复执行
2. 上课时更稳，不容易受外网抖动影响
3. 镜像与 YAML 的来源都清晰、可讲

## 本步脚本

- `k8s/03-north-south-traffic/scripts/01_prepare_north_south_artifacts.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/03-north-south-traffic/scripts/01_prepare_north_south_artifacts.sh
```

```bash
bash /docker_k8s_2026/k8s/03-north-south-traffic/scripts/01_prepare_north_south_artifacts.sh
```

## 这一步做了什么

脚本会按下面顺序执行：

1. 自动检查并恢复集群连通性
2. 创建第三章 `artifacts/` 目录
3. 安装 `Helm`
4. 在 Harbor 中创建 `northsouth` 项目
5. 下载 `MetalLB` 原始安装清单并改写镜像地址为 Harbor
6. 下载 `Gateway API` 标准 CRD 聚合清单
7. 将 `MetalLB` 和演示镜像推送到 Harbor
8. 在所有 Kubernetes 节点预拉镜像

## 执行后的检查

```bash
ls -lh /docker_k8s_2026/k8s/03-north-south-traffic/artifacts/
```

```bash
curl -I http://ops:9000/03-north-south-traffic/artifacts/metallb-native-v0.15.3.yaml
```

```bash
curl -I http://ops:9000/03-north-south-traffic/artifacts/gateway-api-standard-install-v1.4.1.yaml
```

预期：

- 本地存在 `metallb-native-v0.15.3.yaml`
- 本地存在 `gateway-api-standard-install-v1.4.1.yaml`
- 通过 `ops:9000` 可访问这些文件

## 本步完成标准

- Harbor 项目 `northsouth` 已就绪
- 第三章 YAML 已落地到本地 `artifacts/`
- 所有节点已预拉本章所需镜像

## 下一步

进入第 2 步，安装 `MetalLB`：

- `docs/03_install_metallb.md`
