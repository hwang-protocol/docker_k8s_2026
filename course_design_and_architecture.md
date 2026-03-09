# Kubernetes 现代战场：eBPF 网络、零信任安全与微服务生产上线实战

## 一、 课程主线
本课程以一套微服务系统的生产上线为主线，完成以下完整闭环：
容器基础 → Kubernetes 平台搭建 → 云原生网络 → 北向入口与负载均衡 → 存储与有状态能力 → 微服务安全与零信任 → GitOps 自动化上线 → 监控、可观测性与分布式 Trace

## 二、 课程目录详情

### 1. 容器与 Docker
- **本章定位**：先把学生从传统虚拟机思维拉到容器思维，为后面的 Kubernetes 打基础。
- **核心内容**：
  - 容器与虚拟机的本质差异
  - Namespace / Cgroups 容器隔离机制
  - Docker 架构与镜像分层机制
  - Dockerfile、镜像构建与镜像分发
  - Compose 多容器编排
  - 从 Docker 到 Kubernetes 的演进逻辑
- **本章关键词**：Namespace / Cgroups, Image Layers, Container Runtime, Registry, Compose
- **本章实验目标**：完成基础容器运行、镜像构建、镜像推送，为后续私有镜像仓库与微服务部署做准备。

### 2. Kubernetes 基础架构
- **本章定位**：建立 Kubernetes 平台认知，并用 kubeadm 搭起生产风格实验集群。
- **核心内容**：
  - Kubernetes 控制平面与工作节点架构
  - API Server、Scheduler、Controller Manager、etcd 的角色
  - kubeadm 集群初始化与节点加入
  - kubectl 声明式资源管理
  - Pod、Deployment、Service 基础对象
  - kubeconfig、证书、基础运维与常见排错
- **本章关键词**：Control Plane, Worker Node, kubeadm, Declarative API, etcd, Cluster Bootstrap
- **本章实验目标**：完成 3 控制平面 + Worker 的实验集群初始化，能够用 kubectl 管理基础工作负载，并理解 API Server VIP 的意义。

### 3. 云原生网络与服务互联
- **本章定位**：这是整门课的核心卖点之一，重点讲现代 Kubernetes 网络，而不是停留在“Pod 能通”。
- **核心内容**：
  - Kubernetes 网络模型
  - Pod IP、Service、CoreDNS、Service Discovery
  - CNI 的职责与工作机制
  - Cilium 与 eBPF 数据平面
  - Hubble 网络可视化与流量观测
  - Network Policy 与微隔离基础
- **本章关键词**：Kubernetes Network Model, CNI, Cilium + eBPF, Service Discovery, Hubble, Network Policy
- **本章实验目标**：部署 Cilium，验证 Pod 与 Service 通信，使用 Hubble 观察服务调用关系，并用策略实现基础隔离。

### 4. 北向入口与负载均衡
- **本章定位**：把集群内服务真正“发布出去”，形成北向访问入口。
- **核心内容**：
  - ClusterIP、NodePort、LoadBalancer 暴露模型
  - 裸 VM 场景中的负载均衡问题
  - MetalLB 的作用与地址池设计
  - Ingress 的基本模型
  - Gateway API 的现代入口架构
  - 北向 L4 / L7 流量进入微服务系统的路径
- **本章关键词**：Service Exposure, MetalLB, LoadBalancer VIP, Ingress, Gateway API, L4 / L7 Traffic
- **本章实验目标**：通过 MetalLB 为集群提供 VIP，通过 Gateway API 完成前端服务北向暴露，打通业务访问路径。

### 5. 存储与有状态服务
- **本章定位**：让学生理解 Kubernetes 不只是无状态编排平台，而是具备持久化与有状态服务承载能力。
- **核心内容**：
  - PV / PVC / StorageClass 的工作模型
  - 动态卷分配机制
  - Longhorn 分布式存储架构
  - 持久卷挂载与生命周期
  - Stateful Workload 的落地方式
  - 数据持久化、卷故障与恢复基础
- **本章关键词**：PV / PVC, StorageClass, Dynamic Provisioning, Longhorn, Stateful Workload, Persistent Data
- **本章实验目标**：部署 Longhorn，为监控组件或数据库提供持久卷，验证 Pod 重建后数据仍然保留。

### 6. 微服务安全与零信任
- **本章定位**：这是整门课第二个核心卖点。重点不是“装一个安全组件”，而是形成从网络到应用的安全闭环。
- **核心内容**：
  - 云原生安全分层：平台、网络、应用、身份
  - Network Policy 的南北/东西向基础隔离
  - TLS 与北向流量加密
  - JWT 身份认证与应用访问入口保护
  - Istio Ambient Mesh 的基本模型
  - L4 / L7 授权控制与零信任访问
- **本章关键词**：Zero Trust, Micro-Segmentation, TLS / mTLS, JWT, Istio Ambient Mesh, Authorization Policy
- **本章实验目标**：为北向入口配置 TLS，验证 JWT 认证，建立服务间受控访问模型，形成零信任微服务安全基础。

### 7. 微服务发布、自动化与 GitOps
- **本章定位**：这是整门课的“正式上线章”。前面搭的是平台与能力，这一章完成应用自动化交付。
- **核心内容**：
  - 微服务架构拆分与资源组织
  - Deployment / Service / ConfigMap / Secret 的工程化使用
  - Helm Chart 与参数化部署
  - Git 作为配置与发布事实源
  - GitOps 的工作模式
  - Argo CD 持续交付与自动同步
  - 发布、版本变更与回滚基础
- **本章关键词**：Helm, Config as Code, GitOps, Argo CD, Declarative Delivery, Auto Sync / Rollback
- **本章实验目标**：将微服务系统打包为 Helm 部署清单，通过 GitOps 和 Argo CD 将服务自动化上线到 Kubernetes。

### 8. 监控、可观测性与分布式 Trace
- **本章定位**：这是一门现代课必须有的收尾章节。不是只看 Pod 是否 Running，而是建立指标、调用链和网络观测的完整闭环。
- **核心内容**：
  - 监控与可观测性的差异
  - Prometheus 指标采集体系
  - Grafana 仪表盘与可视化展示
  - OpenTelemetry 标准化采集思路
  - Tempo 分布式 Trace
  - 应用指标、调用链、网络流量的联合观测
  - 基于 Metrics + Trace 的故障定位思路
- **本章关键词**：Prometheus Metrics, Grafana Dashboard, OpenTelemetry, Tempo, Distributed Trace, Full-Stack Observability
- **本章实验目标**：完成微服务系统的指标采集、调用链跟踪和统一展示，实现“能看见、能分析、能定位”的全链路可观测性闭环。

---

## 三、 实验环境拓扑规划

**基础环境**：Ubuntu Server 24.04.4 LTS + Windows Server 2019
**网络网关**：10.1.1.254

### 节点角色与 IP 分配

| 节点主机名 | IP 地址 | 角色说明 |
| :--- | :--- | :--- |
| **lb01** | 10.1.1.11 | API Server 负载均衡主节点 (HAProxy + Keepalived) |
| **lb02** | 10.1.1.12 | API Server 负载均衡备节点 (HAProxy + Keepalived) |
| **cp01** | 10.1.1.101 | Kubernetes 控制平面节点 1 (etcd + apiserver) |
| **cp02** | 10.1.1.102 | Kubernetes 控制平面节点 2 (etcd + apiserver) |
| **cp03** | 10.1.1.103 | Kubernetes 控制平面节点 3 (etcd + apiserver) |
| **wk-app01** | 10.1.1.1 | 工作节点 - 业务应用承载，提供 Longhorn 存储 |
| **wk-app02** | 10.1.1.2 | 工作节点 - 业务应用承载，提供 Longhorn 存储 |
| **wk-edge01** | 10.1.1.3 | 工作节点 - 边缘节点 (Gateway API / Ingress 入口) |
| **wk-obs01** | 10.1.1.4 | 工作节点 - 可观测性节点 (Prometheus/Grafana/Tempo) |
| **ops** | 10.1.1.201 | 运维/跳板机 (Ansible, kubectl, Helm 客户端) |
| **git** | 10.1.1.202 | Git 仓库服务器 (Gitea/GitLab) |
| **harbor** | 10.1.1.203 | 私有镜像仓库服务器 |
| **win2019** | 10.1.1.100 | 外部测试客户端 (浏览器访问测试) |

---

## 四、 开工前补充并冻结的关键设计细节

这一部分用于在正式实施前锁定关键参数，避免后续返工。

### 1. VIP 与地址池规划

- Kubernetes API Server VIP 建议固定为 `10.1.1.10`
- Keepalived 漂移 VIP 用于 `lb01` 和 `lb02` 对外提供高可用 API 入口
- MetalLB 地址池建议预留为 `10.1.1.50-10.1.1.79`
- 以上地址段应从现有网络中排除，避免被 DHCP 或人工分配占用

### 2. 访问域名规划

建议统一采用实验域名，便于证书、Ingress、Gateway API 与后续演示。

| 域名 | 指向目标 | 用途 |
| :--- | :--- | :--- |
| `api.k8s.lab` | `10.1.1.10` | Kubernetes API Server 高可用入口 |
| `harbor.k8s.lab` | `10.1.1.203` | Harbor 私有镜像仓库 |
| `git.k8s.lab` | `10.1.1.202` | Git 服务入口 |
| `grafana.k8s.lab` | MetalLB 分配的 VIP | Grafana 可视化入口 |
| `argocd.k8s.lab` | MetalLB 分配的 VIP | Argo CD 控制台入口 |
| `app.k8s.lab` | MetalLB 分配的 VIP | 微服务北向访问入口 |

### 3. Kubernetes 网络参数建议

- Service CIDR 建议使用 `10.96.0.0/12`
- Pod CIDR 建议使用 `10.244.0.0/16`
- kube-proxy 建议在课程中作为“传统实现”讲解，在实际集群中优先采用 Cilium eBPF 数据平面能力
- CoreDNS 使用集群默认部署方式，后续通过 Service Discovery 章节解释解析链路

### 4. 节点职责与调度规划

为避免课程后期组件互相抢占资源，建议提前约定节点标签与调度职责。

| 节点 | 建议标签/用途 |
| :--- | :--- |
| `wk-edge01` | `node-role=edge`，承载 Gateway API / Ingress 入口组件 |
| `wk-obs01` | `node-role=observability`，承载 Prometheus、Grafana、Tempo |
| `wk-app01` | `node-role=app`，承载业务应用与 Longhorn 副本 |
| `wk-app02` | `node-role=app`，承载业务应用与 Longhorn 副本 |

建议在课程中演示：

- Label、Selector、Node Affinity 的基础使用
- 对入口组件和观测组件进行定向调度
- 必要时对 `wk-edge01`、`wk-obs01` 增加 Taint，体现生产环境隔离思路

### 5. Longhorn 前置条件

- `wk-app01` 和 `wk-app02` 建议至少各准备一块独立数据盘，不直接复用系统盘
- 所有参与 Longhorn 的节点需提前安装 `open-iscsi`
- 若课程需要更接近生产实践，可将 `wk-obs01` 也纳入 Longhorn 存储节点
- 如果仅用于教学演示，最小可先使用 2 个存储节点，但需要明确说明这不是严格生产高可用推荐值

### 6. 零信任与证书规划

- 北向 TLS 证书建议统一采用自签 CA 或实验室内部 CA
- JWT 认证建议通过单独的认证服务或网关策略实现
- Istio Ambient Mesh 建议作为“增强模块”引入，先完成基础网络隔离与入口认证，再叠加服务间授权控制
- 课程实施顺序应保持为：Network Policy -> TLS -> JWT -> Ambient Mesh -> Authorization Policy

### 7. GitOps 与制品流转路径

建议从一开始就固定“代码到上线”的链路，后续每章都围绕同一条主线展开：

1. 开发代码构建镜像
2. 镜像推送到 `Harbor`
3. 部署清单或 Helm Chart 存入 `Git`
4. `Argo CD` 从 Git 拉取声明式配置
5. 集群自动同步并发布到 Kubernetes

### 8. 可观测性分层目标

课程最后一章不只讲组件安装，而是要形成三层观测闭环：

- Metrics：Prometheus + Grafana
- Trace：OpenTelemetry + Tempo
- Network Flow：Cilium + Hubble

最终要让学生能够从“接口报错”一路追到：

- 网关入口是否正常
- 服务调用链是否异常
- 网络策略是否阻断
- 后端依赖是否超时

### 9. 建议的实施顺序

为了保证每一步都能被验证，建议按如下顺序推进：

1. 所有 Ubuntu 节点基础初始化
2. `lb01`、`lb02` 部署 HAProxy + Keepalived
3. 使用 `kubeadm` 部署 3 控制平面集群
4. 安装 Cilium 与 Hubble
5. 安装 MetalLB 与 Gateway API
6. 安装 Longhorn
7. 部署 Harbor、Git、基础微服务应用
8. 部署 TLS、JWT 与零信任策略
9. 安装 Argo CD，完成 GitOps 发布
10. 安装 Prometheus、Grafana、Tempo，形成观测闭环

### 10. 当前版本是否可以开工

结论：可以开始。

不过建议把下面这些参数作为第一阶段的“冻结项”：

- API Server VIP：`10.1.1.10`
- MetalLB 地址池：`10.1.1.50-10.1.1.79`
- Service CIDR：`10.96.0.0/12`
- Pod CIDR：`10.244.0.0/16`
- 实验域名后缀：`k8s.lab`
- `wk-edge01`、`wk-obs01`、`wk-app01`、`wk-app02` 的节点职责划分

只要上述信息确认，本设计就可以正式进入实施阶段。
