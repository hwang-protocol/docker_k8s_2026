# 第 5 步：发布 Grafana 正式入口并做验收

## 本步目标

把第七章的可视化入口正式对外发布，并验证：

- Grafana 域名可访问
- Prometheus 数据源正常
- Jaeger 域名可访问
- Dashboard 已自动出现

## 本步脚本

- `k8s/07-observability-and-tracing/scripts/03_verify_observability.sh`

## 执行命令

```bash
bash /docker_k8s_2026/k8s/07-observability-and-tracing/scripts/03_verify_observability.sh
```

## 重点检查项

- `https://grafana.qytk8s.com` 可访问
- `https://jaeger.qytk8s.com` 可访问
- `monitoring` 命名空间核心 Pod 正常
- `observability` 命名空间核心 Pod 正常
- 业务指标可被 `Prometheus` 采集
- `Grafana` 中已出现预置大盘
- `Jaeger` 中能查到业务服务 Trace

## 下一步

进入第 6 步，做课堂上的 Trace 与故障定位演示：

- `docs/07_trace_demo_and_fault_location.md`
