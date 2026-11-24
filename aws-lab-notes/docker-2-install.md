# Docker 第 2 章：安装 Docker

- **状态：** ✅ 完成
- **日期：** 2026-11-23
- **课程原文：** [docker/docker_2_install/install_docker_ubuntu.md](../docker/docker_2_install/install_docker_ubuntu.md)

## 做了什么

按课程步骤，从 Docker 官方 apt 源安装 `docker-ce`、`docker-ce-cli`、`containerd.io`、`docker-buildx-plugin`、`docker-compose-plugin`，把数据目录设为 `/data/docker`，并把 `ubuntu` 用户加进 `docker` 组。

## 结果

| 检查项 | 结果 |
|---|---|
| 系统 | Ubuntu 24.04（noble） |
| `docker version` | Client 29.10.0 / Server 29.10.0 |
| `docker compose version` | v5.8.0 |
| `docker info` | DockerRootDir=`/data/docker`，存储驱动 overlayfs，cgroup v2 + systemd |
| `docker run hello-world` | ✅ `Hello from Docker!` |

版本比课程示例（29.3.0 / v5.1.0）新，结构一样。

## 和课程原版的区别

- **没有配置镜像加速地址。** 课程 `daemon.json` 里有十几个国内镜像站，东京的机器直连 Docker Hub 就很快，而且这些镜像站经常失效。实际写入的是：

  ```json
  { "data-root": "/data/docker" }
  ```

## 完整操作记录

下面是实际执行过的命令和真实输出（只删掉了 apt 的进度噪音；账号 ID、跳板机公网 IP 已隐去）。

### 0. 在 AWS 上创建实验机（在本地 Git Bash 执行）

**0.1 先看账号里现有的资源，找最新的 Ubuntu 24.04 镜像**

```bash
export AWS_PAGER="" MSYS_NO_PATHCONV=1    # MSYS_NO_PATHCONV：防止 Git Bash 把 /dev/sda1 这类参数改成 Windows 路径
R=ap-northeast-1

# 现有实例
aws ec2 describe-instances --region $R \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`]|[0].Value,PrivateIpAddress]' \
  --output text

# Canonical（Ubuntu 官方，账号 099720109477）发布的最新 24.04 AMI
aws ec2 describe-images --region $R \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
  --query 'sort_by(Images,&CreationDate)[-1].[ImageId,Name]' \
  --output text
```

```text
i-0159ac80a3eef4443  t3.micro   running  vpn-tokyo        172.31.2.197
i-0872ca5de433c6364  c7i.large  stopped  flle-trader-2    172.31.12.156
i-0c8565112268f92fb  c7i.large  stopped  flle-exchange-1  172.31.10.43
ami-0146cfc901859a3e4   ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20261120
```

**0.2 创建密钥对、安全组，启动实例**

```bash
VPC=vpc-0af0d7d10bc5485e1                 # 默认 VPC
SUBNET=subnet-058f2e15c807d7996           # ap-northeast-1c
AMI=ami-0146cfc901859a3e4

# 复用本机已有的 SSH 公钥
aws ec2 import-key-pair --region $R \
  --key-name k8s-lab-key \
  --public-key-material "fileb://C:/Users/hongz/.ssh/ec2_vpn_key.pub"

# 安全组：只允许从跳板机所在的安全组 SSH 进来
SG=$(aws ec2 create-security-group --region $R \
  --vpc-id $VPC \
  --group-name k8s-lab-sg \
  --description "docker_k8s_2026 course lab" \
  --query GroupId --output text)
echo SG=$SG

aws ec2 authorize-security-group-ingress --region $R \
  --group-id $SG \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=22,ToPort=22,UserIdGroupPairs=[{GroupId=sg-0a5611cce9f200c88,Description=via-ec2-tokyo-jump}]" \
    "IpProtocol=-1,UserIdGroupPairs=[{GroupId=$SG,Description=lab-internal}]"

# t3.large（2 核 8G），40 GB gp3；CpuCredits=standard 表示 CPU 积分用完就降速，不会额外收费
ID=$(aws ec2 run-instances --region $R \
  --image-id $AMI \
  --instance-type t3.large \
  --key-name k8s-lab-key \
  --security-group-ids $SG \
  --subnet-id $SUBNET \
  --credit-specification CpuCredits=standard \
  --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=40,VolumeType=gp3,DeleteOnTermination=true}' \
  --tag-specifications \
    'ResourceType=instance,Tags=[{Key=Name,Value=k8s-docker-lab},{Key=Project,Value=k8s-lab}]' \
    'ResourceType=volume,Tags=[{Key=Project,Value=k8s-lab}]' \
  --query 'Instances[0].InstanceId' --output text)
echo ID=$ID

aws ec2 wait instance-running --region $R --instance-ids $ID
aws ec2 describe-instances --region $R --instance-ids $ID \
  --query 'Reservations[0].Instances[0].[PrivateIpAddress,PublicIpAddress]' --output text
```

```text
k8s-lab-key
SG=sg-0d032fa4cfeff19f9
True
ID=i-0f8af3c84d76ecf35
172.31.13.147   13.231.168.3
```

**0.3 配置 SSH 别名（经跳板机登录）**

```bash
cat >> ~/.ssh/config <<'EOF'

Host k8s-docker
    HostName 172.31.13.147
    User ubuntu
    IdentityFile ~/.ssh/ec2_vpn_key
    ProxyJump ec2-tokyo
    StrictHostKeyChecking accept-new
EOF

ssh k8s-docker '
  hostname
  grep PRETTY /etc/os-release
  nproc
  free -h | sed -n 2p
  df -h / | tail -1
'
```

```text
ip-172-31-13-147
PRETTY_NAME="Ubuntu 24.04.5 LTS"
2
Mem:           7.6Gi       515Mi       7.1Gi       2.7Mi       324Mi       7.1Gi
/dev/root        38G  2.0G   36G   6% /
```

**0.4 把课程文件上传到 `/docker_k8s_2026`**

```bash
cd /c/Users/hongz/Desktop/qyt/docker_k8s_2026

# 用 git archive 打包，core.autocrlf=false 保证是 Linux 换行（LF），否则 shell 脚本会报 \r 错误
git -c core.autocrlf=false archive --format=tar HEAD docker apps \
  | ssh k8s-docker '
      sudo mkdir -p /docker_k8s_2026
      sudo chown ubuntu:ubuntu /docker_k8s_2026
      tar -xf - -C /docker_k8s_2026
      echo "files=$(find /docker_k8s_2026 -type f | wc -l)"
      ls /docker_k8s_2026/docker
    '
```

```text
files=108
docker_1_intro  docker_2_install  docker_3_cmd  docker_4_data  docker_5_DockerFile  docker_6_compose  docker_7_other
```

### 1. 安装 Docker（在 k8s-docker 上执行）

**1.1 确认系统版本，卸载可能冲突的旧包**

```bash
export DEBIAN_FRONTEND=noninteractive
grep -E "^(ID|VERSION_ID|VERSION_CODENAME)=" /etc/os-release

sudo apt-get remove -y \
  docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc \
  || true
```

```text
VERSION_ID="24.04"
VERSION_CODENAME=noble
ID=ubuntu
```

**1.2 添加 Docker 官方 apt 源**

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# GPG 公钥
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 软件源（新的 deb822 格式）
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update
```

**1.3 安装 Docker 引擎和插件**

```bash
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
```

**1.4 数据目录改到 `/data/docker`，开机自启**

```bash
sudo mkdir -p /data/docker /etc/docker

# 和课程的区别：不写国内镜像加速地址，只保留 data-root
echo '{ "data-root": "/data/docker" }' | sudo tee /etc/docker/daemon.json

sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl restart docker
systemctl is-active docker

# 让 ubuntu 用户不用 sudo 就能用 docker（重新登录后生效）
sudo usermod -aG docker ubuntu
```

```text
{ "data-root": "/data/docker" }
active
```

**1.5 验证**

```bash
sudo docker version --format "client={{.Client.Version}} server={{.Server.Version}}"
sudo docker compose version
sudo docker info --format "DockerRootDir={{.DockerRootDir}} Driver={{.Driver}} Cgroup={{.CgroupDriver}} v{{.CgroupVersion}}"
sudo docker run --rm hello-world
```

```text
client=29.10.0 server=29.10.0
Docker Compose version v5.8.0
DockerRootDir=/data/docker Driver=overlayfs Cgroup=systemd v2
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
...
Hello from Docker!
```

- `DockerRootDir=/data/docker`：`daemon.json` 生效了，镜像和容器都存在这里。
- `Cgroup=systemd v2`：Ubuntu 24.04 默认 cgroup v2，Docker 用 systemd 管理 cgroup。K8s 的 kubelet 也要求用 systemd 驱动，两边一致。

### 2. 停机（实验做完后，在本地执行）

```bash
aws ec2 stop-instances --region ap-northeast-1 --instance-ids i-0f8af3c84d76ecf35
aws ec2 wait instance-stopped --region ap-northeast-1 --instance-ids i-0f8af3c84d76ecf35
```

## 笔记 / 疑问

（自己补充）
