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

## 课前理论导读

正式进入操作前，建议先阅读：

- `docs/00_cilium_hubble_theory.md`

这份文档不属于执行步骤，也不需要敲命令，但它负责解决第二章最核心的理论问题：

- 为什么本章选 `Cilium`
- `Cilium` 和 `Hubble` 分别负责什么
- `Calico` 与 `Cilium` 的教学对比应该怎么讲
- 这里的 `L7` 和后面的 `Istio` 到底有什么边界

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

## 教学提示：为什么这一章选 `Cilium`，而不是先讲 `Calico`

这一段是很多学员都会问的，所以建议你上课时直接先把边界讲清楚：

> `Calico` 不是落后方案，`Cilium` 也不是“全面替代一切”的唯一答案。  
> 第二章之所以选 `Cilium`，是因为它更适合把 **eBPF、东西向可观测、L7 感知策略、BGP 控制面** 这条主线一次讲透。

你可以按下面这个节奏讲：

### 1. 如果学员以前主要用的是 `Calico`

他们通常已经熟悉：

- `BGP`
- `NetworkPolicy`
- `iptables` 或传统转发思路
- “先把 Pod 网络打通，再谈策略”

这套思路完全没有问题，而且在很多生产环境里仍然成立。

### 2. 那为什么这章要切到 `Cilium`

因为这一章要突出的是下面几件事：

- `eBPF kube-proxy replacement`
- 直接看到东西向流量
- 在同一套体系里演示 `L3/L4` 到 `L7`
- 把 `BGP Control Plane` 和 `Route Reflector` 连起来讲

`Cilium` 在这几个点上更适合课堂演示，尤其是：

- 数据平面更容易引出 `eBPF`
- `Hubble` 更容易把“谁访问谁”讲得可视化
- `L7` 策略更容易把“网络安全不只是放端口”讲清楚
- 后续还能自然过渡到服务网格、身份、安全治理

### 3. 上课时可以怎么一句话总结

- `Calico` 更像是很多工程师已经熟悉的“传统云原生网络强者”
- `Cilium` 更像是“把 eBPF、可观测和安全能力整合得更强的现代网络底座”

### 4. 不要把话讲死

建议你提醒学员：

- 不是说用了 `Calico` 就落后
- 也不是说用了 `Cilium` 就自动比别人高级
- 真正的区别在于：你想重点解决什么问题，你想怎么教、怎么运维、怎么观测

## 教学提示：`Cilium` 和后面的 `Istio` 是什么关系

这也是学员最容易混淆的点，建议你提前打预防针：

> 第二章不是在讲 “服务网格”，而是在讲 “网络底座上的零信任能力”。  
> `Cilium` 和 `Istio` 不是简单替代关系，更常见的是分层配合。

你可以这样讲：

### 1. `Cilium` 更偏什么

`Cilium` 更偏：

- CNI
- 数据平面
- 东西向网络连通
- `L3/L4/L7` 基础安全策略
- 流量可观测
- `BGP` 控制面

它更像是在回答这些问题：

- 谁能访问谁
- 哪个端口能不能通
- 哪个 HTTP 方法能不能放
- 这个流量到底有没有被放行

### 2. `Istio` 更偏什么

`Istio` 更偏：

- 服务身份
- `mTLS`
- `JWT`
- `AuthorizationPolicy`
- 灰度、熔断、重试、流量治理

它更像是在回答这些问题：

- 这个服务身份是谁
- 调用方有没有合法凭据
- 这个请求是否满足服务级认证授权
- 这 10% 流量要不要导向新版本

### 3. 课堂上一句最容易让人记住的话

- `Cilium` 更像“网络安全底座”
- `Istio` 更像“服务通信安全与治理平台”

### 4. 对本课程的分工

第二章先讲：

- 网络先打通
- 东西向流量先看见
- 基础零信任先做起来

后续如果进入 `Istio`，再讲：

- 服务身份
- `mTLS`
- 更细粒度的授权
- 服务治理

## 执行标记说明

为了便于你在 `ops` 上直接“贴贴贴”，本章对每个脚本都做执行标记：

- **必须执行**：恢复到第二章起点快照后，默认需要实际执行
- **条件执行**：是否执行取决于你是否保留了上一轮产物
- **只读验证**：这一项主要用于检查结果，不会改配置

## 本章脚本执行矩阵

| 步骤 | 文档 | 脚本 | 执行标记 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| 0 | （内嵌于步骤 1） | `scripts/00_check_and_recover_cluster.sh` | 自动执行 | 快照恢复后集群检查与恢复，API 不可达时重启 lb/cp 服务 |
| 1 | `02_prepare_cilium_artifacts.md` | `scripts/01_prepare_cilium_artifacts.sh` | 必须执行 | 含步骤 0；预热 Cilium / Hubble / Helm chart / CLI / 镜像到 Harbor 与 `ops HTTP` |
| 2 | `03_install_cilium.md` | `scripts/02_install_cilium.sh` | 必须执行 | 清理 kube-proxy，安装并验收启用 `native routing` 与 `kube-proxy replacement` 的 Cilium |
| 3 | `04_service_discovery.md` | `scripts/03_apply_service_discovery_demo.sh` | 必须执行 | 演示 Pod、Service、DNS 与 Service Discovery |
| 4 | `05_enable_hubble.md` | `scripts/04_enable_hubble.sh` | 必须执行 | 启用 Hubble 并观测东西向流量 |
| 5 | `06_l7_policy.md` | `scripts/05_apply_l7_policy_demo.sh` | 必须执行 | 演示 `L3/L4` 与 `L7` 策略 |
| 6 | `07_bgp_rr.md` | `scripts/06_configure_bgp_rr.sh` | 必须执行 | 接入 `VyOS`，建立 `Route Reflector + iBGP client` |
| 7 | `08_verify.md` | 无 | 只读验证 | 本章最终验收，不改配置 |

## 本章执行顺序

请严格按照下面顺序执行：

0. 先阅读理论导读：`00_cilium_hubble_theory.md`
1. `02_prepare_cilium_artifacts.md`
2. `03_install_cilium.md`
3. `04_service_discovery.md`
4. `05_enable_hubble.md`
5. `06_l7_policy.md`
6. `07_bgp_rr.md`
7. `08_verify.md`

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

## 快照恢复后的自动恢复

恢复快照后，`kubectl` 常出现 `EOF` 或 `TLS handshake timeout`，因 lb01/lb02（VIP + HAProxy）和 cp 节点（kube-apiserver）可能尚未就绪。

第一步脚本 `01_prepare_cilium_artifacts.sh` 会先自动执行 `00_check_and_recover_cluster.sh`：

1. 尝试 `kubectl get nodes` 最多 30 次（每 10s 一次）
2. 仍不可达则：重启 lb01/lb02 的 haproxy、keepalived；重启 cp01~03 的 kubelet
3. 等待 45s 后重试，最多 3 轮
4. 仍失败则输出诊断（lb/cp 服务状态、VIP、API healthz）并退出

也可单独运行 `bash scripts/00_check_and_recover_cluster.sh` 做集群连通性检查与恢复。

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
