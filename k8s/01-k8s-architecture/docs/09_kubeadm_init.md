# 第 8 步：初始化第一个控制平面节点

## 本步目标

在 `cp01` 上完成第一台控制平面节点初始化。

这一步完成后，希望达到下面的状态：

- `cp01` 已经成为集群中的第一个控制平面
- `api.qytk8s.com:6443` 已被 kubeadm 正式作为控制平面统一入口使用
- `cp01` 上已经生成管理集群所需的 `admin.conf`
- `ops` 上已经拿到可用的 `kubectl` 配置文件

## 为什么这里必须使用 `api.qytk8s.com`

因为我们做的是高可用控制平面，不是单节点演示集群。

后续会有：

- `cp01`
- `cp02`
- `cp03`

三台控制平面节点。

如果这里直接把控制平面入口写成某一台机器的真实 IP，后面再扩展高可用就会变得很别扭。

所以从第一台控制平面开始，就统一使用：

- `api.qytk8s.com:6443`

## 为什么这里使用 kubeadm 配置文件

这一步如果完全使用长命令，也能做。

但从教学和维护角度来看，使用配置文件更清晰，因为能明确展示：

- `kubernetesVersion`
- `controlPlaneEndpoint`
- `imageRepository`
- `serviceSubnet`
- `podSubnet`
- `certSANs`
- `cgroupDriver`

这也是生产环境中更推荐的写法。

## 本步固定参数

- Kubernetes 版本：`v1.33.9`
- 控制平面统一入口：`api.qytk8s.com:6443`
- 第一个控制平面节点：`cp01`
- 第一个控制平面 advertise address：`10.1.1.101`
- Service CIDR：`10.96.0.0/12`
- Pod CIDR：`10.244.0.0/16`
- 镜像仓库：`harbor.qytk8s.com/k8s`

## 对应脚本

本步对应脚本：

- `k8s/01-k8s-architecture/scripts/08_kubeadm_init_remote.sh`

这个脚本会完成：

1. 在 `ops` 上生成 `kubeadm-init-cp01.yaml`
2. 把配置文件下发到 `cp01`
3. 在 `cp01` 执行 `kubeadm init --config ... --upload-certs`
4. 在 `cp01` 配置 `/root/.kube/config`
5. 生成后续节点加入所需的 join 命令文件
6. 把 `admin.conf` 拷回 `ops`，让 `ops` 也能直接使用 `kubectl`

## 执行命令

先给脚本增加执行权限：

```bash
chmod +x /docker_k8s_2026/k8s/01-k8s-architecture/scripts/08_kubeadm_init_remote.sh
```

然后执行：

```bash
bash /docker_k8s_2026/k8s/01-k8s-architecture/scripts/08_kubeadm_init_remote.sh
```

## 执行后的验证

### 验证 1：在 `cp01` 上检查节点状态

```bash
ssh root@cp01 "kubectl get nodes -o wide"
```

预期：

- `cp01` 已经出现在节点列表中
- 当前状态通常是 `NotReady`

说明：

- 这是正常现象，因为本章此时还没有安装 CNI

### 验证 2：在 `ops` 上检查 kubectl

```bash
kubectl get nodes -o wide
```

预期：

- 在 `ops` 上也能直接看到 `cp01`

### 验证 3：检查 join 命令文件

```bash
ssh root@cp01 "ls -l /root/kubeadm-join-worker.sh /root/kubeadm-join-control-plane.sh"
```

预期：

- 两个文件都存在

## 本步完成标准

只要满足下面条件，就可以进入下一步：

- `cp01` 已完成 `kubeadm init`
- `ops` 上已经可用 `kubectl`
- join 命令文件已生成
- `cp01` 已成为第一个控制平面节点

## 下一步

下一步进入额外控制平面节点加入：

- `docs/10_join_control_planes.md`
