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
- **本章实验目标**：通过 MetalLB 为集群提供 VIP，通过 Gateway API 完成前端服务的域名化、HTTPS 化北向暴露，打通业务访问路径。

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
| `api.qytk8s.com` | `10.1.1.10` | Kubernetes API Server 高可用入口 |
| `harbor.qytk8s.com` | `10.1.1.203` | Harbor 私有镜像仓库 |
| `git.qytk8s.com` | `10.1.1.202` | Git 服务入口 |
| `grafana.qytk8s.com` | MetalLB 分配的 VIP | Grafana 可视化入口 |
| `argocd.qytk8s.com` | MetalLB 分配的 VIP | Argo CD 控制台入口 |
| `app.qytk8s.com` | MetalLB 分配的 VIP | 微服务北向访问入口 |

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
- 实验域名后缀：`qytk8s.com`
- `wk-edge01`、`wk-obs01`、`wk-app01`、`wk-app02` 的节点职责划分

只要上述信息确认，本设计就可以正式进入实施阶段。

---

## 五、 实施记录

### 阶段 01：`ops` 到各 Linux 节点 SSH 免密登录

#### 1. 本阶段目标

为了便于后续统一执行初始化脚本、批量下发配置、安装 Kubernetes 组件，先将 `ops(10.1.1.201)` 作为运维跳板机，为其他 Linux 节点配置 `root` 用户 SSH 公钥免密登录。

#### 2. 执行范围

本次已配置以下目标节点：

- `lb01` `10.1.1.11`
- `lb02` `10.1.1.12`
- `cp01` `10.1.1.101`
- `cp02` `10.1.1.102`
- `cp03` `10.1.1.103`
- `wk-app01` `10.1.1.1`
- `wk-app02` `10.1.1.2`
- `wk-edge01` `10.1.1.3`
- `wk-obs01` `10.1.1.4`
- `git` `10.1.1.202`
- `harbor` `10.1.1.203`

不包含：

- `win2019` `10.1.1.100`
- `10.1.1.254`

#### 3. 实施动作

在 `ops` 节点执行了以下逻辑：

1. 检查 `/root/.ssh` 目录
2. 若不存在 `ed25519` 密钥对，则自动生成 `/root/.ssh/id_ed25519`
3. 读取 `ops` 的公钥
4. 将公钥追加到各目标节点的 `/root/.ssh/authorized_keys`
5. 修正 `.ssh` 和 `authorized_keys` 权限
6. 从 `ops` 节点反向验证到各节点是否可免密执行 `ssh root@<ip> hostname`

#### 4. 验证结果

验证结果：全部成功。

| 源节点 | 目标节点 | IP | 结果 |
| :--- | :--- | :--- | :--- |
| `ops` | `lb01` | `10.1.1.11` | 成功 |
| `ops` | `lb02` | `10.1.1.12` | 成功 |
| `ops` | `cp01` | `10.1.1.101` | 成功 |
| `ops` | `cp02` | `10.1.1.102` | 成功 |
| `ops` | `cp03` | `10.1.1.103` | 成功 |
| `ops` | `wk-app01` | `10.1.1.1` | 成功 |
| `ops` | `wk-app02` | `10.1.1.2` | 成功 |
| `ops` | `wk-edge01` | `10.1.1.3` | 成功 |
| `ops` | `wk-obs01` | `10.1.1.4` | 成功 |
| `ops` | `git` | `10.1.1.202` | 成功 |
| `ops` | `harbor` | `10.1.1.203` | 成功 |

#### 5. 当前结论

后续可以直接基于 `ops` 节点执行：

- 批量系统初始化
- 批量安装容器运行时
- 批量安装 `kubeadm`、`kubelet`、`kubectl`
- 批量分发配置文件
- 执行 Ansible 或 Shell 自动化运维脚本

### 阶段 02：统一切换实验环境 DNS

#### 1. 本阶段目标

将所有 Ubuntu 实验节点的上游 DNS 统一指向 `win2019(10.1.1.100)`，并统一设置搜索域为 `qytk8s.com`，为后续的实验域名解析、Harbor、Git、API VIP、应用入口与证书规划做准备。

#### 2. 执行范围

本次已处理以下节点：

- `lb01` `10.1.1.11`
- `lb02` `10.1.1.12`
- `cp01` `10.1.1.101`
- `cp02` `10.1.1.102`
- `cp03` `10.1.1.103`
- `wk-app01` `10.1.1.1`
- `wk-app02` `10.1.1.2`
- `wk-edge01` `10.1.1.3`
- `wk-obs01` `10.1.1.4`
- `ops` `10.1.1.201`
- `git` `10.1.1.202`
- `harbor` `10.1.1.203`

不包含：

- `win2019` `10.1.1.100`
- `10.1.1.254`

#### 3. 配置方式

确认所有 Ubuntu 节点均使用：

- `netplan`
- 配置文件：`/etc/netplan/ens160.yaml`

统一将 `nameservers` 配置为：

```yaml
nameservers:
  addresses: [10.1.1.100]
  search: [qytk8s.com]
```

#### 4. 自动化脚本

已在当前目录生成脚本：

- `configure_lab_dns.py`

该脚本的作用：

1. 使用 `root` SSH 登录目标节点
2. 备份原始 `netplan` 文件
3. 替换 `nameservers` 配置
4. 执行 `netplan generate`
5. 执行 `netplan apply`
6. 使用 `resolvectl` 验证 DNS Server 与 Search Domain

#### 5. 验证结果

验证结果：全部成功。

| 节点 | IP | DNS Server | Search Domain | 结果 |
| :--- | :--- | :--- | :--- | :--- |
| `lb01` | `10.1.1.11` | `10.1.1.100` | `qytk8s.com` | 成功 |
| `lb02` | `10.1.1.12` | `10.1.1.100` | `qytk8s.com` | 成功 |
| `cp01` | `10.1.1.101` | `10.1.1.100` | `qytk8s.com` | 成功 |
| `cp02` | `10.1.1.102` | `10.1.1.100` | `qytk8s.com` | 成功 |
| `cp03` | `10.1.1.103` | `10.1.1.100` | `qytk8s.com` | 成功 |
| `wk-app01` | `10.1.1.1` | `10.1.1.100` | `qytk8s.com` | 成功 |
| `wk-app02` | `10.1.1.2` | `10.1.1.100` | `qytk8s.com` | 成功 |
| `wk-edge01` | `10.1.1.3` | `10.1.1.100` | `qytk8s.com` | 成功 |
| `wk-obs01` | `10.1.1.4` | `10.1.1.100` | `qytk8s.com` | 成功 |
| `ops` | `10.1.1.201` | `10.1.1.100` | `qytk8s.com` | 成功 |
| `git` | `10.1.1.202` | `10.1.1.100` | `qytk8s.com` | 成功 |
| `harbor` | `10.1.1.203` | `10.1.1.100` | `qytk8s.com` | 成功 |

#### 6. 当前结论

实验环境已经具备统一 DNS 基础。

后续只要在 `win2019 DNS` 中继续补齐对应记录，即可支持：

- `api.qytk8s.com`
- `harbor.qytk8s.com`
- `git.qytk8s.com`
- `app.qytk8s.com`
- `grafana.qytk8s.com`
- `argocd.qytk8s.com`

---

## 六、 第一章实施记录：Kubernetes 基础架构

### 阶段 01：版本冻结

#### 1. 最终结论

本课程后续所有 Kubernetes 相关内容，统一冻结为：

- Kubernetes：`v1.33.9`

#### 2. 选择依据

- `v1.31.x` 已经停止维护，不适合作为新课程长期基线
- `v1.34.x` 虽然较新，但对后续 `Longhorn` 章节的公开兼容证据不够强
- `v1.33.9` 在课程目标涉及的关键组件上更平衡：
  - `Cilium`
  - `Istio Ambient Mesh`
  - `Argo CD`
  - `Longhorn`

#### 3. 执行要求

从第一章开始，到后续章节结束：

- 所有脚本
- 所有文档
- 所有镜像清单
- 所有 `kubeadm` 配置

全部统一按 `v1.33.9` 编写，不再变动。

### 阶段 02：第一章第 1 步 - 所有节点系统初始化

#### 1. 本阶段目标

在正式部署 Harbor、containerd 和 kubeadm 之前，先将所有 Ubuntu 节点初始化为适合 Kubernetes 的基础状态。

本阶段完成后需要满足：

- swap 已关闭
- `overlay` 与 `br_netfilter` 已加载
- `net.ipv4.ip_forward=1`
- 时区统一为 `Asia/Shanghai`
- SSH 登录关闭 `UseDNS`
- 课堂环境不再受 `unattended-upgrades` 抢占 `apt/dpkg` 锁影响
- 基础工具已安装
- `open-iscsi` 与 `iscsid` 已准备完成

#### 2. 处理节点

本阶段已处理：

- `lb01`
- `lb02`
- `cp01`
- `cp02`
- `cp03`
- `wk-app01`
- `wk-app02`
- `wk-edge01`
- `wk-obs01`
- `harbor`
- `git`

#### 3. 交付物

本阶段已生成：

- 课件总入口：`k8s/01-k8s-architecture/docs/01_chapter_guide.md`
- 第 1 步课件：`k8s/01-k8s-architecture/docs/02_prepare_os.md`
- 第 1 步小脚本：`k8s/01-k8s-architecture/scripts/01_prepare_os_remote.sh`

#### 4. 实施说明

本阶段采用“文档主导 + 小脚本辅助”的方式进行：

- 学员在 `ops` 节点阅读 `02_prepare_os.md`
- 按文档说明执行 `01_prepare_os_remote.sh`
- 该脚本通过 SSH 使用主机名批量下发系统初始化命令

脚本实际处理的关键动作包括：

1. 关闭 swap
2. 配置内核模块
3. 配置 sysctl
4. 设置时区
5. 关闭 `UseDNS`
6. 关闭 `UFW`
7. 关闭自动更新与 `apt` 定时任务
8. 安装基础工具
9. 启动 `iscsid`

#### 5. 过程中的关键修正

在首次执行时发现：

- `Ubuntu 24.04` 默认的 `unattended-upgrades` 会占用 `apt/dpkg` 锁

因此已将脚本增强为：

- 先关闭 `unattended-upgrades.service`
- 关闭 `apt-daily.timer` 和 `apt-daily-upgrade.timer`
- 等待 `apt/dpkg` 锁释放后再继续安装
- 对 `apt-get update` 与 `apt-get install` 增加锁等待与重试
- 如果锁等待超时，主动清理 `unattended-upgrades` 残留进程
- 支持只传入单个主机名进行补刷，例如只补刷 `wk-app02`

这样更适合课堂环境和快照恢复后的重复执行。

#### 6. 验证结果

批量脚本第二次执行后已完整成功结束。

并对以下节点进行了抽查验证：

- `cp01`
- `wk-app01`

抽查项包括：

- `swapon --show`
- `lsmod | grep br_netfilter`
- `lsmod | grep overlay`
- `sysctl net.ipv4.ip_forward`
- `timedatectl`
- `systemctl is-enabled unattended-upgrades.service`
- `systemctl is-enabled apt-daily.timer`
- `resolvectl dns ens160`
- `systemctl is-active iscsid`

抽查结果：

- swap 关闭成功
- `br_netfilter` 与 `overlay` 已加载
- `net.ipv4.ip_forward = 1`
- 时区为 `Asia/Shanghai`
- 自动更新服务与定时任务已禁用
- DNS 仍为 `10.1.1.100`
- `iscsid` 为 `active`

#### 7. 当前结论

第一章第 1 步已经完成，可以进入下一步：

- Harbor 部署

### 阶段 03：第一章第 2 步 - 部署 Harbor 私有镜像仓库

#### 1. 本阶段目标

在 `harbor` 节点部署 Harbor 私有镜像仓库，为后续 Kubernetes 核心镜像和课程业务镜像提供本地仓库存储。

本阶段完成后需要满足：

- `harbor.qytk8s.com` 可访问
- Harbor 使用 HTTPS
- Harbor 管理员账号可登录
- Harbor 健康状态为 `healthy`

#### 2. 固定参数

本阶段已固定以下参数：

- Harbor 域名：`harbor.qytk8s.com`
- Harbor 节点：`harbor`
- Harbor 版本：`v2.13.0`
- Harbor 管理员账号：`admin`
- Harbor 管理员密码：`Harbor12345`

#### 3. 交付物

本阶段已生成：

- 第 2 步课件：`k8s/01-k8s-architecture/docs/03_harbor.md`
- 第 2 步小脚本：`k8s/01-k8s-architecture/scripts/02_install_harbor_remote.sh`

#### 4. 实施说明

本阶段采用“ops 本机生成证书 + 远程部署 Harbor”的方式进行：

1. 在 `ops` 上生成 Harbor 根 CA
2. 在 `ops` 上签发 `harbor.qytk8s.com` 服务端证书
3. 下载 Harbor Offline Installer
4. 将安装包和证书下发到 `harbor` 节点
5. 在 `harbor` 节点安装 `docker.io` 和 `docker-compose-v2`
6. 配置 Harbor HTTPS
7. 执行 Harbor 安装

#### 5. 证书与目录结果

在 `ops` 上已生成 Harbor 证书材料目录：

- `k8s/01-k8s-architecture/pki/harbor`

其中包含：

- Harbor CA 私钥
- Harbor CA 证书
- `harbor.qytk8s.com` 服务端私钥
- `harbor.qytk8s.com` 服务端证书

这些文件后续还会继续用于：

- 分发 Harbor CA 到 Kubernetes 节点
- 配置 `containerd` 信任 Harbor

#### 6. 实施结果

在 `harbor` 节点已成功完成：

- `docker.io` 安装
- `docker-compose-v2` 安装
- Harbor Offline Installer 解压
- Harbor HTTPS 配置
- Harbor 核心组件启动

实际运行容器包括：

- `harbor-core`
- `harbor-db`
- `harbor-jobservice`
- `harbor-log`
- `harbor-portal`
- `nginx`
- `redis`
- `registry`
- `registryctl`
- `trivy-adapter`

#### 7. 验证结果

本阶段已完成以下验证：

1. `docker ps` 检查 Harbor 组件状态
2. `curl -k https://harbor.qytk8s.com/api/v2.0/health`
3. `curl -k -u 'admin:Harbor12345' https://harbor.qytk8s.com/api/v2.0/projects?page=1&page_size=2`
4. 检查 `docker compose version`
5. 检查 `docker --version`

验证结论：

- Harbor 所有核心组件健康
- Harbor 健康接口返回 `status=healthy`
- 管理员账号认证成功
- 默认 `library` 项目存在
- Harbor 已具备承载 Kubernetes 核心镜像的基础能力

#### 8. 当前结论

第一章第 2 步已经完成，可以进入下一步：

- 预热 Kubernetes 基础镜像到 Harbor

### 阶段 04：第一章第 3 步 - 预热 Kubernetes 核心镜像到 Harbor

#### 1. 本阶段目标

将第一章所需的 Kubernetes `v1.33.9` 核心镜像全部推送到本地 Harbor，保证后续 `kubeadm init` 尽量走本地仓库。

#### 2. 固定镜像版本

本阶段已固定并推送的镜像如下：

- `kube-apiserver:v1.33.9`
- `kube-controller-manager:v1.33.9`
- `kube-scheduler:v1.33.9`
- `kube-proxy:v1.33.9`
- `pause:3.10`
- `etcd:3.5.24-0`
- `coredns:v1.12.0`

目标仓库统一为：

- `harbor.qytk8s.com/k8s`

#### 3. 交付物

本阶段已生成：

- 第 3 步课件：`k8s/01-k8s-architecture/docs/04_push_k8s_images.md`
- 第 3 步小脚本：`k8s/01-k8s-architecture/scripts/03_push_k8s_images_remote.sh`

#### 4. 实施说明

本阶段脚本完成的动作：

1. 通过 Harbor API 创建 `k8s` 项目
2. 在 `harbor` 节点执行 `docker login`
3. 从 `registry.k8s.io` 拉取上游镜像
4. 按课程预定目标路径重新打标签
5. 推送到 `harbor.qytk8s.com/k8s`

#### 5. 验证结果

已完成以下验证：

1. Harbor API 列出 `k8s` 项目仓库
2. `harbor` 节点本地 `docker images` 检查目标镜像
3. Harbor 项目元数据检查

实际已确认存在的仓库包括：

- `k8s/kube-apiserver`
- `k8s/kube-controller-manager`
- `k8s/kube-scheduler`
- `k8s/kube-proxy`
- `k8s/pause`
- `k8s/etcd`
- `k8s/coredns`

并且已确认：

- Harbor 项目 `k8s` 的 `metadata.public=true`

这样后续 `containerd` 和 `kubeadm` 从 Harbor 拉取基础镜像时，不需要额外处理 Harbor 项目访问认证。

#### 6. 当前结论

第一章第 3 步已经完成，可以进入下一步：

- API Server 高可用入口部署

### 阶段 05：第一章第 4 步 - 部署 API Server 高可用入口

#### 1. 本阶段目标

在 `lb01` 和 `lb02` 上部署 `HAProxy + Keepalived`，提供统一的控制平面入口：

- 域名：`api.qytk8s.com`
- VIP：`10.1.1.10`

#### 2. 固定参数

本阶段使用的固定参数如下：

- VIP：`10.1.1.10`
- 接口：`ens160`
- `lb01`：MASTER
- `lb02`：BACKUP
- 后端控制平面节点：
  - `cp01:6443`
  - `cp02:6443`
  - `cp03:6443`

#### 3. 交付物

本阶段已生成：

- 第 4 步课件：`k8s/01-k8s-architecture/docs/05_loadbalancer.md`
- 第 4 步小脚本：`k8s/01-k8s-architecture/scripts/04_setup_haproxy_keepalived_remote.sh`

#### 4. 实施说明

本阶段脚本完成的动作：

1. 在 `lb01` 和 `lb02` 安装 `haproxy`
2. 在 `lb01` 和 `lb02` 安装 `keepalived`
3. 配置 `haproxy.cfg`，监听 `6443`
4. 配置 `keepalived.conf`，提供漂移 VIP
5. 配置 `haproxy` 进程健康检查脚本
6. 启动并设置服务开机自启

#### 5. 验证结果

已完成以下验证：

1. `lb01` 和 `lb02` 的 `haproxy` 服务状态
2. `lb01` 和 `lb02` 的 `keepalived` 服务状态
3. VIP 所在节点检查
4. `api.qytk8s.com:6443` TCP 连通性测试
5. 两台负载均衡器本地 `6443` 监听状态

验证结论：

- `lb01` 的 `haproxy` 为 `active`
- `lb01` 的 `keepalived` 为 `active`
- `lb02` 的 `haproxy` 为 `active`
- `lb02` 的 `keepalived` 为 `active`
- VIP `10.1.1.10` 当前漂移在 `lb01`
- `api.qytk8s.com:6443` 已经可以建立 TCP 连接

#### 6. 当前结论

第一章第 4 步已经完成，可以进入下一步：

- 安装 containerd

### 阶段 06：第一章第 5 步 - 安装 containerd

#### 1. 本阶段目标

在所有 Kubernetes 节点安装并启用 `containerd`，同时明确启用：

- `SystemdCgroup = true`

#### 2. 处理节点

本阶段已处理：

- `cp01`
- `cp02`
- `cp03`
- `wk-app01`
- `wk-app02`
- `wk-edge01`
- `wk-obs01`

#### 3. 交付物

本阶段已生成：

- 第 5 步课件：`k8s/01-k8s-architecture/docs/06_containerd.md`
- 第 5 步小脚本：`k8s/01-k8s-architecture/scripts/05_install_containerd_remote.sh`

#### 4. 验证结果

已对 `cp01` 和 `wk-app01` 进行抽查：

- `containerd --version`
- `systemctl is-active containerd`
- `containerd config dump | grep SystemdCgroup`

验证结论：

- 所有目标节点的 `containerd` 已安装
- `containerd` 版本为 `1.7.28`
- `containerd` 服务为 `active`
- `SystemdCgroup = true`

#### 5. 当前结论

第一章第 5 步已经完成，可以进入下一步：

- 配置 containerd 信任 Harbor

### 阶段 07：第一章第 6 步 - 配置 containerd 信任 Harbor

#### 1. 本阶段目标

让所有 Kubernetes 节点上的 `containerd` 信任 `harbor.qytk8s.com`，并将基础 `pause` 镜像切换到 Harbor。

#### 2. 交付物

本阶段已生成：

- 第 6 步课件：`k8s/01-k8s-architecture/docs/07_containerd_harbor.md`
- 第 6 步小脚本：`k8s/01-k8s-architecture/scripts/06_config_containerd_harbor_remote.sh`

#### 3. 实施说明

本阶段脚本完成：

1. 从 `ops` 分发 Harbor CA 到各节点
2. 创建 `/etc/containerd/certs.d/harbor.qytk8s.com/hosts.toml`
3. 设置 `config_path = "/etc/containerd/certs.d"`
4. 设置 `sandbox_image = "harbor.qytk8s.com/k8s/pause:3.10"`
5. 重启 `containerd`

#### 4. 验证结果

已对 `cp01` 和 `wk-app01` 进行抽查：

- Harbor CA 文件存在
- `hosts.toml` 内容正确
- `sandbox_image` 指向 Harbor
- `containerd` 服务为 `active`

并额外在 `cp01` 上执行了：

- `ctr -n k8s.io images pull --hosts-dir /etc/containerd/certs.d harbor.qytk8s.com/k8s/pause:3.10`

验证结论：

- Harbor 信任链已经真正打通
- 节点已经可以从本地 Harbor 拉取 `pause:3.10`

#### 5. 当前结论

第一章第 6 步已经完成，可以进入下一步：

- 安装 kubeadm、kubelet、kubectl

### 阶段 08：第一章第 7 步 - 安装 kubeadm、kubelet、kubectl

#### 1. 本阶段目标

在 Kubernetes 节点安装固定版本的：

- `kubeadm`
- `kubelet`
- `kubectl`

并在 `ops` 本机安装：

- `kubectl`

#### 2. 版本冻结

本阶段实际锁定的 apt 包版本为：

- `kubeadm=1.33.9-1.1`
- `kubelet=1.33.9-1.1`
- `kubectl=1.33.9-1.1`

#### 3. 交付物

本阶段已生成：

- 第 7 步课件：`k8s/01-k8s-architecture/docs/08_kube_tools.md`
- 第 7 步小脚本：`k8s/01-k8s-architecture/scripts/07_install_kube_tools_remote.sh`

#### 4. 验证结果

已完成：

- `ops` 本机 `kubectl version --client`
- `cp01` 上 `kubeadm version -o short`
- `cp01` 上 `kubectl version --client`
- `wk-app01` 上 `kubeadm version -o short`
- `wk-app01` 上 `kubectl version --client`
- `systemctl is-enabled kubelet`

验证结论：

- `ops` 本机已经具备 `kubectl`
- 所有 Kubernetes 节点已安装 `kubeadm/kubelet/kubectl`
- 版本统一为 `v1.33.9`
- `kubelet` 已设置开机自启

#### 5. 当前结论

第一章第 7 步已经完成，可以进入下一步：

- 初始化第一个控制平面节点

### 阶段 09：第一章第 8 步 - 初始化 cp01

#### 1. 本阶段目标

在 `cp01` 上执行 `kubeadm init`，创建第一台控制平面节点，并将 `ops` 连接到集群管理链路。

#### 2. 固定参数

本阶段实际使用：

- Kubernetes 版本：`v1.33.9`
- 控制平面统一入口：`api.qytk8s.com:6443`
- Service CIDR：`10.96.0.0/12`
- Pod CIDR：`10.244.0.0/16`
- 镜像仓库：`harbor.qytk8s.com/k8s`

#### 3. 交付物

本阶段已生成：

- 第 8 步课件：`k8s/01-k8s-architecture/docs/09_kubeadm_init.md`
- 第 8 步小脚本：`k8s/01-k8s-architecture/scripts/08_kubeadm_init_remote.sh`

#### 4. 实施结果

本阶段完成了：

- `cp01` 执行 `kubeadm init`
- `cp01` 配置 `/root/.kube/config`
- 生成：
  - `/root/kubeadm-join-worker.sh`
  - `/root/kubeadm-join-control-plane.sh`
- 将 `/etc/kubernetes/admin.conf` 拷回 `ops`

#### 5. 验证结果

验证结论：

- `cp01` 已成为第一个控制平面节点
- `ops` 上已经可以直接执行 `kubectl`
- 当前 `cp01` 为 `NotReady`，原因是本章尚未安装 CNI，这一状态符合预期

#### 6. 当前结论

第一章第 8 步已经完成，可以进入下一步：

- 加入额外控制平面节点

### 阶段 10：第一章第 9 步 - 加入 cp02 与 cp03

#### 1. 本阶段目标

将 `cp02` 与 `cp03` 加入当前集群，形成 3 控制平面高可用架构。

#### 2. 交付物

本阶段已生成：

- 第 9 步课件：`k8s/01-k8s-architecture/docs/10_join_control_planes.md`
- 第 9 步小脚本：`k8s/01-k8s-architecture/scripts/09_join_control_planes_remote.sh`

#### 3. 实施结果

脚本从 `cp01` 读取控制平面 join 命令，并成功让：

- `cp02`
- `cp03`

加入控制平面。

#### 4. 验证结果

`kubectl get nodes -o wide` 已确认：

- `cp01`
- `cp02`
- `cp03`

三台控制平面节点均已加入集群。

#### 5. 当前结论

第一章第 9 步已经完成，可以进入下一步：

- 加入 Worker 节点

### 阶段 11：第一章第 10 步 - 加入 Worker 节点并打标签

#### 1. 本阶段目标

将四台 Worker 节点加入集群，并为后续章节提前打好角色标签。

#### 2. 处理节点

本阶段已加入：

- `wk-app01`
- `wk-app02`
- `wk-edge01`
- `wk-obs01`

#### 3. 标签结果

本阶段已写入标签：

- `wk-app01` -> `node-role=app`
- `wk-app02` -> `node-role=app`
- `wk-edge01` -> `node-role=edge`
- `wk-obs01` -> `node-role=observability`

#### 4. 交付物

本阶段已生成：

- 第 10 步课件：`k8s/01-k8s-architecture/docs/11_join_workers.md`
- 第 10 步小脚本：`k8s/01-k8s-architecture/scripts/10_join_workers_remote.sh`

#### 5. 验证结果

`kubectl get nodes --show-labels` 已确认：

- 4 台 Worker 节点全部加入
- 标签全部正确

#### 6. 当前结论

第一章第 10 步已经完成，可以进入本章总验收。

### 阶段 12：第一章总验收

#### 1. 交付物

本阶段已生成：

- 第一章总览：`k8s/01-k8s-architecture/docs/01_chapter_guide.md`
- 第一章总验收文档：`k8s/01-k8s-architecture/docs/12_verify.md`

#### 2. 验证项

本章已完成以下总体验证：

1. `kubectl get nodes -o wide`
2. `kubectl get nodes --show-labels`
3. `kubectl get pods -A -o wide`
4. `curl -k https://harbor.qytk8s.com/api/v2.0/health`
5. `nc -vz api.qytk8s.com 6443`
6. 在 `cp01` 上通过 `crictl exec ... etcdctl member list` 查看 etcd 成员

#### 3. 最终验收结论

当前状态如下：

- Harbor 正常，健康状态为 `healthy`
- `api.qytk8s.com:6443` 可以建立 TCP 连接
- 3 控制平面节点全部加入
- 4 Worker 节点全部加入
- etcd 已形成 3 成员集群
- 节点标签已提前完成
- 当前所有节点为 `NotReady`

这里的 `NotReady` 属于**预期现象**，原因是：

- 本章尚未安装 CNI
- `coredns` 处于 `Pending`
- 此处的 `coredns` 为集群内 DNS 组件 `CoreDNS`
- `CoreDNS Pod Pending` 的直接原因是 Pod 网络尚未建立
- 该现象不属于外部 DNS 解析问题，与 `win2019` 无关

结合本次 `kubectl get pods -A -o wide` 的实际结果，可以进一步确认：

- `etcd-cp01`、`etcd-cp02`、`etcd-cp03` 均为 `Running`
- `kube-apiserver`、`kube-controller-manager`、`kube-scheduler` 在 3 台控制平面节点均为 `Running`
- `kube-proxy` 已在 `cp01`、`cp02`、`cp03`、`wk-app01`、`wk-app02`、`wk-edge01`、`wk-obs01` 全部运行
- 两个 `CoreDNS` Pod 均为 `Pending`
- 两个 `CoreDNS` Pod 当前都没有分配节点与 Pod IP，符合“尚未安装 CNI”的阶段特征

这说明第一章已经完成控制平面、Worker 加入和基础系统组件启动；当前剩余的关键工作是下一章的 CNI 与 Pod 网络建设。

这正好为第二章：

- 云原生网络与服务互联
- Cilium
- eBPF
- Hubble

做铺垫。

#### 4. 第一章最终结论

第一章“Kubernetes 基础架构”已经完成。

### 阶段 13：第一章课件语言清洗

#### 1. 目标

将第一章 `k8s/01-k8s-architecture/docs/` 全部课件正文统一为正式教材口吻。

#### 2. 清洗原则

- 只保留教学目标、理论说明、执行步骤、验证方法、预期结果和结论
- 不写开发过程中的试错、修正、排障、补救和过程性叙事
- 保留必要的条件执行说明，但使用客观、稳定、可复现的表达

#### 3. 本次处理范围

- `docs/01_chapter_guide.md`
- `docs/02_prepare_os.md`
- `docs/03_harbor.md`
- `docs/04_push_k8s_images.md`
- `docs/06_containerd.md`
- `docs/07_containerd_harbor.md`
- `docs/08_kube_tools.md`
- `docs/12_verify.md`

#### 4. 结果

第一章课件正文已统一为“默认一次通过”的课程材料风格，可直接用于课堂讲解与按顺序复制执行。

### 阶段 15：课程文件 HTTP 发布与 YAML 独立管理

#### 1. 目标

在 `ops` 上部署 nginx HTTP 服务，将课程 YAML 文件通过 HTTP 发布，实现：

- YAML 文件从脚本中独立出来，统一放在 `manifests/` 目录
- 脚本和远程节点通过 HTTP 直接获取 YAML
- 后续 `kubectl apply -f` 可直接使用 HTTP 地址

#### 2. nginx 配置

- 监听端口：`9000`
- 根目录：`/docker_k8s_2026/k8s/`
- 配置文件：`/etc/nginx/sites-available/k8s-manifests`
- autoindex 已开启

#### 3. 本次处理的文件

新建：

- `k8s/01-k8s-architecture/manifests/kubeadm-init-cp01.yaml`

改动：

- `scripts/08_kubeadm_init_remote.sh`：不再嵌入 YAML，改为 `cp01` 通过 HTTP 下载
- `docs/01_chapter_guide.md`：新增"课程文件 HTTP 服务"段落，包含安装步骤和验证方法
- `docs/09_kubeadm_init.md`：更新配置文件引用方式
- `.cursor/rules/course_implementation.mdc`：新增"YAML 文件管理与 HTTP 发布"规则

删除：

- `tmp/kubeadm-init-cp01.yaml`（已迁移到 `manifests/`）

#### 4. 结果

nginx 已在 `ops` 上运行，`http://ops:9000/` 可访问所有章节目录和 YAML 文件。第一章 `kubeadm` 初始化配置已通过 HTTP 方式验证可用。

### 阶段 16：第二章启动与主线冻结

#### 1. 目标

正式启动第二章“云原生网络与服务互联”，并在实施前冻结本章的技术边界、版本、主线路径与教学重点，避免后续边做边漂移。

#### 2. 第二章定位

第二章定位为整门课的核心章节之一，重点不是“装一个 CNI”，而是完整体现：

- 东西向网络
- `Cilium + eBPF`
- `kube-proxy replacement`
- `Hubble`
- `L3/L4` 与 `L7` 策略
- `Cilium BGP Control Plane`
- `VyOS Route Reflector`

同时明确与第三章的边界：

- 第二章：东西向流量与 eBPF 高级能力
- 第三章：南北向流量与 7 层入口控制

#### 3. 版本与安装策略冻结

本章统一冻结：

- Kubernetes：`v1.33.9`
- Cilium：`1.19.1`
- Helm Chart：`1.19.1`

安装策略冻结为：

- 以 `Helm` 为主
- 相关镜像尽量全走 `Harbor`
- YAML / values / 演示清单全部放在本章 `manifests/`
- 通过 `http://ops:9000/` 对外发布

#### 4. 网络与 BGP 主线冻结

本章继续沿用第一章地址设计：

- 宿主机网络：`10.1.1.0/24`
- Service CIDR：`10.96.0.0/12`
- Pod CIDR：`10.244.0.0/16`

`Cilium` 主线设计冻结为：

- `native routing`
- `eBPF kube-proxy replacement`
- `Hubble`
- `L7` policy

BGP 主线冻结为：

- `10.1.1.254` 为 `VyOS`
- `VyOS` 作为 `Route Reflector`
- 4 台 Worker 作为 `iBGP client`
- 全部使用私有 ASN：`65001`

#### 5. 风险点预先识别

在开始实施前，已明确识别的关键风险点如下：

- 第一章集群中已存在 `kube-proxy`，第二章必须先删除 `kube-proxy` 并清理 `iptables` 中的 `KUBE-*` 规则，再安装开启 `kubeProxyReplacement=true` 的 Cilium
- `Cilium` 安装时必须显式指定 `k8sServiceHost` 与 `k8sServicePort`
- `L7` policy 依赖 Envoy；在 `Cilium 1.19` 中默认采用 embedded 模式
- 第二章的 BGP 主线必须避免和第三章的南北向入口发布内容混讲

#### 6. 当前实施状态

第二章目录已创建：

- `k8s/02-cloud-native-networking/docs/`
- `k8s/02-cloud-native-networking/scripts/`
- `k8s/02-cloud-native-networking/manifests/`

第二章总览已生成：

- `k8s/02-cloud-native-networking/docs/01_chapter_guide.md`

第二章开始前的运行环境已确认：

- `helm` 已在 `ops` 上安装完成
- `Harbor` 已恢复并验证为 `healthy`

### 阶段 17：第二章第 1 步 - 预热 Cilium 制品

#### 1. 目标

将第二章安装 `Cilium` 所需的关键制品全部前置准备到本地环境中，降低课堂中对公网下载的依赖。

#### 2. 交付物

本阶段已生成：

- 第二章第 1 步课件：`k8s/02-cloud-native-networking/docs/02_prepare_cilium_artifacts.md`
- 第二章第 1 步脚本：`k8s/02-cloud-native-networking/scripts/01_prepare_cilium_artifacts.sh`
- 第二章 Helm values：`k8s/02-cloud-native-networking/manifests/cilium-values.yaml`
- 第二章本地 chart 包：`k8s/02-cloud-native-networking/artifacts/cilium-1.19.1.tgz`

#### 3. 实施说明

本阶段完成了以下动作：

1. 在 `ops` 上安装 `helm`
2. 从官方仓库下载 `cilium-1.19.1.tgz`
3. 在 `ops` 上安装 `cilium CLI`
4. 在 `ops` 上安装 `hubble CLI`
5. 在 Harbor 中创建公共项目 `cilium`
6. 将第二章所需主线镜像与 demo 镜像推送到 `harbor.qytk8s.com/cilium`

#### 4. 已推送镜像

已确认进入 Harbor 的镜像包括：

- `cilium/cilium:v1.19.1`
- `cilium/operator-generic:v1.19.1`
- `cilium/hubble-relay:v1.19.1`
- `cilium/hubble-ui:v0.13.3`
- `cilium/hubble-ui-backend:v0.13.3`
- `cilium/certgen:v0.3.2`
- `cilium/whoami:v1.10.3`
- `cilium/curl:8.12.1`

#### 5. 验证结果

本阶段已验证：

- `helm version --short` 返回正常
- Harbor 健康接口返回 `healthy`
- Harbor API 可列出 `cilium` 项目中的镜像仓库
- `cilium version --client` 返回 `v0.19.1`
- `hubble version` 返回 `v1.18.6`

#### 6. 当前结论

第二章的本地化预热已经完成，可以进入 `Cilium` 正式安装与 `kube-proxy replacement` 切换阶段。

### 阶段 18：第二章第 2-4 步 - Cilium 接管、服务发现与 Hubble

#### 1. 目标

完成第二章前半段主线，让集群从“已初始化但缺失 CNI”的状态，进入“东西向网络完全可用且可观测”的状态。

#### 2. 交付物

本阶段已生成：

- 第二章第 2 步课件：`k8s/02-cloud-native-networking/docs/03_install_cilium.md`
- 第二章第 2 步脚本：`k8s/02-cloud-native-networking/scripts/02_install_cilium.sh`
- 第二章第 3 步课件：`k8s/02-cloud-native-networking/docs/04_service_discovery.md`
- 第二章第 3 步脚本：`k8s/02-cloud-native-networking/scripts/03_apply_service_discovery_demo.sh`
- 第二章第 4 步课件：`k8s/02-cloud-native-networking/docs/05_enable_hubble.md`
- 第二章第 4 步脚本：`k8s/02-cloud-native-networking/scripts/04_enable_hubble.sh`
- 第二章演示清单：`k8s/02-cloud-native-networking/manifests/00_net-demo_namespace.yaml`
- 第二章演示清单：`k8s/02-cloud-native-networking/manifests/10_whoami.yaml`
- 第二章演示清单：`k8s/02-cloud-native-networking/manifests/20_client.yaml`

#### 3. 实施说明

本阶段完成了以下动作：

1. 删除 `kube-proxy`，清理各节点 `KUBE-*` iptables 规则
2. 使用本地 `cilium-1.19.1.tgz` 与本章 `values.yaml` 安装 `Cilium`
3. 启用 `native routing`、`kube-proxy replacement`、`Hubble` 与 `BGP Control Plane`
4. 验证 `CoreDNS`、`Cilium`、`Hubble Relay`、`Hubble UI` 恢复
5. 部署 `net-demo` 命名空间中的 `whoami` 与 `client`
6. 演示 `Service`、短名 DNS、FQDN 访问
7. 通过 `hubble observe` 观察 `client -> whoami` 的东西向流量

#### 4. 验证结果

本阶段已验证：

- 7 台 Kubernetes 节点全部恢复为 `Ready`
- `coredns`、`cilium`、`cilium-operator`、`hubble-relay`、`hubble-ui` 全部正常
- `kube-proxy` 已不再存在
- `client -> whoami` 可通过 `Service` 名称和 `FQDN` 访问
- `hubble observe` 能看到 `net-demo/client` 与 `net-demo/whoami` 的流量

#### 5. 当前结论

第二章前半段已经完成，后续可以继续进入“零信任策略 + BGP 控制面”主线。

### 阶段 19：第二章第 5 步 - L3/L4 与 L7 零信任策略演示

#### 1. 目标

通过 `CiliumNetworkPolicy` 把第二章的安全能力讲透，明确体现“东西向零信任 + eBPF L7 感知”。

#### 2. 交付物

本阶段已生成：

- 第二章第 5 步课件：`k8s/02-cloud-native-networking/docs/06_l7_policy.md`
- 第二章第 5 步脚本：`k8s/02-cloud-native-networking/scripts/05_apply_l7_policy_demo.sh`
- 第二章策略清单：`k8s/02-cloud-native-networking/manifests/21_other.yaml`
- 第二章策略清单：`k8s/02-cloud-native-networking/manifests/30_cnp_l3l4_allow_client.yaml`
- 第二章策略清单：`k8s/02-cloud-native-networking/manifests/31_cnp_l7_allow_get.yaml`

#### 3. 实施说明

本阶段完成了以下动作：

1. 增加 `other` 作为第二个访问方
2. 先验证 `client` 与 `other` 都可访问 `whoami`
3. 应用 `L3/L4` 策略，只允许 `app=client` 访问 `whoami:80`
4. 再切换到 `L7 GET-only` 策略，只允许 `GET /`
5. 将脚本判定方式从“命令成功/失败”修正为“HTTP 状态码”

#### 4. 验证结果

本阶段已验证：

- 基线阶段：`client` 与 `other` 的 `HTTP Code` 均为 `200`
- `L3/L4` 阶段：`client` 为 `200`，`other` 为 `000`
- `L7` 阶段：`client GET /` 为 `200`，`client POST /` 为 `403`
- `kubectl get cnp -n net-demo` 可看到当前策略对象
- `kubectl get cep -n net-demo` 可看到三个端点对象

#### 5. 当前结论

第二章中的“零信任 + L7 HTTP 感知”已经可以稳定演示。

### 阶段 20：第二章第 6-7 步 - VyOS RR、Cilium BGP 与最终验收

#### 1. 目标

把第二章最后一段控制面能力补齐，让 4 台 Worker 通过 `iBGP` 接入 `VyOS Route Reflector`，并补全最终验收文档。

#### 2. 交付物

本阶段已生成：

- 第二章第 6 步课件：`k8s/02-cloud-native-networking/docs/07_bgp_rr.md`
- 第二章第 6 步脚本：`k8s/02-cloud-native-networking/scripts/06_configure_bgp_rr.sh`
- 第二章第 7 步验收文档：`k8s/02-cloud-native-networking/docs/08_verify.md`
- 第二章 BGP 清单：`k8s/02-cloud-native-networking/manifests/40_cilium_bgp_peer_config.yaml`
- 第二章 BGP 清单：`k8s/02-cloud-native-networking/manifests/41_cilium_bgp_advertisement_podcidr.yaml`
- 第二章 BGP 清单：`k8s/02-cloud-native-networking/manifests/42_cilium_bgp_cluster_config_rr.yaml`

#### 3. 实施说明

本阶段完成了以下动作：

1. 将 `VyOS(10.1.1.254)` 配置为 `AS65001` 下的 `Route Reflector`
2. 使用 `peer-group CILIUM` 绑定 4 个 Worker 邻居
3. 通过 `CiliumBGPPeerConfig`、`CiliumBGPAdvertisement`、`CiliumBGPClusterConfig` 配置 `Cilium BGP`
4. 让 4 台 Worker 向 `VyOS` 广告自己的 `PodCIDR`
5. 生成第二章最终验收文档 `08_verify.md`

#### 4. 关键实现细节

本阶段确认了一个重要实现细节：

- 在 `VyOS 1.4.3` 上，直接给单个 neighbor 配置 `route-reflector-client` 会触发配置脚本异常
- 为了保证课程可复现性，最终采用了 `peer-group CILIUM + route-reflector-client` 的稳定写法

#### 5. 验证结果

本阶段已验证：

- 4 台 Worker 与 `10.1.1.254` 的 `BGP Session State` 全部为 `established`
- `kubectl get cbgpnode` 中出现 4 台 Worker
- `VyOS show ip bgp summary` 中可看到 4 个 `Established` 邻居
- `VyOS show ip route bgp` 中已学到：
  - `10.244.0.0/24`
  - `10.244.1.0/24`
  - `10.244.2.0/24`
  - `10.244.5.0/24`

#### 6. 当前结论

第二章主线已经完整闭环：

- `Cilium` 接管了数据平面
- `Hubble` 具备了东西向可观测能力
- `L3/L4` 与 `L7` 策略具备了零信任演示能力
- `VyOS RR + Cilium BGP Control Plane` 具备了控制面演示能力

可以正式进入第三章：南北向流量与入口控制主线。
