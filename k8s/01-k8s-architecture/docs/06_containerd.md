# 第 5 步：在 Kubernetes 节点安装 containerd

## 本步目标

在所有 Kubernetes 节点上安装并启用 `containerd`。

这一步完成后，下面这些节点都应该具备可用的容器运行时：

- `cp01`
- `cp02`
- `cp03`
- `wk-app01`
- `wk-app02`
- `wk-edge01`
- `wk-obs01`

## 为什么要先安装 containerd

Kubernetes 本身不直接负责运行容器。  
它需要一个 **container runtime（容器运行时）** 来真正启动 Pod 里的容器。

在这门课里，我们统一使用：

- `containerd`

这样做的好处是：

- 结构清晰
- 更贴近 Kubernetes 当前主流实践
- 与 `kubelet` 的集成稳定

## 为什么要设置 `SystemdCgroup = true`

这一点非常关键。

在 Ubuntu 24.04 上，`systemd` 是系统的初始化和服务管理器。  
Kubernetes 的 `kubelet` 也默认更适合配合 `systemd` 的 cgroup 驱动工作。

如果 `containerd` 和 `kubelet` 的 cgroup 驱动不一致，后续可能出现：

- Pod 生命周期管理不一致
- `kubelet` 与运行时协同异常
- 资源隔离与统计结果不一致

所以这里必须明确设置：

```text
SystemdCgroup = true
```

## 对应脚本

本步对应脚本：

- `k8s/01-k8s-architecture/scripts/05_install_containerd_remote.sh`

这个脚本会完成：

1. 安装 `containerd`
2. 生成默认配置文件 `/etc/containerd/config.toml`
3. 把 `SystemdCgroup` 改成 `true`
4. 启动并设置 `containerd` 开机自启
5. 打印版本和关键状态

## 执行命令

先给脚本增加执行权限：

```bash
chmod +x /docker_k8s_2026/k8s/01-k8s-architecture/scripts/05_install_containerd_remote.sh
```

然后执行：

```bash
bash /docker_k8s_2026/k8s/01-k8s-architecture/scripts/05_install_containerd_remote.sh
```

## 执行后的验证

建议至少抽查 `cp01` 和 `wk-app01`。

### 抽查命令

```bash
ssh root@cp01 "containerd --version && systemctl status containerd --no-pager && containerd config dump | grep SystemdCgroup | head -n 1"
ssh root@wk-app01 "containerd --version && systemctl status containerd --no-pager && containerd config dump | grep SystemdCgroup | head -n 1"
```

## 预期结果

### 1. 版本存在

```bash
containerd --version
```

预期：

- 能看到 `containerd 1.7.x`

### 2. 服务状态正常

```bash
systemctl status containerd --no-pager
```

预期：

- `active (running)`

### 3. Cgroup 驱动正确

```bash
containerd config dump | grep SystemdCgroup | head -n 1
```

预期：

```text
SystemdCgroup = true
```

## 本步完成标准

只要满足下面条件，就可以进入下一步：

- 所有 K8s 节点均已安装 `containerd`
- `containerd` 服务为 `active`
- `SystemdCgroup = true`

## 下一步

下一步进入 Harbor 信任配置：

- `docs/07_containerd_harbor.md`
