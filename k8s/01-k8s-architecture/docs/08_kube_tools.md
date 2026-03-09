# 第 7 步：安装 kubeadm、kubelet、kubectl

## 本步目标

把 Kubernetes 基础工具安装到所有 K8s 节点，并在 `ops` 本机安装 `kubectl`。

这一步完成后，希望达到下面的状态：

- 所有 K8s 节点都具备：
  - `kubeadm`
  - `kubelet`
  - `kubectl`
- `ops` 本机具备：
  - `kubectl`

## 为什么这一节非常关键

这一节实际上是在给后面的集群初始化准备“施工工具”。

### `kubeadm` 是什么

`kubeadm` 用来初始化控制平面、生成 join 命令、把节点加入集群。

### `kubelet` 是什么

`kubelet` 是每个节点上的核心代理进程。  
后面每个节点是否能真正承载 Pod，都离不开它。

### `kubectl` 是什么

`kubectl` 是我们日常操作 Kubernetes 的命令行工具。

这门课里，除了节点本机上的 `kubectl`，我们还要在 `ops` 上单独装一个 `kubectl`，这样后面你就能在 `ops` 上直接管理整个集群。

## 版本固定

本课程统一冻结：

- Kubernetes：`v1.33.9`

在 apt 包层面，本节直接锁定为：

- `1.33.9-1.1`

这样做的目的，是保证快照恢复后结果一致，不会因为仓库更新而出现版本漂移。

## 对应脚本

本步对应脚本：

- `k8s/01-k8s-architecture/scripts/07_install_kube_tools_remote.sh`

这个脚本会做两件事：

1. 在 `ops` 本机安装固定版本的 `kubectl`
2. 在所有 K8s 节点安装固定版本的：
   - `kubeadm`
   - `kubelet`
   - `kubectl`

## 执行命令

先给脚本增加执行权限：

```bash
chmod +x /docker_k8s_2026/k8s/01-k8s-architecture/scripts/07_install_kube_tools_remote.sh
```

然后执行：

```bash
bash /docker_k8s_2026/k8s/01-k8s-architecture/scripts/07_install_kube_tools_remote.sh
```

## 执行后的验证

### 验证 1：检查 `ops` 本机的 kubectl

```bash
kubectl version --client
```

预期：

- 能看到 `v1.33.9`

### 验证 2：检查控制平面节点

```bash
ssh root@cp01 "kubeadm version -o short && kubectl version --client && systemctl is-enabled kubelet"
```

预期：

- `kubeadm` 版本为 `v1.33.9`
- `kubectl` 客户端版本为 `v1.33.9`
- `kubelet` 已经 `enabled`

### 验证 3：检查工作节点

```bash
ssh root@wk-app01 "kubeadm version -o short && kubectl version --client && systemctl is-enabled kubelet"
```

预期：

- 结果与控制平面节点一致

## 本步完成标准

只要满足下面条件，就可以进入下一步：

- `ops` 本机已安装 `kubectl`
- 所有 K8s 节点已安装 `kubeadm/kubelet/kubectl`
- 所有版本均固定为 `v1.33.9`
- `kubelet` 已设置开机自启

## 下一步

下一步进入第一个控制平面初始化：

- `docs/09_kubeadm_init.md`
