# 第 6 步：演示 L3/L4 与 L7 策略

## 本步目标

利用 `CiliumNetworkPolicy` 演示第二章最关键的安全能力：

1. `L3/L4` 级别的访问控制
2. `L7` 级别的 HTTP 感知控制

本步会通过 `whoami`、`client`、`other` 三个工作负载，逐步演示：

- 基线状态：都能访问
- `L3/L4`：只允许 `client`
- `L7`：只允许 `client` 发起 `GET /`

## 对应清单

- `manifests/21_other.yaml`
- `manifests/30_cnp_l3l4_allow_client.yaml`
- `manifests/31_cnp_l7_allow_get.yaml`

## 对应脚本

- `k8s/02-cloud-native-networking/scripts/06_apply_l7_policy_demo.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/06_apply_l7_policy_demo.sh
```

```bash
bash /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/06_apply_l7_policy_demo.sh
```

## 脚本做了什么

脚本会完成下面 6 个动作：

1. 创建 `other` Pod，并清理旧策略
2. 验证基线状态下 `client` 与 `other` 都能访问 `whoami`
3. 应用 `L3/L4` 策略，只允许 `client`
4. 切换为 `L7 GET-only` 策略
5. 查看当前 `CiliumNetworkPolicy`
6. 查看当前 `CiliumEndpoint`

## 你会看到什么

在脚本输出中，应能明确看到：

- 基线阶段：`client` 与 `other` 都返回 `whoami` 输出
- 基线阶段：`client` 与 `other` 的 `HTTP Code` 都是 `200`
- `L3/L4` 阶段：`client` 为 `200`，`other` 为非 `200`（常见为 `000`）
- `L7` 阶段：`client GET` 为 `200`，`client POST` 为非 `200`（常见为 `403`）

最后应看到：

```text
OK: L3/L4 与 L7 策略演示完成
```

## 单项验证

### 验证 1：查看策略对象

```bash
kubectl get cnp -n net-demo
```

预期：

- 能看到当前生效的 `CiliumNetworkPolicy`

### 验证 2：查看端点对象

```bash
kubectl get cep -n net-demo
```

预期：

- 能看到 `whoami`
- 能看到 `client`
- 能看到 `other`

### 验证 3：手动测试 GET

```bash
kubectl exec -n net-demo deployment/client -- sh -c "curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 http://whoami/"
```

预期：

- 返回 `200`

### 验证 4：手动测试 POST

```bash
kubectl exec -n net-demo deployment/client -- sh -c "curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 -X POST http://whoami/"
```

预期：

- 返回非 `200`
- 常见返回为 `403`

## 本步完成标准

满足下面条件后，就可以进入下一步：

- `L3/L4` 策略演示成功
- `L7` GET-only 策略演示成功
- `CiliumNetworkPolicy` 与 `CiliumEndpoint` 可被正确观察

## 下一步

下一步进入 `VyOS Route Reflector + Cilium BGP Control Plane`：

- `docs/08_bgp_rr.md`
