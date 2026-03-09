# 第 7 步：第二章最终验收

## 本步目标

对第二章做一次只读验收，确认这条主线已经闭环：

- `Cilium` 已接管网络平面
- `Service Discovery` 正常
- `Hubble` 可观察东西向流量
- `L3/L4` 与 `L7` 策略可演示
- `VyOS RR + Cilium BGP` 已建立

本步不改配置，只做验收。

## 验收顺序

请按下面顺序检查：

1. 集群基础状态
2. `net-demo` 演示应用
3. `Hubble`
4. `CiliumNetworkPolicy`
5. `BGP`

## 验证 1：节点与系统组件

```bash
kubectl get nodes -o wide
```

```bash
kubectl get pods -n kube-system -o wide
```

```bash
cilium status --wait
```

预期：

- 所有节点均为 `Ready`
- `cilium`、`cilium-operator`、`hubble-relay`、`hubble-ui`、`coredns` 正常
- `Cilium: OK`

## 验证 2：Service Discovery 演示应用

```bash
kubectl get pods -n net-demo -o wide
```

```bash
kubectl get svc -n net-demo
```

```bash
kubectl exec -n net-demo deployment/client -- curl -sS http://whoami
```

预期：

- `client`、`other`、`whoami` 均为 `Running`
- `whoami` Service 存在
- `curl` 返回 `whoami` 输出

## 验证 3：Hubble 可观测性

```bash
kubectl -n kube-system port-forward svc/hubble-relay 4245:80
```

另开一个终端执行：

```bash
hubble status --server localhost:4245
```

```bash
hubble observe --server localhost:4245 --last 20
```

预期：

- `Healthcheck: Ok`
- 能看到最近的东西向流量

## 验证 4：L3/L4 与 L7 策略

```bash
kubectl get cnp -n net-demo
```

```bash
kubectl exec -n net-demo deployment/client -- sh -c "curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 http://whoami/"
```

```bash
kubectl exec -n net-demo deployment/client -- sh -c "curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 -X POST http://whoami/"
```

预期：

- 当前存在 `whoami-l7-allow-get`
- `GET /` 返回 `200`
- `POST /` 返回非 `200`

## 验证 5：BGP 邻居与路由

```bash
cilium bgp peers
```

预期：

- 4 台 Worker 都连接到 `10.1.1.254`
- `Session State` 为 `established`

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

- 4 个邻居为 `Established`
- `show ip route bgp` 中能看到 `10.244.x.0/24` Pod 路由

## 第二章通过标准

满足下面条件后，第二章即可视为完成：

- `Cilium` 与 `Hubble` 正常
- `Service Discovery` 正常
- `L3/L4` 与 `L7` 策略正常
- `VyOS RR + Cilium BGP` 正常

## 下一步

下一步进入第三章：南北向流量、`LoadBalancer VIP`、`Ingress` 与 `Gateway API`。
