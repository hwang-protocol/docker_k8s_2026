# 第 3 步：预热 Kubernetes 核心镜像到 Harbor

## 本步目标

把第一章需要用到的 Kubernetes 核心镜像，提前推送到本地 Harbor 中。

这样做完之后，后面的 `kubeadm init` 和节点加入操作，就可以优先从本地 Harbor 拉取镜像，而不是依赖公网仓库。

## 为什么要做这一步

如果没有提前预热镜像，后面执行 `kubeadm init` 时会现场去拉：

- `kube-apiserver`
- `kube-controller-manager`
- `kube-scheduler`
- `kube-proxy`
- `pause`
- `etcd`
- `coredns`

在课堂环境里，这样做有两个问题：

1. 拉取速度不稳定
2. 现场出网异常时会直接影响集群初始化

所以更合理的方式是：

1. 先把镜像拉到 `harbor` 节点
2. 重新打标签
3. 推送到 `harbor.qytk8s.com/k8s`

## 本步固定版本

本课程已经冻结 Kubernetes 版本为：

- `v1.33.9`

因此本步镜像版本也全部固定写死：

| 组件 | 上游镜像 | Harbor 镜像 |
| :--- | :--- | :--- |
| kube-apiserver | `registry.k8s.io/kube-apiserver:v1.33.9` | `harbor.qytk8s.com/k8s/kube-apiserver:v1.33.9` |
| kube-controller-manager | `registry.k8s.io/kube-controller-manager:v1.33.9` | `harbor.qytk8s.com/k8s/kube-controller-manager:v1.33.9` |
| kube-scheduler | `registry.k8s.io/kube-scheduler:v1.33.9` | `harbor.qytk8s.com/k8s/kube-scheduler:v1.33.9` |
| kube-proxy | `registry.k8s.io/kube-proxy:v1.33.9` | `harbor.qytk8s.com/k8s/kube-proxy:v1.33.9` |
| pause | `registry.k8s.io/pause:3.10` | `harbor.qytk8s.com/k8s/pause:3.10` |
| etcd | `registry.k8s.io/etcd:3.5.24-0` | `harbor.qytk8s.com/k8s/etcd:3.5.24-0` |
| coredns | `registry.k8s.io/coredns/coredns:v1.12.0` | `harbor.qytk8s.com/k8s/coredns:v1.12.0` |

## 为什么 `coredns` 要单独说明

`CoreDNS` 的上游镜像路径是：

```text
registry.k8s.io/coredns/coredns:v1.12.0
```

但是在我们自己的 Harbor 里，为了让后续 `kubeadm` 使用自定义仓库更直接，这里统一整理为：

```text
harbor.qytk8s.com/k8s/coredns:v1.12.0
```

这一步必须提前处理好，否则后面很容易出现 `coredns` 拉取路径不一致的问题。

## 对应脚本

本步对应脚本：

- `k8s/01-k8s-architecture/scripts/03_push_k8s_images_remote.sh`

这个脚本会完成两件事：

1. 调用 Harbor API，创建 **公开的** `k8s` 项目
2. 在 `harbor` 节点执行 `docker pull / tag / push`

## 执行命令

先给脚本增加执行权限：

```bash
chmod +x /docker_k8s_2026/k8s/01-k8s-architecture/scripts/03_push_k8s_images_remote.sh
```

然后执行：

```bash
bash /docker_k8s_2026/k8s/01-k8s-architecture/scripts/03_push_k8s_images_remote.sh
```

## 你会看到什么

脚本会分成两个阶段：

```text
[1/2] 创建 Harbor 项目
[2/2] 在 harbor 节点拉取并推送核心镜像
```

然后会按镜像逐个输出：

```text
源镜像：registry.k8s.io/kube-apiserver:v1.33.9
目标镜像：harbor.qytk8s.com/k8s/kube-apiserver:v1.33.9
```

最后应该看到：

```text
OK: Kubernetes 核心镜像已推送到 Harbor
```

## 执行后的验证

### 验证 1：查看 Harbor 项目列表

```bash
curl -k -u 'admin:Harbor12345' https://harbor.qytk8s.com/api/v2.0/projects
```

预期：

- 可以看到 `k8s` 项目
- `k8s` 项目应为公开项目（public）

### 验证 2：查看 `k8s` 项目的仓库列表

```bash
curl -k -u 'admin:Harbor12345' "https://harbor.qytk8s.com/api/v2.0/projects/k8s/repositories?page=1&page_size=20"
```

预期：

- 可以看到 `kube-apiserver`
- 可以看到 `kube-controller-manager`
- 可以看到 `kube-scheduler`
- 可以看到 `kube-proxy`
- 可以看到 `pause`
- 可以看到 `etcd`
- 可以看到 `coredns`

### 验证 3：查看 `harbor` 节点本地镜像

```bash
ssh root@harbor "docker images | grep 'harbor.qytk8s.com/k8s'"
```

预期：

- 可以看到所有刚刚推送过的目标镜像

## 本步完成标准

只要满足下面条件，就可以进入下一步：

- Harbor 项目 `k8s` 已创建
- Harbor 项目 `k8s` 为公开项目
- 所有第一章核心镜像都已推送到 Harbor
- Harbor API 可以列出这些仓库

## 下一步

下一步进入 API Server 高可用入口部署：

- `docs/05_loadbalancer.md`
