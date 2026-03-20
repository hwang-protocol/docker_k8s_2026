# 第 0 部分：Kubernetes 特性（官网口径版）

## 使用说明

- 本文按 `2026-03-20` 的 Kubernetes 官网首页 `Kubernetes Features` 整理
- 每个特性单独一页
- 每页固定结构：
  1. 原文
  2. 翻译
  3. 精彩的高级的激动人心的解释
- 适合直接复制到 PPT 中自行排版

---

## 第 1 页：Automated rollouts and rollbacks

**1. 原文：**

Kubernetes progressively rolls out changes to your application or its configuration, while monitoring application health to ensure it doesn't kill all your instances at the same time. If something goes wrong, Kubernetes will rollback the change for you. Take advantage of a growing ecosystem of deployment solutions.

**2. 翻译：**

Kubernetes 会逐步将变更发布到你的应用或其配置中，同时监控应用的健康状况，以确保它不会同时杀死你所有的实例。如果出现问题，Kubernetes 会为你回滚变更。你可以充分利用不断增长的部署解决方案生态系统。

**3. 精彩的高级的激动人心的解释：**

摒弃传统的手工变更模式，Kubernetes 将应用发布转化为声明式的状态收敛过程。它通过精细的步长控制和实时的健康度检查，在保障业务连续性的前提下实现平滑过渡；一旦探测到异常指标，系统将毫秒级触发熔断并自动回滚至稳定基线。这不仅是发布工具的升级，更是工程化交付能力的质变。

---

## 第 2 页：Service discovery and load balancing

**1. 原文：**

No need to modify your application to use an unfamiliar service discovery mechanism. Kubernetes gives Pods their own IP addresses and a single DNS name for a set of Pods, and can load-balance across them.

**2. 翻译：**

无需修改你的应用去使用不熟悉的服务发现机制。Kubernetes 为 Pod 赋予了独立的 IP 地址，并为一组 Pod 提供统一的 DNS 名称，同时能在它们之间进行负载均衡。

**3. 精彩的高级的激动人心的解释：**

彻底解耦了网络拓扑与应用逻辑。Kubernetes 在基础设施层内建了动态寻址与流量分发机制，通过虚拟 IP 和内部 DNS 屏蔽了底层 Pod 的生灭变化。应用无需集成臃肿的注册中心客户端，即可享受原生的、高可用的服务间通信，实现了真正的“网络即服务”。

---

## 第 3 页：Storage orchestration

**1. 原文：**

Automatically mount the storage system of your choice, whether from local storage, a public cloud provider, or a network storage system such as iSCSI or NFS.

**2. 翻译：**

自动挂载你所选择的存储系统，无论是来自本地存储、公有云提供商，还是像 iSCSI 或 NFS 这样的网络存储系统。

**3. 精彩的高级的激动人心的解释：**

实现了计算与存储的彻底分离。Kubernetes 将底层异构的存储介质（本地磁盘、分布式文件系统、公有云块存储）抽象为统一的声明式 API。应用只需声明容量和访问模式，平台即可自动完成卷的供给、挂载与回收，让有状态工作负载的调度变得如无状态般轻量。

---

## 第 4 页：Secret and configuration management

**1. 原文：**

Deploy and update Secrets and application configuration without rebuilding your image and without exposing Secrets in your stack configuration.

**2. 翻译：**

部署和更新 Secrets 与应用配置，无需重新构建你的镜像，也无需在你的技术栈配置中暴露 Secrets。

**3. 精彩的高级的激动人心的解释：**

践行了“不可变基础设施”的最佳实践。将敏感凭证与环境配置从容器镜像中物理剥离，使得同一份镜像可以安全、无缝地流转于开发、测试与生产环境。通过内存级挂载与动态热更新机制，在提升安全合规水位的同时，极大降低了配置变更的运维成本。

---

## 第 5 页：Automatic bin packing

**1. 原文：**

Automatically places containers based on their resource requirements and other constraints, while not sacrificing availability. Mix critical and best-effort workloads in order to drive up utilization and save even more resources.

**2. 翻译：**

根据容器的资源需求和其他约束条件自动放置容器，同时不牺牲可用性。混合关键工作负载和尽力而为的工作负载，以提高利用率并节省更多资源。

**3. 精彩的高级的激动人心的解释：**

重新定义了数据中心的资源利用率。基于多维度的资源请求、节点亲和性以及拓扑分布约束，Kubernetes 的调度器能够在全局视角下计算出最优的容器放置策略。它允许将核心在线业务与离线批处理任务混合部署，在确保高优先级服务 SLA 的同时，极致压榨集群的闲置算力。

---

## 第 6 页：Batch execution

**1. 原文：**

In addition to services, Kubernetes can manage your batch and CI workloads, replacing containers that fail, if desired.

**2. 翻译：**

除了服务之外，Kubernetes 还可以管理你的批处理和 CI 工作负载，并能在需要时替换失败的容器。

**3. 精彩的高级的激动人心的解释：**

突破了微服务平台的边界，将其扩展为统一的通用工作负载控制平面。无论是短暂的 CI/CD 流水线任务，还是大规模的并行数据处理，Kubernetes 都能提供完善的作业生命周期管理。它统一了在线与离线算力的调度底座，大幅降低了企业基础设施的碎片化程度。

---

## 第 7 页：Self-healing

**1. 原文：**

Kubernetes restarts containers that crash, replaces entire Pods where needed, reattaches storage in response to wider failures, and can integrate with node autoscalers to self-heal even at the node level.

**2. 翻译：**

Kubernetes 会重启崩溃的容器，在需要时替换整个 Pod，在应对更大范围故障时重新挂载存储，并且可以与节点自动伸缩器集成，甚至在节点级别实现自我修复。

**3. 精彩的高级的激动人心的解释：**

构筑了面向未来的高可用防线。基于强大的控制循环（Control Loop）架构，Kubernetes 持续比对集群的“期望状态”与“实际状态”。无论是进程崩溃、节点宕机还是网络脑裂，控制平面都能在无人干预的情况下，自动完成实例的驱逐、重建与流量切换，将故障恢复从被动响应提升为系统的内生能力。

---

## 第 8 页：Horizontal scaling

**1. 原文：**

Scale your application up and down with a simple command, with a UI, or automatically based on CPU usage.

**2. 翻译：**

通过一个简单的命令、一个 UI 界面，或者基于 CPU 使用率自动地对你的应用进行水平扩缩容。

**3. 精彩的高级的激动人心的解释：**

赋予了应用应对突发流量的极致弹性。通过对接 CPU、内存或自定义的业务指标（如 QPS、队列深度），Kubernetes 能够以秒级延迟动态增减工作负载副本。它将容量规划从静态的“预留模式”转变为动态的“按需供给”，在保障业务平稳度过流量洪峰的同时，最大化降低云资源开销。

---

## 第 9 页：Vertical scaling

**1. 原文：**

Automatically adjust resource requests and limits based on actual usage patterns.

**2. 翻译：**

根据实际的使用模式，自动调整资源的请求值和限制值。

**3. 精彩的高级的激动人心的解释：**

实现了资源规格的智能化自适应。摒弃了依赖人工经验的容量预估，Kubernetes 能够根据应用在运行时的真实资源消耗画像，动态调整容器的 CPU 和内存 Request/Limit。这不仅消除了因资源碎片导致的浪费，更有效避免了因 OOM（内存溢出）或 CPU 节流引发的隐性性能降级。

---

## 第 10 页：IPv4/IPv6 dual-stack

**1. 原文：**

Allocation of IPv4 and IPv6 addresses to Pods and Services.

**2. 翻译：**

为 Pods 和 Services 分配 IPv4 和 IPv6 地址。

**3. 精彩的高级的激动人心的解释：**

奠定了面向下一代互联网的基础设施底座。Kubernetes 原生支持为 Pod 和 Service 并发分配双栈地址，使得集群能够无缝接入现代复杂的企业网络与 5G/IoT 场景。它打破了 IPv4 地址枯竭的瓶颈，为海量微服务实例的扁平化互联提供了无限的寻址空间。

---

## 第 11 页：Designed for extensibility

**1. 原文：**

Add features to your Kubernetes cluster without changing upstream source code.

**2. 翻译：**

无需更改上游源代码，即可为你的 Kubernetes 集群添加新功能。

**3. 精彩的高级的激动人心的解释：**

展现了作为“云原生操作系统”的终极生命力。Kubernetes 并非封闭的产品，而是一个高度可插拔的控制平面框架。通过 CRD（自定义资源定义）和 Operator 模式，企业可以将任何基础设施（如数据库、消息队列甚至硬件设备）的运维逻辑注入集群大脑，实现“万物皆可声明式管理”的架构愿景。

---

## 收尾页：一句话总结

**标题：**

如何用一句话理解 Kubernetes 特性

**要点：**

- Kubernetes 把发布、服务访问、存储接入、配置治理、资源调度、故障恢复和弹性伸缩统一进了同一个控制平面
- 所以它不是一个“容器启动工具”，而是一套“生产级应用运行平台”
