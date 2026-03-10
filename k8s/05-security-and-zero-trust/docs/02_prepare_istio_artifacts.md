# 第 1 步：预热 Istio 制品与演示镜像

## 本步目标

在真正安装 `Istio` 之前，先把第五章所需的关键制品准备到本地环境中：

- `istioctl`
- `Istio` 离线安装包
- Harbor 中的 `istio` 镜像项目
- `helloworld` / `httpbin` / `curl` 演示镜像

这样后续课堂安装时，就不会过度依赖当下的公网状态。

## 本步脚本

- `k8s/05-security-and-zero-trust/scripts/01_prepare_istio_artifacts.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/01_prepare_istio_artifacts.sh
```

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/01_prepare_istio_artifacts.sh
```

## 这一步做了什么

脚本会按下面顺序执行：

1. 自动检查并恢复集群连通性
2. 在 `ops` 上安装或更新 `helm`
3. 下载 `Istio 1.29.0` 离线安装包
4. 在 `ops` 上安装 `istioctl`
5. 在 Harbor 中创建 `istio` 项目
6. 将 `pilot`、`proxyv2`、`ztunnel`、`install-cni` 与演示镜像推送到 Harbor
7. 在所有 Kubernetes 节点预拉关键镜像

## 执行后的检查

```bash
istioctl version --remote=false
```

```bash
ls -lh /docker_k8s_2026/k8s/05-security-and-zero-trust/artifacts
```

```bash
curl -k -u 'admin:Harbor12345' "https://harbor.qytk8s.com/api/v2.0/projects/istio/repositories?page=1&page_size=30"
```

## 预期

- `istioctl` 已可直接使用
- 本地 `artifacts/` 目录中出现 `Istio 1.29.0` 安装包
- Harbor 项目 `istio` 中能看到本章所需镜像

## 理论讲解点

这一节建议你重点讲：

- 为什么课堂环境需要“制品前置准备”
- 为什么 `Istio` 安装不能完全依赖即时公网下载
- 为什么示例镜像也要冻结版本

## 下一步

进入第 2 步，安装 `Istio Ambient`：

- `docs/03_install_istio_ambient.md`
