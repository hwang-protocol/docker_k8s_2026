# 第 11 步：本章总验收

## 本步目标

对第一章当前已经完成的 Kubernetes 基础架构进行一次总体验收。

本章结束时，预期状态不是“所有节点 Ready”，而是：

- Harbor 正常
- 高可用入口正常
- 3 控制平面 + 4 Worker 已全部加入
- 因为还没有安装 CNI，节点整体 `NotReady` 是正常现象

## 为什么本章结束时节点仍然可能是 NotReady

这是第一章最容易让学员误解的地方。

当前我们已经完成了：

- 控制平面
- etcd
- kubelet
- kube-proxy
- Harbor
- HA 入口

但是还**没有完成**：

- Pod 网络
- CNI 安装

所以节点现在显示 `NotReady`，并不是失败，而是课程进度还没有进入下一章 `Cilium`。

## 验收命令

### 验收 1：查看完整节点列表

```bash
kubectl get nodes -o wide
```

预期：

- 共 7 个节点
- 3 个控制平面
- 4 个 Worker
- 当前大概率为 `NotReady`

### 验收 2：查看节点标签

```bash
kubectl get nodes --show-labels
```

预期：

- `wk-app01` 和 `wk-app02` 带 `node-role=app`
- `wk-edge01` 带 `node-role=edge`
- `wk-obs01` 带 `node-role=observability`

### 验收 3：查看系统 Pod

```bash
kubectl get pods -A -o wide
```

预期：

- 控制平面静态 Pod 正常
- `coredns` 可能还未完全 Ready

### 验收 4：查看 Harbor 健康状态

```bash
curl -k https://harbor.qytk8s.com/api/v2.0/health
```

预期：

- `status` 为 `healthy`

### 验收 5：查看 API 高可用入口

```bash
nc -vz api.qytk8s.com 6443
```

预期：

- 连接成功

### 验收 6：查看 etcd 成员

```bash
ssh root@cp01 "export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock && ETCD_ID=\$(crictl ps --name etcd -q) && crictl exec \$ETCD_ID etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key --endpoints=https://10.1.1.101:2379,https://10.1.1.102:2379,https://10.1.1.103:2379 member list"
```

预期：

- 能看到 3 个 etcd 成员

## 本章最终完成标准

只要下面这些都成立，就说明第一章完成：

- Harbor 正常
- `api.qytk8s.com:6443` 可达
- 3 控制平面已加入
- 4 Worker 已加入
- 节点标签已完成
- etcd 成员正常
- 节点当前 `NotReady`，且原因明确是“还未安装 CNI”

## 下一章衔接

下一章将进入：

- `Cilium`
- `eBPF`
- `Hubble`

也就是：

- 云原生网络与服务互联
