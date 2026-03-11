# 第 4 步：安装 Prometheus、Grafana、Jaeger 与 OTel Collector

## 本步目标

从第六章结束快照出发，把第七章需要的观测栈一次性装进集群。

本步完成后，应达到下面状态：

- 业务代码已同步到 Git 仓库
- 业务镜像已更新到带可观测能力的新版本
- 业务 Deployment 已完成滚动
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
2. 同步第七章业务代码到 Git 仓库
3. 构建并推送带 `OpenTelemetry` 能力的新镜像
4. 等待业务 Deployment 滚动完成
5. 安装 `kube-prometheus-stack`
6. 安装 `Jaeger`
7. 安装 `OpenTelemetry Collector`
8. 创建业务 `ServiceMonitor`
9. 发布 `Grafana` 与 `Jaeger` 正式域名
10. 下发 `Grafana` 自定义大盘

## 预期

- `monitoring` 命名空间出现 `Prometheus` 和 `Grafana`
- `observability` 命名空间出现 `Jaeger` 和 `OTel Collector`
- `QYT NetDevOps` 已经滚动到带指标和 Trace 的新版本
- `Grafana` 可通过正式域名访问
- `Jaeger` 可通过正式域名访问
- `Prometheus` Targets 中能看到业务服务

## 关键理解

这一节不是做“组件迁移”，而是做“第七章首次安装”。

也就是说：

- 第六章结束时还没有第七章 Trace 后端
- 学员恢复到第六章结束快照后
- 不能只装监控组件，还必须先把业务应用升级到第七章版本
- 这个升级动作已经收敛进本步脚本，不需要课堂上额外手工发布一轮

## 下一步

进入第 5 步，做正式入口、Targets、Dashboard 和 Trace 验收：

- `docs/06_publish_grafana_and_verify.md`
