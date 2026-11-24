# K8s 部分总结（第 1–7 章，AWS 版）

- **日期：** 2026-11-24（一天内从建环境做到第 7 章）
- **环境：** 东京区 12 台 EC2，独立 VPC `10.1.1.0/24`，建环境脚本 [k8s-infra/create.sh](k8s-infra/create.sh)
- **结论：** 7 章主线全部跑通。课程架构不用改就能搬到 AWS，真正因 AWS 改动的只有 4 处，其余问题都和“从零搭建”或“软件版本变化”有关。

## 每章结果

| 章 | 内容 | 结果 | 一句话 |
|---|---|---|---|
| 1 | kubeadm 高可用集群 | ✅ | 3 控制平面 + 4 Worker，VIP 故障切换实测可用 |
| 2 | Cilium + Hubble | ✅ | native routing + eBPF 替代 kube-proxy，L3/L4/L7 策略都生效 |
| 3 | MetalLB + Gateway API | ✅ | `https://app.qytk8s.com`、`https://hubble.qytk8s.com` 都是 200 |
| 4 | Longhorn + StatefulSet | ✅ | PVC 数据保留、MongoDB 副本集删除恢复都验证了 |
| 5 | Istio Ambient | ✅ | mTLS STRICT、JWT 401/403/200、L7 授权；扩展测试有 3 项被课程自己的策略拦截 |
| 6 | GitOps | ✅ | 改代码 → 自动构建 → Argo CD 发布 v0.3.0；改 Git 扩容到 2 副本 |
| 7 | 可观测性 | ✅ | 业务指标 `up=1`；5 条 trace 跨 4 个服务 |

## 所有改动和问题，按原因分类

### A. 因为 AWS 才需要改（4 处）

| # | 章 | 课程做法 | AWS 上 | 记录 |
|---|---|---|---|---|
| A1 | 1 | Keepalived 用免费 ARP 漂移 VIP | 加 `notify_master` 钩子，调 EC2 API 把 VIP 挂到新主节点网卡 | [第 1 章](k8s-01-architecture.md) |
| A2 | 2 | Pod 流量直接路由 | K8s 节点关闭**源/目标检查**，安全组放行 `10.244.0.0/16` | [第 2 章](k8s-02-networking.md) |
| A3 | 3 | MetalLB 用 ARP 宣告 VIP | VIP 挂成 wk-edge01 网卡的**辅助私有 IP** | [第 3 章](k8s-03-north-south.md) |
| A4 | 1/4 | 网卡 `ens160`、数据盘 `/dev/sdb`、Worker IP `.1–.4`、win2019 DNS | `ens5`、`/dev/nvme1n1`、`.21–.24`、Route 53 私有域 | [第 1 章](k8s-01-architecture.md)、[第 4 章](k8s-04-storage.md) |

### B. 软件版本变了（课程写完后 Ubuntu 源 / Helm Chart 升级；在课程虚拟机上从零重做也会遇到）

| # | 章 | 问题 | 处理 |
|---|---|---|---|
| B1 | 1 | Docker 29 push 到 Harbor 报 `x509`（不认 `/etc/docker/certs.d`） | 课程 CA 加入系统信任（harbor、git 节点） |
| B2 | 1 | containerd 变成 2.2.1，第 6 步改不了配置 | 用 apt pin 钉回课程要求的 1.7.12 |
| B3 | 4 | **B2 的副作用**：Ubuntu 24.04 的 runc AppArmor 配置导致 containerd 1.7 停不掉容器 | 卸载 `/etc/apparmor.d/runc` |
| B4 | 7 | Jaeger 2.23 去掉了 `/api/services`，验收脚本报错 | 用 `/api/v3/...` 手工验收 |

### C. 课程本身的问题（和 AWS 无关）

| # | 章 | 问题 | 建议 |
|---|---|---|---|
| C1 | 1 | Keepalived `weight +10` 不够，**只停 HAProxy 时 VIP 不会漂移**，API 入口断开 | `weight -60` 或把优先级差调到 10 以内 |
| C2 | 5 | 超时、重试、503 中断测试访问的路径被 JWT 授权策略拦截（403） | 在开启 JWT 前做这些测试，或给这些路径加 ALLOW 规则 |
| C3 | 6 | Harbor `library` 里缺 6 个镜像，课程里没有推送步骤 | 补一个推送脚本 |
| C4 | 6 | 构建标签 `v0.1.0`，部署配置要 `v0.2.3` | 统一默认标签 |
| C5 | 6 | 扩容脚本在 Argo CD 发现新提交前就判定完成 | 等 `sync.revision` 变成新提交再判断 |
| C6 | 7 | 检查不存在的 `grafana/provisioning` 目录 | 删掉这段检查，或在目录里放 `.gitkeep` |
| C7 | 7 | Helm 安装没写 `--version` | 固定 Chart 版本 |
| C8 | 7 | controller-manager / scheduler / etcd 只监听 `127.0.0.1`，Prometheus 抓不到（9 个目标异常） | kubeadm 配置里改监听地址 |

C3、C4 的根本原因相同：课程的 harbor 虚拟机“不要恢复快照”，上面残留着以前的镜像，**从零搭建时才会暴露**。

### D. 资源规格比课程小带来的

| # | 章 | 问题 | 处理 |
|---|---|---|---|
| D1 | 7 | 数据盘 30 GB（课程 100 GB），Prometheus 20 Gi 卷分配不了 | Longhorn 超额分配比例 100% → 200% |

### E. 偶发 / 启动顺序

| # | 章 | 问题 | 处理 |
|---|---|---|---|
| E1 | 1 | Harbor 重启后容器 `Exited (128)`（日志容器没先起来） | 加 `harbor-compose.service` 开机自动拉起 |
| E2 | 2 | hubble-relay 启动太早，健康状态卡在 `NOT_SERVING` | 删 Pod 重建 |
| E3 | 6 | ops 上的课程目录不是 git 仓库，发布脚本检测不到改动 | `git init` 并提交基线 |

## Review 时建议重点看

1. **C1（Keepalived）**：课程文档说的“HAProxy 挂了 VIP 会漂移”实测不成立，值得自己再推算一遍优先级。
2. **B2 → B3**：为了贴合课程把 containerd 降级，结果引出另一个问题。生产中一般选择升级配置，而不是降级软件。你可以判断哪种处理更合适。
3. **A2、A3**：这两处体现了云上网络和机房网络最大的区别：云网络不认 ARP、不认“不属于网卡的 IP”。
4. **C3、C4、C7**：可复现性的问题，“在老师的环境里能跑”不等于“从零能跑”。

## 当前状态与费用

- 所有资源在 `Project=k8s-course` 标签下；实验做完后**已停机**（见 README 里的开停机脚本）。
- 停机后仍在收费：约 450 GB 硬盘 + ops 弹性 IP，**约 45 美元/月**。
- 如果短期不再用：可以整套删除，下次用 `create.sh` 重建，再按章节脚本重做（大约 2–3 小时）。

## 下次开机后要注意

- 用 `start-stop.sh start`：先开 harbor、lb、ops、git，再开 K8s 节点。
- Harbor 有开机自启服务（E1），Keepalived 会自动把 VIP 挂回 lb01（A1），MetalLB 的 VIP 辅助 IP 不会丢（A3）。
- 开机后先检查：`ssh k8s-ops kubectl get nodes` 和 `cilium status`。
