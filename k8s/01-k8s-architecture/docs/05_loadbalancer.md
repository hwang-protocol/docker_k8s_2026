# 第 4 步：部署 API Server 高可用入口

## 本步目标

在 `lb01` 和 `lb02` 上部署一套用于 Kubernetes API Server 的高可用入口。

本步完成后，希望达到下面的状态：

- `api.qytk8s.com` 指向 VIP `10.1.1.10`
- `lb01` 和 `lb02` 运行 `HAProxy`
- `lb01` 和 `lb02` 运行 `Keepalived`
- VIP `10.1.1.10` 在正常情况下漂移到 `lb01`
- 后续 `kubeadm init` 可以把 `api.qytk8s.com:6443` 作为控制平面统一入口

## 为什么需要这一步

我们这一章不是单控制平面，而是：

- `cp01`
- `cp02`
- `cp03`

组成三控制平面高可用架构。

如果没有一个固定入口，后续客户端、`kubeadm join`、`kubectl`、甚至后续的自动化脚本都需要记住某一台控制平面的真实地址。

这不符合高可用设计。

所以这里要先准备一层入口：

- `HAProxy`：负责把 `6443` 端口的流量转发给控制平面节点
- `Keepalived`：负责提供漂移 VIP

## 两个组件分别做什么

### HAProxy 做什么

`HAProxy` 是四层负载均衡器。

在这里，它只做一件事：

- 监听 `6443`
- 把进入的流量转发给：
  - `cp01:6443`
  - `cp02:6443`
  - `cp03:6443`

### Keepalived 做什么

`Keepalived` 负责管理一个漂移的虚拟 IP（VIP）。

在这里，这个 VIP 是：

- `10.1.1.10`

正常情况下：

- VIP 在 `lb01`

如果 `lb01` 挂掉：

- VIP 漂移到 `lb02`

这样，外部永远只访问一个固定入口：

- `api.qytk8s.com:6443`

## 本步固定参数

- VIP：`10.1.1.10`
- 域名：`api.qytk8s.com`
- 网卡：`ens160`
- `lb01`：主节点（MASTER）
- `lb02`：备节点（BACKUP）

## 对应脚本

本步对应脚本：

- `k8s/01-k8s-architecture/scripts/04_setup_haproxy_keepalived_remote.sh`

这个脚本会做下面几件事：

1. 在 `lb01`、`lb02` 安装 `haproxy` 和 `keepalived`
2. 写入 `haproxy.cfg`
3. 写入 `keepalived.conf`
4. 写入健康检查脚本
5. 启动并设置服务开机自启

## 执行命令

先给脚本增加执行权限：

```bash
chmod +x /docker_k8s_2026/k8s/01-k8s-architecture/scripts/04_setup_haproxy_keepalived_remote.sh
```

然后执行：

```bash
bash /docker_k8s_2026/k8s/01-k8s-architecture/scripts/04_setup_haproxy_keepalived_remote.sh
```

## 执行后的验证

### 验证 1：检查服务状态

```bash
for node in lb01 lb02; do
  echo "===== ${node} ====="
  ssh root@${node} "systemctl is-active haproxy keepalived"
done
```

预期：

- 每台机器都会先打印主机名分隔线
- `haproxy` 和 `keepalived` 都显示为 `active`

### 验证 2：检查 VIP 在哪台机器上

```bash
for node in lb01 lb02; do
  echo "===== ${node} ====="
  ssh root@${node} "ip addr show ens160 | grep 10.1.1.10 || true"
done
```

预期：

- 哪台机器输出了 `10.1.1.10`，VIP 就在那台机器上
- 正常情况下，VIP 出现在 `lb01`

### 验证 3：检查 `api.qytk8s.com` 是否能连到 6443

```bash
nc -vz api.qytk8s.com 6443
```

预期：

- TCP 端口可以建立连接

说明：

- 此时后端控制平面节点还没有启动 API Server
- 所以这里的重点是“入口层已经准备好”，不是 API Server 已经可用

### 验证 4：检查配置文件

```bash
ssh root@lb01 "cat /etc/haproxy/haproxy.cfg"
ssh root@lb01 "cat /etc/keepalived/keepalived.conf"
```

预期：

- `HAProxy` 后端包含 `cp01`、`cp02`、`cp03`
- `Keepalived` 已配置 VIP `10.1.1.10`

## 本步完成标准

只要满足下面条件，就可以进入下一步：

- `lb01` 和 `lb02` 的 `haproxy` 正常运行
- `lb01` 和 `lb02` 的 `keepalived` 正常运行
- VIP `10.1.1.10` 已成功漂移到主节点
- `api.qytk8s.com` 已成为后续 kubeadm 可以使用的统一入口

## 下一步

下一步进入 containerd 安装：

- `docs/06_containerd.md`
