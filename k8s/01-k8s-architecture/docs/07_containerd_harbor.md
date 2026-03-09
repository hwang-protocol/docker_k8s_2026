# 第 6 步：让 containerd 信任 Harbor

## 本步目标

让所有 Kubernetes 节点上的 `containerd` 可以安全地从 `harbor.qytk8s.com` 拉取镜像。

这一步完成后，希望达到下面的状态：

- Harbor CA 已分发到所有 K8s 节点
- `containerd` 已信任 `harbor.qytk8s.com`
- `sandbox_image` 已改为本地 Harbor 中的 `pause:3.10`

## 为什么必须做这一步

Harbor 现在是 HTTPS 部署，而且使用的是课程内部自签发证书。

如果不把 Harbor CA 分发到 Kubernetes 节点，后面节点拉镜像时就会遇到典型错误：

```text
x509: certificate signed by unknown authority
```

所以这一步的本质是：

1. 把 Harbor 的 CA 告诉每个节点
2. 告诉 `containerd` 去哪里找这个 CA
3. 把后续最基础的 `pause` 镜像先切到 Harbor

## 为什么要改 `pause` 镜像

`pause` 是 Kubernetes 每个 Pod 都会依赖的基础镜像之一。

后续即使你的业务镜像都是本地的，如果 `pause` 还指向公网仓库，集群初始化和启动 Pod 时仍然可能失败。

所以这里要明确改成：

```text
harbor.qytk8s.com/k8s/pause:3.10
```

## 对应脚本

本步对应脚本：

- `k8s/01-k8s-architecture/scripts/06_config_containerd_harbor_remote.sh`

这个脚本会完成：

1. 把 Harbor CA 从 `ops` 分发到各 K8s 节点
2. 创建 `/etc/containerd/certs.d/harbor.qytk8s.com/hosts.toml`
3. 修改 `config_path`
4. 修改 `sandbox_image`
5. 重启 `containerd`

## 执行命令

先给脚本增加执行权限：

```bash
chmod +x /docker_k8s_2026/k8s/01-k8s-architecture/scripts/06_config_containerd_harbor_remote.sh
```

然后执行：

```bash
bash /docker_k8s_2026/k8s/01-k8s-architecture/scripts/06_config_containerd_harbor_remote.sh
```

## 执行后的验证

建议抽查 `cp01` 和 `wk-app01`。

### 验证 1：检查 Harbor CA

```bash
ssh root@cp01 "ls -l /etc/containerd/certs.d/harbor.qytk8s.com/ca.crt"
ssh root@wk-app01 "ls -l /etc/containerd/certs.d/harbor.qytk8s.com/ca.crt"
```

### 验证 2：检查 hosts.toml

```bash
ssh root@cp01 "cat /etc/containerd/certs.d/harbor.qytk8s.com/hosts.toml"
```

预期：

- `server = "https://harbor.qytk8s.com"`
- `ca = "/etc/containerd/certs.d/harbor.qytk8s.com/ca.crt"`

### 验证 3：检查 containerd 配置

```bash
ssh root@cp01 "grep -n 'config_path' /etc/containerd/config.toml && grep -n 'sandbox_image' /etc/containerd/config.toml"
```

预期：

- `config_path = "/etc/containerd/certs.d"`
- `sandbox_image = "harbor.qytk8s.com/k8s/pause:3.10"`

### 验证 4：检查 containerd 服务状态

```bash
ssh root@cp01 "systemctl status containerd --no-pager"
```

预期：

- `active (running)`

## 本步完成标准

只要满足下面条件，就可以进入下一步：

- Harbor CA 已分发到所有 K8s 节点
- `hosts.toml` 配置正确
- `sandbox_image` 已切换到 Harbor
- `containerd` 重启后正常运行

## 下一步

下一步进入 Kubernetes 工具安装：

- `docs/08_kube_tools.md`
