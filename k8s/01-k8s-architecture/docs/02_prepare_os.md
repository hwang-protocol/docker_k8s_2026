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

---

## 本步顺序

这一小节建议按下面顺序执行：

1. 先按要求处理快照
2. 确认相关虚拟机已经正常开机
3. 登录 `ops`，执行 `01_prepare_os_remote.sh`
4. 抽查 `cp01` 和任意一台 Worker，确认系统初始化结果正确

---

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

### 6. 为什么要优化启动速度（Ubuntu 默认安装的一些问题）

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

---

## 包管理执行机制

脚本会先处理 Ubuntu 后台自动更新与包管理锁，确保系统初始化过程连续完成。

本步重点不是手工处理 `apt/dpkg` 冲突，而是让所有节点进入统一、可继续安装 Kubernetes 的基础状态。

---

## 执行前准备：先恢复快照，再执行脚本

这一章默认你是从一套“可复现的基础环境”重新开始。  
因此这里先只处理两件事：

1. 按下面的要求处理快照
2. 恢复快照后确认相关虚拟机已经正常开机

下面表格中的名称使用的是虚拟化平台里的 **VM 名称**。

| VM 名称 | 快照名称 / 快照要求 |
| :--- | :--- |
| `K8S-cp01` | `免密+网络+DNS` |
| `K8S-cp02` | `免密+网络+DNS` |
| `K8S-cp03` | `免密+网络+DNS` |
| `K8S-git` | `免密+网络+DNS` |
| `K8S-lb01` | `免密+网络+DNS` |
| `K8S-lb02` | `免密+网络+DNS` |
| `K8S-harbor` | `不要恢复` |
| `K8S-ops` | `不要恢复` |
| `K8S-Win2019` | `不要恢复` |
| `K8S2026-VyOS` | `不要恢复` |
| `K8S-wk-app01` | `添加100g硬盘, 推荐快照` |
| `K8S-wk-app02` | `添加100g硬盘, 推荐快照` |
| `K8S-wk-edge01` | `添加100g硬盘, 推荐快照` |
| `K8S-wk-obs01` | `添加100g硬盘, 推荐快照` |

---

## 本步涉及节点

下面这些是脚本里实际使用的 **Linux 主机名**。  
也就是说，前一节表格写的是虚拟化平台里的 VM 名称，这一节写的是脚本里通过 SSH 访问的主机名。

这一步会处理下面这些节点（含 `ops`，实现所有 Linux 统一优化）：

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

补充：

- `win2019` 不属于本步范围
- 在执行本步脚本前，先完成上一节中的快照处理并开机

---

## 先看脚本

这个脚本在 `ops` 上执行，目标节点使用的是上面这一节中的主机名。

脚本路径：

- `k8s/01-k8s-architecture/scripts/01_prepare_os_remote.sh`

这个脚本的思路非常重要：

1. 在 `ops` 上定义一组目标主机名
2. 通过 `ssh root@主机名` 登录远端
3. 把一段 Bash 初始化代码下发到远端执行
4. 每台机器执行完后打印结果

这就是最典型的 **Shell 自动化批量运维** 思路。

脚本内部已经写了详细注释，阅读脚本本身即可：

- `k8s/01-k8s-architecture/scripts/01_prepare_os_remote.sh`

---

## 执行命令

下面这些命令都在 `ops` 上执行。

在执行下面命令之前，先确认两件事：

- 需要恢复 `免密+网络+DNS` 快照的机器已经恢复完成并成功开机
- 其他机器也已经按表格要求处理完成并正常开机

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

---

## 你会看到什么

正常情况下，你会在 `ops` 上看到脚本按节点逐台输出，类似下面这种结构：

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

---

## 执行后的验证

建议你至少抽查一台控制平面节点和一台工作节点。

下面示例仍然在 `ops` 上执行。  
例如检查 `cp01`，可以直接整段执行下面这段命令：

```bash
ssh root@cp01 'bash -s' <<'EOF'
echo '+++ cp01 output begin +++'

echo '========== swap =========='
swapon --show

echo '========== kernel modules =========='
lsmod | grep br_netfilter
lsmod | grep overlay

echo '========== ip_forward =========='
sysctl net.ipv4.ip_forward

echo '========== timezone =========='
timedatectl

echo '========== iscsid =========='
systemctl status iscsid --no-pager

echo '+++ cp01 output end +++'
EOF
```

正常情况下，你会看到类似下面的输出：

```text
+++ cp01 output begin +++

========== swap ==========

========== kernel modules ==========
br_netfilter           32768  0
bridge                421888  1 br_netfilter
overlay               212992  0

========== ip_forward ==========
net.ipv4.ip_forward = 1

========== timezone ==========
               Local time: Mon 2026-03-23 09:00:00 CST
           Universal time: Mon 2026-03-23 01:00:00 UTC
                 RTC time: Mon 2026-03-23 01:00:00
                Time zone: Asia/Shanghai (CST, +0800)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no

========== iscsid ==========
● iscsid.service - iSCSI initiator daemon (iscsid)
     Loaded: loaded (...)
     Active: active (running) ...

+++ cp01 output end +++
```

判断标准：

- `swap` 这一段没有输出，表示 swap 已关闭
- `kernel modules` 这一段能看到 `br_netfilter` 和 `overlay`
- `ip_forward` 这一段应为 `net.ipv4.ip_forward = 1`
- `timezone` 这一段能看到 `Asia/Shanghai`
- `iscsid` 这一段显示 `active (running)` 或至少服务已经正确安装

---

## 本步完成标准

只要满足下面条件，就可以进入下一步：

- 相关虚拟机已经按要求处理快照并正常开机
- 所有目标节点（含 ops）脚本执行完成
- 启动优化已生效（重启后到登录界面时间明显缩短）
- 至少抽查 1 台控制平面节点和 1 台工作节点
- swap 已关闭
- `ip_forward=1`
- DNS 仍然保持为 `10.1.1.100`
- SSH 登录速度明显改善
- `unattended-upgrades` 不再干扰课堂安装过程

---

## 下一步

下一步进入 Harbor 部署：

- `docs/03_harbor.md`
