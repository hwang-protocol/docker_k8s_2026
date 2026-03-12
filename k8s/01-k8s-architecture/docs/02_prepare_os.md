# 第 1 步：所有节点系统初始化

## 本步目标

在正式安装 Harbor、containerd、kubeadm 之前，先把所有 Ubuntu 节点整理成适合 Kubernetes 的基础状态。

这一步完成后，我们希望所有相关节点都具备下面这些条件：

- 启动速度已优化（multi-user.target、禁用 snapd/e2scrub/apport 等拖慢启动的服务）
- swap 已关闭
- 内核模块 `overlay` 和 `br_netfilter` 已加载
- `sysctl` 已具备 Kubernetes 网络基础参数
- 时区统一为 `Asia/Shanghai`
- SSH 登录不再因为 `UseDNS` 产生明显等待
- 基础工具已经安装完成
- `open-iscsi` 已安装，为后续 Longhorn 做准备
- 自动更新服务不会在课堂执行过程中抢占 `apt/dpkg` 锁

## 为什么要做这一步

### 1. 为什么要关闭 swap

`kubelet` 默认要求关闭 swap。  
如果不关闭，后续初始化集群时可能无法满足 Kubernetes 的基础运行要求。

### 2. 为什么要加载 `overlay` 和 `br_netfilter`

- `overlay`：容器镜像分层和容器运行依赖这个模块
- `br_netfilter`：让 Linux bridge 流量可以被 iptables 看到，这是 Kubernetes 网络的基础能力

### 3. 为什么要配置 `ip_forward`

Pod 网络转发依赖 `net.ipv4.ip_forward=1`。  
如果不打开，后面无论是 `Cilium` 还是其他 CNI，都可能无法正常转发流量。

### 4. 为什么要关闭 `UseDNS`

关闭 `UseDNS` 后，SSH 登录过程会更顺畅，也更适合批量运维与课堂演示。

### 5. 为什么现在就安装 `open-iscsi`

因为第五章会用到 `Longhorn`。  
我们现在先把基础依赖装好，后面就不用再回头补环境。

### 6. 为什么要优化启动速度

实验环境为纯 CLI，不需要图形界面。默认的 `graphical.target` 会等待 GDM、snapd.seeded、e2scrub_reap 等大量服务，导致到登录界面需 3 分钟以上。优化后通常可缩至 1 分钟内：

- `multi-user.target`：CLI 服务器标准，不再等待图形栈
- `mask e2scrub_reap`：ext4 后台校验可改为按需执行
- `disable snapd`：课程环境未使用 snap
- `disable update-notifier-download / apport`：减少不必要的后台服务

上述优化不影响 Kubernetes、containerd、Harbor 等核心组件。

### 7. 为什么要关闭自动更新

`Ubuntu Server 24.04` 默认会运行 `unattended-upgrades`。  
如果它正在后台更新软件包，就会占用 `apt/dpkg` 锁，从而影响初始化阶段的软件安装顺序。

对于课程环境和快照复现环境，更适合先关闭自动更新，保证每次执行结果稳定、可控。

## 包管理执行机制

脚本会先处理 Ubuntu 后台自动更新与包管理锁，确保系统初始化过程连续完成。

本步重点不是手工处理 `apt/dpkg` 冲突，而是让所有节点进入统一、可继续安装 Kubernetes 的基础状态。

## 本步涉及节点

这一步会处理下面这些节点（含 ops，实现所有 Linux 统一优化）：

- `ops`
- `lb01`
- `lb02`
- `cp01`
- `cp02`
- `cp03`
- `wk-app01`
- `wk-app02`
- `wk-edge01`
- `wk-obs01`
- `harbor`
- `git`

说明：

- `win2019` 不属于本步范围

## 先看脚本

脚本路径：

- `k8s/01-k8s-architecture/scripts/01_prepare_os_remote.sh`

这个脚本的思路非常重要：

1. 在 `ops` 上定义一组目标主机名
2. 通过 `ssh root@主机名` 登录远端
3. 把一段 Bash 初始化代码下发到远端执行
4. 每台机器执行完后打印结果

这就是最典型的 **Shell 自动化批量运维** 思路。

## 执行命令

先给脚本增加执行权限：

```bash
chmod +x /docker_k8s_2026/k8s/01-k8s-architecture/scripts/01_prepare_os_remote.sh
```

然后执行脚本：

```bash
bash /docker_k8s_2026/k8s/01-k8s-architecture/scripts/01_prepare_os_remote.sh
```

脚本也支持按主机名单独执行。示例：

```bash
bash /docker_k8s_2026/k8s/01-k8s-architecture/scripts/01_prepare_os_remote.sh wk-app02
```

## 你会看到什么

正常情况下，脚本会按节点逐台输出，类似下面这种结构：

```text
=========================================================
节点：cp01
=========================================================
[1/10] 优化启动速度
[2/10] 关闭 swap
[3/10] 加载内核模块
[4/10] 配置 sysctl
[5/10] 设置时区
[6/10] 优化 SSH 登录
[7/10] 关闭 UFW
[8/10] 关闭自动更新，避免 apt 锁冲突
[等待阶段可能会出现]
等待 apt/dpkg 锁释放... (0s/180s)
等待 apt/dpkg 锁释放... (3s/180s)
[9/10] 安装基础工具
[10/10] 启动 Longhorn 依赖服务
hostname=cp01
swap_status=0
timezone=Asia/Shanghai
dns=10.1.1.100
gateway=10.1.1.254
OK
```

## 执行后的验证

建议你至少抽查一台控制平面节点和一台工作节点。

例如检查 `cp01`：

```bash
ssh root@cp01
```

进入后执行：

```bash
swapon --show
lsmod | grep br_netfilter
lsmod | grep overlay
sysctl net.ipv4.ip_forward
timedatectl
systemctl status iscsid --no-pager
exit
```

## 预期结果

### 1. swap

```bash
swapon --show
```

预期：

- 没有输出

### 2. 内核模块

```bash
lsmod | grep br_netfilter
lsmod | grep overlay
```

预期：

- 都能看到对应模块

### 3. 转发参数

```bash
sysctl net.ipv4.ip_forward
```

预期：

```text
net.ipv4.ip_forward = 1
```

### 4. 时区

```bash
timedatectl
```

预期：

- 时区为 `Asia/Shanghai`

### 5. iscsid

```bash
systemctl status iscsid --no-pager
```

预期：

- 服务存在并已启动，或至少已正确安装

## 本步完成标准

只要满足下面条件，就可以进入下一步：

- 所有目标节点（含 ops）脚本执行完成
- 启动优化已生效（重启后到登录界面时间明显缩短）
- 至少抽查 1 台控制平面节点和 1 台工作节点
- swap 已关闭
- `ip_forward=1`
- DNS 仍然保持为 `10.1.1.100`
- SSH 登录速度明显改善
- `unattended-upgrades` 不再干扰课堂安装过程

## 下一步

下一步进入 Harbor 部署：

- `docs/03_harbor.md`
