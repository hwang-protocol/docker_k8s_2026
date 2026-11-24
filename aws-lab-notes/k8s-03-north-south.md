# K8s 第 3 章：南北向入口（MetalLB + Cilium Gateway API）

- **状态：** ✅ 完成
- **日期：** 2026-11-24
- **课程原文：** [k8s/03-north-south-traffic/docs/](../k8s/03-north-south-traffic/docs/)

## 结果

7 个脚本（01–07）一次全部成功。

| 验证项 | 结果 |
|---|---|
| MetalLB 分配 VIP | `app-gateway` → `10.1.1.60`，`hubble-ui-gateway` → `10.1.1.61`（和课程一致） |
| Gateway 状态 | 两个都是 `PROGRAMMED True`，`CLASS cilium` |
| `http://app.qytk8s.com/` | `301` → `https://app.qytk8s.com:443/` |
| `https://app.qytk8s.com/` | `200`，返回 whoami 的 `Hostname`，证书用课程 CA 校验通过（`ssl_verify=0`） |
| `https://hubble.qytk8s.com/` | `200`，`<title>Hubble UI</title>` |

## 和课程原版的区别（AWS）

**问题：** MetalLB 的 L2 模式靠“谁回应 ARP，流量就发给谁”。VPC 不看实例发出的 ARP，只把流量交给**拥有这个 IP 的网卡**，所以 MetalLB 分配了 VIP 也收不到流量。

**解决：** 课程的 `L2Advertisement` 只在 `qytk8s.com/node-role: edge` 节点上宣告，也就是只有 wk-edge01。所以直接把 VIP 作为**辅助私有 IP** 挂到 wk-edge01 的网卡上：

```bash
aws ec2 assign-private-ip-addresses \
  --network-interface-id <wk-edge01 的 ENI> \
  --private-ip-addresses 10.1.1.50 10.1.1.51 10.1.1.52 10.1.1.53 \
                         10.1.1.60 10.1.1.61 10.1.1.62
```

- 课程全部 7 章固定用到的 VIP：`.50`（Argo CD）、`.60`（共用 HTTPS 网关）、`.61`（Hubble UI）、`.62`（Istio 入口）。`.51–.53` 留给自动分配。
- 操作系统里**不需要**配置这些 IP：包到达 wk-edge01 的网卡后，Cilium 的 eBPF 直接按 LoadBalancer IP 转给后端 Pod。
- 局限：只能在 wk-edge01 上，没有 MetalLB 的节点故障切换。课程本来也只有一台 edge 节点，所以不影响。真实生产里，AWS 上一般直接用 NLB（`type: LoadBalancer` 由 AWS Load Balancer Controller 创建）。

**DNS：** 课程的 win2019 DNS 里只有 api/harbor/git，应用域名都用 `curl --resolve`。我在 Route 53 里补了应用域名，方便以后浏览器访问：

| 域名 | IP |
|---|---|
| app / netdevops / longhorn / grafana / jaeger | 10.1.1.60 |
| hubble | 10.1.1.61 |
| secure-app | 10.1.1.62 |
| argocd | 10.1.1.50 |

## 学到的

- **一个 VIP 多个域名**：`.60` 这一个 IP 后面挂了 app、longhorn、grafana、jaeger、netdevops 多个网站，Gateway 按 HTTPS 的域名（SNI / Host）区分。这就是 L7 网关比“一个服务一个 IP”省地址的原因。
- **MetalLB 只负责分配 IP 和宣告，Cilium 负责转发**：两者分工明确，换成云上的 NLB 时，只需要替换前一半。

## 完整操作记录

### 0. 准备工作：找出课程用到的 VIP（本地，读课程文件）

```bash
cd /c/Users/hongz/Desktop/qyt/docker_k8s_2026/k8s

# MetalLB 只在 edge 节点上宣告
sed -n 9,20p 03-north-south-traffic/manifests/02_metallb_l2advertisement.yaml

# 7 章里所有写死的 LoadBalancer IP（排除地址池定义本身）
grep -rnE "10\.1\.1\.(5[0-9]|6[0-9]|7[0-9])" . --include=*.yaml --include=*.sh \
  | grep -v archive | grep -v "10.1.1.50-10.1.1.79"
```

```text
  nodeSelectors:
    - matchLabels:
        qytk8s.com/node-role: edge

./03-north-south-traffic/manifests/20_gateway_https_demo.yaml:11:      metallb.io/loadBalancerIPs: 10.1.1.60
./03-north-south-traffic/manifests/21_hubble_ui_gateway.yaml:11:      metallb.io/loadBalancerIPs: 10.1.1.61
./05-security-and-zero-trust/manifests/91_ingress_gateway_values.yaml:12:    metallb.io/loadBalancerIPs: 10.1.1.62
./06-gitops-and-automation/scripts/12_install_argocd_and_sync.sh:19:ARGOCD_VIP="10.1.1.50"
./07-observability-and-tracing/scripts/02_install_observability_stack.sh:32:GRAFANA_VIP="10.1.1.60"
...（共 20 多处，只用到 .50 / .60 / .61 / .62 四个）
```

### 0.1 AWS 适配：把 VIP 挂到 wk-edge01 的网卡上（本地）

```bash
export MSYS_NO_PATHCONV=1 AWS_PAGER=""
R=ap-northeast-1

ENI=$(aws ec2 describe-instances --region $R \
  --filters "Name=tag:Name,Values=k8s-course-wk-edge01" \
  --query "Reservations[0].Instances[0].NetworkInterfaces[0].NetworkInterfaceId" \
  --output text)
echo "wk-edge01 ENI: $ENI"

aws ec2 assign-private-ip-addresses --region $R \
  --network-interface-id "$ENI" \
  --private-ip-addresses 10.1.1.50 10.1.1.51 10.1.1.52 10.1.1.53 10.1.1.60 10.1.1.61 10.1.1.62

aws ec2 describe-network-interfaces --region $R --network-interface-ids "$ENI" \
  --query "NetworkInterfaces[0].PrivateIpAddresses[].PrivateIpAddress" --output text
```

```text
wk-edge01 ENI: eni-0956efaef99a14f24
10.1.1.23	10.1.1.50	10.1.1.51	10.1.1.52	10.1.1.53	10.1.1.60	10.1.1.61	10.1.1.62
```

t3.large 每块网卡最多 12 个 IP（1 个主 IP + 11 个辅助 IP），这里用了 8 个。

### 0.2 应用域名加进 Route 53（本地）

```bash
ZONE=Z09255932TYZ4TT81ZONJ
rec() {
  echo "{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"$1.qytk8s.com\",\"Type\":\"A\",\"TTL\":60,\"ResourceRecords\":[{\"Value\":\"$2\"}]}}"
}

CHANGES="$(rec app 10.1.1.60),$(rec netdevops 10.1.1.60),$(rec longhorn 10.1.1.60),\
$(rec grafana 10.1.1.60),$(rec jaeger 10.1.1.60),$(rec hubble 10.1.1.61),\
$(rec secure-app 10.1.1.62),$(rec argocd 10.1.1.50)"

aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE \
  --change-batch "{\"Changes\":[$CHANGES]}" \
  --query ChangeInfo.Status --output text
```

```text
PENDING        ← 几十秒后变成 INSYNC
```

### 第 1–7 步：依次执行课程脚本（ops）

```bash
cd /docker_k8s_2026/k8s/03-north-south-traffic/scripts
chmod +x *.sh

for s in 01_prepare_north_south_artifacts.sh \
         02_install_metallb.sh \
         03_enable_gateway_api.sh \
         04_issue_tls_certs.sh \
         05_publish_gateway_demo.sh \
         06_publish_hubble_ui.sh \
         07_trigger_north_south_traffic.sh; do
  timeout 1200 bash "$s" > "/root/ch3-$s.log" 2>&1 </dev/null
  rc=$?
  echo "$s exit=$rc"
  [ $rc -ne 0 ] && { tail -15 "/root/ch3-$s.log"; break; }
done
```

```text
01_prepare_north_south_artifacts.sh exit=0
02_install_metallb.sh exit=0
03_enable_gateway_api.sh exit=0
04_issue_tls_certs.sh exit=0
05_publish_gateway_demo.sh exit=0
06_publish_hubble_ui.sh exit=0
07_trigger_north_south_traffic.sh exit=0
```

下面是每个脚本日志里的关键内容。

**01 准备制品**

```text
MetalLB 版本：v0.15.3
Gateway API 版本：v1.4.1
[4/8] 下载并固化 MetalLB 原始清单
[5/8] 下载并固化 Gateway API 标准 CRD
[6/8] 在 harbor 节点拉取并推送镜像
源镜像：quay.io/metallb/controller:v0.15.3
目标镜像：harbor.qytk8s.com/northsouth/metallb-controller:v0.15.3
源镜像：quay.io/metallb/speaker:v0.15.3
目标镜像：harbor.qytk8s.com/northsouth/metallb-speaker:v0.15.3
源镜像：docker.io/traefik/whoami:v1.10.3
目标镜像：harbor.qytk8s.com/northsouth/whoami:v1.10.3
[7/8] 在所有 Kubernetes 节点预拉镜像
OK: 第三章北向入口制品预热完成
```

**02 安装 MetalLB**

```text
[1/6] 预创建并标记 metallb-system 命名空间
[2/6] 安装 MetalLB 原始组件
customresourcedefinition.apiextensions.k8s.io/ipaddresspools.metallb.io created
customresourcedefinition.apiextensions.k8s.io/l2advertisements.metallb.io created
...
deployment.apps/controller created
daemonset.apps/speaker created
validatingwebhookconfiguration.admissionregistration.k8s.io/metallb-webhook-configuration created
[3/6] 等待 MetalLB 控制器就绪
deployment "controller" successfully rolled out
[4/6] 应用业务 VIP 地址池
Error from server (InternalError): ... failed calling webhook "ipaddresspoolvalidationwebhook.metallb.io":
  ... dial tcp 10.109.167.192:443: connect: operation not permitted
应用业务 VIP 地址池 暂未成功（第 1/12 次），5 秒后重试        ← webhook 刚起来，脚本自带重试
ipaddresspool.metallb.io/edge-pool created
[5/6] 为 wk-edge01 打入口标签并应用 L2Advertisement
node/wk-edge01 labeled
l2advertisement.metallb.io/edge-pool-on-edge-nodes created
daemon set "speaker" successfully rolled out
[6/6] 查看 MetalLB 状态
controller-6f85dfd56b-ql2jf   1/1   Running   10.244.1.121   wk-app02
speaker-mz9dq                 1/1   Running   10.1.1.23      wk-edge01   ← speaker 只在 edge 节点（hostNetwork）
NAME                                 AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
ipaddresspool.metallb.io/edge-pool   true          true              ["10.1.1.50-10.1.1.79"]
OK: MetalLB 已安装并完成地址池配置
```

**03 为 Cilium 开启 Gateway API**

```text
[3/7] 安装 Gateway API 标准 CRD
customresourcedefinition.apiextensions.k8s.io/gatewayclasses.gateway.networking.k8s.io created
customresourcedefinition.apiextensions.k8s.io/gateways.gateway.networking.k8s.io created
customresourcedefinition.apiextensions.k8s.io/httproutes.gateway.networking.k8s.io created
...
[5/7] Helm 升级 Cilium，开启 Gateway API
Release "cilium" has been upgraded. Happy Helming!
REVISION: 2
[6/7] 重启 Cilium 组件以加载新的 gateway 配置
daemonset.apps/cilium restarted
deployment.apps/cilium-operator restarted
[7/7] 查看 Gateway API 状态
Cilium:   1 errors, 2 warnings        ← 重启过程中的瞬时状态（endpoints not ready），几秒后恢复
...
Cilium:   OK
Operator: OK
Hubble Relay: OK
NAME     CONTROLLER                     ACCEPTED   AGE
cilium   io.cilium/gateway-controller   Unknown    59s
OK: Cilium Gateway API 已启用
```

**04 签发 app.qytk8s.com 证书**

```text
[2/4] 使用 Harbor CA 签发服务端证书
Certificate request self-signature ok
subject=C = CN, ST = Beijing, L = Beijing, O = QYT, OU = K8S, CN = app.qytk8s.com
[3/4] 创建/更新 Kubernetes TLS Secret
namespace/gateway-demo created
secret/app-qytk8s-com-tls created
OK: 第三章 TLS 证书已签发
```

**05 发布 HTTPS 演示应用**

```text
[2/7] 部署 whoami 演示应用
deployment.apps/whoami created
service/whoami created
[3/7] 应用 Gateway 与 HTTPRoute
gateway.gateway.networking.k8s.io/app-gateway created
httproute.gateway.networking.k8s.io/app-http-redirect created
httproute.gateway.networking.k8s.io/app-https-backend created
[4/8] 处理 Cilium Gateway 与 MetalLB 的 EndpointSlice 兼容标签
等待 Gateway EndpointSlice 生成（第 1/30 次）…
...
等待 Gateway EndpointSlice 生成（第 20/30 次）…
endpointslice.discovery.k8s.io/cilium-gateway-app-gateway labeled
已为 EndpointSlice cilium-gateway-app-gateway 补充 kubernetes.io/service-name label
[5/8] 等待 Gateway 获取 MetalLB VIP
Gateway 地址已就绪：10.1.1.60
[6/8] 查看 Gateway 与路由状态
gateway.gateway.networking.k8s.io/app-gateway   cilium   10.1.1.60   True   62s
httproute.gateway.networking.k8s.io/app-http-redirect   ["app.qytk8s.com"]
httproute.gateway.networking.k8s.io/app-https-backend   ["app.qytk8s.com"]
NAME                         TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)
cilium-gateway-app-gateway   LoadBalancer   10.104.50.160   10.1.1.60     80:32060/TCP,443:31125/TCP
whoami                       ClusterIP      10.97.193.74    <none>        80/TCP
[7/8] 本机验证 HTTP -> HTTPS 跳转
HTTP/1.1 301 Moved Permanently
location: https://app.qytk8s.com:443/
server: envoy
[8/8] 本机验证 HTTPS 访问
Hostname: whoami-6d7f87fc75-m9jnh
IP: 10.244.1.117
RemoteAddr: 10.244.2.52:38297          ← Envoy（在 wk-edge01 上）发起的连接
Host: app.qytk8s.com
X-Envoy-Internal: true
X-Forwarded-For: 10.1.1.201            ← 真实客户端：ops
X-Forwarded-Proto: https
OK: Gateway API HTTPS 演示应用已发布
```

完整路径：ops（10.1.1.201）→ VPC 把发往 `.60` 的包交给 wk-edge01 的网卡 → Cilium eBPF 识别是 LoadBalancer IP → Cilium 内置 Envoy 终结 TLS、按 HTTPRoute 转发 → whoami Pod。

**06 发布 Hubble UI**

```text
subject=... CN = hubble.qytk8s.com
secret/hubble-qytk8s-com-tls created
gateway.gateway.networking.k8s.io/hubble-ui-gateway created
httproute.gateway.networking.k8s.io/hubble-ui-http-redirect created
httproute.gateway.networking.k8s.io/hubble-ui-https-backend created
Hubble UI Gateway 地址已就绪：10.1.1.61
[7/7] 本机验证 Hubble UI HTTPS 访问
HTTP/1.1 301 Moved Permanently
location: https://hubble.qytk8s.com:443/
HTTP/1.1 200 OK
server: envoy
content-type: text/html
OK: Hubble UI 已通过 HTTPS 发布
```

**07 触发北向流量（给 Hubble UI 看）**

```text
[1/3] 触发 HTTP -> HTTPS 重定向
HTTP/1.1 301 Moved Permanently
[2/3] 连续触发 HTTPS 业务访问
第 1/8 次访问 ... 第 8/8 次访问（每次 341 字节）
```

### 第 8 步：验收（ops，课程 08_verify.md）

```bash
CA=/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt

kubectl get svc -A --field-selector spec.type=LoadBalancer \
  -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,IP:.status.loadBalancer.ingress[0].ip

kubectl get gateway -A

# 不再需要 --resolve：Route 53 里已经有这些域名
curl -sI http://app.qytk8s.com/ | head -3

curl -s --cacert $CA https://app.qytk8s.com/ \
  -w "\nhttp=%{http_code} ssl_verify=%{ssl_verify_result}\n" \
  | grep -E "Hostname|http="

curl -s --cacert $CA https://hubble.qytk8s.com/ -w "\nhttp=%{http_code}\n" \
  | grep -oE "<title>[^<]*</title>|http=[0-9]+"
```

```text
NS             NAME                               IP
gateway-demo   cilium-gateway-app-gateway         10.1.1.60
kube-system    cilium-gateway-hubble-ui-gateway   10.1.1.61

NAMESPACE      NAME                CLASS    ADDRESS     PROGRAMMED   AGE
gateway-demo   app-gateway         cilium   10.1.1.60   True         85s
kube-system    hubble-ui-gateway   cilium   10.1.1.61   True         20s

HTTP/1.1 301 Moved Permanently
location: https://app.qytk8s.com:443/

Hostname: whoami-6d7f87fc75-m9jnh
http=200 ssl_verify=0

<title>Hubble UI</title>
http=200
```

### 补充：两处课程脚本自带的“兼容处理”

1. **MetalLB webhook 第一次调用失败**：`connect: operation not permitted`。MetalLB 的 webhook 刚启动时 Cilium 还没给它的 Service 建好转发规则，脚本自带 12 次重试，第 2 次就成功了。
2. **EndpointSlice 补标签**：Cilium 为 Gateway 自动创建的 LoadBalancer Service，它的 EndpointSlice 缺少 `kubernetes.io/service-name` 标签，MetalLB 靠这个标签判断“哪个节点上有后端”。缺标签时 MetalLB 不会宣告 VIP，课程脚本会自动补上。

## 笔记 / 疑问

（自己补充）
