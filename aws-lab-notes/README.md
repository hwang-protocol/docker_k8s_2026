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
| 01 | kubeadm 集群架构 | ✅ 完成 | Keepalived 加 EC2 API 钩子挂 VIP；containerd 钉 1.7.12；见 [k8s-01-architecture.md](k8s-01-architecture.md) |
| 02 | 云原生网络（Cilium/Hubble） | ✅ 完成 | 不用改（native routing 靠关闭源/目标检查）；见 [k8s-02-networking.md](k8s-02-networking.md) |
| 03 | 北向入口（MetalLB/Gateway API） | ✅ 完成 | VIP 挂成 wk-edge01 的辅助 IP；见 [k8s-03-north-south.md](k8s-03-north-south.md) |
| 04 | 存储（Longhorn） | ✅ 完成 | `/dev/sdb` → `/dev/nvme1n1`；runc AppArmor 问题；见 [k8s-04-storage.md](k8s-04-storage.md) |
| 05 | 安全与零信任 | ✅ 完成 | 不用改；扩展测试被课程自己的 JWT 策略拦截；见 [k8s-05-security.md](k8s-05-security.md) |
| 06 | GitOps（Argo CD） | ✅ 完成 | 无 AWS 改动；补 Harbor `library` 镜像、标签 v0.2.3、ops 上建 git 基线；见 [k8s-06-gitops.md](k8s-06-gitops.md) |
| 07 | 可观测性与链路追踪 | ✅ 完成 | Longhorn 超额分配调到 200%；Jaeger 2.23 用 v3 API 验收；见 [k8s-07-observability.md](k8s-07-observability.md) |

**K8s 部分的总结和 review 清单：** [k8s-summary.md](k8s-summary.md)

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

## K8s 集群环境（第 1–7 章）

| 项 | 值 |
|---|---|
| VPC | `k8s-course-vpc` 10.1.1.0/24（和课程同网段），所有资源打 `Project=k8s-course` |
| 节点 | 12 台：ops .201、harbor .203、git .202、lb01/02 .11/.12、cp01–03 .101–.103、wk-app01/02、wk-edge01、wk-obs01 **.21–.24** |
| API VIP | 10.1.1.10（`api.qytk8s.com`） |
| DNS | Route 53 私有域 `qytk8s.com`，搜索域已配，短主机名可用 |
| SSH | `ssh k8s-ops`（root，经 `ec2-tokyo` 跳板到 ops 的弹性 IP）；在 ops 上 `ssh root@cp01` 等，和课程一样 |
| 建环境 | [k8s-infra/create.sh](k8s-infra/create.sh)（可重复执行） |
| 开机 / 停机 | `bash aws-lab-notes/k8s-infra/start-stop.sh start|stop|status` |

## 费用

| 资源 | 大约费用 |
|---|---|
| Docker 实验机 t3.large 运行中 | 约 0.11 美元/小时 |
| Docker 实验机 40 GB 硬盘（停机也收） | 约 3.8 美元/月 |
| K8s 集群 12 台运行中 | 约 0.85 美元/小时 |
| K8s 集群硬盘约 450 GB + ops 弹性 IP（停机也收） | 约 45 美元/月 |

价格是东京区大致数字，以 AWS 账单为准。**不用就停机。**

## 踩过的坑（通用）

1. **课程的镜像加速地址是给国内网络用的**：东京直连 Docker Hub 更快，所以 `daemon.json` 只保留 `data-root`。
2. **脚本通过 `ssh … bash -s` 远程执行时**，`docker exec -i`、`docker compose exec` 会把脚本剩余部分当成自己的输入读走，后面的命令就“消失”了。解决：给这类命令加 `</dev/null`。课堂上手敲命令不会遇到。
3. **`docker compose up --wait`** 遇到一次性服务（如 `cert-init`）正常退出后会一直等，不会返回。用 `docker compose ps -a` 看状态即可。
