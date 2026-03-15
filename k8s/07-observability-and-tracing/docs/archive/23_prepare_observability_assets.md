# 第 2 步：准备可观测性资产

## 本步目标

在安装监控栈之前，先把第七章的本地资产和执行入口固定下来。

这一节只负责检查第七章资产是否齐全，不负责发布新的业务版本。

本步完成后，应达到下面状态：

- 第七章目录结构已固定
- `Grafana` 的 provisioning 目录已存在
- Dashboard 资产有明确落点
- 脚本执行顺序已明确
- 当前业务应用是否已经更新到第七章版本，不在本步处理范围内

## 本步脚本

- `k8s/07-observability-and-tracing/scripts/01_prepare_observability_assets.sh`

## 执行命令

```bash
bash /docker_k8s_2026/k8s/07-observability-and-tracing/scripts/01_prepare_observability_assets.sh
```

## 这一步做了什么

脚本会按下面顺序执行：

1. 自动检查并恢复集群连通性
2. 检查第七章目录与 Grafana provisioning 目录
3. 检查第七章主线文档
4. 输出后续执行入口

## 重要说明

执行完这一步后，如果你看到业务应用仍然是第六章版本，这是正常现象。

原因很简单：

- 这一步只是做资产检查
- 业务代码同步、镜像构建、GitOps 发布会在下一步安装脚本里统一完成
- 所以不要把这一步误解成“第七章应用已经更新完毕”

## 目录分工

### `docs/`

用于正式课件。

### `scripts/`

用于在 `ops` 节点执行的一把梭脚本。

### `manifests/`

用于存放第七章安装与发布相关的 YAML。

这里特别要注意：

- 第七章自己的 `Gateway listener` 在 `20_gateway_observability_listeners.json`
- 第七章自己的 `HTTPRoute / ReferenceGrant` 在 `21_gateway_observability_https.yaml`

这一步虽然还不安装观测栈，但要先明确第七章入口对象由本章自管，不复用前面章节的入口清单。

### `artifacts/`

用于存放：

- `Grafana` provisioning 文件
- 自定义 dashboard JSON
- 本章安装过程中需要复用的资产

## 本步完成标准

满足下面条件即可进入下一步：

- 第七章目录结构齐全
- `Grafana` 资产目录已存在
- 第七章脚本清单已明确
- 你已经理解：业务应用升级不在本步发生

## 下一步

进入第 3 步，理解业务服务接入指标与 Trace 的方式：

- `docs/02_install_prometheus_grafana_jaeger.md`
