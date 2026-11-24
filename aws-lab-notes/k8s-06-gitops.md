# K8s 第 6 章：GitOps（Gitea + Harbor + Argo CD）

- **状态：** ✅ 完成（包括发布演示和扩容演示）
- **日期：** 2026-11-24
- **课程原文：** [k8s/06-gitops-and-automation/docs/](../k8s/06-gitops-and-automation/docs/)

## 结果

| 步骤 | 结果 |
|---|---|
| 01–06 本地预览与素材检查 | ✅ ops 上用 Python venv 跑起 4 个服务，`02_verify_local_preview` 通过 |
| 07 Gitea | ✅ git 节点用 Docker Compose 起了 Gitea 1.25.4 + Postgres 17 |
| 08–10 建仓库、推代码 | ✅ `https://git.qytk8s.com/gitadmin/qytang-netdevops.git` |
| 11 构建镜像 | ✅ git 节点构建 4 个镜像推到 Harbor |
| 12 Argo CD v3.3.3 | ✅ 应用 `qytang-netdevops`：`Synced + Healthy` |
| 13 端到端验证 | ✅ |
| 14–15 正式域名 | ✅ `netdevops.qytk8s.com` → `.60`，`argocd.qytk8s.com` → `.50` |
| 16 发布演示 | ✅ 页面标题改成 `QYTANG NetDevOps（AWS lab v0.3.0）`，`frontend:v0.2.3 → v0.3.0` 自动上线 |
| 17 扩容演示 | ✅ `values-lab.yaml` 里 `frontend.replicaCount: 1 → 2`，约 10 秒后 2 个 Pod 分布在 wk-obs01、wk-edge01 |

**Gitea 里的提交历史**（每一行都是一次 GitOps 变更）：

```
2d52f9e feat(gitops): 调整业务服务副本数
ccb9b20 feat(gitops): 发布前端镜像v0.3.0
cc2ea47 feat(ui): 发布课堂演示代码 v0.3.0
```

## 和课程原版的区别

这一章没有 AWS 相关的改动，遇到的问题**全部来自“从零搭建”和“课程环境里的残留状态”不一样**。

**1. Harbor 的 `library` 项目里缺 6 个镜像**

07、11、12 步默认 Harbor 里已经有这些镜像，但课程里没有任何一步推送它们。课程的 harbor 虚拟机是“不要恢复快照”，一直保留着以前推过的镜像，所以课程环境里不会出问题。手工补齐：

```bash
# 在 harbor 节点：官方镜像 -> harbor.qytk8s.com/library/<名字>
docker.io/library/postgres:17          -> postgres:17
docker.io/gitea/gitea:1.25.4           -> gitea:1.25.4
docker.io/library/python:3.12-slim     -> python:3.12-slim
docker.io/library/redis:8.2.3-alpine   -> redis:8.2.3-alpine
quay.io/argoproj/argocd:v3.3.3         -> argocd:v3.3.3
ghcr.io/dexidp/dex:v2.43.0             -> dex:v2.43.0
```

**2. 镜像标签对不上：构建 `v0.1.0`，部署 `v0.2.3`**

- 11 号脚本默认 `IMAGE_TAG=v0.1.0`，但 Argo CD 用的 `deploy/helm/qytang-netdevops/values-lab.yaml` 写的是 `v0.2.3`，Pod 一直 `ImagePullBackOff`。
- 原因同上：老师的 Harbor 里保留着以前的 `v0.2.3`。
- 解决：`IMAGE_TAG=v0.2.3 bash 11_build_and_push_images_remote.sh`（脚本本来就支持这个变量，第 7 章也是这样调用的）。
- **容易误判的地方**：拉不存在的标签时，事件里报的是 `x509: certificate signed by unknown authority`，看起来像证书问题。实际原因是 containerd 在 `hosts.toml` 配的地址返回 404 后，又退回默认地址重试，而默认地址没配 CA。用 `crictl pull` 拉一个**存在的**标签就能确认证书没问题。

**3. 发布 / 扩容脚本检测不到改动**

16、17 号脚本用 `git status` 判断 `/docker_k8s_2026` 下有没有改动，课程里这个目录是 git clone 出来的。我是用 `git archive` 上传的，没有 `.git`。解决：在 ops 上 `git init` 并提交一次基线（课程文件 + AWS 适配改动），然后再修改页面或 values。

**4. 扩容脚本提前返回（课程脚本的小问题）**

17 号脚本 push 后马上看 Argo CD 状态，这时 Argo CD 还没发现新提交，显示的是**旧提交**的 `Synced + Healthy`，脚本就直接返回了（副本数还是 1）。实际约 10 秒后会收敛到 2。更严谨的写法是等 `status.sync.revision` 变成新提交的哈希以后再判断。

## 学到的

- **三个系统的职责边界**：Gitea 存“想要什么样”（代码 + values），Harbor 存“装好的集装箱”（镜像），Argo CD 负责“让集群变成 Git 里描述的样子”。发布和扩容都**只改 Git**，从头到尾没有直接 `kubectl edit`。
- **回滚就是 `git revert`**：Git 历史就是部署历史，上面三条提交随时可以回退。
- **镜像标签必须和配置一起管理**：第 2 个问题说明，如果“构建出来的标签”和“Git 里写的标签”靠人工对齐，迟早会出错。16 号脚本就是把“构建 → 回写标签 → 提交”自动串起来，避免这个问题。

## 完整操作记录

以下都在 ops 上执行。课程里的演示账号密码（Harbor `admin/Harbor12345`、Gitea `gitadmin/Gitea12345`、Argo CD `admin/Cisc0123`）都写在课程脚本里，这里照原样出现。

### 0. 预先处理：git 节点信任课程 CA

git 节点会装 Ubuntu 源里的 Docker 29，第 1 章的 `x509` 问题一定会再次出现，所以提前把 CA 加进系统信任：

```bash
scp -q /docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt \
  root@git:/usr/local/share/ca-certificates/qyt-harbor-ca.crt

ssh root@git 'update-ca-certificates 2>&1 | tail -1' </dev/null

# 不带 --cacert 也能访问 Harbor，说明系统已信任
ssh root@git 'curl -s -o /dev/null -w "git -> harbor https: %{http_code}\n" https://harbor.qytk8s.com/api/v2.0/health' </dev/null
```

```text
done.
git -> harbor https: 200
```

### 第一轮：按 `99_bootstrap_chapter6.sh` 的顺序执行

```bash
cd /docker_k8s_2026/k8s/06-gitops-and-automation/scripts
chmod +x *.sh

for s in 00_check_and_recover_cluster.sh \
         01_run_local_preview.sh 02_verify_local_preview.sh \
         03_verify_chapter6.sh 04_verify_docker_assets.sh \
         05_verify_gitops_assets.sh 06_verify_phase2_assets.sh \
         07_install_gitea_remote.sh 08_create_gitea_repo.sh 09_verify_gitea.sh \
         10_push_qytang_netdevops_repo.sh 11_build_and_push_images_remote.sh \
         12_install_argocd_and_sync.sh 13_verify_gitops_e2e.sh \
         14_publish_netdevops_https_domain.sh 15_configure_argocd_domain.sh; do
  timeout 1500 bash "$s" > "/root/ch6-$s.log" 2>&1 </dev/null
  rc=$?
  echo "$s exit=$rc  | $(tail -1 /root/ch6-$s.log | cut -c1-120)"
  [ $rc -ne 0 ] && { tail -20 "/root/ch6-$s.log"; break; }
done
```

```text
00_check_and_recover_cluster.sh exit=0  | OK: 第六章开始前，集群已可访问
01_run_local_preview.sh exit=0  |   http://10.1.1.201:8003/docs
02_verify_local_preview.sh exit=0  | OK: 本地预览链路正常
03_verify_chapter6.sh exit=0  | OK: 第六章第一阶段验收通过
04_verify_docker_assets.sh exit=0  | OK: Docker 化素材已就绪
05_verify_gitops_assets.sh exit=0  | OK: Helm 与 GitOps 素材已就绪
06_verify_phase2_assets.sh exit=0  | OK: 第六章第二阶段验收通过
07_install_gitea_remote.sh exit=1  | Error response from daemon: failed to resolve reference
                                     "harbor.qytk8s.com/library/postgres:17": ... not found
```

**01 本地预览**（在 ops 上直接用 Python 跑 4 个服务）

```text
启动 QYTANG NetDevOps 本地预览
[2/4] 检查虚拟环境
未找到 .venv，正在创建并安装依赖...
The virtual environment was not created successfully because ensurepip is not available.
需要安装 python3-venv，执行: apt install -y python3-venv           ← 脚本自动补装
The following NEW packages will be installed:
  python3-pip-whl python3-setuptools-whl python3-venv python3.12-venv
...
已后台启动，日志目录：/tmp/qytang_netdevops_local
本地预览已就绪
Win2019 访问地址：
  http://10.1.1.201:8080
API 文档地址：
  http://10.1.1.201:8001/docs
  http://10.1.1.201:8002/docs
  http://10.1.1.201:8003/docs
```

**02 验证本地预览**

```text
[1/5] 前端页面
OK: 检测到 QYTANG NetDevOps 页面
[2/5] 设备服务
{"status":"ok","service":"device-service"}
[3/5] 资源服务
{"status":"ok","service":"resource-service"}
[4/5] 审计服务
{"status":"ok","service":"audit-service"}
[5/5] Dashboard 汇总
{"total_devices":12,"online_devices":8,"interface_up_count":67,"recent_change_count":8,...}
OK: 本地预览链路正常
```

### 问题 1：Harbor `library` 缺镜像

```bash
# 07 号脚本要哪些镜像
grep -nE "_IMAGE=" 07_install_gitea_remote.sh

# 第 6、7 章所有引用的 Harbor 镜像
cd /docker_k8s_2026
grep -rhoE "harbor\.qytk8s\.com/[a-z0-9._/-]+:[A-Za-z0-9._-]+|harbor\.qytk8s\.com/[a-z0-9._/-]+" \
  k8s/06-gitops-and-automation/scripts k8s/06-gitops-and-automation/manifests \
  k8s/07-observability-and-tracing/scripts k8s/07-observability-and-tracing/manifests \
  apps/qytang-netdevops | sort -u

# 课程文档里有没有推送这些镜像的步骤
grep -rn "docker push harbor.qytk8s.com/library" k8s/06-gitops-and-automation/docs/*.md
```

```text
18:POSTGRES_IMAGE="harbor.qytk8s.com/library/postgres:17"
19:GITEA_IMAGE="harbor.qytk8s.com/library/gitea:${GITEA_VERSION}"

harbor.qytk8s.com/library/argocd:v3.3.3
harbor.qytk8s.com/library/dex:v2.43.0
harbor.qytk8s.com/library/gitea
harbor.qytk8s.com/library/postgres:17
harbor.qytk8s.com/library/python:3.12-slim
harbor.qytk8s.com/library/redis:8.2.3-alpine
harbor.qytk8s.com/qytang-netdevops/...（这 4 个由第 11 步构建）

（文档里没有推送 library 镜像的步骤）
```

补齐（在 harbor 节点上执行）：

```bash
ssh root@harbor 'bash -s' </dev/null <<'EOF'
set -e
docker login harbor.qytk8s.com -u admin -p Harbor12345 >/dev/null 2>&1

while read -r src dst; do
  docker pull -q "$src" >/dev/null
  docker tag "$src" "harbor.qytk8s.com/library/$dst"
  docker push -q "harbor.qytk8s.com/library/$dst" >/dev/null
  echo "pushed library/$dst  <- $src"
done <<'LIST'
docker.io/library/postgres:17              postgres:17
docker.io/gitea/gitea:1.25.4               gitea:1.25.4
docker.io/library/python:3.12-slim         python:3.12-slim
docker.io/library/redis:8.2.3-alpine       redis:8.2.3-alpine
quay.io/argoproj/argocd:v3.3.3             argocd:v3.3.3
ghcr.io/dexidp/dex:v2.43.0                 dex:v2.43.0
LIST
EOF
```

```text
pushed library/postgres:17  <- docker.io/library/postgres:17
pushed library/gitea:1.25.4  <- docker.io/gitea/gitea:1.25.4
pushed library/python:3.12-slim  <- docker.io/library/python:3.12-slim
pushed library/redis:8.2.3-alpine  <- docker.io/library/redis:8.2.3-alpine
pushed library/argocd:v3.3.3  <- quay.io/argoproj/argocd:v3.3.3
pushed library/dex:v2.43.0  <- ghcr.io/dexidp/dex:v2.43.0
```

### 第二轮：从 07 继续

```bash
cd /docker_k8s_2026/k8s/06-gitops-and-automation/scripts
for s in 07_install_gitea_remote.sh 08_create_gitea_repo.sh 09_verify_gitea.sh \
         10_push_qytang_netdevops_repo.sh 11_build_and_push_images_remote.sh \
         12_install_argocd_and_sync.sh 13_verify_gitops_e2e.sh \
         14_publish_netdevops_https_domain.sh 15_configure_argocd_domain.sh; do
  timeout 1500 bash "$s" > "/root/ch6-$s.log" 2>&1 </dev/null
  rc=$?
  echo "$s exit=$rc  | $(tail -1 /root/ch6-$s.log | cut -c1-120)"
  [ $rc -ne 0 ] && { tail -20 "/root/ch6-$s.log"; break; }
done
```

```text
07_install_gitea_remote.sh exit=0  | OK: Gitea 部署完成
08_create_gitea_repo.sh exit=0  | 仓库地址：https://git.qytk8s.com/gitadmin/qytang-netdevops.git
09_verify_gitea.sh exit=0  | OK: Gitea 验证通过
10_push_qytang_netdevops_repo.sh exit=0  | OK: 已同步最新应用内容到 https://git.qytk8s.com/gitadmin/qytang-netdevops.git
11_build_and_push_images_remote.sh exit=0  | OK: 四个镜像已推送到 Harbor，标签为 v0.1.0
12_install_argocd_and_sync.sh exit=1  | 当前状态: sync=Synced health=Progressing   ← 超时
```

**07 安装 Gitea**（git 节点，Docker Compose）

```text
[3/6] 生成 Git 服务端证书
[4/6] 生成 Gitea docker compose
[6/6] 在 git 节点安装 Gitea
[git 1/6] 安装 Docker 与 docker compose
docker.io is already the newest version (29.1.3-0ubuntu3~24.04.2).
[git 3/6] 启动 Gitea 与 Postgres
Status: Downloaded newer image for harbor.qytk8s.com/library/postgres:17
Status: Downloaded newer image for harbor.qytk8s.com/library/gitea:1.25.4
 Container gitea-postgres  Started
 Container gitea  Started
OK: Gitea 部署完成
```

**09 验证 Gitea**

```text
[1/3] 访问首页
HTTP/2 200
[2/3] 查看版本接口
{"version":"1.25.4"}
[3/3] 查看 git 节点上的容器
gitea            Up 6 seconds              0.0.0.0:2222->22/tcp, 0.0.0.0:443->3000/tcp
gitea-postgres   Up 11 seconds (healthy)   5432/tcp
OK: Gitea 验证通过
```

**10 首次推送代码到 Gitea**

```text
[main (root-commit) 929a606] feat(gitops): 推送QYTANG NetDevOps教学仓库
 create mode 100644 deploy/helm/qytang-netdevops/templates/postgres.yaml
 ...
 * [new branch]      main -> main
OK: 已同步最新应用内容到 https://git.qytk8s.com/gitadmin/qytang-netdevops.git
```

**11 在 git 节点构建 4 个镜像**

```text
[5/6] 预拉 Harbor 基础镜像 harbor.qytk8s.com/library/python:3.12-slim
[6/6] 构建并推送四个镜像
Step 1/8 : FROM harbor.qytk8s.com/library/python:3.12-slim
Successfully installed fastapi-0.165.0 opentelemetry-api-1.45.2 ... prometheus-client-0.26.0 sqlalchemy-2.1.9 uvicorn-0.54.0
Successfully tagged harbor.qytk8s.com/qytang-netdevops/frontend:v0.1.0
Successfully tagged harbor.qytk8s.com/qytang-netdevops/device-service:v0.1.0
Successfully tagged harbor.qytk8s.com/qytang-netdevops/resource-service:v0.1.0
Successfully tagged harbor.qytk8s.com/qytang-netdevops/audit-service:v0.1.0
OK: 四个镜像已推送到 Harbor，标签为 v0.1.0
```

### 问题 2：应用 Pod 拉不到镜像

```bash
kubectl get applications -n argocd \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

kubectl -n qytang-netdevops get pods -o wide
kubectl -n qytang-netdevops get events --sort-by=.lastTimestamp | grep -v Normal | tail -6
```

```text
NAME               SYNC     HEALTH
qytang-netdevops   Synced   Progressing

audit-service-6bdffb9648-glpzm     0/1   ImagePullBackOff   wk-edge01
device-service-65c8968458-n8hfc    0/1   ImagePullBackOff   wk-obs01
frontend-5fc89c755d-7wx8b          0/1   ErrImagePull       wk-app01
postgres-768454dc9d-2n6vm          1/1   Running            wk-app01
resource-service-998c97f75-hphbq   0/1   ErrImagePull       wk-obs01

Warning  Failed  pod/device-service-...  Failed to pull image "harbor.qytk8s.com/qytang-netdevops/device-service:v0.2.3":
  ... failed to do request: Head "https://harbor.qytk8s.com/v2/qytang-netdevops/device-service/manifests/v0.2.3":
  tls: failed to verify certificate: x509: certificate signed by unknown authority
```

看起来是证书问题，但在节点上直接拉一个存在的标签是成功的：

```bash
ssh root@wk-obs01 'bash -s' </dev/null <<'EOF'
grep -n 'config_path' /etc/containerd/config.toml
ls /etc/containerd/certs.d/harbor.qytk8s.com/
crictl pull harbor.qytk8s.com/qytang-netdevops/device-service:v0.1.0 2>&1 | tail -1
EOF
```

```text
160:      config_path = "/etc/containerd/certs.d"
ca.crt  hosts.toml
Image is up to date for sha256:747dd7893f0eb2d01531e265d229246e5a102992da087b59e893f21dbd933ef0
```

真正的问题是**标签**：部署要 `v0.2.3`，构建出来的是 `v0.1.0`。containerd 在 `hosts.toml` 配的地址上找不到 `v0.2.3`，就退回默认地址再试一次，默认地址没配 CA，最后报出来的才是 x509。

```bash
cd /docker_k8s_2026
grep -rn "tag: v" apps/qytang-netdevops --include=*.yaml
grep -n "IMAGE_TAG=" k8s/06-gitops-and-automation/scripts/11_build_and_push_images_remote.sh
```

```text
apps/qytang-netdevops/deploy/gitops/lab/values-lab.yaml:11:    tag: v0.1.0
apps/qytang-netdevops/deploy/helm/qytang-netdevops/values-lab.yaml:13:    tag: v0.2.3     ← Argo CD 实际用的
apps/qytang-netdevops/deploy/helm/qytang-netdevops/values.yaml:18:    tag: v0.2.3
10:IMAGE_TAG="${IMAGE_TAG:-v0.1.0}"                                                       ← 构建默认
```

用 `v0.2.3` 重新构建，再删掉卡住的 Pod：

```bash
cd /docker_k8s_2026/k8s/06-gitops-and-automation/scripts
IMAGE_TAG=v0.2.3 bash 11_build_and_push_images_remote.sh > /root/ch6-11_build_v0.2.3.log 2>&1 </dev/null
tail -1 /root/ch6-11_build_v0.2.3.log

NS=qytang-netdevops
kubectl -n $NS get pods --no-headers \
  | awk '$3 != "Running" {print $1}' \
  | xargs -r kubectl -n $NS delete pod --wait=false

kubectl -n $NS get pods -o wide --no-headers | awk '{print $1, $2, $3, $7}'
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
```

```text
OK: 四个镜像已推送到 Harbor，标签为 v0.2.3
audit-service-6bdffb9648-rv46l 1/1 Running wk-edge01
device-service-65c8968458-g422r 1/1 Running wk-obs01
frontend-5fc89c755d-2dc6g 1/1 Running wk-obs01
postgres-768454dc9d-2n6vm 1/1 Running wk-app01
resource-service-998c97f75-scxlk 1/1 Running wk-app01
NAME               SYNC     HEALTH
qytang-netdevops   Synced   Healthy
```

### 第三轮：12–17

```bash
for s in 12_install_argocd_and_sync.sh 13_verify_gitops_e2e.sh \
         14_publish_netdevops_https_domain.sh 15_configure_argocd_domain.sh; do
  timeout 1500 bash "$s" > "/root/ch6-$s.log" 2>&1 </dev/null
  echo "$s exit=$?  | $(tail -1 /root/ch6-$s.log | cut -c1-120)"
done
```

```text
12_install_argocd_and_sync.sh exit=0  | OK: Argo CD 与应用同步完成
13_verify_gitops_e2e.sh exit=0  | OK: GitOps 端到端验证通过
14_publish_netdevops_https_domain.sh exit=0  | OK: netdevops.qytk8s.com 已发布到 10.1.1.60
15_configure_argocd_domain.sh exit=0  | OK: argocd.qytk8s.com 已配置到 10.1.1.50
```

**12 安装 Argo CD 并同步**

```text
[1/10] 安装 Argo CD
[2/10] 预拉 Argo CD Harbor 镜像
deployment.apps/argocd-server serverside-applied
deployment.apps/argocd-repo-server serverside-applied
statefulset.apps/argocd-application-controller serverside-applied
...
[3/10] 配置 Gitea CA 信任                  ← Argo CD 拉 Gitea 仓库也要信任课程 CA
[5/10] 生成 Argo CD 正式域名证书
[7/10] 固定 argocd-server VIP
[8/10] 设置固定管理员密码并重启服务
[9/10] 创建 Application
application.argoproj.io/qytang-netdevops unchanged
[10/10] 等待应用同步完成
当前状态: sync=Synced health=Healthy
NAME            TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)
argocd-server   LoadBalancer   10.110.45.149   10.1.1.50     80:30202/TCP,443:30327/TCP
OK: Argo CD 与应用同步完成
```

**13 端到端验证**

```text
[1/6] 查看 Gitea 仓库
{"name":"qytang-netdevops","full_name":"gitadmin/qytang-netdevops","default_branch":"main","language":"Python",...}
[2/6] 查看 Harbor 项目与制品
qytang-netdevops/audit-service      artifact_count=2      ← v0.1.0 和 v0.2.3 两个版本
qytang-netdevops/resource-service   artifact_count=2
qytang-netdevops/device-service     artifact_count=2
qytang-netdevops/frontend           artifact_count=2
[3/6] 查看 Argo CD 应用状态
qytang-netdevops   Synced   Healthy   929a6063abb7c6152b578dc1d4bae7e56300dd0a   default
[4/6] 查看业务命名空间资源
pod/audit-service-...      1/1   Running   wk-edge01
pod/device-service-...     1/1   Running   wk-obs01
pod/frontend-...           1/1   Running   wk-obs01
pod/postgres-...           1/1   Running   wk-app01
pod/resource-service-...   1/1   Running   wk-app01
[5/6] 访问前端 Service（正式域名发布前验证）
{"total_devices":12,"online_devices":8,...}
[6/6] 输出 Argo CD 登录信息
Argo CD 域名: argocd.qytk8s.com -> 10.1.1.50
HTTP/1.1 200 OK
OK: GitOps 端到端验证通过
```

**14 发布 netdevops.qytk8s.com**（复用 `.60` 的 app-gateway）

```text
subject=... CN = netdevops.qytk8s.com
secret/netdevops-qytk8s-com-tls created
gateway.gateway.networking.k8s.io/app-gateway replaced
已将 NetDevOps listeners 增量注入 app-gateway，现有其他 listeners 保持不变
httproute.gateway.networking.k8s.io/netdevops-http-redirect created
httproute.gateway.networking.k8s.io/netdevops-https-backend created
referencegrant.gateway.networking.k8s.io/allow-gateway-demo-to-qytang-netdevops-frontend created
OK: netdevops.qytk8s.com 已发布到 10.1.1.60
```

### 发布演示（16）

第一次直接执行，报“没有检测到代码变更”。检查原因：

```bash
grep -n -A4 "^require_changes" 16_release_frontend_gitops.sh
```

```text
require_changes() {
  if [[ -z "$(git -C "${ROOT_DIR}" status --porcelain -- "apps/qytang-netdevops")" ]]; then
    echo "ERROR: 当前没有检测到代码变更。请先修改应用代码，再执行脚本。"
```

`/docker_k8s_2026` 不是 git 仓库（我是用 `git archive` 上传的），`git status` 永远是空的。建立基线：

```bash
cd /docker_k8s_2026
git init -q
git config user.name "ops"
git config user.email "ops@qytk8s.com"
git add -A          # .gitignore 里有 .venv/、data/、*.db，本地预览产生的文件不会进来
git commit -q -m "baseline: course files + AWS adaptations"
git log --oneline -1
echo "工作区是否干净: [$(git status --porcelain -- apps/qytang-netdevops)]"
```

```text
1b494df baseline: course files + AWS adaptations
工作区是否干净: []
```

按课程文档：改页面 → 指定版本 → 执行发布：

```bash
CA=/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt

echo "--- 发布前"
curl -s --cacert $CA https://netdevops.qytk8s.com/ | grep -o "<title>[^<]*</title>"

# 1. 改页面内容
sed -i 's#</title>#（AWS lab v0.3.0）</title>#' apps/qytang-netdevops/frontend/index.html
git status --porcelain -- apps/qytang-netdevops

# 2. 发布（文档说改脚本里的 VERSION，用环境变量传效果一样）
cd k8s/06-gitops-and-automation/scripts
VERSION=v0.3.0 bash 16_release_frontend_gitops.sh > /root/ch6-16_release.log 2>&1 </dev/null
grep -E "^\[[0-9]/7\]|OK|sync=|->|Successfully tagged" /root/ch6-16_release.log

echo "--- 发布后"
kubectl -n qytang-netdevops get deploy frontend -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
curl -s --cacert $CA https://netdevops.qytk8s.com/ | grep -o "<title>[^<]*</title>"
```

```text
--- 发布前
<title>QYTANG NetDevOps</title>
 M apps/qytang-netdevops/frontend/index.html
[1/7] 提交源码变更到 Gitea
[main cc2ea47] feat(ui): 发布课堂演示代码 v0.3.0
   929a606..cc2ea47  main -> main
[2/7] 在 git 节点构建并推送前端镜像 v0.3.0
Successfully tagged harbor.qytk8s.com/qytang-netdevops/frontend:v0.3.0
[3/7] 回写 GitOps tag 到 values
[4/7] 提交新的 GitOps tag
[main ccb9b20] feat(gitops): 发布前端镜像v0.3.0
 3 files changed, 3 insertions(+), 3 deletions(-)       ← values.yaml / values-lab.yaml / gitops/lab/values-lab.yaml
   cc2ea47..ccb9b20  main -> main
[5/7] 触发并观察 Argo CD 同步
sync=Synced health=Healthy image=harbor.qytk8s.com/qytang-netdevops/frontend:v0.2.3
sync=Synced health=Healthy image=harbor.qytk8s.com/qytang-netdevops/frontend:v0.3.0
[6/7] 输出观察命令
qytang-netdevops   Synced   Healthy   ccb9b20b697b733ccb9f97ea93f092702938091d   default
frontend   1/1   1   1   17m   frontend   harbor.qytk8s.com/qytang-netdevops/frontend:v0.3.0
[7/7] 验证页面
HTTP/1.1 200 OK
OK: 代码变更已通过 GitOps 发布完成
--- 发布后
harbor.qytk8s.com/qytang-netdevops/frontend:v0.3.0
<title>QYTANG NetDevOps（AWS lab v0.3.0）</title>
```

### 扩容演示（17）

```bash
cd /docker_k8s_2026
F=apps/qytang-netdevops/deploy/helm/qytang-netdevops/values-lab.yaml

# 先把上一步发布产生的 values 改动并入本地基线，免得混在一起
git add -A apps && git commit -q -m "release frontend v0.3.0"

echo "--- 修改前"; grep -n -A3 "^frontend:" $F

# 把 frontend 段里的 replicaCount: 1 改成 2
sed -i '/^frontend:/,/^[a-zA-Z]/ s/^\(  replicaCount:\) *1$/\1 2/' $F

echo "--- 修改后"; grep -n -A3 "^frontend:" $F
git status --porcelain -- $F

cd k8s/06-gitops-and-automation/scripts
bash 17_scale_frontend_gitops.sh > /root/ch6-17_scale.log 2>&1 </dev/null
grep frontendDesired /root/ch6-17_scale.log | tail -1
```

```text
--- 修改前
8:frontend:
9-  # 可以改：前端是无状态服务，课堂上最推荐先改这里。
10-  replicaCount: 1
--- 修改后
8:frontend:
9-  # 可以改：前端是无状态服务，课堂上最推荐先改这里。
10-  replicaCount: 2
 M apps/qytang-netdevops/deploy/helm/qytang-netdevops/values-lab.yaml
sync=Synced health=Healthy frontendDesired=1 frontendAvailable=1      ← 脚本在这时就返回了（旧提交的状态）
```

脚本返回得太早，自己再等一下实际收敛：

```bash
for i in $(seq 1 18); do
  r=$(kubectl -n qytang-netdevops get deploy frontend -o jsonpath='{.spec.replicas}/{.status.availableReplicas}')
  [ "$r" = "2/2" ] && break
  sleep 10
done
echo "frontend desired/available = $r（等了约 $((i*10)) 秒）"

kubectl -n qytang-netdevops get pods --no-headers -o wide | grep frontend | awk '{print $1, $3, $7}'

# Argo CD 同步到的提交 = Gitea 最新提交？
kubectl -n argocd get application qytang-netdevops -o jsonpath='{.status.sync.revision}{"\n"}'
ssh root@git 'docker exec -u git gitea sh -c "cd /data/git/repositories/gitadmin/qytang-netdevops.git && git log --oneline -3"' </dev/null
```

```text
frontend desired/available = 2/2（等了约 10 秒）
frontend-ccb9b8864-86pwj Running wk-obs01
frontend-ccb9b8864-xknrj Running wk-edge01
2d52f9e8d5c46a5387308aa9c9ff2f2dc6bc890a
2d52f9e feat(gitops): 调整业务服务副本数
ccb9b20 feat(gitops): 发布前端镜像v0.3.0
cc2ea47 feat(ui): 发布课堂演示代码 v0.3.0
```

### 收尾：停掉本地预览进程

```bash
bash 18_stop_local_preview.sh
```

## 笔记 / 疑问

（自己补充）
