# 第 5 步：演示 L3/L4 与 L7 策略

## 本步目标

利用 `CiliumNetworkPolicy` 演示第二章最关键的东西向安全能力：

- `L3/L4` 级别的访问控制
- `L7` 级别的 HTTP 感知控制

本步使用 `whoami`、`client`、`other` 三个工作负载，依次验证下面 4 个状态：

1. 基线状态下，`client` 与 `other` 都可以访问 `whoami`
2. 应用 `L3/L4` 策略后，只允许 `client`
3. 切换为 `L7` 策略后，只允许 `client` 发起 `GET /`
4. 可以从 `CiliumNetworkPolicy` 与 `CiliumEndpoint` 侧看到策略对象已经生效

---

## 执行标记

- **执行标记：必须执行**
- 第二章从“网络已通”进入“网络可控”的关键验证

---

## 理论说明

### 策略收紧路径

```mermaid
flowchart LR
  baseline[基线状态<br/>client 与 other 都可访问]
  l34[L3/L4 策略<br/>只允许 client -> whoami:80]
  l7[L7 HTTP 策略<br/>只允许 client 发起 GET /]
  identity[CiliumEndpoint 身份与标签]

  baseline --> l34
  l34 --> l7
  l34 --> identity
  l7 --> identity
```

本步按 3 层关系递进：默认全通，先按工作负载身份控制，再按 HTTP 行为控制。

### `L3/L4` 与 `L7` 的区别

这里先看两层控制：

- 来源是谁
- 目标是谁
- 访问哪个端口

这就是这里的 `L3/L4` 控制。`L7` 则在此基础上继续限制 HTTP 方法和路径。

本步可直接记成：

- `L3/L4` 解决“谁可以连过来”
- `L7` 解决“连过来以后允许做什么”

### 为什么这一页要引入 `other`

`other` 作为对照组，用来说明“基线可访问，策略收紧后不再允许”。

### 本步策略清单与关键字段

本步使用下面 3 份清单：

- `manifests/21_other.yaml`
- `manifests/30_cnp_l3l4_allow_client.yaml`
- `manifests/31_cnp_l7_allow_get.yaml`

#### `L3/L4` 策略关键字段

下面这段内容来自：

- `manifests/30_cnp_l3l4_allow_client.yaml`

```yaml
spec:
  endpointSelector:
    matchLabels:
      app: whoami
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: client
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
```

关键字段说明：

- `endpointSelector`
  - 策略作用对象是 `whoami`
- `fromEndpoints`
  - 只允许带有 `app=client` 标签的源端点
- `toPorts`
  - 只允许访问 TCP `80`

#### `L7 HTTP` 策略关键字段

下面这段内容来自：

- `manifests/31_cnp_l7_allow_get.yaml`

```yaml
spec:
  endpointSelector:
    matchLabels:
      app: whoami
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: client
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/"
```

关键字段说明：

- `rules.http`
  - 进一步把允许行为收紧到 HTTP 请求层
- `method: "GET"`
  - 只允许 `GET`
- `path: "/"`
  - 只允许访问根路径

---

## 对应脚本

本步对应脚本：

- `k8s/02-cloud-native-networking/scripts/05_apply_l7_policy_demo.sh`

原始清单独立保存在项目目录中：

- `manifests/21_other.yaml`
- `manifests/30_cnp_l3l4_allow_client.yaml`
- `manifests/31_cnp_l7_allow_get.yaml`

文档按手动测试展开；脚本只是把这些动作串联起来。

---

## 执行过程与关键看点

### 步骤 1：创建 `other` 并清理旧策略

执行命令：

```bash
kubectl apply -f http://ops:9000/02-cloud-native-networking/manifests/21_other.yaml
kubectl delete cnp -n net-demo whoami-l3l4-allow-client --ignore-not-found
kubectl delete cnp -n net-demo whoami-l7-allow-get --ignore-not-found
kubectl rollout status deployment/other -n net-demo --timeout=5m
```

然后立刻查看当前 Pod 状态：

```bash
kubectl get pod -n net-demo
```

示例输出：

```text
NAME                      READY   STATUS    RESTARTS   AGE
client-5d75665b4d-c8th2   1/1     Running   0          57m
other-56dbc7b4cb-wcrj2    1/1     Running   0          41s
whoami-578dd87854-j4hpd   1/1     Running   0          57m
```

结果看点：

- `other` 应成功进入 `Running`
- 删除旧策略时显示 `deleted` 或 `not found` 都是正常现象
- 此时 `net-demo` 中应能同时看到：
  - `client`
  - `other`
  - `whoami`

### 步骤 2：验证基线状态

基线访问关系图：

```mermaid
flowchart LR
  client["1. client Pod<br/>curl http://whoami/"]
  other["2. other Pod<br/>curl http://whoami/"]
  svc["3. whoami Service<br/>稳定入口"]
  pod["4. whoami Pod<br/>后端服务"]

  client -->|允许访问| svc
  other -->|允许访问| svc
  svc -->|转发到后端| pod
```

执行命令：

```bash
kubectl exec -n net-demo deployment/client -- \
  sh -c "curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 http://whoami/"
kubectl exec -n net-demo deployment/other -- \
  sh -c "curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 http://whoami/"
```

结果看点：

- `client` 与 `other` 都应能访问 `whoami`
- 两个 HTTP 返回码都应为 `200`

### 步骤 3：应用 `L3/L4` 策略并观察结果

`L3/L4` 策略后关系图：

```mermaid
flowchart LR
  client["1. client Pod"]
  other["2. other Pod"]
  svc["3. whoami Service"]
  pod["4. whoami Pod"]

  client -->|允许访问| svc
  svc -->|转发到后端| pod
  other -.拒绝访问.-> svc
```

执行命令：

```bash
kubectl apply -f http://ops:9000/02-cloud-native-networking/manifests/30_cnp_l3l4_allow_client.yaml
sleep 5
kubectl exec -n net-demo deployment/client -- \
  sh -c "curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 http://whoami/"
kubectl exec -n net-demo deployment/other -- \
  sh -c "curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 http://whoami/"
```

结果看点：

- `client` 应继续返回 `200`
- `other` 应不再返回 `200`

### 步骤 4：切换为 `L7 GET-only` 策略并观察结果

`L7 GET-only` 策略后关系图：

```mermaid
flowchart LR
  client_get["1. client Pod<br/>GET /"]
  client_post["2. client Pod<br/>POST /"]
  svc["3. whoami Service"]
  pod["4. whoami Pod"]

  client_get -->|允许访问| svc
  svc -->|转发到后端| pod
  client_post -.拒绝访问.-> svc
```

执行命令：

```bash
kubectl delete -f http://ops:9000/02-cloud-native-networking/manifests/30_cnp_l3l4_allow_client.yaml
kubectl apply -f http://ops:9000/02-cloud-native-networking/manifests/31_cnp_l7_allow_get.yaml
sleep 5
kubectl exec -n net-demo deployment/client -- \
  sh -c "curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 http://whoami/"
kubectl exec -n net-demo deployment/client -- \
  sh -c "curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 -X POST http://whoami/"
```

结果看点：

- `GET /` 应返回 `200`
- `POST /` 应返回非 `200`
- 常见拒绝结果为 `403`

### 步骤 5：查看当前策略对象与端点对象

策略对象与端点对象关系图：

```mermaid
flowchart LR
  cnp["1. CiliumNetworkPolicy<br/>whoami-l7-allow-get"]
  whoami["2. CiliumEndpoint<br/>whoami"]
  client["3. CiliumEndpoint<br/>client"]
  other["4. CiliumEndpoint<br/>other"]

  cnp -->|endpointSelector: app=whoami| whoami
  client -.fromEndpoints 匹配.-> cnp
  other -.来源标签不匹配.-> cnp
```

执行命令：

```bash
kubectl get cnp -n net-demo
kubectl get cep -n net-demo
```

这里的两个缩写分别表示：

- `cnp`
  - `CiliumNetworkPolicy`
  - 用来查看当前命名空间中的 Cilium 策略对象
- `cep`
  - `CiliumEndpoint`
  - 用来查看 Cilium 为每个 Pod 自动生成并维护的端点对象

说明：

- `cnp` 通常来自手工应用的策略 YAML
- `cep` 不是手工创建的业务清单，而是 Pod 被 Cilium 接管后自动生成的运行时对象

结果看点：

- 当前通常会看到 `whoami-l7-allow-get`
- 能看到 `whoami`、`client`、`other` 对应的 `CiliumEndpoint`

---

## 关键看点

本步优先观察下面 3 件事：

- 基线阶段，`client` 与 `other` 都应返回 `200`
- `L3/L4` 阶段，`client` 继续 `200`，`other` 不再 `200`
- `L7` 阶段，同一个 `client` 对 `GET /` 与 `POST /` 会得到不同结果

---

## 通过标准

满足下面条件后，就可以进入下一步：

- `other` 工作负载已创建成功
- `L3/L4` 策略演示成功
- `L7 GET-only` 策略演示成功
- `CiliumNetworkPolicy` 与 `CiliumEndpoint` 可以被正确观察

---

## 下一步

下一步进入第二章最终验收：

- `docs/07_verify.md`
