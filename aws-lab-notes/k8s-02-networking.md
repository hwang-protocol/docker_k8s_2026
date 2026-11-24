# K8s 第 2 章：云原生网络（Cilium + Hubble）

- **状态：** ✅ 完成
- **日期：** 2026-11-24
- **课程原文：** [k8s/02-cloud-native-networking/docs/](../k8s/02-cloud-native-networking/docs/)

## 结果

| 步骤 | 结果 |
|---|---|
| 1. 准备制品 | ✅ Helm、cilium CLI、hubble CLI；镜像推到 Harbor `cilium` 项目；在 harbor 节点从源码编译了 `hubble-ui:v0.13.3-qyfix` |
| 2. 安装 Cilium 1.19.1 | ✅ 7 个节点 `NotReady → Ready`，CoreDNS `Running`；kube-proxy 已删除，`KubeProxyReplacement: True`，`Routing: Native` |
| 3. 服务发现 | ✅ client（wk-obs01）→ `whoami` / `whoami.net-demo.svc.cluster.local` → whoami（wk-app02），**跨节点** |
| 4. Hubble | ✅ `Connected Nodes: 7/7`，能看到 DNS → Service 转换 → SYN → SYN/ACK |
| 5. 策略 | ✅ L3/L4：client 200、other 000（被丢包）；L7：GET 200、POST 403 |
| Hubble UI | ✅ 端口转发后返回 `<title>Hubble UI</title>`（还没在浏览器里看） |

Cilium 自带的健康检查（`cilium-health status --probe`）：7 个节点之间主机和 Pod 的连通性全部 1/1。

## 和课程原版的区别

**AWS：** 不需要改。课程用 native routing（Pod IP 不封装、直接在节点间路由），在 AWS 上要满足两个条件，建环境时已经做好：

1. 所有节点在同一个子网（`autoDirectNodeRoutes` 要求二层相邻）。
2. K8s 节点**关闭源/目标检查**，并且安全组放行 Pod 网段 `10.244.0.0/16`。不关的话，VPC 会丢掉源或目的地址不是网卡自身 IP 的包，也就是所有 Pod 流量。

**遇到的问题：hubble-relay 一直不 Ready**

- 现象：`rollout status` 超时（`exceeded its progress deadline`），`cilium status` 显示 `Hubble Relay: 1 errors`，探针报 `NOT_SERVING`。
- 但 relay 本身其实能用：端口转发后 `hubble status` 显示 `Healthcheck: Ok`、`Connected Nodes: 7/7`。
- 原因：relay Pod 在 Cilium 还没完全就绪时就启动了，gRPC 健康状态卡在 `NOT_SERVING`，网络恢复后也不会自己更新。
- 解决：`kubectl -n kube-system delete pod -l k8s-app=hubble-relay`，重建后 12 秒就 Ready。和 AWS 无关，属于启动顺序问题。

**小提示：** 课程的 hubble CLI 是 v1.18.6，relay 是 v1.19.1，会打印版本不匹配的警告，不影响使用。

## 学到的

- **native routing 和 VXLAN 的区别在 AWS 上看得很清楚**：native 依赖底层网络“认” Pod IP，所以要关源/目标检查；VXLAN 把 Pod 包封装在节点 IP 里，底层网络完全不用配合，但每个包多 50 字节、多一次封装和解封装。
- **eBPF 替代 kube-proxy**：删掉 kube-proxy 并清理 `KUBE-*` iptables 规则以后，Service 照样能用，因为转发由 Cilium 在 eBPF 里完成（Hubble 里的 `pre-xlate-fwd` 就是 Service IP → Pod IP 的那一步转换）。
- **L7 策略返回 403、L3/L4 策略直接丢包**：L3/L4 在内核里丢包，客户端只能等到超时（000）；L7 由 Envoy 代理处理，能返回一个明确的 HTTP 403。

## 完整操作记录

以下都在 ops 上执行（`ssh k8s-ops`），输出是真实输出。

### 0. 先读 Cilium 的安装参数（课程的 values 文件）

```bash
cat /docker_k8s_2026/k8s/02-cloud-native-networking/manifests/cilium-values.yaml
```

关键几行：

```yaml
k8sServiceHost: "10.1.1.10"          # 删了 kube-proxy 以后，Cilium 自己要知道 API Server 在哪（VIP）
k8sServicePort: 6443

routingMode: "native"                # 不封装，Pod IP 直接在节点间路由
autoDirectNodeRoutes: true           # 每个节点自动加路由：10.244.X.0/24 via 对应节点 IP
ipv4NativeRoutingCIDR: "10.244.0.0/16"

kubeProxyReplacement: true           # 用 eBPF 取代 kube-proxy

ipam:
  mode: "cluster-pool"
  operator:
    clusterPoolIPv4PodCIDRList: ["10.244.0.0/16"]
    clusterPoolIPv4MaskSize: 24      # 每个节点分一个 /24

hubble:
  enabled: true
  relay: { enabled: true, image: { repository: "harbor.qytk8s.com/cilium/hubble-relay", tag: "v1.19.1" } }
  ui:    { enabled: true }

image:
  repository: "harbor.qytk8s.com/cilium/cilium"   # 所有镜像都从 Harbor 拉
  tag: "v1.19.1"
```

`autoDirectNodeRoutes` 要求所有节点在同一个二层网络里：AWS 上 12 台机器在同一个子网 `10.1.1.0/24`，满足。

### 第 1 步：准备 Cilium 制品

```bash
cd /docker_k8s_2026/k8s/02-cloud-native-networking/scripts
chmod +x *.sh
bash 01_prepare_cilium_artifacts.sh > /root/ch2-step1.log 2>&1 </dev/null
grep -E "^\[|^OK|源镜像|目标镜像|上游版本|目标标签" /root/ch2-step1.log
```

```text
Cilium 版本：1.19.1
Harbor 项目：harbor.qytk8s.com/cilium
[0/9] 集群连通性检查与恢复（快照恢复后 API 可能暂不可达）
OK: 集群可连通
[1/9] 准备本地目录
[2/9] 安装 Helm
v3.22.1+gd6c1a0e
[3/9] 创建 Harbor 项目
Harbor 项目 cilium 已就绪
[4/9] 下载 Helm chart
[5/9] 安装 cilium CLI
[6/9] 安装 hubble CLI
[7/9] 在 harbor 节点拉取并推送镜像
源镜像：quay.io/cilium/cilium:v1.19.1
目标镜像：harbor.qytk8s.com/cilium/cilium:v1.19.1
源镜像：quay.io/cilium/operator-generic:v1.19.1
目标镜像：harbor.qytk8s.com/cilium/operator-generic:v1.19.1
源镜像：quay.io/cilium/hubble-relay:v1.19.1
目标镜像：harbor.qytk8s.com/cilium/hubble-relay:v1.19.1
源镜像：quay.io/cilium/certgen:v0.3.2
目标镜像：harbor.qytk8s.com/cilium/certgen:v0.3.2
源镜像：docker.io/traefik/whoami:v1.10.3
目标镜像：harbor.qytk8s.com/cilium/whoami:v1.10.3
源镜像：docker.io/curlimages/curl:8.12.1
目标镜像：harbor.qytk8s.com/cilium/curl:8.12.1
上游版本：v0.13.3
目标标签：v0.13.3-qyfix                      ← 在 harbor 节点从源码编译课程定制的 hubble-ui
Successfully built 97c1e92c4512
[8/9] / [9/9] 各节点预拉镜像
预拉镜像：harbor.qytk8s.com/cilium/hubble-ui:v0.13.3-qyfix
预拉镜像：harbor.qytk8s.com/cilium/hubble-ui-backend:v0.13.3-qyfix
...
OK: 第二章 Cilium 制品预热完成
```

这一步比较慢（10 多分钟），主要时间花在 harbor 节点（t3.medium）上编译 hubble-ui 的 Go 后端。

### 第 2 步：安装 Cilium

```bash
bash 02_install_cilium.sh > /root/ch2-step2.log 2>&1 </dev/null
```

脚本做的事情：

```bash
# 1. 删掉 kube-proxy
kubectl -n kube-system delete ds kube-proxy --ignore-not-found
kubectl -n kube-system delete cm kube-proxy --ignore-not-found

# 2. 每个节点清理 kube-proxy 留下的 iptables 规则
iptables-save  | grep -v 'KUBE' | iptables-restore
ip6tables-save | grep -v 'KUBE' | ip6tables-restore

# 3. Helm 安装
helm upgrade --install cilium artifacts/cilium-1.19.1.tgz \
  --namespace kube-system \
  --values manifests/cilium-values.yaml

# 4. 等待
kubectl -n kube-system rollout status ds/cilium --timeout=10m
kubectl -n kube-system rollout status deploy/cilium-operator --timeout=10m
kubectl -n kube-system rollout status deploy/hubble-relay --timeout=10m
kubectl -n kube-system rollout status deploy/hubble-ui --timeout=10m
cilium status --wait
```

输出：

```text
=========================================================
开始安装 Cilium 1.19.1
模式：native routing + eBPF kube-proxy replacement
=========================================================
[1/5] 删除 kube-proxy DaemonSet 与 ConfigMap
daemonset.apps "kube-proxy" deleted
configmap "kube-proxy" deleted
[2/5] 在所有 Kubernetes 节点清理 KUBE iptables 规则
节点：cp01
[iptables 1/2] 清理 IPv4 中的 KUBE 规则
[iptables 2/2] 清理 IPv6 中的 KUBE 规则
OK
...（7 个节点）
[3/5] 通过 Helm 安装 Cilium
Release "cilium" does not exist. Installing it now.
NAME: cilium
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
You have successfully installed Cilium with Hubble Relay and Hubble UI.
[4/5] 等待 Cilium 组件就绪
Waiting for daemon set "cilium" rollout to finish: 0 of 7 updated pods are available...
...
Waiting for daemon set "cilium" rollout to finish: 6 of 7 updated pods are available...
daemon set "cilium" successfully rolled out
deployment "cilium-operator" successfully rolled out
Waiting for deployment "hubble-relay" rollout to finish: 0 of 1 updated replicas are available...
error: deployment "hubble-relay" exceeded its progress deadline        ← 卡在这里
```

**这时节点已经全部 Ready：**

```bash
kubectl get nodes --no-headers
kubectl get pods -n kube-system -o wide --no-headers | grep -v " Running "
```

```text
cp01        Ready   control-plane   33m   v1.33.9
cp02        Ready   control-plane   32m   v1.33.9
cp03        Ready   control-plane   32m   v1.33.9
wk-app01    Ready   <none>          32m   v1.33.9
wk-app02    Ready   <none>          32m   v1.33.9
wk-edge01   Ready   <none>          32m   v1.33.9
wk-obs01    Ready   <none>          32m   v1.33.9
hubble-generate-certs-1beaeb43b5-n7rn9   0/1   Completed   0     9m58s   ...   ← 一次性任务，正常
```

**排查 hubble-relay**

```bash
kubectl -n kube-system get pods -l k8s-app=hubble-relay -o wide
kubectl -n kube-system logs deploy/hubble-relay --tail=8
kubectl -n kube-system get events --field-selector involvedObject.kind=Pod \
  --sort-by=.lastTimestamp | grep -i relay | tail -5
```

```text
NAME                            READY   STATUS    RESTARTS   AGE   IP             NODE
hubble-relay-6997fff775-fhkv6   0/1     Running   0          10m   10.244.0.145   wk-app01

level=info msg=Connected subsys=hubble-relay address=10.1.1.21:4244 tls=true peer=wk-app01
level=info msg=Connected subsys=hubble-relay address=10.1.1.101:4244 tls=true peer=cp01
level=info msg=Connected subsys=hubble-relay address=10.1.1.23:4244 tls=true peer=wk-edge01
level=info msg=Connected subsys=hubble-relay address=10.1.1.22:4244 tls=true peer=wk-app02
level=info msg=Connected subsys=hubble-relay address=10.1.1.102:4244 tls=true peer=cp02

Warning   Unhealthy   pod/hubble-relay-...   Startup probe failed: service unhealthy (responded with "NOT_SERVING")
Normal    Killing     pod/hubble-relay-...   Container hubble-relay failed startup probe, will be restarted
```

先排除网络问题：用 Cilium 自带的健康探测看节点之间的连通性：

```bash
kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
  cilium-health status --probe \
  | grep -E "^  [a-z0-9-]+"
```

```text
                          节点 IP         主机连通   Pod(endpoint)连通
  wk-edge01 (localhost)   10.1.1.23       1/1        1/1
  cp01                    10.1.1.101      1/1        1/1
  cp02                    10.1.1.102      1/1        1/1
  cp03                    10.1.1.103      1/1        1/1
  wk-app01                10.1.1.21       1/1        1/1
  wk-app02                10.1.1.22       1/1        1/1
  wk-obs01                10.1.1.24       1/1        1/1
```

全部连通：**native routing 在 AWS 上工作正常**（前提是关了源/目标检查）。再直接问 relay 本身：

```bash
cilium status | sed -n 1,12p

kubectl -n kube-system port-forward svc/hubble-relay 4245:80 >/tmp/pf.log 2>&1 &
PF=$!
sleep 4
hubble status --server localhost:4245
kill $PF

# 探针检查的是什么
kubectl -n kube-system get deploy hubble-relay \
  -o jsonpath='{.spec.template.spec.containers[0].startupProbe}'
```

```text
    /¯¯\__/¯¯\    Cilium:             OK
    \__/¯¯\__/    Operator:           OK
    /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
    \__/¯¯\__/    Hubble Relay:       1 errors
Deployment             hubble-relay             Desired: 1, Unavailable: 1/1

Healthcheck (via localhost:4245): Ok
Current/Max Flows: 18,726/28,665 (65.33%)
Flows/s: 32.08
Connected Nodes: 7/7                         ← relay 其实是好的

{"failureThreshold":20,"grpc":{"port":4222,"service":""},"initialDelaySeconds":10,"periodSeconds":3,...}
```

relay 的功能正常，只是 4222 端口的 gRPC 健康状态一直是 `NOT_SERVING`：它启动时 Cilium 还没就绪，健康状态卡住了。删 Pod 重建：

```bash
kubectl -n kube-system delete pod -l k8s-app=hubble-relay --wait=false
kubectl -n kube-system rollout status deploy/hubble-relay --timeout=3m
kubectl -n kube-system get pods -l k8s-app=hubble-relay
```

```text
pod "hubble-relay-6997fff775-fhkv6" deleted
deployment "hubble-relay" successfully rolled out
NAME                            READY   STATUS        RESTARTS   AGE
hubble-relay-6997fff775-bncsp   1/1     Running       0          12s
hubble-relay-6997fff775-fhkv6   0/1     Terminating   0          11m
```

**补完第 2 步的验证**

```bash
cilium status --wait | sed 's/\x1b\[[0-9;]*m//g' \
  | grep -E "Cilium:|Operator:|Hubble Relay:|DaemonSet|Deployment"

kubectl -n kube-system get ds kube-proxy

kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \
  | grep -E "KubeProxyReplacement|Routing|Masquerading"
```

```text
Cilium:             OK
Operator:           OK
Hubble Relay:       OK
DaemonSet    cilium            Desired: 7, Ready: 7/7, Available: 7/7
Deployment   cilium-operator   Desired: 2, Ready: 2/2, Available: 2/2
Deployment   hubble-relay      Desired: 1, Ready: 1/1, Available: 1/1
Deployment   hubble-ui         Desired: 1, Ready: 1/1, Available: 1/1

Error from server (NotFound): daemonsets.apps "kube-proxy" not found

KubeProxyReplacement:    True   [ens5   10.1.1.23 fe80::8ff:f9ff:fe7e:d809 (Direct Routing)]
Routing:                 Network: Native   Host: Legacy
Masquerading:            IPTables [IPv4: Enabled, IPv6: Disabled]
```

### 第 3 步：服务发现演示

```bash
bash 03_apply_service_discovery_demo.sh
```

脚本内容：

```bash
BASE_URL="http://ops:9000/02-cloud-native-networking/manifests"
kubectl apply -f ${BASE_URL}/00_net-demo_namespace.yaml
kubectl apply -f ${BASE_URL}/10_whoami.yaml
kubectl apply -f ${BASE_URL}/20_client.yaml
kubectl rollout status deployment/whoami -n net-demo --timeout=5m
kubectl rollout status deployment/client -n net-demo --timeout=5m
kubectl get pods -n net-demo -o wide
kubectl get svc -n net-demo

kubectl exec -n net-demo deployment/client -- curl -sS http://whoami                               # 短名
kubectl exec -n net-demo deployment/client -- curl -sS http://whoami.net-demo.svc.cluster.local    # 全名
kubectl exec -n net-demo deployment/client -- sh -c 'getent hosts whoami | head -n 1'
```

输出：

```text
namespace/net-demo created
deployment.apps/whoami created
service/whoami created
deployment.apps/client created
deployment "whoami" successfully rolled out
deployment "client" successfully rolled out

NAME                      READY   STATUS    IP             NODE
client-5d75665b4d-45qjf   1/1     Running   10.244.3.78    wk-obs01      ← client 在 wk-obs01
whoami-578dd87854-tsz5x   1/1     Running   10.244.1.142   wk-app02      ← whoami 在 wk-app02（跨节点）

NAME     TYPE        CLUSTER-IP       PORT(S)
whoami   ClusterIP   10.108.247.140   80/TCP

Hostname: whoami-578dd87854-tsz5x
IP: 10.244.1.142
RemoteAddr: 10.244.3.78:37254          ← 源地址就是 client 的 Pod IP：跨节点没有做 NAT
GET / HTTP/1.1
Host: whoami

Hostname: whoami-578dd87854-tsz5x
RemoteAddr: 10.244.3.78:37268
Host: whoami.net-demo.svc.cluster.local

Service IP:
10.108.247.140    whoami.net-demo.svc.cluster.local  whoami.net-demo.svc.cluster.local whoami
OK: Service Discovery 演示完成
```

### 第 4 步：Hubble 观测

```bash
bash 04_enable_hubble.sh
```

脚本内容：端口转发 relay → 用 client 访问 3 次 whoami → `hubble observe` 抓出关键流量：

```bash
kubectl -n kube-system port-forward svc/hubble-relay 4245:80 &
hubble status --server localhost:4245
kubectl exec -n net-demo deployment/client -- sh -c 'for i in 1 2 3; do curl -sS http://whoami >/dev/null; sleep 1; done'
hubble observe --server localhost:4245 --since 20s --last 100
```

输出：

```text
[1/4] 检查 Hubble Relay
hubble-relay-6997fff775-bncsp   1/1     Running   0   34s   10.244.3.113   wk-obs01
[2/4] 建立本地端口转发
WARN msg="Hubble CLI version is lower than Hubble Relay ..." hubble-cli-version=1.18.6 hubble-relay-version=1.19.1
Healthcheck (via localhost:4245): Ok
Current/Max Flows: 20,294/28,665 (70.80%)
Flows/s: 38.00
Connected Nodes: 7/7
[3/4] 生成演示流量
[4/4] 输出关键 Hubble 观测记录
net-demo/client-...:47594 -> kube-system/coredns-...:53 to-stack FORWARDED (UDP)                     ← ① DNS 查询 whoami
net-demo/client-... <> net-demo/whoami:80 (world) pre-xlate-fwd TRACED (TCP)                          ← ② Service IP → Pod IP 转换（eBPF）
net-demo/client-...:37254 -> net-demo/whoami-...:80 to-stack FORWARDED (TCP Flags: SYN)               ← ③ 发 SYN
net-demo/client-...:37254 <- net-demo/whoami-...:80 to-stack FORWARDED (TCP Flags: SYN, ACK)          ← ④ 回 SYN/ACK
OK: Hubble 观测演示完成
```

### 第 5 步：L3/L4 和 L7 策略

两条策略的区别只在 `rules.http` 这一段：

```yaml
# 30_cnp_l3l4_allow_client.yaml：只允许 app=client 访问 whoami 的 TCP 80
spec:
  endpointSelector:
    matchLabels: { app: whoami }
  ingress:
    - fromEndpoints:
        - matchLabels: { app: client }
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP

# 31_cnp_l7_allow_get.yaml：在上面基础上，再限制只能 GET /
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/"
```

```bash
bash 05_apply_l7_policy_demo.sh
```

```text
[1/6] 准备 other Pod 与清理旧策略
deployment.apps/other created
[2/6] 基线验证：client 与 other 都可访问 whoami
client -> whoami HTTP 200 (baseline)
HTTP Code: 200
other -> whoami HTTP 200 (baseline)
HTTP Code: 200
[3/6] 应用 L3/L4 策略
ciliumnetworkpolicy.cilium.io/whoami-l3l4-allow-client created
client -> whoami (L3/L4 allow)
HTTP Code: 200
other -> whoami (L3/L4 deny)
HTTP Code: 000                          ← 包被直接丢掉，curl 超时，没有任何 HTTP 响应
[4/6] 切换到 L7 GET-only 策略
ciliumnetworkpolicy.cilium.io "whoami-l3l4-allow-client" deleted
ciliumnetworkpolicy.cilium.io/whoami-l7-allow-get created
client GET / -> whoami (L7 allow)
HTTP Code: 200
client POST / -> whoami (L7 deny)
HTTP Code: 403                          ← Envoy 代理返回明确的 403
[5/6] 查看当前策略对象
NAME                  AGE   VALID
whoami-l7-allow-get   6s    True
[6/6] 查看 whoami 端点身份
NAME                      SECURITY IDENTITY   ENDPOINT STATE   IPV4
client-5d75665b4d-45qjf   3642                ready            10.244.3.78
other-56dbc7b4cb-8mxfs    47028               ready            10.244.2.112
whoami-578dd87854-tsz5x   14059               ready            10.244.1.142
OK: L3/L4 与 L7 策略演示完成
```

`SECURITY IDENTITY` 是 Cilium 按 Pod 标签算出来的身份号。策略匹配的是这个身份，不是 IP，所以 Pod 重建换了 IP，策略照样生效。

### 额外：确认 Hubble UI 能打开

```bash
kubectl -n kube-system port-forward svc/hubble-ui 12000:80 >/tmp/pf-ui.log 2>&1 &
PF=$!
sleep 4
curl -s http://localhost:12000/ | grep -o "<title>[^<]*</title>"
kill $PF
```

```text
<title>Hubble UI</title>
```

## 笔记 / 疑问

（自己补充）
