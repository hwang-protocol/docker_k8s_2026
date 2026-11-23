# AWS 实验记录（总览）

这里按章记录 `docker_k8s_2026` 课程在 AWS EC2 上的实验：做了什么、结果如何、和课程原版有什么不同。每章一个文件，做完一章就更新对应的文件和下面的进度表。

## 进度表

### Docker 部分（`docker/`）

| 章 | 内容 | 状态 | 记录 |
|---|---|---|---|
| 1 | 简介：服务与容器、可迁移性 | ✅ 完成 | [docker-1-intro.md](docker-1-intro.md) |
| 2 | 安装 Docker | ✅ 完成 | [docker-2-install.md](docker-2-install.md) |
| 3 | 常用命令 | ✅ 完成 | [docker-3-cmd.md](docker-3-cmd.md) |
| 4 | 数据持久化 | ✅ 完成 | [docker-4-data.md](docker-4-data.md) |
| 5 | Dockerfile | ✅ 完成 | [docker-5-dockerfile.md](docker-5-dockerfile.md) |
| 6 | Compose（基础 + TLS/ELK） | ✅ 完成 | [docker-6-compose.md](docker-6-compose.md) |
| 7 | Podman、nerdctl | ✅ 完成 | [docker-7-other.md](docker-7-other.md) |

### Kubernetes 部分（`k8s/`）

| 章 | 内容 | 状态 | AWS 上要改的地方 |
|---|---|---|---|
| 01 | kubeadm 集群架构 | ⬜ 未开始 | Keepalived VIP 不能用（VPC 不支持 VRRP），改用 NLB 或单 HAProxy |
| 02 | 云原生网络（Cilium/Hubble） | ⬜ 未开始 | Cilium 用 VXLAN 隧道，或关闭源/目标检查 |
| 03 | 北向入口（MetalLB/Gateway API） | ⬜ 未开始 | MetalLB L2 地址需改成网卡辅助 IP，或改用 NodePort + NLB |
| 04 | 存储（Longhorn） | ⬜ 未开始 | 每个 worker 挂一块 EBS 数据盘 |
| 05 | 安全与零信任 | ⬜ 未开始 | 预计可照做 |
| 06 | GitOps（Argo CD） | ⬜ 未开始 | 预计可照做 |
| 07 | 可观测性与链路追踪 | ⬜ 未开始 | 预计可照做 |

## AWS 环境

| 项 | 值 |
|---|---|
| 区域 / 可用区 | 东京 ap-northeast-1c |
| Docker 实验机 | `k8s-docker-lab`，i-0f8af3c84d76ecf35，t3.large（2 vCPU / 8 GB），40 GB gp3，CPU 积分 standard（不会额外收突发费） |
| 系统 | Ubuntu 24.04.5 LTS（课程基础环境就是 24.04） |
| 内网 IP | 172.31.13.147（停机再开不会变） |
| SSH | `ssh k8s-docker`（经 `ec2-tokyo` 跳板，配置在 `~/.ssh/config`） |
| 课程目录 | `/docker_k8s_2026`（和课程文档里的路径一致） |
| 资源标签 | 全部打了 `Project=k8s-lab`；安全组 `k8s-lab-sg`，密钥对 `k8s-lab-key` |

和低延迟课程（`flle-*`）的资源完全分开，互不影响。`vpn-tokyo` 是个人代理服务器，不碰。

## 常用操作

```bash
# 停机 / 开机（Git Bash）
MSYS_NO_PATHCONV=1 aws ec2 stop-instances  --region ap-northeast-1 --instance-ids i-0f8af3c84d76ecf35
MSYS_NO_PATHCONV=1 aws ec2 start-instances --region ap-northeast-1 --instance-ids i-0f8af3c84d76ecf35

# 更新课程文件到实验机（用 LF 换行打包，避免 Windows CRLF）
git -c core.autocrlf=false archive --format=tar HEAD docker apps | ssh k8s-docker 'tar -xf - -C /docker_k8s_2026'
```

## 费用

| 资源 | 大约费用 |
|---|---|
| t3.large 运行中 | 约 0.11 美元/小时 |
| 40 GB 硬盘（停机也收） | 约 3.8 美元/月 |

价格是东京区大致数字，以 AWS 账单为准。**不用就停机。**

## 踩过的坑（通用）

1. **课程的镜像加速地址是给国内网络用的**：东京直连 Docker Hub 更快，所以 `daemon.json` 只保留 `data-root`。
2. **脚本通过 `ssh … bash -s` 远程执行时**，`docker exec -i`、`docker compose exec` 会把脚本剩余部分当成自己的输入读走，后面的命令就“消失”了。解决：给这类命令加 `</dev/null`。课堂上手敲命令不会遇到。
3. **`docker compose up --wait`** 遇到一次性服务（如 `cert-init`）正常退出后会一直等，不会返回。用 `docker compose ps -a` 看状态即可。
