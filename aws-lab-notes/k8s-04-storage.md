# K8s 第 4 章：存储与有状态应用（Longhorn + StatefulSet）

- **状态：** ✅ 完成
- **日期：** 2026-11-24
- **课程原文：** [k8s/04-storage-and-stateful/docs/](../k8s/04-storage-and-stateful/docs/)

## 结果

按课程表格的顺序执行：01 → 02 → 03 → 04 → 05 → 08 → 07 → 06（脚本编号和表格顺序不完全一致）。

| 步骤 | 结果 |
|---|---|
| 1. 数据盘 | ✅ 4 台 Worker 的数据盘格式化为 ext4，按 UUID 挂到 `/var/lib/longhorn` |
| 2–3. Longhorn | ✅ 安装完成，首批 3 个存储节点 |
| 4. PVC 动态供给 | ✅ `qytang-pvc-demo` 2Gi `Bound`；删掉 Pod 后，新 Pod 挂上原 PVC，**读到原来的数据** |
| 5. 扩容 | ✅ wk-edge01 成为第 4 个存储节点 |
| 7. StatefulSet（MongoDB 副本集） | ✅ 3 个成员分布在 wk-obs01 / wk-edge01 / wk-app01，`PRIMARY + 2×SECONDARY` |
| 8. Longhorn UI | ✅ `https://longhorn.qytk8s.com`（共用 VIP `.60`） |
| 9. 验收 | ✅ `06_verify_storage.sh` 通过 |

**StatefulSet 删除恢复（手工验证）：**

| | 删除前 | 重建后 |
|---|---|---|
| Pod 名 | `qytang-statefulset-mongodb-demo-1` | **同名** |
| UID | `3f316054-…` | `0079f70d-…`（是新 Pod） |
| PVC | `datadir-…-demo-1` | **同一块盘** |
| 副本集角色 | SECONDARY | SECONDARY（自动回到副本集） |

## 和课程原版的区别

**1. 数据盘设备名（AWS）**

课程脚本写死了 `/dev/sdb`。AWS Nitro 机型的 EBS 盘是 NVMe 设备，ops 副本里改成了 `/dev/nvme1n1` 和 `/dev/nvme1n1p1`。

格式化前**逐台确认过** `nvme1n1` 不是系统盘：NVMe 编号不保证固定，有时系统盘反而是 `nvme1n1`，而这里两块盘都是 30 GB，靠大小区分不了。确认方法：

```bash
# 系统盘 = 挂载 / 的那个分区所属的磁盘
lsblk -no PKNAME "$(findmnt -no SOURCE /)"
```

盘的大小也不一样：课程是 100 GB，这里是 30 GB，对实验没有影响。

**2. Pod 删不掉：`runc ... unable to signal init: permission denied`（重要）**

- 现象：PVC 演示删除 Pod 时，旧 Pod 一直 `Terminating`；新 Pod 报 `Multi-Attach error`，因为卷还被旧 Pod 占着，脚本卡了十几分钟。
- 内核日志：`apparmor="DENIED" operation="signal" profile="cri-containerd.apparmor.d" ... signal=kill peer="runc"`
- 原因：Ubuntu 24.04 给 `runc` 加了自己的 AppArmor 配置（`/etc/apparmor.d/runc`）。containerd **1.7.x** 生成的容器配置不允许来自 `runc` 配置的信号，所以停不掉任何容器。containerd 2.x 已经修复了。
- **也就是说，这是第 1 章把 containerd 钉回 1.7.12 带来的副作用**。前几章没暴露出来，是因为没有删除正在运行的 Pod 的操作。
- 解决（7 个 K8s 节点）：

```bash
# 卸载 runc 的 AppArmor 配置，并禁止开机时重新加载
apparmor_parser -R /etc/apparmor.d/runc
ln -sf /etc/apparmor.d/runc /etc/apparmor.d/disable/runc
```

  runc 回到 Ubuntu 24.04 之前的“不受限”状态，容器本身的 AppArmor 保护（`cri-containerd.apparmor.d`）不受影响。另一种方案是升级到 containerd 2.x，再手工调整第 6 步的配置。

## 学到的

- **Deployment + PVC 和 StatefulSet 的区别**：Deployment 的 Pod 名字是随机的，多个副本共用一个 PVC（RWO 时只能有一个副本）；StatefulSet 的每个 Pod 有固定序号和**自己专属的 PVC**（`volumeClaimTemplates`），删掉重建后，名字和盘都会回来。
- **RWO 卷的 Multi-Attach**：ReadWriteOnce 的卷同一时间只能挂在一个节点上，旧 Pod 不彻底退出，新 Pod 就起不来。生产中节点宕机时也会遇到，这时要靠 Longhorn 或 K8s 的 node-lease 机制强制解绑。
- Longhorn 把每个卷在多个节点上各存一份副本，所以 MongoDB 自己有 3 副本、Longhorn 每个卷再有多副本，两层冗余。

## 完整操作记录

以下都在 ops 上执行。

### 0. AWS 适配：数据盘设备名

**0.1 看课程脚本怎么用这块盘**

```bash
grep -nE "^DEVICE|^PARTITION|^MOUNT_POINT|sfdisk|mkfs|fstab" \
  /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/01_prepare_longhorn_disks.sh
```

```text
31:DEVICE="/dev/sdb"
32:PARTITION="/dev/sdb1"
33:MOUNT_POINT="/var/lib/longhorn"
54:  printf ',,L\n' | sfdisk "${DEVICE}" >/dev/null
63:  mkfs.ext4 -F -L LONGHORN "${PARTITION}" >/dev/null
74:fstab_line="UUID=${uuid} ${MOUNT_POINT} ext4 defaults 0 2"
```

**0.2 看 AWS 上的磁盘**

```bash
for n in wk-app01 wk-app02 wk-edge01 wk-obs01; do
  echo "== $n"
  ssh root@$n 'lsblk -dno NAME,SIZE,MODEL | grep -v loop' </dev/null
done
```

```text
== wk-app01
nvme1n1   30G Amazon Elastic Block Store
nvme0n1   30G Amazon Elastic Block Store
== wk-app02
nvme0n1   30G Amazon Elastic Block Store
nvme1n1   30G Amazon Elastic Block Store
...
```

两块都是 30 GB，看大小区分不了。**格式化之前必须确认哪块是系统盘**：

```bash
for n in wk-app01 wk-app02 wk-edge01 wk-obs01; do
  ssh root@$n 'bash -s' </dev/null <<'EOF'
root_disk=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)")     # 挂着 / 的分区属于哪块盘
data_parts=$(lsblk -no NAME /dev/nvme1n1 | wc -l)
echo "$(hostname): 系统盘=$root_disk  nvme1n1 的分区数=$((data_parts - 1))"
EOF
done
```

```text
wk-app01: 系统盘=nvme0n1  nvme1n1 的分区数=0
wk-app02: 系统盘=nvme0n1  nvme1n1 的分区数=0
wk-edge01: 系统盘=nvme0n1  nvme1n1 的分区数=0
wk-obs01: 系统盘=nvme0n1  nvme1n1 的分区数=0
```

确认 `nvme1n1` 是空的数据盘之后，再改脚本（先替换分区名，再替换设备名，顺序不能反）：

```bash
cd /docker_k8s_2026/k8s/04-storage-and-stateful/scripts
sed -i \
  -e 's#/dev/sdb1#/dev/nvme1n1p1#g' \
  -e 's#/dev/sdb#/dev/nvme1n1#g' \
  01_prepare_longhorn_disks.sh
grep -nE "^DEVICE|^PARTITION" 01_prepare_longhorn_disks.sh
```

```text
31:DEVICE="/dev/nvme1n1"
32:PARTITION="/dev/nvme1n1p1"
```

### 按课程顺序执行（01 → 02 → 03 → 04 → 05 → 08 → 07 → 06）

```bash
chmod +x *.sh
for s in 01_prepare_longhorn_disks.sh \
         02_prepare_longhorn_artifacts.sh \
         03_install_longhorn.sh \
         04_deploy_stateful_demo.sh \
         05_expand_longhorn_node.sh \
         08_deploy_statefulset_demo.sh \
         07_publish_longhorn_ui.sh \
         06_verify_storage.sh; do
  timeout 1500 bash "$s" > "/root/ch4-$s.log" 2>&1 </dev/null
  rc=$?
  echo "$s exit=$rc"
  [ $rc -ne 0 ] && { tail -20 "/root/ch4-$s.log"; break; }
done
```

### 01 准备数据盘（以 wk-app01 为例）

```text
节点：wk-app01
补齐 Longhorn 宿主机前提
提示: 当前节点未安装 nfs-common，Longhorn 会保留 RWX 相关前置告警，但不影响本章 RWO 演示
创建 /dev/nvme1n1 分区表与主分区
格式化 /dev/nvme1n1p1 为 ext4
mke2fs 1.47.0 (5-Feb-2023)
写入 /etc/fstab
挂载 /var/lib/longhorn
--- lsblk ---
NAME          SIZE FSTYPE   MOUNTPOINT
nvme1n1        30G
`-nvme1n1p1    30G ext4     /var/lib/longhorn         ← 数据盘
nvme0n1        30G
|-nvme0n1p1    29G ext4     /                         ← 系统盘没动
|-nvme0n1p15  106M vfat     /boot/efi
`-nvme0n1p16  913M ext4     /boot
--- df ---
/dev/nvme1n1p1   30G   24K   28G   1% /var/lib/longhorn
OK
首批 Longhorn 节点：wk-app01 wk-app02 wk-obs01
后续扩容节点：wk-edge01
OK: Longhorn 数据盘已准备完成
```

### 02 准备制品

```text
Longhorn 版本：1.11.0
MongoDB Chart 版本：15.6.0
[4/8] 下载 Longhorn 与 MongoDB Chart
[5/8] 生成 Longhorn 与 MongoDB 镜像列表、离线渲染清单
[6/8] 在 harbor 节点拉取并推送镜像
源镜像：longhornio/longhorn-engine:v1.11.0
目标镜像：harbor.qytk8s.com/longhornio/longhorn-engine:v1.11.0
源镜像：longhornio/longhorn-instance-manager:v1.11.0
目标镜像：harbor.qytk8s.com/longhornio/longhorn-instance-manager:v1.11.0
源镜像：longhornio/csi-provisioner:v5.3.0-20251226
...（Longhorn 一共十几个镜像，加上 MongoDB 和 busybox）
OK: 第四章存储制品预热完成
```

### 03 安装 Longhorn

```text
[2/6] 预创建并标记 longhorn-system 命名空间
[3/6] 标记首批 Longhorn 存储节点
标记 Longhorn 初始存储节点：wk-app01
node/wk-app01 labeled
node/wk-app01 annotated
标记 Longhorn 初始存储节点：wk-app02
标记 Longhorn 初始存储节点：wk-obs01
[4/6] Helm 安装 Longhorn
Release "longhorn" does not exist. Installing it now.
STATUS: deployed
Longhorn is now installed on the cluster!
[5/6] 等待 Longhorn 核心组件就绪
daemon set "longhorn-manager" successfully rolled out
deployment "longhorn-driver-deployer" successfully rolled out
deployment "longhorn-ui" successfully rolled out
pod/engine-image-ei-32e10da1-... condition met     （4 个）
pod/instance-manager-...         condition met     （4 个）
[6/6] 查看 Longhorn 初始状态
NAME                 PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION
longhorn (default)   driver.longhorn.io   Delete          Immediate           true
longhorn-static      driver.longhorn.io   Delete          Immediate           true
NAME        READY   ALLOWSCHEDULING   SCHEDULABLE
wk-app01    True    true              True
wk-app02    True    true              True
wk-edge01   True    true              True
wk-obs01    True    true              True
OK: Longhorn 已安装，首批 3 个存储节点已初始化
```

`longhorn (default)`：Longhorn 成了默认 StorageClass，以后 PVC 不写 `storageClassName` 就用它。

### 04 PVC 动态供给 + 数据保留（这里卡住了）

```text
[1/7] 创建演示命名空间与 PVC
namespace/qytang-stateful-demo created
persistentvolumeclaim/qytang-pvc-demo created
persistentvolumeclaim/qytang-pvc-demo condition met
[3/7] 部署 1 副本有状态演示工作负载
deployment.apps/qytang-deployment-volume-demo created
qytang-deployment-volume-demo-58fdb6fcb8-xcdsf   1/1   Running   10.244.0.217   wk-app01
[4/7] 写入演示数据
hello-from-longhorn-2026-11-24-184750
[5/7] 删除当前 Pod，验证 Deployment 自动重建
pod "qytang-deployment-volume-demo-58fdb6fcb8-xcdsf" deleted
Waiting for deployment "qytang-deployment-volume-demo" rollout to finish: 0 of 1 updated replicas are available...
（卡了 10 多分钟）
```

**排查**

```bash
NS=qytang-stateful-demo
kubectl -n $NS get pvc,pod -o wide
kubectl -n $NS get events --sort-by=.lastTimestamp | tail -8
kubectl -n longhorn-system get volumes.longhorn.io \
  -o custom-columns=NAME:.metadata.name,STATE:.status.state,ROBUST:.status.robustness,NODE:.status.currentNodeID
```

```text
persistentvolumeclaim/qytang-pvc-demo   Bound    pvc-93969310-...   2Gi   RWO   longhorn
pod/qytang-deployment-volume-demo-...-vkzcf   0/1   ContainerCreating   wk-app02     ← 新 Pod
pod/qytang-deployment-volume-demo-...-xcdsf   1/1   Terminating         wk-app01     ← 旧 Pod 删不掉

Warning   FailedAttachVolume   pod/...-vkzcf   Multi-Attach error for volume "pvc-93969310-..."
          Volume is already used by pod(s) qytang-deployment-volume-demo-58fdb6fcb8-xcdsf
Warning   FailedKillPod        pod/...-xcdsf   error killing pod: ... failed to stop container "5cc207a4...":
          unknown error after kill: runc did not terminate successfully: exit status 1:
          unable to signal init: permission denied

NAME                                       STATE      ROBUST    NODE
pvc-93969310-511b-44af-bb7a-c14cc5b78555   attached   healthy   wk-app01                ← 卷还挂在旧节点
```

去旧 Pod 所在的节点看内核日志：

```bash
ssh root@wk-app01 'bash -s' </dev/null <<'EOF'
runc --version | head -1
ls -l /etc/apparmor.d/runc
dmesg | grep -i 'apparmor="DENIED"' | grep -i signal | tail -2
EOF
```

```text
runc version 1.3.4-0ubuntu1~24.04.1
-rw-r--r-- 1 root root 334 Sep 19 01:52 /etc/apparmor.d/runc
[ 5482.590049] audit: type=1400 audit(...): apparmor="DENIED" operation="signal" class="signal"
  profile="cri-containerd.apparmor.d" pid=21415 comm="runc"
  requested_mask="receive" denied_mask="receive" signal=kill peer="runc"
```

解读：容器进程受 `cri-containerd.apparmor.d` 配置保护（containerd 1.7 生成的），这个配置只允许“不受限”的进程给它发信号；而 Ubuntu 24.04 的 runc 跑在自己的 `runc` AppArmor 配置下（`peer="runc"`），所以 kill 信号被拒绝。

**修复（7 个 K8s 节点）**

```bash
for n in cp01 cp02 cp03 wk-app01 wk-app02 wk-edge01 wk-obs01; do
  ssh root@$n 'bash -s' </dev/null <<'EOF'
apparmor_parser -R /etc/apparmor.d/runc 2>/dev/null || true      # 从内核卸载
ln -sf /etc/apparmor.d/runc /etc/apparmor.d/disable/runc           # 开机不再加载
echo "$(hostname): runc profile loaded? $(grep -c '^runc ' /sys/kernel/security/apparmor/profiles)"
EOF
done

sleep 30
kubectl get pods -A | grep -E "Terminating|ContainerCreating" || echo "(没有卡住的 Pod 了)"
```

```text
cp01: runc profile loaded? 0
...（7 个节点都是 0）
(没有卡住的 Pod 了)
```

修复后脚本自己继续往下跑，最终输出：

```text
[6/7] 在自动重建的新 Pod 中验证数据仍存在
旧 Pod: qytang-deployment-volume-demo-58fdb6fcb8-xcdsf
新 Pod: qytang-deployment-volume-demo-58fdb6fcb8-vkzcf
hello-from-longhorn-2026-11-24-184750                ← 新 Pod（在 wk-app02 上）读到了旧 Pod 写的数据
[7/7] 查看 PVC、PV 与当前运行状态
qytang-pvc-demo   Bound    pvc-93969310-511b-44af-bb7a-c14cc5b78555   2Gi   RWO   longhorn
pvc-93969310-...  2Gi   RWO   Delete   Bound   qytang-stateful-demo/qytang-pvc-demo   longhorn
qytang-deployment-volume-demo-58fdb6fcb8-vkzcf   1/1   Running   10.244.1.27   wk-app02
OK: 已验证 Deployment 自动重建的新 Pod 继续挂载原 PVC 并读到原有数据
```

Pod 从 wk-app01 换到了 wk-app02，数据跟着走：Longhorn 卷不绑定在某台机器上，新节点上的 Longhorn 会把卷挂过来。

### 05 扩容：wk-edge01 成为第 4 个存储节点

```text
[1/4] 为 wk-edge01 打 Longhorn 默认磁盘标签与注解
node/wk-edge01 labeled
node/wk-edge01 annotated
[2/4] 等待 Longhorn 自动识别 wk-edge01 的默认数据盘
Longhorn 已识别 wk-edge01 的数据盘：/var/lib/longhorn
[4/4] 查看 wk-edge01 详情
spec:
  allowScheduling: true
  disks:
    default-disk-2dc127db9bf52149:
      allowScheduling: true
      diskType: filesystem
      path: /var/lib/longhorn
OK: 已把 wk-edge01 初始化为第 4 个 Longhorn 存储节点
```

### 08 StatefulSet：MongoDB 副本集

```text
[2/5] 使用本地 Chart 与 Harbor 镜像安装 MongoDB ReplicaSet
Release "qytang-mongodb-demo" does not exist. Installing it now.
CHART VERSION: 15.6.0
APP VERSION: 7.0.9
MongoDB can be accessed on the following DNS name(s) and ports from within your cluster:
    qytang-statefulset-mongodb-demo-0.qytang-statefulset-mongodb-demo-headless.qytang-mongodb-demo.svc.cluster.local:27017
    qytang-statefulset-mongodb-demo-1.qytang-statefulset-mongodb-demo-headless.qytang-mongodb-demo.svc.cluster.local:27017
    qytang-statefulset-mongodb-demo-2.qytang-statefulset-mongodb-demo-headless.qytang-mongodb-demo.svc.cluster.local:27017
[3/5] 等待 StatefulSet 就绪
statefulset rolling update complete 3 pods at revision qytang-statefulset-mongodb-demo-76bc6c459c...
[4/5] 查看 Pod、PVC 与 Service
qytang-statefulset-mongodb-demo-0   1/1   Running   114s   10.244.3.101   wk-obs01      ← 按 0、1、2 的顺序依次创建
qytang-statefulset-mongodb-demo-1   1/1   Running   87s    10.244.2.2     wk-edge01
qytang-statefulset-mongodb-demo-2   1/1   Running   30s    10.244.0.78    wk-app01
datadir-qytang-statefulset-mongodb-demo-0   Bound   pvc-2c31d759-...   2Gi   RWO   longhorn
datadir-qytang-statefulset-mongodb-demo-1   Bound   pvc-b239b239-...   2Gi   RWO   longhorn
datadir-qytang-statefulset-mongodb-demo-2   Bound   pvc-11066f5c-...   2Gi   RWO   longhorn
qytang-statefulset-mongodb-demo-headless   ClusterIP   None   27017/TCP           ← Headless Service
OK: MongoDB ReplicaSet 已部署完成，后续请按文档执行手工 show 与删除恢复验证
```

- 每个 Pod 都有一个**固定的 DNS 名**：`<pod名>.<headless service>.<namespace>.svc.cluster.local`。副本集成员之间就是用这些名字互相找的。
- `CLUSTER-IP None` = Headless Service：不做负载均衡，DNS 直接返回每个 Pod 的 IP。

### 08 补充：手工验证（课程 08_statefulset_intro.md）

```bash
NS=qytang-mongodb-demo
MONGO_ROOT_PASSWORD=$(kubectl -n $NS get secret qytang-statefulset-mongodb-demo \
  -o jsonpath='{.data.mongodb-root-password}' | base64 -d)

rs_members() {
  kubectl -n $NS exec pod/qytang-statefulset-mongodb-demo-0 -c mongodb -- \
    mongosh admin -u root -p "$MONGO_ROOT_PASSWORD" --quiet \
    --eval 'rs.status().members.map(m => m.name.split(".")[0] + "=" + m.stateStr).join("  ")' </dev/null
}

echo "--- 副本集成员"
rs_members

echo "--- 删除 demo-1，等它重建"
kubectl -n $NS get pod qytang-statefulset-mongodb-demo-1 -o jsonpath='删除前 UID={.metadata.uid}{"\n"}'
kubectl -n $NS delete pod/qytang-statefulset-mongodb-demo-1 --wait=true
kubectl -n $NS wait --for=condition=Ready pod/qytang-statefulset-mongodb-demo-1 --timeout=900s
kubectl -n $NS get pod qytang-statefulset-mongodb-demo-1 \
  -o jsonpath='重建后 UID={.metadata.uid}  PVC={.spec.volumes[?(@.persistentVolumeClaim)].persistentVolumeClaim.claimName}{"\n"}'

sleep 10
echo "--- 重建后的副本集成员"
rs_members
```

```text
--- 副本集成员
qytang-statefulset-mongodb-demo-0=PRIMARY  qytang-statefulset-mongodb-demo-1=SECONDARY  qytang-statefulset-mongodb-demo-2=SECONDARY
--- 删除 demo-1，等它重建
删除前 UID=3f316054-2533-4a7f-a08f-8fc6bb3b5b9c
pod "qytang-statefulset-mongodb-demo-1" deleted
pod/qytang-statefulset-mongodb-demo-1 condition met
重建后 UID=0079f70d-cccd-4172-8351-649e152d4684  PVC=datadir-qytang-statefulset-mongodb-demo-1
--- 重建后的副本集成员
qytang-statefulset-mongodb-demo-0=PRIMARY  qytang-statefulset-mongodb-demo-1=SECONDARY  qytang-statefulset-mongodb-demo-2=SECONDARY
```

### 07 发布 Longhorn UI

```text
[2/9] 使用 Harbor CA 签发 Longhorn UI 证书
subject=... CN = longhorn.qytk8s.com
[3/9] 创建/更新 Kubernetes TLS Secret
secret/longhorn-qytk8s-com-tls created
[4/9] 为 Longhorn UI 增加专用 Gateway listener
gateway.gateway.networking.k8s.io/app-gateway replaced
已为 app-gateway 增加 longhorn 专用 http/https listener          ← 复用第 3 章的 app-gateway（VIP .60）
[5/9] 应用 Longhorn UI HTTPRoute/ReferenceGrant 清单
httproute.gateway.networking.k8s.io/longhorn-http-redirect created
httproute.gateway.networking.k8s.io/longhorn-https-backend created
referencegrant.gateway.networking.k8s.io/allow-gateway-demo-to-longhorn-frontend created
[7/9] 等待 Gateway 获取 MetalLB VIP
Gateway 地址已就绪：10.1.1.60
[8/9] 查看网关与路由状态
app-gateway   cilium   10.1.1.60   True   27m
app-http-redirect        ["app.qytk8s.com"]
app-https-backend        ["app.qytk8s.com"]
longhorn-http-redirect   ["longhorn.qytk8s.com"]
longhorn-https-backend   ["longhorn.qytk8s.com"]
OK: Longhorn UI 已可通过 https://longhorn.qytk8s.com 访问
```

`ReferenceGrant`：Gateway 的路由在 `gateway-demo` 命名空间，Longhorn UI 的 Service 在 `longhorn-system` 命名空间。Gateway API 默认**不允许跨命名空间引用**，要由被引用的一方（longhorn-system）明确授权。

### 06 最终验收

```text
[1/8] 查看 Kubernetes 节点               （7 个 Ready）
[2/8] 查看 Longhorn 组件                 （csi-attacher/provisioner/resizer/snapshotter 各 3 个，
                                           engine-image/instance-manager/csi-plugin/longhorn-manager 各 4 个，全部 Running）
[3/8] 查看 Longhorn 节点与磁盘          （4 个节点 READY/SCHEDULABLE 都是 True，磁盘路径 /var/lib/longhorn）
[4/8] 查看 StorageClass、PVC、PV
...
OK: 第四章 Longhorn 与有状态演示验收通过
```

## 笔记 / 疑问

（自己补充）
