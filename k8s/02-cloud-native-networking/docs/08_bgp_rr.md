# 第 7 步：接入 VyOS Route Reflector 与 Cilium BGP

## 本步目标

把第二章的控制面能力补齐，让 4 台 Worker 通过 `iBGP` 接入 `VyOS Route Reflector`：

- `VyOS(10.1.1.254)` 作为 `Route Reflector`
- `wk-app01`、`wk-app02`、`wk-edge01`、`wk-obs01` 作为 `iBGP client`
- 统一使用 `AS65001`
- 由 `Cilium BGP Control Plane` 向 `VyOS` 广告各 Worker 的 `PodCIDR`

## 为什么这一步重要

这一段不是为了替代集群内部转发，而是为了让网络工程师看到：

- `Cilium` 不只是 `CNI`
- `eBPF` 数据平面之外，还有可编排的 `BGP` 控制面
- `Route Reflector` 可以把 Kubernetes 节点从 `full-mesh` 中解耦出来

## 对应清单

- `manifests/40_cilium_bgp_peer_config.yaml`
- `manifests/41_cilium_bgp_advertisement_podcidr.yaml`
- `manifests/42_cilium_bgp_cluster_config_rr.yaml`

## 对应脚本

- `k8s/02-cloud-native-networking/scripts/07_configure_bgp_rr.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/07_configure_bgp_rr.sh
```

```bash
bash /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/07_configure_bgp_rr.sh
```

## 脚本做了什么

脚本会完成下面 5 个动作：

1. 登录 `VyOS`，把它配置为 `AS65001` 下的 `Route Reflector`
2. 在 `VyOS` 上创建 `peer-group CILIUM`
3. 应用 `Cilium BGP` 三份清单
4. 等待 4 台 Worker 与 `10.1.1.254` 建立 `BGP` 邻居
5. 查看 `Cilium` 和 `VyOS` 两侧状态

## VyOS 实施说明

在 `VyOS 1.4.3` 上，直接对单个 neighbor 配置 `route-reflector-client` 会触发配置脚本异常。

因此本课程采用更稳的写法：

- 先创建 `peer-group CILIUM`
- 在 `peer-group` 上配置 `route-reflector-client`
- 再把 4 个 Worker neighbor 绑定到该 `peer-group`

这样既能稳定提交，也更符合网络工程师熟悉的批量邻居建模方式。

## 你会看到什么

脚本成功时，应明确看到：

- `wk-app01`、`wk-app02`、`wk-edge01`、`wk-obs01` 全部显示 `established`
- `CiliumBGPNodeConfig` 中出现 4 个 Worker
- `VyOS show ip bgp summary` 中出现 4 个邻居
- `VyOS show ip route bgp` 中出现 `10.244.x.0/24` 这样的 Pod 路由

最后应看到：

```text
OK: VyOS RR 与 Cilium BGP Control Plane 演示完成
```

## 单项验证

### 验证 1：查看 Cilium 邻居状态

```bash
cilium bgp peers
```

预期：

- 4 台 Worker 都指向 `10.1.1.254`
- `Session State` 为 `established`

### 验证 2：查看 BGP 资源

```bash
kubectl get cbgppeer,cbgpadvert,cbgpcluster
```

```bash
kubectl get cbgpnode
```

预期：

- `vyos-rr-peer` 存在
- `worker-podcidr` 存在
- `workers-to-vyos-rr` 存在
- `cbgpnode` 中有 4 台 Worker

### 验证 3：查看 VyOS 邻居摘要

```bash
python3 - <<'PY'
import pexpect

shell_prompt = r"vyos@[^\r\n]*\$ "
child = pexpect.spawn(
    "ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vyos@10.1.1.254",
    encoding="utf-8",
    timeout=20,
)
child.expect("password:")
child.sendline("vyos")
while True:
    idx = child.expect([r"Press RETURN to continue", shell_prompt], timeout=20)
    if idx == 0:
        child.sendline("")
        continue
    break
child.sendline("set terminal length 0")
child.expect(shell_prompt, timeout=20)
child.sendline("show ip bgp summary")
while True:
    idx = child.expect([r"Press RETURN to continue", shell_prompt], timeout=20)
    if idx == 0:
        child.sendline("")
        continue
    break
print(child.before)
child.sendline("exit")
child.expect(pexpect.EOF, timeout=10)
PY
```

预期：

- 4 个邻居均为 `Established`

### 验证 4：查看 VyOS 学到的 Pod 路由

```bash
python3 - <<'PY'
import pexpect

shell_prompt = r"vyos@[^\r\n]*\$ "
child = pexpect.spawn(
    "ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vyos@10.1.1.254",
    encoding="utf-8",
    timeout=20,
)
child.expect("password:")
child.sendline("vyos")
while True:
    idx = child.expect([r"Press RETURN to continue", shell_prompt], timeout=20)
    if idx == 0:
        child.sendline("")
        continue
    break
child.sendline("set terminal length 0")
child.expect(shell_prompt, timeout=20)
child.sendline("show ip route bgp")
while True:
    idx = child.expect([r"Press RETURN to continue", shell_prompt], timeout=20)
    if idx == 0:
        child.sendline("")
        continue
    break
print(child.before)
child.sendline("exit")
child.expect(pexpect.EOF, timeout=10)
PY
```

预期：

- 出现 `10.244.0.0/24`
- 出现 `10.244.1.0/24`
- 出现 `10.244.2.0/24`
- 出现 `10.244.5.0/24`

## 本步完成标准

满足下面条件后，就可以进入第二章最终验收：

- 4 台 Worker 与 `VyOS` 邻居建立成功
- `VyOS` 成功接收 Worker 的 `PodCIDR`
- 你能够从 `Cilium` 和 `VyOS` 两侧同时观察到 BGP 状态

## 下一步

下一步进入第二章最终验收：

- `docs/09_verify.md`
