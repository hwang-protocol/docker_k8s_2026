# 第 5 步：验收 Grafana、Jaeger 与可观测数据面

## 本步目标

验证第七章可观测性环境已经真正可用，并确认：

- Grafana 域名可访问
- Prometheus 数据源正常
- Jaeger 域名可访问
- Dashboard 已自动出现
- Jaeger 中已经开始出现业务 Trace

## 理论说明

到这一页时，发布动作其实已经在上一页完成了。

这一页要回答的是另外两个问题：

1. 入口能不能打开
`Grafana` 和 `Jaeger` 不是只看 Pod `Running`，而是要确认正式域名真的可访问。

2. 数据有没有进来
`Prometheus`、`Grafana`、`Jaeger` 就算组件都启动了，如果没有业务指标、没有 Trace，这一章也不算完成。

## 本步脚本

- `k8s/07-observability-and-tracing/scripts/03_verify_observability.sh`

## 执行命令

```bash
bash /docker_k8s_2026/k8s/07-observability-and-tracing/scripts/03_verify_observability.sh
```

## 验证方法

```bash
bash /docker_k8s_2026/k8s/07-observability-and-tracing/scripts/03_verify_observability.sh
```

关键看点：

- 脚本会先看 `monitoring` 和 `observability` 的核心资源
- 然后直接验证 `Grafana` 与 `Jaeger` 正式域名
- 最后会主动打一次业务流量，再去检查 `Jaeger` 里是否已经出现跨 4 个服务的完整 Trace

预期结果：

- `monitoring` 命名空间中 `Grafana / Prometheus` 相关资源正常
- `observability` 命名空间中 `Jaeger / OTel Collector` 相关资源正常
- `https://grafana.qytk8s.com` 返回正常登录页
- `https://jaeger.qytk8s.com` 返回正常首页
- `Jaeger services` 输出里能看到业务服务名
- 脚本最终能找到同时包含 `frontend / device-service / resource-service / audit-service` 的完整 Trace

## GUI 观察重点

### Grafana

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

## 下一步

进入第 6 步，做课堂上的 Trace 与故障定位演示：

- `docs/05_trace_demo_and_fault_location.md`
