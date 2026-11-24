# K8s 第 1 章：Kubernetes 基础架构（kubeadm 高可用集群）

- **状态：** ✅ 完成
- **日期：** 2026-11-24
- **课程原文：** [k8s/01-k8s-architecture/docs/](../k8s/01-k8s-architecture/docs/)

## 结果

| 步骤 | 结果 |
|---|---|
| 1. 系统初始化（12 台） | ✅ swap 关闭、`overlay`/`br_netfilter`、`ip_forward=1`、时区 Asia/Shanghai、`iscsid` 运行、自动更新已屏蔽 |
| 2. Harbor v2.13.0 | ✅ 10 个容器，`/api/v2.0/health` 8 个组件全部 healthy（含 Trivy） |
| 3. 推送 K8s 核心镜像 | ✅ 7 个镜像推到 `harbor.qytk8s.com/k8s` |
| 4. HAProxy + Keepalived | ✅ VIP `10.1.1.10` 在 lb01，`nc -vz api.qytk8s.com 6443` 通 |
| 5–6. containerd + 信任 Harbor | ✅ containerd 1.7.12，`SystemdCgroup=true`，pause 走 Harbor |
| 7. kubeadm/kubelet/kubectl | ✅ v1.33.9 |
| 8–10. init / join | ✅ 3 控制平面 + 4 Worker，角色标签 `app/app/edge/observability` |
| 13. 验收 | ✅ 7 节点 `NotReady`（还没装 CNI，正常），CoreDNS `Pending`（正常），所有镜像来自 Harbor，证书到 2027-11 |

## 故障切换实测（课程文档只讲了原理）

| 操作 | VIP 在哪 | API 入口 |
|---|---|---|
| 正常 | lb01 | 通 |
| 停 lb01 的 keepalived（模拟 lb01 宕机） | **lb02**，几秒内 | 通 |
| lb01 恢复 | 抢回 lb01（默认抢占） | 通 |
| **只停 lb01 的 haproxy** | **仍在 lb01** | **断** |

最后一行是**课程配置本身的问题**，和 AWS 无关：`weight 10` 表示“检查成功 +10”，lb01 的 haproxy 挂了还剩 200，仍高于 lb02 的 150+10=160，所以 VIP 不会漂走。文档“haproxy 异常时 VIP 漂移到 lb02”的说法按这份配置做不到。修法：`weight -60`（失败减分），或把两边优先级差调到 10 以内。课程配置保持原样未改。

## 和课程原版的区别

**AWS 环境带来的：**

| 课程 | AWS 上 | 原因 |
|---|---|---|
| 13 台 VMware 虚拟机 + VyOS 网关 | 12 台 EC2（[k8s-infra/create.sh](k8s-infra/create.sh)），独立 VPC `10.1.1.0/24` | 课程 IP 基本原样可用 |
| Worker IP `.1–.4` | **`.21–.24`** | AWS 保留每个子网的 `.0–.3`；脚本都用主机名，所以不受影响 |
| win2019 做 DNS（`10.1.1.100`） | Route 53 私有域 `qytk8s.com` + DHCP 搜索域，DNS 是 `10.1.1.2` | `ssh root@cp01` 这类短主机名照样能用 |
| 快照“免密+网络+DNS” | 开机时 cloud-init 写入 root 公钥；私钥只放在 ops | |
| 网卡 `ens160` | `ens5` | ops 上的课程副本里全部替换（6 个文件） |
| Keepalived 免费 ARP 宣告 VIP | 加 `notify_master` 钩子 [aws-vip.sh](k8s-infra/aws-vip.sh)，变成 MASTER 时调 EC2 API 把 VIP 挂到自己网卡 | VPC 不认免费 ARP；课程本来就是单播 VRRP，只差这一步 |

**软件版本变化带来的（课程写完后 Ubuntu 源升级了，在 VM 上重做也会遇到）：**

1. **Docker 29 的 push 不认 `/etc/docker/certs.d`**：Ubuntu 的 `docker.io` 已是 29.x，默认用 containerd 镜像存储，push 时拿令牌只认系统 CA，报 `x509: certificate signed by unknown authority`（`docker login` 却成功）。解决：在 harbor 节点 `cp ca.crt /usr/local/share/ca-certificates/ && update-ca-certificates && systemctl restart docker`。
2. **重启 Docker 后 Harbor 起不来**：所有 Harbor 容器把日志发给 `harbor-log`（syslog），Docker 启动时它还没起来，其他容器 `Exited (128)`，`restart: always` 也救不回来。**每次开机都会遇到**。解决：加了 `harbor-compose.service`，Docker 启动后执行 `docker compose up -d`。
3. **containerd 变成 2.2.1**：配置格式从 v2 变成 v3，第 6 步的 `sed` 匹配不到，检查失败。课程文档要求 `1.7.x`，源里还有 `1.7.12`，所以用 `/etc/apt/preferences.d/containerd-course` 把版本钉在 1.7.12（不能用 `apt-mark hold`，课程脚本的 `apt-get install -y containerd` 会因此报错 100）。

## 学到的

- `kubeadm init` 时 `controlPlaneEndpoint: api.qytk8s.com:6443`，所以 kubectl、join 全部经过 VIP → HAProxy → 3 台 apiserver，不依赖任何一台控制平面。
- etcd 新成员先以 learner 身份加入，同步完才提升为正式成员，所以 join 时会看到 `can only promote a learner member which is in sync with leader` 的重试警告，属于正常现象。
- 镜像全部来自 Harbor：`imageRepository: harbor.qytk8s.com/k8s` + containerd 的 `sandbox_image`，集群节点不需要访问外网镜像仓库。

## 完整操作记录

说明：
- “本地”= 你的 Windows（Git Bash）；“ops”= `ssh k8s-ops` 登录后的 ops 节点（root）。课程里所有脚本都在 ops 上执行，和课程一致。
- 输出是真实输出，删掉了 apt 下载进度这类噪音；join token、证书密钥、账号 ID、跳板机公网 IP 已隐去。

### 0. 建环境（本地）

**0.1 检查配额和现有资源**

```bash
export MSYS_NO_PATHCONV=1 AWS_PAGER=""
R=ap-northeast-1

# 按需实例 / Spot 的 vCPU 配额（之前申请从 16/32 提到了 64）
aws service-quotas get-service-quota --region $R --service-code ec2 --quota-code L-1216C47A --query "Quota.Value"
aws service-quotas get-service-quota --region $R --service-code ec2 --quota-code L-34B43A08 --query "Quota.Value"

aws ec2 describe-instances --region $R \
  --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,InstanceType,State.Name]" \
  --output text
```

```text
64.0
64.0
vpn-tokyo        t3.micro   running
k8s-docker-lab   t3.large   stopped
flle-trader-2    c7i.large  stopped
flle-exchange-1  c7i.large  stopped
```

**0.2 生成课程内部用的 root 免密密钥**（替代课程的“免密+网络+DNS”快照）

```bash
# 私钥只放在本机 ~/.ssh 和 ops 上，不进仓库
ssh-keygen -t ed25519 -N "" -C "k8s-course-root" -f ~/.ssh/k8s_course_root -q
```

**0.3 一键建环境**

```bash
cd /c/Users/hongz/Desktop/qyt/docker_k8s_2026
bash aws-lab-notes/k8s-infra/create.sh
```

```text
== VPC / subnet / IGW / routes
== Route 53 private zone qytk8s.com + DHCP search domain
== Security groups
== IAM role for keepalived VIP failover (lb01/lb02)
== Instances
  ops -> i-0ee244a596acda616 (10.1.1.201, t3.small)
  harbor -> i-0cfb73d82cc2cdd13 (10.1.1.203, t3.medium)
  git -> i-0aba00e3e0d504253 (10.1.1.202, t3.medium)
  lb01 -> i-0cafa6336866742fa (10.1.1.11, t3.small)
  lb02 -> i-01649ada983457433 (10.1.1.12, t3.small)
  cp01 -> i-09e34bee0d5026013 (10.1.1.101, t3.medium)
  cp02 -> i-0158b200b838b4e6c (10.1.1.102, t3.medium)
  cp03 -> i-09f77b2c99cdff620 (10.1.1.103, t3.medium)
  wk-app01 -> i-0308a7a089bce1f32 (10.1.1.21, t3.large)
  wk-app02 -> i-012e311a133bc1b1c (10.1.1.22, t3.large)
  wk-edge01 -> i-050ec0d0d7a40e60e (10.1.1.23, t3.large)
  wk-obs01 -> i-039875929f87e042d (10.1.1.24, t3.large)
== Wait for all nodes running
== Disable source/dest check on K8s nodes (pod traffic)
== Elastic IP for ops (stable SSH target)
ops EIP: 57.182.10.61
VPC=vpc-060e2b9ebac6a0387 SUBNET=subnet-0bd474edb8192e4d4 SG=sg-0f431bb23426f94bd ZONE=Z09255932TYZ4TT81ZONJ
```

`create.sh` 里做的事情，拆开看是这些 AWS 命令（每一步都会先按 Name 标签查，已存在就跳过）：

```bash
# VPC 和子网都用课程网段 10.1.1.0/24
aws ec2 create-vpc --cidr-block 10.1.1.0/24
aws ec2 create-subnet --vpc-id $VPC --cidr-block 10.1.1.0/24 --availability-zone ap-northeast-1c
aws ec2 modify-subnet-attribute --subnet-id $SUBNET --map-public-ip-on-launch   # 节点要上网装软件

# 互联网网关 + 默认路由
aws ec2 create-internet-gateway
aws ec2 attach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC
aws ec2 create-route --route-table-id $RTB --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW

# 私有 DNS 域 qytk8s.com（只在这个 VPC 内可解析），代替课程的 win2019 DNS
aws route53 create-hosted-zone --name qytk8s.com --vpc VPCRegion=ap-northeast-1,VPCId=$VPC \
  --hosted-zone-config PrivateZone=true --caller-reference k8s-course-<时间戳>

# DHCP 选项：搜索域 qytk8s.com，这样 "ssh root@cp01" 会自动补成 cp01.qytk8s.com
aws ec2 create-dhcp-options --dhcp-configurations \
  "Key=domain-name,Values=qytk8s.com" "Key=domain-name-servers,Values=AmazonProvidedDNS"
aws ec2 associate-dhcp-options --dhcp-options-id $DHCP --vpc-id $VPC

# 每台机器一条 A 记录，外加 api -> 10.1.1.10（UPSERT，可重复执行）
aws route53 change-resource-record-sets --hosted-zone-id $ZONE --change-batch '{"Changes":[...]}'

# 安全组：组内全通；另外放行 Pod 网段 10.244.0.0/16（native routing 的 Pod 流量源地址是 Pod IP）
aws ec2 create-security-group --group-name k8s-course-sg --vpc-id $VPC --description "..."
aws ec2 authorize-security-group-ingress --group-id $SG --ip-permissions \
  "IpProtocol=-1,UserIdGroupPairs=[{GroupId=$SG}]" \
  "IpProtocol=-1,IpRanges=[{CidrIp=10.1.1.0/24},{CidrIp=10.244.0.0/16}]"

# ops 专用安全组：只允许从跳板机的公网 IP SSH 进来
aws ec2 authorize-security-group-ingress --group-id $SG_OPS --protocol tcp --port 22 --cidr <跳板机公网IP>/32

# lb01/lb02 用的 IAM 角色：只能“给网卡分配/取消辅助 IP”，给 Keepalived 挂 VIP 用
aws iam create-role --role-name k8s-course-lb-vip --assume-role-policy-document '{...ec2.amazonaws.com...}'
aws iam put-role-policy --role-name k8s-course-lb-vip --policy-name vip-move --policy-document \
  '{"Statement":[{"Effect":"Allow","Action":["ec2:AssignPrivateIpAddresses","ec2:UnassignPrivateIpAddresses","ec2:DescribeNetworkInterfaces","ec2:DescribeInstances"],"Resource":"*"}]}'
aws iam create-instance-profile --instance-profile-name k8s-course-lb-vip
aws iam add-role-to-instance-profile --instance-profile-name k8s-course-lb-vip --role-name k8s-course-lb-vip

# 每台机器：固定私有 IP + cloud-init（设主机名、写入 root 公钥）
aws ec2 run-instances \
  --image-id ami-0146cfc901859a3e4 --instance-type t3.medium \
  --subnet-id $SUBNET --private-ip-address 10.1.1.101 \
  --security-group-ids $SG --key-name k8s-lab-key \
  --credit-specification CpuCredits=standard \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
  --user-data "$(cat <<EOF
#cloud-config
hostname: cp01
fqdn: cp01.qytk8s.com
disable_root: false
runcmd:
  - mkdir -p /root/.ssh && chmod 700 /root/.ssh
  - echo '<k8s_course_root.pub 的内容>' > /root/.ssh/authorized_keys
EOF
)"
# Worker 多一块数据盘：{"DeviceName":"/dev/sdb","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}
# lb 多一个参数：--iam-instance-profile Name=k8s-course-lb-vip

# K8s 节点关闭源/目标检查（第 2 章 native routing 需要）
aws ec2 modify-instance-attribute --instance-id $ID --no-source-dest-check

# ops 绑定弹性 IP，停机再开 IP 不变
aws ec2 allocate-address --domain vpc
aws ec2 associate-address --allocation-id $EIP --instance-id $OPS_ID
```

**0.4 SSH 到 ops，把私钥放到 ops 上，确认 ops 能免密登录所有节点**

```bash
# 本地 ~/.ssh/config 增加
cat >> ~/.ssh/config <<'EOF'

Host k8s-ops
    HostName 57.182.10.61
    User root
    IdentityFile ~/.ssh/k8s_course_root
    ProxyJump ec2-tokyo
    StrictHostKeyChecking accept-new
EOF

ssh k8s-ops 'hostname; cloud-init status'
scp ~/.ssh/k8s_course_root k8s-ops:/root/.ssh/id_ed25519
```

```text
ops
status: done
```

在 ops 上：

```bash
chmod 600 /root/.ssh/id_ed25519
grep -E "search|nameserver" /etc/resolv.conf

for h in harbor git lb01 lb02 cp01 cp02 cp03 wk-app01 wk-app02 wk-edge01 wk-obs01; do
  printf "%-10s " $h
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new root@$h hostname
done

getent hosts api.qytk8s.com
```

```text
nameserver 127.0.0.53
search qytk8s.com              ← DHCP 下发的搜索域
harbor     harbor
git        git
lb01       lb01
...（11 台全部免密成功）
wk-obs01   wk-obs01
10.1.1.10       api.qytk8s.com
```

**0.5 上传课程文件到 ops（本地）**

```bash
cd /c/Users/hongz/Desktop/qyt/docker_k8s_2026
S=<临时目录>

git -c core.autocrlf=false archive --format=tar HEAD > $S/course.tar

# 去掉两个超大文件（Harbor 安装包脚本会自己下载；cilium 二进制也会下载）
tar --delete -f $S/course.tar \
  k8s/01-k8s-architecture/tmp/harbor-offline-installer-v2.13.0.tgz \
  k8s/02-cloud-native-networking/artifacts/bin/cilium

ssh k8s-ops 'mkdir -p /docker_k8s_2026 && tar -xf - -C /docker_k8s_2026 && du -sh /docker_k8s_2026' < $S/course.tar
```

```text
150M	/docker_k8s_2026
```

**0.6 AWS 适配：网卡名 `ens160` → `ens5`（ops）**

```bash
ip -br link | grep -v lo

cd /docker_k8s_2026/k8s
grep -rl "ens160" . | grep -v archive | tee /root/ens160-files.txt | xargs sed -i "s/ens160/ens5/g"
cat /root/ens160-files.txt
```

```text
ens5             UP             0a:ff:c0:cf:6b:5b <BROADCAST,MULTICAST,UP,LOWER_UP>
./03-north-south-traffic/scripts/00_check_and_recover_cluster.sh
./01-k8s-architecture/docs/05_loadbalancer.md
./01-k8s-architecture/configs/loadbalancer/keepalived-lb02.conf
./01-k8s-architecture/configs/loadbalancer/keepalived-lb01.conf
./01-k8s-architecture/scripts/01_prepare_os_remote.sh
./02-cloud-native-networking/scripts/00_check_and_recover_cluster.sh
```

**0.7 课程要求的 HTTP 文件服务（ops）**

```bash
apt-get install -y nginx

cat > /etc/nginx/sites-available/k8s-manifests <<'EOF'
server {
    listen 9000;
    server_name _;
    root /docker_k8s_2026/k8s;
    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;
    location / { try_files $uri $uri/ =404; }
}
EOF

ln -sf /etc/nginx/sites-available/k8s-manifests /etc/nginx/sites-enabled/k8s-manifests
nginx -t && systemctl restart nginx && systemctl enable nginx

curl -s http://ops:9000/01-k8s-architecture/manifests/kubeadm-init-cp01.yaml | head -3
```

```text
nginx: configuration file /etc/nginx/nginx.conf test is successful
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
```

### 第 1 步：所有节点系统初始化（ops）

```bash
cd /docker_k8s_2026/k8s/01-k8s-architecture/scripts
chmod +x *.sh

# 课程原样：串行处理 12 台
bash 01_prepare_os_remote.sh > /root/ch1-step1.log 2>&1 &

# 串行每台约 3 分钟太慢，利用脚本“可以只处理指定节点”的特性并行跑其余 9 台
for n in cp01 cp02 cp03 wk-app01 wk-app02 wk-edge01 wk-obs01 harbor git; do
  bash 01_prepare_os_remote.sh $n > /root/ch1-step1-$n.log 2>&1 &
done
wait
```

每台的输出（以 wk-app01 为例）：

```text
=========================================================
节点：wk-app01
=========================================================
[1/10] 优化启动速度
[2/10] 关闭 swap
[3/10] 加载内核模块
[4/10] 配置 sysctl
[5/10] 设置时区
[6/10] 优化 SSH 登录
[7/10] 关闭 UFW
[8/10] 关闭自动更新，避免 apt 锁冲突
[9/10] 安装基础工具
0 upgraded, 5 newly installed, 0 to remove and 4 not upgraded.
[10/10] 启动 Longhorn 依赖服务
hostname=wk-app01
swap_status=0
timezone=Asia/Shanghai
dns=10.1.1.2              ← 课程是 10.1.1.100（win2019），这里是 AWS 自带 DNS
gateway=10.1.1.1          ← 课程是 10.1.1.254（VyOS），这里是 VPC 路由器
OK
```

脚本对每台节点实际执行的核心命令（节选自 `01_prepare_os_remote.sh`）：

```bash
systemctl set-default multi-user.target
swapoff -a
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

cat >/etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

cat >/etc/sysctl.d/99-kubernetes.conf <<'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

timedatectl set-timezone Asia/Shanghai
systemctl mask unattended-upgrades.service
apt-get install -y conntrack ipset jq open-iscsi socat ...
systemctl enable --now iscsid
```

抽查（课程要求至少 1 台控制平面 + 1 台 Worker）：

```bash
for n in cp01 wk-app01; do
  ssh root@$n '
    echo "== $(hostname): swap=[$(swapon --show)] \
mods=$(lsmod | grep -cE "^(br_netfilter|overlay) ") \
ip_forward=$(sysctl -n net.ipv4.ip_forward) \
tz=$(timedatectl show -p Timezone --value) \
iscsid=$(systemctl is-active iscsid) \
unattended=$(systemctl is-enabled unattended-upgrades 2>&1)"
  ' </dev/null
done
```

```text
== cp01: swap=[] mods=2 ip_forward=1 tz=Asia/Shanghai iscsid=active unattended=masked
== wk-app01: swap=[] mods=2 ip_forward=1 tz=Asia/Shanghai iscsid=active unattended=masked
```

### 第 2 步：部署 Harbor（ops）

```bash
bash 02_install_harbor_remote.sh > /root/ch1-step2.log 2>&1
grep -E "^\[|Step [0-9]|✔|^OK" /root/ch1-step2.log
```

```text
[1/4] 准备本地目录
[2/4] 生成 Harbor CA 与服务端证书
[3/4] 下载 Harbor Offline Installer          ← 从 GitHub 下载 627 MB 安装包
[4/4] 在 harbor 节点安装 Harbor
[harbor 1/7] 安装 Docker
[harbor 2/7] 配置 Docker 信任 Harbor CA
[harbor 3/7] 解压 Harbor 离线安装包
[harbor 4/7] 分发证书到 Harbor 数据目录
[harbor 5/7] 生成 harbor.yml 配置
[harbor 6/7] 执行 Harbor 安装
[Step 0]: checking if docker is installed ...
[Step 1]: checking docker-compose is installed ...
[Step 2]: loading Harbor images ...
[Step 3]: preparing environment ...
[Step 4]: preparing harbor configs ...
[Step 5]: starting Harbor ...
✔ ----Harbor has been installed and started successfully.----
[harbor 7/7] 查看 Harbor 容器列表
harbor-core  harbor-db  harbor-jobservice  harbor-log  harbor-portal  nginx  redis  registry  registryctl  trivy-adapter
OK: Harbor 部署完成
```

验证健康状态（课程 CA 校验 HTTPS）：

```bash
CA=/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt

C=$CA
until [ "$(curl -s --cacert $C https://harbor.qytk8s.com/api/v2.0/health | jq -r .status)" = healthy ]; do
  sleep 5
done
curl -s --cacert $CA https://harbor.qytk8s.com/api/v2.0/health \
  | jq -c "{status, components: [.components[].name]}"

# 容器重启次数
ssh root@harbor 'docker inspect -f "{{.Name}} restarts={{.RestartCount}}" $(docker ps -q)' </dev/null
```

```text
{"status":"healthy","components":["core","database","jobservice","portal","redis","registry","registryctl","trivy"]}
/nginx restarts=0
/harbor-jobservice restarts=5          ← 正常：要等 harbor-core 就绪，启动时会重启几次
/harbor-core restarts=0
...
```

### 第 3 步：推送 K8s 核心镜像到 Harbor（ops）

第一次执行失败：

```bash
bash 03_push_k8s_images_remote.sh > /root/ch1-step3.log 2>&1
tail -3 /root/ch1-step3.log
```

```text
The push refers to repository [harbor.qytk8s.com/k8s/kube-apiserver]
failed to authorize: failed to fetch oauth token: Post "https://harbor.qytk8s.com/service/token":
tls: failed to verify certificate: x509: certificate signed by unknown authority
```

排查：

```bash
ssh root@harbor '
  docker version -f {{.Server.Version}}
  docker info -f "{{.Driver}} {{index .DriverStatus 0}}"
  ls /etc/docker/certs.d/harbor.qytk8s.com/
' </dev/null
```

```text
29.1.3
overlayfs [driver-type io.containerd.snapshotter.v1]     ← Docker 29 默认用 containerd 镜像存储
ca.crt                                                   ← certs.d 里的 CA 是配好的
```

`docker login` 成功、push 拿令牌却失败：Docker 29 的 containerd 镜像存储在获取令牌时只认**系统 CA**，不看 `/etc/docker/certs.d`。修复：

```bash
ssh root@harbor '
  cp /etc/docker/certs.d/harbor.qytk8s.com/ca.crt /usr/local/share/ca-certificates/qyt-harbor-ca.crt
  update-ca-certificates
  systemctl restart docker
' </dev/null
```

```text
1 added, 0 removed; done.
```

再跑一次，这次脚本卡在“等待 Harbor 就绪”：

```text
Harbor 尚未就绪（第 1/20 次，HTTP 000），5 秒后重试
...
Harbor 尚未就绪（第 20/20 次，HTTP 000），5 秒后重试
等待 Harbor 就绪超时
```

```bash
curl -sv https://harbor.qytk8s.com/ 2>&1 | grep -E "Trying|refused"
ssh root@harbor 'docker ps -a --format "{{.Names}}|{{.Status}}" | head -4' </dev/null
```

```text
*   Trying 10.1.1.203:443...
* connect to 10.1.1.203 port 443 from 10.1.1.201 port 46736 failed: Connection refused
nginx|Exited (128) 2 minutes ago
harbor-jobservice|Exited (128) 2 minutes ago
harbor-core|Exited (128) 2 minutes ago
trivy-adapter|Exited (128) 2 minutes ago
```

重启 Docker 后 Harbor 容器全部 `Exited (128)`：它们的日志驱动是 syslog，发给 `harbor-log` 容器；Docker 启动时 `harbor-log` 还没起来，其他容器就启动失败，`restart: always` 也不会再拉起。手工拉起，并加一个开机服务防止以后再出现：

```bash
ssh root@harbor 'cd /opt/harbor-install && docker compose up -d' </dev/null

ssh root@harbor 'cat > /etc/systemd/system/harbor-compose.service <<EOF
[Unit]
Description=Bring Harbor compose stack up after Docker starts (harbor-log ordering fix)
After=docker.service network-online.target
Requires=docker.service
[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/harbor-install
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/docker compose up -d
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable harbor-compose.service' </dev/null
```

第三次执行成功：

```bash
bash 03_push_k8s_images_remote.sh > /root/ch1-step3.log 2>&1
grep -E "^\[|源镜像|目标镜像|^OK" /root/ch1-step3.log
```

```text
[1/2] 创建 Harbor 项目
Harbor 项目 k8s 已就绪
[2/2] 在 harbor 节点拉取并推送核心镜像
源镜像：registry.k8s.io/kube-apiserver:v1.33.9
目标镜像：harbor.qytk8s.com/k8s/kube-apiserver:v1.33.9
源镜像：registry.k8s.io/kube-controller-manager:v1.33.9
目标镜像：harbor.qytk8s.com/k8s/kube-controller-manager:v1.33.9
源镜像：registry.k8s.io/kube-scheduler:v1.33.9
目标镜像：harbor.qytk8s.com/k8s/kube-scheduler:v1.33.9
源镜像：registry.k8s.io/kube-proxy:v1.33.9
目标镜像：harbor.qytk8s.com/k8s/kube-proxy:v1.33.9
源镜像：registry.k8s.io/pause:3.10
目标镜像：harbor.qytk8s.com/k8s/pause:3.10
源镜像：registry.k8s.io/etcd:3.5.24-0
目标镜像：harbor.qytk8s.com/k8s/etcd:3.5.24-0
源镜像：registry.k8s.io/coredns/coredns:v1.12.0
目标镜像：harbor.qytk8s.com/k8s/coredns:v1.12.0
OK: Kubernetes 核心镜像已推送到 Harbor
```

### 第 4 步：HAProxy + Keepalived（ops）

**4.1 AWS 适配：给 Keepalived 加 `notify_master` 钩子**

钩子脚本是 [k8s-infra/aws-vip.sh](k8s-infra/aws-vip.sh)。它从实例元数据（IMDSv2）拿到网卡 ID 和临时凭证，用 `curl --aws-sigv4` 直接调用 EC2 API `AssignPrivateIpAddresses`（`AllowReassignment=true`，把 VIP 从另一台“抢”过来）。

```bash
# 拷进课程配置目录，并在两份 keepalived.conf 的 track_script 前插入 notify_master
cp aws-vip.sh /docker_k8s_2026/k8s/01-k8s-architecture/configs/loadbalancer/
cd /docker_k8s_2026/k8s/01-k8s-architecture/configs/loadbalancer

for f in keepalived-lb01.conf keepalived-lb02.conf; do
  sed -i '/^    track_script {/i\    # AWS: VPC ignores gratuitous ARP, so move the VIP via EC2 API when becoming MASTER\n    notify_master "/etc/keepalived/aws-vip.sh"\n' $f
done

# 课程脚本不会分发这个钩子，手工放到两台 lb 上
for n in lb01 lb02; do
  ssh root@$n 'mkdir -p /etc/keepalived && cat > /etc/keepalived/aws-vip.sh && chmod +x /etc/keepalived/aws-vip.sh' < aws-vip.sh
done
```

改完后 lb02 的配置（课程原本就是单播 VRRP，只多了 `notify_master` 两行，网卡名改成 `ens5`）：

```text
vrrp_instance VI_K8S_API {
    state BACKUP
    interface ens5
    virtual_router_id 51
    priority 150
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass K8S2026
    }
    unicast_src_ip 10.1.1.12
    unicast_peer {
        10.1.1.11
    }
    virtual_ipaddress {
        10.1.1.10/24 dev ens5
    }
    # AWS: VPC ignores gratuitous ARP, so move the VIP via EC2 API when becoming MASTER
    notify_master "/etc/keepalived/aws-vip.sh"
    track_script {
        chk_haproxy
    }
}
```

**4.2 执行课程脚本**

```bash
cd /docker_k8s_2026/k8s/01-k8s-architecture/scripts
bash 04_setup_haproxy_keepalived_remote.sh > /root/ch1-step4.log 2>&1 </dev/null
grep -E "^\[|active" /root/ch1-step4.log
```

```text
[1/2] 配置 lb01
[lb01 1/5] 安装 haproxy 和 keepalived
[lb01 2/5] 下发 haproxy.cfg
[lb01 3/5] 下发健康检查脚本
[lb01 4/5] 下发 keepalived.conf
[lb01 5/5] 启动 haproxy 和 keepalived
active
active
[2/2] 配置 lb02
...（同上）
active
active
```

**4.3 验证：VIP 在哪台 lb 上（系统里 + AWS 里）**

```bash
for n in lb01 lb02; do
  echo "== $n: $(ssh root@$n '
    ip -4 addr show ens5 | grep -o "10\.1\.1\.10/24" || echo no-VIP
    journalctl -t aws-vip --no-pager -o cat | tail -1
  ' </dev/null | paste -sd' ')"
done

nc -vz -w3 api.qytk8s.com 6443
```

```text
== lb01: 10.1.1.10/24 VIP 10.1.1.10 assigned to eni-04166e6593fa1fde5 (lb01)
== lb02: no-VIP
Connection to api.qytk8s.com (10.1.1.10) 6443 port [tcp/*] succeeded!
```

本地查 AWS 一侧（VIP 是否真的挂到了 lb01 的网卡上）：

```bash
aws ec2 describe-network-interfaces --region ap-northeast-1 \
  --filters Name=addresses.private-ip-address,Values=10.1.1.10 \
  --query "NetworkInterfaces[].[Attachment.InstanceId,PrivateIpAddresses[].PrivateIpAddress|join(',',@)]" \
  --output text
```

```text
i-0cafa6336866742fa	10.1.1.11,10.1.1.10        ← lb01 的网卡：主 IP .11 + 辅助 IP .10
```

**4.4 故障切换实测（课程文档只讲原理，这里实际做了一遍）**

```bash
vip() {
  for n in lb01 lb02; do
    printf "%s=%s " $n "$(ssh root@$n 'ip -4 addr show ens5 | grep -c 10.1.1.10' </dev/null)"
  done
  nc -z -w2 api.qytk8s.com 6443 && echo "api:reachable" || echo "api:DOWN"
}

echo "before:               $(vip)"

# 测试 1：停掉 lb01 的 keepalived（模拟 lb01 整机故障）
ssh root@lb01 'systemctl stop keepalived' </dev/null;  sleep 6
echo "lb01 keepalived down: $(vip)"
ssh root@lb01 'systemctl start keepalived' </dev/null; sleep 6
echo "lb01 back (preempt):  $(vip)"

# 测试 2：只停 lb01 的 haproxy
ssh root@lb01 'systemctl stop haproxy' </dev/null;     sleep 8
echo "lb01 haproxy down:    $(vip)"
ssh root@lb01 'systemctl start haproxy' </dev/null;    sleep 4
echo "restored:             $(vip)"
```

```text
before:               lb01=1 lb02=0 api:reachable
lb01 keepalived down: lb01=0 lb02=1 api:reachable    ← VIP 漂到 lb02，入口不断
lb01 back (preempt):  lb01=1 lb02=0 api:reachable    ← lb01 恢复后抢回（默认抢占）
lb01 haproxy down:    lb01=1 lb02=0 api:DOWN         ← VIP 没走，入口断了！（课程配置问题，见上文）
restored:             lb01=1 lb02=0 api:reachable
```

### 第 5–7 步：containerd、信任 Harbor、kubeadm 工具（ops）

**第一次执行：第 6 步失败**

```bash
for s in 05_install_containerd_remote.sh 06_config_containerd_harbor_remote.sh 07_install_kube_tools_remote.sh; do
  bash $s > /root/ch1-$s.log 2>&1 </dev/null
  echo "$s exit=$?"
done
```

```text
05_install_containerd_remote.sh exit=0
06_config_containerd_harbor_remote.sh exit=1
07_install_kube_tools_remote.sh exit=0
```

排查：

```bash
ssh root@cp01 '
  containerd --version
  grep -nE "config_path|sandbox|version" /etc/containerd/config.toml | head
  apt-cache policy containerd | head -12
' </dev/null
```

```text
containerd github.com/containerd/containerd/v2 2.2.1
1:version = 3                                                  ← 新的 v3 配置格式
51:      sandbox = 'registry.k8s.io/pause:3.10.1'              ← 课程脚本找的是 sandbox_image = "..."
54:      config_path = '/etc/containerd/certs.d:/etc/docker/certs.d'
containerd:
  Installed: 2.2.1-0ubuntu1~24.04.4
  Candidate: 2.2.1-0ubuntu1~24.04.4
  Version table:
 *** 2.2.1-0ubuntu1~24.04.4 500    (noble-updates)
     2.2.1-0ubuntu1~24.04.3 500    (noble-security)
     1.7.12-0ubuntu4 500           (noble 原始版本)   ← 课程文档要求的 1.7.x
```

**修复：用 apt pin 把 containerd 钉在 1.7.12**

第一次用 `apt-mark hold` 不行：

```bash
apt-get install -y --allow-downgrades containerd=1.7.12-0ubuntu4
apt-mark hold containerd
bash 05_install_containerd_remote.sh       # exit=100
```

课程脚本里是 `apt-get install -y containerd`，被 hold 的包 apt 想升级又不能升，直接报错 100。改用版本优先级（7 台 K8s 节点都执行）：

```bash
for n in cp01 cp02 cp03 wk-app01 wk-app02 wk-edge01 wk-obs01; do
  ssh root@$n '
    apt-mark unhold containerd
    printf "Package: containerd\nPin: version 1.7.12*\nPin-Priority: 1001\n" \
      > /etc/apt/preferences.d/containerd-course
    echo "$(hostname) candidate=$(apt-cache policy containerd | awk "/Candidate/{print \$2}")"
  ' </dev/null &
done
wait
```

```text
cp01 candidate=1.7.12-0ubuntu4
...（7 台都是 1.7.12）
```

`Pin-Priority: 1001` 大于 1000，apt 会把 1.7.12 当作“候选版本”，必要时还会主动降级，所以课程脚本的 `apt-get install -y containerd` 能正常执行。

**重跑第 5、6 步**

```bash
for s in 05_install_containerd_remote.sh 06_config_containerd_harbor_remote.sh; do
  bash $s > /root/ch1-$s.log 2>&1 </dev/null
  echo "$s exit=$?"
done
```

```text
05_install_containerd_remote.sh exit=0
06_config_containerd_harbor_remote.sh exit=0
```

第 5 步每台的输出：

```text
=========================================================
节点：cp01
=========================================================
[1/4] 安装 containerd
[2/4] 生成默认配置文件
[3/4] 设置 SystemdCgroup = true
[4/4] 启动 containerd 并设置开机自启
containerd github.com/containerd/containerd 1.7.12
            SystemdCgroup = true
OK
```

第 6 步每台的输出：

```text
节点：cp01
[CA] 分发 Harbor CA 证书
[配置] 写入 hosts.toml / config_path / sandbox_image
[1/4] 创建 hosts.toml 配置
[2/4] 修改 config_path 指向证书目录
[3/4] 修改 sandbox_image 为本地 Harbor pause 镜像
[4/4] 重启 containerd
160:      config_path = "/etc/containerd/certs.d"
256:    config_path = "/etc/containerd/certs.d"
65:    sandbox_image = "harbor.qytk8s.com/k8s/pause:3.10"
active
```

验证 containerd 能用课程 CA 从 Harbor 拉镜像：

```bash
for n in cp01 wk-app01; do
  ssh root@$n '
    echo "$(hostname): $(containerd --version | cut -d" " -f3)"
    crictl --runtime-endpoint unix:///run/containerd/containerd.sock \
      pull harbor.qytk8s.com/k8s/pause:3.10 2>&1 | tail -1
  ' </dev/null
done
```

```text
cp01: 1.7.12
Image is up to date for sha256:873ed75102791e5b0b8a7fcd41606c92fcec98d56d05ead4ac5131650004c136
wk-app01: 1.7.12
Image is up to date for sha256:873ed75102791e5b0b8a7fcd41606c92fcec98d56d05ead4ac5131650004c136
```

第 7 步（第一次就成功）：

```text
先在 ops 本机安装 kubectl 1.33.9-1.1
[ops 1/3] 导入 Kubernetes APT 签名密钥
[ops 2/3] 配置 Kubernetes APT 仓库
[ops 3/3] 安装并锁定 kubectl 固定版本
kubectl set on hold.
Client Version: v1.33.9
=========================================================
节点：cp01
=========================================================
[1/5] 导入 Kubernetes APT 签名密钥
[2/5] 配置 Kubernetes APT 仓库
[3/4] 安装 kubelet、kubeadm、kubectl 固定版本
  cri-tools kubeadm kubectl kubelet kubernetes-cni
[4/4] 锁定版本，防止自动升级
kubelet set on hold.
kubeadm set on hold.
kubectl set on hold.
```

### 第 8 步：kubeadm init（ops）

```bash
ssh root@cp01 'kubeadm version -o short; kubelet --version' </dev/null
bash 08_kubeadm_init_remote.sh > /root/ch1-step8.log 2>&1 </dev/null
```

```text
v1.33.9
Kubernetes v1.33.9
=========================================================
开始初始化第一个控制平面 cp01
=========================================================
[1/4] cp01 从 ops HTTP 服务下载 kubeadm 初始化配置
[2/4] 在 cp01 执行 kubeadm init
[init] Using Kubernetes version: v1.33.9
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
...
[control-plane-check] Checking kube-apiserver at https://10.1.1.101:6443/livez
[control-plane-check] Checking kube-controller-manager at https://127.0.0.1:10257/healthz
[control-plane-check] Checking kube-scheduler at https://127.0.0.1:10259/livez
[control-plane-check] kube-controller-manager is healthy after 3.917380954s
[control-plane-check] kube-scheduler is healthy after 4.875012597s
[control-plane-check] kube-apiserver is healthy after 6.50237485s
[upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
Your Kubernetes control-plane has initialized successfully!

You can now join any number of control-plane nodes running the following command on each as root:
  kubeadm join api.qytk8s.com:6443 --token <隐去> \
	--discovery-token-ca-cert-hash <隐去> \
	--control-plane --certificate-key <隐去>

Then you can join any number of worker nodes by running the following on each as root:
kubeadm join api.qytk8s.com:6443 --token <隐去> \
	--discovery-token-ca-cert-hash <隐去>

[3/4] 将 admin.conf 拷回 ops，配置 kubectl
[4/4] 在 ops 验证 kubectl
NAME   STATUS     ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION   CONTAINER-RUNTIME
cp01   NotReady   control-plane   5s    v1.33.9   10.1.1.101    <none>        Ubuntu 24.04.5 LTS   7.0.0-1018-aws   containerd://1.7.12
OK: cp01 初始化完成
```

- join 命令里的地址是 `api.qytk8s.com:6443`（VIP），不是 cp01 的 IP，因为 kubeadm 配置里写了 `controlPlaneEndpoint: api.qytk8s.com:6443`。
- controller-manager 和 scheduler 的健康检查地址是 `127.0.0.1`：它们默认只监听本机，这就是第 7 章 Prometheus 抓不到它们的原因。

### 第 9–10 步：加入控制平面和 Worker（ops）

```bash
bash 09_join_control_planes_remote.sh > /root/ch1-step9.log 2>&1 </dev/null
echo "step9 exit=$?"
grep -E "OK|error" /root/ch1-step9.log | tail -3

bash 10_join_workers_remote.sh > /root/ch1-step10.log 2>&1 </dev/null
echo "step10 exit=$?"
tail -1 /root/ch1-step10.log

kubectl get nodes -o wide -L node-role
```

```text
step9 exit=0
{"level":"warn",...,"msg":"retrying of unary invoker failed","target":"etcd-endpoints://.../10.1.1.102:2379",
 "error":"rpc error: code = FailedPrecondition desc = etcdserver: can only promote a learner member which is in sync with leader"}
OK: 控制平面扩展完成
step10 exit=0
OK: Worker 加入与标签完成
NAME        STATUS     ROLES           AGE   VERSION   INTERNAL-IP   ...   CONTAINER-RUNTIME     NODE-ROLE
cp01        NotReady   control-plane   73s   v1.33.9   10.1.1.101    ...   containerd://1.7.12
cp02        NotReady   control-plane   36s   v1.33.9   10.1.1.102    ...   containerd://1.7.12
cp03        NotReady   control-plane   11s   v1.33.9   10.1.1.103    ...   containerd://1.7.12
wk-app01    NotReady   <none>          8s    v1.33.9   10.1.1.21     ...   containerd://1.7.12   app
wk-app02    NotReady   <none>          6s    v1.33.9   10.1.1.22     ...   containerd://1.7.12   app
wk-edge01   NotReady   <none>          3s    v1.33.9   10.1.1.23     ...   containerd://1.7.12   edge
wk-obs01    NotReady   <none>          1s    v1.33.9   10.1.1.24     ...   containerd://1.7.12   observability
```

第 10 步打标签的命令（脚本里）：

```bash
kubectl label node wk-app01  node-role=app           --overwrite
kubectl label node wk-app02  node-role=app           --overwrite
kubectl label node wk-edge01 node-role=edge          --overwrite
kubectl label node wk-obs01  node-role=observability --overwrite
```

### 第 12 步：验收（ops）

```bash
kubectl get pods -n kube-system -o wide | awk '{print $1, $3, $7}' | column -t

# 所有系统组件的镜像都来自 Harbor？
kubectl get pods -n kube-system \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' | sort -u

curl -k -s https://harbor.qytk8s.com/api/v2.0/health | jq -r .status

ssh root@cp01 'kubeadm certs check-expiration | sed -n 4,6p' </dev/null
```

```text
NAME                          STATUS   NODE
coredns-5846f85477-6j88b      Pending  <none>       ← 没装 CNI，正常
coredns-5846f85477-fk2pk      Pending  <none>
etcd-cp01                     Running  cp01
etcd-cp02                     Running  cp02
etcd-cp03                     Running  cp03
kube-apiserver-cp01           Running  cp01
kube-apiserver-cp02           Running  cp02
kube-apiserver-cp03           Running  cp03
kube-controller-manager-cp01  Running  cp01
kube-controller-manager-cp02  Running  cp02
kube-controller-manager-cp03  Running  cp03
kube-proxy-4nxfp              Running  wk-edge01
kube-proxy-7qdn9              Running  cp01
kube-proxy-d5rmg              Running  wk-app02
kube-proxy-fwbjv              Running  cp02
kube-proxy-jcwnn              Running  cp03
kube-proxy-l64j5              Running  wk-app01
kube-proxy-llj6f              Running  wk-obs01
kube-scheduler-cp01           Running  cp01
kube-scheduler-cp02           Running  cp02
kube-scheduler-cp03           Running  cp03

harbor.qytk8s.com/k8s/coredns:v1.12.0
harbor.qytk8s.com/k8s/etcd:3.5.24-0
harbor.qytk8s.com/k8s/kube-apiserver:v1.33.9
harbor.qytk8s.com/k8s/kube-controller-manager:v1.33.9
harbor.qytk8s.com/k8s/kube-proxy:v1.33.9
harbor.qytk8s.com/k8s/kube-scheduler:v1.33.9

healthy

CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 Nov 24, 2027 09:54 UTC   364d            ca                      no
apiserver                  Nov 24, 2027 09:54 UTC   364d            ca                      no
```

## 笔记 / 疑问

（自己补充）
