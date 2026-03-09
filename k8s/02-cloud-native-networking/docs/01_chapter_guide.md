# 第二章总览：云原生网络与服务互联

## 本章目标

本章的目标是把第一章已经完成控制平面初始化、但尚未安装 CNI 的集群，推进到 **东西向网络完全可用** 的状态。

本章结束后，应该达到下面的状态：

- 所有节点从 `NotReady` 变为 `Ready`
- `CoreDNS` 从 `Pending` 变为 `Running`
- `Cilium` 已接管集群 CNI，并启用 `eBPF kube-proxy replacement`
- `Pod IP`、`Service`、`CoreDNS`、`Service Discovery` 可以完整演示
- `Hubble` 可以观察东西向流量
- `L3/L4` 与 `L7` 策略都可以演示
- `VyOS` 作为 `Route Reflector`，4 台 Worker 作为 `iBGP client`
- 第二章重点体现东西向网络、eBPF 数据平面与 BGP 控制面能力

## 本章学习方式

这一章继续采用“**文档主导 + 小脚本辅助 + YAML 独立发布**”的方式进行。

也就是说：

1. 你只需要登录 `ops`
2. 按文档顺序一段一段复制命令
3. 每执行一步，都先验证，再继续下一步
4. 较长命令或批量动作由小型 Bash 脚本完成
5. 所有 YAML 都放在 `manifests/`，并通过 `http://ops:9000/` 发布

## 本章重点边界

第二章主打 **东西向流量** 与 **eBPF 高级能力**，不把第三章的南北向入口设计提前讲散。

本章重点包括：

- `Cilium`
- `eBPF kube-proxy replacement`
- `native routing`
- `Hubble`
- `L3/L4` 与 `L7` 策略
- `Cilium BGP Control Plane`
- `VyOS Route Reflector`

第三章再集中处理：

- `LoadBalancer VIP`
- `Ingress`
- `Gateway API`
- 北向 `L4 / L7` 入口控制

## 执行标记说明

为了便于你在 `ops` 上直接“贴贴贴”，本章对每个脚本都做执行标记：

- **必须执行**：恢复到第二章起点快照后，默认需要实际执行
- **条件执行**：是否执行取决于你是否保留了上一轮产物
- **只读验证**：这一项主要用于检查结果，不会改配置

## 本章脚本执行矩阵

| 步骤 | 文档 | 脚本 | 执行标记 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `02_prepare_cilium_artifacts.md` | `scripts/01_prepare_cilium_artifacts.sh` | 必须执行 | 预热 Cilium / Hubble / Helm chart / CLI / 镜像到 Harbor 与 `ops HTTP` |
| 2 | `03_install_cilium.md` | `scripts/02_install_cilium.sh` | 必须执行 | 清理 kube-proxy，安装启用 `native routing` 与 `kube-proxy replacement` 的 Cilium |
| 3 | `04_verify_network_ready.md` | `scripts/03_verify_network_ready.sh` | 必须执行 | 验证节点、CoreDNS、Pod 网络、Service 基本恢复 |
| 4 | `05_service_discovery.md` | `scripts/04_apply_service_discovery_demo.sh` | 必须执行 | 演示 Pod、Service、DNS 与 Service Discovery |
| 5 | `06_enable_hubble.md` | `scripts/05_enable_hubble.sh` | 必须执行 | 启用 Hubble 并观测东西向流量 |
| 6 | `07_l7_policy.md` | `scripts/06_apply_l7_policy_demo.sh` | 必须执行 | 演示 `L3/L4` 与 `L7` 策略 |
| 7 | `08_bgp_rr.md` | `scripts/07_configure_bgp_rr.sh` | 必须执行 | 接入 `VyOS`，建立 `Route Reflector + iBGP client` |
| 8 | `09_verify.md` | 无 | 只读验证 | 本章最终验收，不改配置 |

## 本章执行顺序

请严格按照下面顺序执行：

1. `02_prepare_cilium_artifacts.md`
2. `03_install_cilium.md`
3. `04_verify_network_ready.md`
4. `05_service_discovery.md`
5. `06_enable_hubble.md`
6. `07_l7_policy.md`
7. `08_bgp_rr.md`
8. `09_verify.md`

## 第二章起点状态

第二章开始前，集群应满足下面这些前提：

- 第一章已经完成
- Kubernetes 版本固定为 `v1.33.9`
- 当前节点整体为 `NotReady`
- `CoreDNS` 当前为 `Pending`
- `ops` 已具备 `kubectl`
- `ops` 已具备 nginx 文件发布服务：`http://ops:9000/`
- `Harbor` 已可用，且第一章核心镜像已经在 `harbor.qytk8s.com`

## 快照恢复说明

| 节点 | 是否恢复快照 | 说明 |
| :--- | :--- | :--- |
| `ops` | **不恢复** | 保留脚本、manifests、CLI 工具 |
| `cp01` / `cp02` / `cp03` | 恢复 | 恢复到第一章结束状态（kube-proxy 运行、无 CNI） |
| `wk-app01` / `wk-app02` / `wk-edge01` / `wk-obs01` | 恢复 | 同上 |
| `harbor` | **不恢复** | Harbor 数据持久保留，镜像无需重新推送 |
| `VyOS` | 恢复 | 恢复到第一章结束状态（无 BGP 配置） |

> **Harbor 镜像说明**：由于 Harbor 不做快照恢复，第一步脚本中的镜像推送步骤为**幂等操作**（已存在则秒跳过）。保留该步骤的目的是完整记录如何将上游镜像搬运到私有仓库，供教学演示参考。

这意味着第二章的第一性目标不是“重新建集群”，而是：

- 补齐 CNI
- 让集群网络平面真正可用
- 用 eBPF 的方式体现东西向高级能力

## 版本冻结

为了确保课程的可复现性和兼容性，第二章统一冻结以下版本：

- Kubernetes：`v1.33.9`
- Cilium：`1.19.1`
- Helm Chart：`1.19.1`

## 第二章网络设计要点

本章继续沿用第一章已经冻结的地址设计：

- 宿主机网络：`10.1.1.0/24`
- API VIP：`10.1.1.10`
- Service CIDR：`10.96.0.0/12`
- Pod CIDR：`10.244.0.0/16`

本章中 Cilium 采用：

- `native routing`
- `eBPF kube-proxy replacement`
- 与第一章一致的 `Pod CIDR`

## 第二章 BGP 设计要点

本章中 BGP 的主线设计如下：

- `VyOS(10.1.1.254)` 作为 `Route Reflector`
- 4 台 Worker 作为 `iBGP client`
- 全部使用私有 ASN：`65001`

本章重点讲：

- 为什么 `Cilium` 不只是 CNI
- 为什么 `eBPF` 不只是“转发更快”
- 为什么网络工程师要关心 Kubernetes 里的 BGP 控制面

## 课程文件 HTTP 服务

第二章继续沿用 `ops` 节点上的 nginx 文件服务：

- 服务地址：`http://ops:9000/`
- 根目录：`/docker_k8s_2026/k8s/`
- 本章所有 YAML 文件统一放在 `manifests/`

后续章节中凡是涉及：

- Helm values
- Kubernetes YAML
- 演示工作负载清单

都通过 `http://ops:9000/02-cloud-native-networking/...` 发布和引用。
