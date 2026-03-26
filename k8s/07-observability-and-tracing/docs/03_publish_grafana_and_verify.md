# 第 3 步：验收 Grafana、Jaeger 与可观测数据面

## 本步目标

验证第七章可观测性环境已经真正可用，并确认：

- Grafana 域名可访问
- Prometheus 数据源正常
- Jaeger 域名可访问
- Dashboard 已自动出现
- Jaeger 中已经开始出现业务 Trace

## 理论说明

到这一页时，发布动作其实已经在上一页完成了。

这一页不再新增安装清单，而是直接对已经安装完成的观测栈做验收。

这一页要回答的是另外两个问题：

1. 入口能不能打开
`Grafana` 和 `Jaeger` 不是只看 Pod `Running`，而是要确认正式域名真的可访问。

2. 数据有没有进来
`Prometheus`、`Grafana`、`Jaeger` 就算组件都启动了，如果没有业务指标、没有 Trace，这一章也不算完成。

---

## 执行命令与脚本操作

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #34a853; border-radius: 6px; background: rgba(52,168,83,0.08); margin: 12px 0;">
<strong>本步执行方式</strong><br/>
这一页以一条只读验收脚本为主，再配合 GUI 观察 Grafana 和 Jaeger。
</div>

对应脚本：

- [03_verify_observability.sh](/docker_k8s_2026/k8s/07-observability-and-tracing/scripts/03_verify_observability.sh)

执行命令：

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #ea4335; border-radius: 6px; background: rgba(234,67,53,0.10); margin: 8px 0;">
<strong>❗ 本条命令建议粘贴执行</strong><br/>
执行这条脚本，会从组件状态、正式入口和真实 Trace 三个方向做一次只读验收。
</div>

```bash
bash /docker_k8s_2026/k8s/07-observability-and-tracing/scripts/03_verify_observability.sh
```

这个脚本会按下面顺序完成整条验收链路：

1. 查看 `monitoring` 和 `observability` 的核心资源
2. 查看业务 `ServiceMonitor` 和相关 Pod
3. 查看 `Prometheus` 是否已经具备抓取目标
4. 验证 `Grafana` 与 `Jaeger` 正式入口
5. 主动打一次真实业务流量
6. 到 `Jaeger` 中检查服务名与完整 Trace

如果只用一句最短的话概括，这个脚本其实同时做了 3 件事：

- 验证组件是否都已就绪
- 验证正式域名是否可访问
- 验证真实业务 Trace 是否已经形成闭环

---

## 脚本关键内容

### 关键点 1：先验证正式入口

脚本原文：

```bash
curl --resolve "${GRAFANA_DOMAIN}:443:${GRAFANA_VIP}" \
  --cacert "${CA_CERT}" \
  -I -s "https://${GRAFANA_DOMAIN}/login" | sed -n '1,5p'
curl --resolve "${JAEGER_DOMAIN}:443:${JAEGER_VIP}" \
  --cacert "${CA_CERT}" \
  -I -s "https://${JAEGER_DOMAIN}/" | sed -n '1,5p'
```

关键解释：

- `--resolve`
  - 强制把域名解析到本章当前 VIP
- `--cacert`
  - 让 `curl` 使用课程统一 CA 验证证书
- `-I`
  - 只看响应头，不下载整页内容

这一段真正要证明的是：

- `Grafana` 入口已经能通过正式域名访问
- `Jaeger` 入口也已经能通过正式域名访问

### 关键点 2：主动生成一轮业务流量

脚本原文：

```bash
device_id="$(get_demo_device_id)"
curl --resolve "${NETDEVOPS_DOMAIN}:443:${NETDEVOPS_VIP}" \
  --cacert "${CA_CERT}" \
  -s "https://${NETDEVOPS_DOMAIN}/api/device/api/v1/dashboard/summary" >/dev/null
curl --resolve "${NETDEVOPS_DOMAIN}:443:${NETDEVOPS_VIP}" \
  --cacert "${CA_CERT}" \
  -s "https://${NETDEVOPS_DOMAIN}/api/device/api/v1/devices/${device_id}" >/dev/null
```

关键解释：

- 先取一个真实设备 ID
- 再打两条真实业务请求
- 这样后面去 `Jaeger` 查询时，才有更大概率立刻看到完整 Trace

这一段真正要证明的是：

- 第七章不是只检查“空跑的组件”
- 而是要检查真实业务流量已经能留下 Trace

### 关键点 3：在 Jaeger 中查完整 Trace

脚本原文：

```bash
curl --resolve "${JAEGER_DOMAIN}:443:${JAEGER_VIP}" \
  --cacert "${CA_CERT}" \
  -s "https://${JAEGER_DOMAIN}/api/services"
```

以及：

```bash
verify_multiservice_trace "${device_id}"
```

关键解释：

- `/api/services`
  - 用来确认 `Jaeger` 已经开始识别到业务服务名
- `verify_multiservice_trace`
  - 会反复查最近 `15m` 的 Trace
  - 直到找到同时包含：
    - `frontend`
    - `device-service`
    - `resource-service`
    - `audit-service`
    的完整链路

这一段真正要证明的是：

- 第七章不是只有单服务 Trace
- 而是已经形成了跨多个服务的真实调用链

---

## GUI 观察重点

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选观察</strong><br/>
脚本验收通过后，再用浏览器分别打开 <code>Grafana</code> 和 <code>Jaeger</code> 看大盘与 Trace，会更适合课堂演示。
</div>

### Grafana

- 地址：`https://grafana.qytk8s.com`
- 用户名：`admin`
- 密码：`Cisc0123`
- 先看 `QYT NetDevOps` 总览大盘
- 再看 Kubernetes 基础大盘
- 重点看请求量、延迟、错误率和 Pod / 节点状态

### Jaeger

- 进入 `Find Traces`
- 选中 `frontend` 或 `device-service`
- 再看完整调用链和瀑布图

## 通过标准

满足下面条件即可进入最后一页课堂演示：

- `Grafana` 正式入口可访问
- `Jaeger` 正式入口可访问
- `Prometheus` 已采到业务指标
- `Jaeger` 已能检索到完整业务 Trace

---

## 下一步

进入第 4 步，做课堂上的 Trace 与故障定位演示：

- `docs/04_trace_demo_and_analysis.md`
