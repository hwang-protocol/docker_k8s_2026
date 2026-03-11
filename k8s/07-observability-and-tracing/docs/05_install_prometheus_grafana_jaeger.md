# 第 4 步：安装 Prometheus、Grafana、Jaeger 与 OTel Collector

## 本步目标

从第六章结束快照出发，把第七章需要的观测栈一次性装进集群。

本步完成后，应达到下面状态：

- Kubernetes 基础指标已被采集
- 业务服务指标已被采集
- `Grafana` 已就绪
- `Jaeger` 已就绪
- `OpenTelemetry Collector` 已就绪

## 本步脚本

- `k8s/07-observability-and-tracing/scripts/02_install_observability_stack.sh`

## 执行命令

```bash
bash /docker_k8s_2026/k8s/07-observability-and-tracing/scripts/02_install_observability_stack.sh
```

## 这一步做了什么

脚本会按下面顺序执行：

1. 自动检查并恢复集群连通性
2. 安装 `kube-prometheus-stack`
3. 安装 `Jaeger`
4. 安装 `OpenTelemetry Collector`
5. 创建业务 `ServiceMonitor`
6. 发布 `Grafana` 与 `Jaeger` 正式域名
7. 下发 `Grafana` 自定义大盘

## 预期

- `monitoring` 命名空间出现 `Prometheus` 和 `Grafana`
- `observability` 命名空间出现 `Jaeger` 和 `OTel Collector`
- `Grafana` 可通过正式域名访问
- `Jaeger` 可通过正式域名访问
- `Prometheus` Targets 中能看到业务服务

## 关键理解

这一节不是做“组件迁移”，而是做“第七章首次安装”。

也就是说：

- 第六章结束时还没有第七章 Trace 后端
- 学员恢复到第六章结束快照后
- 直接按第七章脚本把 `Jaeger` 装出来即可

## 下一步

进入第 5 步，做正式入口、Targets、Dashboard 和 Trace 验收：

- `docs/06_publish_grafana_and_verify.md`
