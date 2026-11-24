# K8s 第 7 章：可观测性与链路追踪（Prometheus + Grafana + Jaeger + OTel）

- **状态：** ✅ 完成（课程验收脚本因 Jaeger 新版 API 变化报错，改用 v3 API 手工验收通过）
- **日期：** 2026-11-24
- **课程原文：** [k8s/07-observability-and-tracing/docs/](../k8s/07-observability-and-tracing/docs/)

## 结果

| 组件 | 版本（安装当天的最新版，课程没有固定） |
|---|---|
| kube-prometheus-stack | Chart 93.9.0 / Operator v0.95.2 |
| Jaeger | Chart 4.20.0 / **Jaeger 2.23.0** |
| OpenTelemetry Collector | Chart 0.183.1 / 0.165.0 |

| 验证项 | 结果 |
|---|---|
| 业务指标 | 4 个服务 + frontend 的抓取目标都是 `up=1` |
| 全部抓取目标 | 52 个里 43 个正常，9 个异常（原因见下，属于 kubeadm 默认配置） |
| Grafana 大盘 | `QYT NetDevOps 总览大盘`、`Trace 线索与 Jaeger 跳转` 已加载 |
| `https://grafana.qytk8s.com`、`https://jaeger.qytk8s.com` | 都是 HTTP 200（共用 VIP `.60`） |
| Jaeger 服务列表 | `frontend, device-service, resource-service, audit-service, jaeger` |
| **跨服务链路** | 15 分钟内 10 条 trace，其中 **5 条同时经过 4 个服务**；示例 trace 有 18 个 span |

## 遇到的问题

**1. `01_prepare` 检查不存在的目录（课程问题）**

脚本 `ls` 检查 `artifacts/grafana/provisioning/{datasources,dashboards}`，但这几个目录不在课程仓库里。估计是空目录，git 不跟踪空目录，所以提交时丢了。安装脚本也没用到它们。解决：手工 `mkdir -p` 创建。

**2. Prometheus 卷建不出来：`insufficient storage`（数据盘太小）**

- Prometheus 要 20 Gi、Grafana 要 10 Gi，Longhorn 每个卷存 3 份副本。
- Longhorn 默认每块盘预留 30%，超额分配比例 100%，所以 29 GB 的盘每个节点只能分配约 20 GB，而前几章已经用掉 11 GB。
- 课程是 100 GB 数据盘，不会遇到这个问题。
- 解决：把超额分配比例调到 200%（Longhorn 是精简分配，实际占用很小，短期实验不会写满）：

```bash
kubectl -n longhorn-system patch settings.longhorn.io \
  storage-over-provisioning-percentage \
  --type merge -p '{"value":"200"}'
```

- 另一种做法：把 4 块 EBS 数据盘扩到 100 GB（`aws ec2 modify-volume` + `growpart` + `resize2fs`），和课程一致，每月多约 27 美元。

**3. 验收脚本 Jaeger 报 `JSONDecodeError`（版本问题）**

- 课程的 Helm 安装**没有写 `--version`**，装的是当天最新的 Jaeger 2.23.0。
- 新版 Jaeger **去掉了旧的 `/api/services` 和 `/api/traces`**（返回 `404 page not found`），只保留 `/api/v3/...`，返回格式也换成了 OpenTelemetry 标准格式（`resourceSpans`）。
- 数据本身没问题，用 v3 API 手工完成了同样的验收：

```bash
# 服务列表
curl https://jaeger.qytk8s.com/api/v3/services

# 查询 frontend 最近 15 分钟的 trace
curl -G https://jaeger.qytk8s.com/api/v3/traces \
  --data-urlencode "query.service_name=frontend" \
  --data-urlencode "query.start_time_min=<15 分钟前，RFC3339>" \
  --data-urlencode "query.start_time_max=<现在>"
```

- 建议课程在 `helm upgrade --install` 时都加上 `--version`，否则过几个月重做就可能对不上。

**4. 9 个控制面抓取目标异常（kubeadm 默认配置）**

controller-manager（10257）、scheduler（10259）、etcd（2381）在 3 台控制平面上都连不上：kubeadm 默认让它们只监听 `127.0.0.1`。要监控它们，需要在 kubeadm 配置里把 `bind-address` / `listen-metrics-urls` 改成 `0.0.0.0` 或节点 IP。这和 AWS 无关，课程环境也会是这样。

## 学到的

- **指标 → 链路 → 定位**：Grafana 大盘发现“哪个服务慢”，跳到 Jaeger 看那一次请求的瀑布图，就能找到“慢在哪个 span”。一次请求 18 个 span，跨 4 个服务，靠日志很难拼起来。
- **OpenTelemetry 是“中间层”**：应用只管按 OTel 格式往 Collector 发数据，后端换成 Jaeger、Tempo 还是商业产品，应用都不用改。
- **不固定版本 = 埋雷**：这一章的两个问题（Jaeger API 变化、Chart 默认值变化）都是因为没有固定 Chart 版本。生产环境的 Helm 安装一定要写 `--version`。

## 完整操作记录

以下都在 ops 上执行。

### 第一轮执行：01 就失败

```bash
cd /docker_k8s_2026/k8s/07-observability-and-tracing/scripts
chmod +x *.sh

for s in 01_prepare_observability_assets.sh \
         02_install_observability_stack.sh \
         03_verify_observability.sh; do
  timeout 2400 bash "$s" > "/root/ch7-$s.log" 2>&1 </dev/null
  rc=$?
  echo "$s exit=$rc"
  [ $rc -ne 0 ] && { tail -25 "/root/ch7-$s.log"; break; }
done
```

```text
01_prepare_observability_assets.sh exit=2
[1/4] 检查 Grafana provisioning 目录
ls: cannot access '/docker_k8s_2026/k8s/07-observability-and-tracing/artifacts/grafana/provisioning': No such file or directory
ls: cannot access '.../artifacts/grafana/provisioning/datasources': No such file or directory
ls: cannot access '.../artifacts/grafana/provisioning/dashboards': No such file or directory
drwxrwxr-x 3 root root 4096 Nov 24 07:52 .../artifacts/grafana
drwxrwxr-x 2 root root 4096 Nov 24 07:52 .../artifacts/grafana/dashboards
```

在本地仓库确认这几个目录本来就不存在，而且安装脚本用不到：

```bash
cd /c/Users/hongz/Desktop/qyt/docker_k8s_2026/k8s/07-observability-and-tracing
find artifacts -maxdepth 4
git ls-files artifacts
grep -n "provisioning" scripts/02_install_observability_stack.sh
```

```text
artifacts
artifacts/grafana
artifacts/grafana/dashboards
artifacts/grafana/dashboards/k8s-platform-overview.json
artifacts/grafana/dashboards/qytang-netdevops-overview.json
artifacts/grafana/dashboards/qytang-trace-overview.json
（git 只跟踪了 3 个 json；02 号脚本里没有 provisioning）
```

### 第二轮：补目录后重跑

```bash
G=/docker_k8s_2026/k8s/07-observability-and-tracing/artifacts/grafana
mkdir -p $G/provisioning/datasources $G/provisioning/dashboards

cd /docker_k8s_2026/k8s/07-observability-and-tracing/scripts
for s in 01_prepare_observability_assets.sh 02_install_observability_stack.sh 03_verify_observability.sh; do
  timeout 2400 bash "$s" > "/root/ch7-$s.log" 2>&1 </dev/null
  rc=$?
  echo "$s exit=$rc  | $(tail -1 /root/ch7-$s.log | cut -c1-120)"
  [ $rc -ne 0 ] && break
done
```

```text
01_prepare_observability_assets.sh exit=0  | OK: 第七章资产目录已就绪
02_install_observability_stack.sh exit=0  | OK: 第七章可观测性栈安装完成
03_verify_observability.sh exit=1  | json.decoder.JSONDecodeError: Extra data: line 1 column 5 (char 4)
```

**02 安装过程**

```text
Grafana 域名：grafana.qytk8s.com
Jaeger 域名：jaeger.qytk8s.com
[2/11] 准备 Helm 仓库                        ← helm repo add prometheus-community / grafana / jaegertracing / open-telemetry
[3/11] 发布启用可观测能力的新应用版本      ← 调用第 6 章 11 号脚本，IMAGE_TAG=v0.2.3
Successfully tagged harbor.qytk8s.com/qytang-netdevops/frontend:v0.2.3
Successfully tagged harbor.qytk8s.com/qytang-netdevops/device-service:v0.2.3
Successfully tagged harbor.qytk8s.com/qytang-netdevops/resource-service:v0.2.3
Successfully tagged harbor.qytk8s.com/qytang-netdevops/audit-service:v0.2.3
OK: 四个镜像已推送到 Harbor，标签为 v0.2.3
[5/11] 生成 Grafana 与 Jaeger 正式域名证书
subject=... CN = grafana.qytk8s.com
subject=... CN = jaeger.qytk8s.com
[6/11] 安装 kube-prometheus-stack
Release "kps" does not exist. Installing it now.
STATUS: deployed
[7/11] 安装 Jaeger
Release "jaeger" does not exist. Installing it now.
STATUS: deployed
[8/11] 安装 OpenTelemetry Collector
Release "otel" does not exist. Installing it now.
STATUS: deployed
[9/11] 应用 ServiceMonitor 与 Grafana Gateway
servicemonitor.monitoring.coreos.com/qytang-netdevops-services created      ← 告诉 Prometheus 去抓业务服务的 /metrics
gateway.gateway.networking.k8s.io/app-gateway replaced
已将 Observability listeners 增量注入 app-gateway，现有其他 listeners 保持不变
httproute.gateway.networking.k8s.io/grafana-http-redirect created
httproute.gateway.networking.k8s.io/grafana-https-backend created
referencegrant.gateway.networking.k8s.io/allow-gateway-demo-to-kps-grafana created
httproute.gateway.networking.k8s.io/jaeger-http-redirect created
...
OK: 第七章可观测性栈安装完成
```

（第 6 章遇到的 `v0.1.0 / v0.2.3` 标签问题，第 7 章的脚本自己就是用 `IMAGE_TAG=v0.2.3` 调用构建的，说明课程后期默认的就是 `v0.2.3`。）

安装的版本（Chart 没有固定版本）：

```bash
helm list -A -o json \
  | jq -r '.[] | select(.namespace=="observability" or .namespace=="monitoring") | "\(.name)  \(.chart)  app=\(.app_version)"'
```

```text
jaeger  jaeger-4.20.0  app=2.23.0
kps  kube-prometheus-stack-93.9.0  app=v0.95.2
otel  opentelemetry-collector-0.183.1  app=0.165.0
```

### 问题 1：Prometheus 一直 `Init`

```bash
kubectl get pods -n monitoring --no-headers | grep -v "Running\|Completed"

P=prometheus-kps-kube-prometheus-stack-prometheus-0
kubectl -n monitoring get events --field-selector involvedObject.name=$P --sort-by=.lastTimestamp | tail -6
kubectl -n monitoring get pvc
```

```text
prometheus-kps-kube-prometheus-stack-prometheus-0     0/2   Init:0/1   0     113s

Warning   FailedScheduling     pod/prometheus-...-0   0/7 nodes are available: pod has unbound immediate PersistentVolumeClaims.
Normal    Scheduled            pod/prometheus-...-0   Successfully assigned monitoring/prometheus-...-0 to wk-obs01
Warning   FailedAttachVolume   pod/prometheus-...-0   AttachVolume.Attach failed for volume "pvc-f3f990b0-...": rpc error: code = Aborted

NAME                                  STATUS   VOLUME             CAPACITY   STORAGECLASS
kps-grafana                           Bound    pvc-bf5eddf6-...   10Gi       longhorn
prometheus-...-prometheus-0           Bound    pvc-f3f990b0-...   20Gi       longhorn
```

看 Longhorn 一侧：

```bash
kubectl -n longhorn-system get volumes.longhorn.io \
  -o custom-columns=NAME:.metadata.name,SIZE:.spec.size,REPLICAS:.spec.numberOfReplicas,STATE:.status.state,ROBUST:.status.robustness

kubectl -n longhorn-system get nodes.longhorn.io \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .status.diskStatus.*}{.storageScheduled}{" "}{.storageMaximum}{end}{"\n"}{end}' \
  | awk '{printf "%-10s scheduled=%.0fG max=%.0fG\n", $1, $2/1073741824, $3/1073741824}'

kubectl -n longhorn-system get volumes.longhorn.io pvc-f3f990b0-b772-4eb0-8229-2b66fe11abd4 \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason} {.message}{"\n"}{end}'

kubectl -n longhorn-system get settings.longhorn.io \
  storage-over-provisioning-percentage storage-reserved-percentage-for-default-disk storage-minimal-available-percentage \
  -o custom-columns=NAME:.metadata.name,VALUE:.value
```

```text
NAME                                      SIZE  REPLICAS  STATE     ROBUST
pvc-11066f5c-...                          2Gi   3         attached  healthy     ← MongoDB
pvc-2c31d759-...                          2Gi   3         attached  healthy     ← MongoDB
pvc-56200700-...                          5Gi   3         attached  healthy     ← 第 6 章 postgres
pvc-93969310-...                          2Gi   3         attached  healthy     ← 第 4 章 PVC 演示
pvc-b239b239-...                          2Gi   3         attached  healthy     ← MongoDB
pvc-bf5eddf6-...                          10Gi  3         attached  degraded    ← Grafana：副本没放全
pvc-f3f990b0-...                          20Gi  3         detached  faulted     ← Prometheus：一个副本都放不下

wk-app01   scheduled=11G max=29G
wk-app02   scheduled=11G max=29G
wk-edge01  scheduled=11G max=29G
wk-obs01   scheduled=16G max=29G

Scheduled=False ReplicaSchedulingFailure precheck new replica failed: insufficient storage

storage-over-provisioning-percentage           100
storage-reserved-percentage-for-default-disk   30
storage-minimal-available-percentage           10
```

算一下：每块盘 29 GB，预留 30% 以后可分配约 20 GB（超额分配 100% = 不超额）；已经分配了 11 GB，剩 9 GB，放不下 20 Gi 的 Prometheus 副本。

修复：超额分配比例调到 200%：

```bash
kubectl -n longhorn-system patch settings.longhorn.io storage-over-provisioning-percentage \
  --type merge -p '{"value":"200"}'

sleep 60
kubectl -n monitoring wait --for=condition=Ready pod/prometheus-kps-kube-prometheus-stack-prometheus-0 --timeout=300s

kubectl -n longhorn-system get volumes.longhorn.io \
  pvc-f3f990b0-b772-4eb0-8229-2b66fe11abd4 pvc-bf5eddf6-f125-4f34-a8ab-48d2f8f22198 \
  -o custom-columns=NAME:.metadata.name,STATE:.status.state,ROBUST:.status.robustness
```

```text
setting.longhorn.io/storage-over-provisioning-percentage patched
pod/prometheus-kps-kube-prometheus-stack-prometheus-0 condition met
NAME                                       STATE      ROBUST
pvc-f3f990b0-b772-4eb0-8229-2b66fe11abd4   attached   healthy
pvc-bf5eddf6-f125-4f34-a8ab-48d2f8f22198   attached   healthy
```

### 问题 2：验收脚本 `JSONDecodeError`

重跑 03：

```bash
bash 03_verify_observability.sh > /root/ch7-03_verify_observability.sh.log 2>&1 </dev/null
echo "verify exit=$?"
grep -E "^\[|HTTP|JSONDecodeError" /root/ch7-03_verify_observability.sh.log
```

```text
verify exit=1
[1/6] 查看 monitoring 命名空间核心资源
[2/6] 查看业务 /metrics 入口
[3/6] 查看 Prometheus Targets
[4/6] 验证 Grafana 与 Jaeger 正式入口
HTTP/1.1 200 OK            ← grafana.qytk8s.com
HTTP/1.1 200 OK            ← jaeger.qytk8s.com
[5/6] 生成一轮演示流量并检查 Jaeger 服务名
json.decoder.JSONDecodeError: Extra data: line 1 column 5 (char 4)
```

前 4 步通过时看到的资源：

```text
pod/kps-grafana-658d74c467-6wr8m                          3/3   Running
pod/kps-kube-prometheus-stack-operator-75cc97ccbf-p69r5   1/1   Running
pod/kps-kube-state-metrics-67fb46f68f-c2nvp               1/1   Running
pod/kps-prometheus-node-exporter-xxxxx                    1/1   Running    （7 个，DaemonSet）
pod/prometheus-kps-kube-prometheus-stack-prometheus-0     2/2   Running
pod/jaeger-6d59698f56-f9k6g                               1/1   Running
pod/otel-opentelemetry-collector-668bcb75db-27hlp         1/1   Running
```

逐个检查 [5/6] 用到的接口：

```bash
CA=/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt

# 业务接口正常
curl -s --cacert $CA "https://netdevops.qytk8s.com/api/device/api/v1/devices" -w "\nhttp=%{http_code}\n" | cut -c1-120

# Jaeger 服务列表接口
curl -s --cacert $CA https://jaeger.qytk8s.com/api/services -w "\nhttp=%{http_code}\n"
```

```text
[{"hostname":"bj-core-01","mgmt_ip":"10.10.1.11","vendor":"Cisco","model":"Nexus9000",...
http=200
404 page not found                  ← Python 把 "404" 解析成数字，后面多出来的文字就报 "Extra data"
http=404
```

绕过网关，直接问 Jaeger：

```bash
kubectl -n observability port-forward svc/jaeger 16686:16686 >/tmp/pf-jaeger.log 2>&1 &
PF=$!
sleep 4

for p in / /api/services /api/v3/services; do
  printf "%-20s " "$p"
  curl -s -o /tmp/jr.txt -w "http=%{http_code}  " "http://localhost:16686$p"
  head -c 120 /tmp/jr.txt | tr '\n' ' '
  echo
done

kill $PF
```

```text
/                    http=200  <!doctype html> <html lang="en">  ...
/api/services        http=404  404 page not found
/api/v3/services     http=200  {"services":["resource-service","audit-service","device-service","jaeger","frontend"]}
```

Jaeger 2.23 去掉了旧接口，只剩 `/api/v3/...`。用 v3 API 把验收脚本的“跨 4 个服务的 trace”检查重做一遍：

```bash
CA=/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt
APP=https://netdevops.qytk8s.com
J=https://jaeger.qytk8s.com

# 1. 和验收脚本一样，产生一轮业务流量
curl -s --cacert $CA $APP/api/device/api/v1/dashboard/summary >/dev/null
curl -s --cacert $CA $APP/api/device/api/v1/devices/1 >/dev/null
sleep 5

# 2. v3 API 查最近 15 分钟 frontend 的 trace
START=$(date -u -d '15 min ago' +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
curl -s --cacert $CA -G "$J/api/v3/traces" \
  --data-urlencode "query.service_name=frontend" \
  --data-urlencode "query.start_time_min=$START" \
  --data-urlencode "query.start_time_max=$END" \
  > /tmp/v3traces.json

# 3. v3 返回 OpenTelemetry 格式：resourceSpans → resource.attributes 里有 service.name → scopeSpans → spans
python3 - <<'PY'
import json, collections
data = json.load(open("/tmp/v3traces.json"))
svc_by_trace = collections.defaultdict(set)
spans_by_trace = collections.Counter()
for rs in data.get("result", {}).get("resourceSpans", []):
    svc = next((a["value"]["stringValue"] for a in rs["resource"]["attributes"]
                if a["key"] == "service.name"), "unknown")
    for ss in rs.get("scopeSpans", []):
        for sp in ss.get("spans", []):
            svc_by_trace[sp["traceId"]].add(svc)
            spans_by_trace[sp["traceId"]] += 1
required = {"frontend", "device-service", "resource-service", "audit-service"}
full = [t for t, s in svc_by_trace.items() if required <= s]
print(f"trace 总数: {len(svc_by_trace)}，同时经过 4 个服务的: {len(full)}")
if full:
    t = full[0]
    print("示例 Trace ID:", t, " span 数:", spans_by_trace[t], " 服务:", sorted(svc_by_trace[t]))
PY
```

```text
trace 总数: 10，同时经过 4 个服务的: 5
示例 Trace ID: d726151062bc06d27bc7021f10f5788b  span 数: 18  服务: ['audit-service', 'device-service', 'frontend', 'resource-service']
```

### Prometheus 抓取目标和 Grafana 大盘

```bash
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 >/tmp/pf-prom.log 2>&1 &
PF=$!
sleep 4

echo "--- 业务服务（up=1 表示正常）"
curl -s 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=up{namespace="qytang-netdevops"}' \
  | jq -r '.data.result[] | "\(.metric.service)  up=\(.value[1])"'

echo "--- 全部目标：正常 / 总数"
curl -s 'http://localhost:9090/api/v1/targets?state=active' \
  | jq -r '[.data.activeTargets[] | .health] | "\(map(select(.=="up"))|length) / \(length)"'

echo "--- 异常的目标"
curl -s 'http://localhost:9090/api/v1/targets?state=active' \
  | jq -r '.data.activeTargets[] | select(.health != "up") | "\(.labels.job)  \(.scrapeUrl)"' | sort

kill $PF

echo "--- Grafana 大盘"
GPASS=$(kubectl -n monitoring get secret kps-grafana -o jsonpath='{.data.admin-password}' | base64 -d)
curl -s --cacert $CA -u "admin:$GPASS" "https://grafana.qytk8s.com/api/search?type=dash-db" \
  | jq -r '.[].title' | grep -iE "qyt|platform|trace|netdevops"
```

```text
--- 业务服务（up=1 表示正常）
resource-service  up=1
device-service  up=1
frontend  up=1
frontend  up=1                 ← frontend 有 2 个副本（第 6 章扩容的结果）
audit-service  up=1
--- 全部目标：正常 / 总数
43 / 52
--- 异常的目标
kube-controller-manager  https://10.1.1.101:10257/metrics
kube-controller-manager  https://10.1.1.102:10257/metrics
kube-controller-manager  https://10.1.1.103:10257/metrics
kube-etcd  http://10.1.1.101:2381/metrics
kube-etcd  http://10.1.1.102:2381/metrics
kube-etcd  http://10.1.1.103:2381/metrics
kube-scheduler  https://10.1.1.101:10259/metrics
kube-scheduler  https://10.1.1.102:10259/metrics
kube-scheduler  https://10.1.1.103:10259/metrics
--- Grafana 大盘
QYT NetDevOps 总览大盘
Trace 线索与 Jaeger 跳转
```

9 个异常目标的原因，在第 1 章 `kubeadm init` 的输出里就能看到：

```text
[control-plane-check] Checking kube-controller-manager at https://127.0.0.1:10257/healthz
[control-plane-check] Checking kube-scheduler at https://127.0.0.1:10259/livez
```

它们只监听 `127.0.0.1`，Prometheus 从别的节点按节点 IP 去抓，自然连不上。

## 笔记 / 疑问

（自己补充）
