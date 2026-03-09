# 第 2 步：部署 Harbor 私有镜像仓库

## 本步目标

在 `harbor` 节点部署一套可用的 Harbor 私有镜像仓库，为后续 Kubernetes 基础镜像、本课程自己的业务镜像和 Helm Chart 制品提供本地存储位置。

这一步完成后，我们希望达到下面的状态：

- `harbor.qytk8s.com` 可以访问
- `harbor` 节点已经安装 `Docker` 和 `docker compose`
- Harbor 核心组件已经启动
- Harbor 使用 HTTPS
- 我们已经拥有一套本课程自己的 Harbor CA 和 Harbor 服务端证书

## 执行标记

- **执行标记：条件执行**

说明：

- 如果你恢复的是“第一章起点快照”，这一步需要执行
- 如果 Harbor 已经保留，并且 `https://harbor.qytk8s.com` 正常可访问，这一步可以不重复执行，只做验证

## 为什么本章先部署 Harbor

因为这门课的目标之一，是让后续尽量减少对公网镜像仓库的依赖。

如果先把 Harbor 建好，后面就可以把这些镜像尽量提前推送到本地：

- `kube-apiserver`
- `kube-controller-manager`
- `kube-scheduler`
- `kube-proxy`
- `pause`
- `etcd`
- `coredns`

这样后续的 `kubeadm init` 和节点加入过程会更可控，也更符合生产思路。

## 本步使用的固定参数

为了保证可复现性，这一步统一写死下面这些参数：

- Harbor 域名：`harbor.qytk8s.com`
- Harbor 节点：`harbor`
- Harbor 版本：`v2.13.0`
- Harbor 管理员账号：`admin`
- Harbor 管理员密码：`Harbor12345`

## 证书设计说明

这一步不使用外部商业证书，而是采用课程内部自建 CA 的方式：

1. 在 `ops` 上生成 Harbor 根 CA
2. 在 `ops` 上签发 `harbor.qytk8s.com` 的服务端证书
3. 把证书下发到 `harbor` 节点
4. Harbor 使用这套证书提供 HTTPS 服务

这样做有两个好处：

- 后续可以把同一个 CA 分发给 Kubernetes 节点，让 `containerd` 信任 Harbor
- 课程环境完全自洽，不依赖外部证书服务

## 对应脚本

本步对应脚本：

- `k8s/01-k8s-architecture/scripts/02_install_harbor_remote.sh`

这个脚本完成的事情包括：

1. 在 `ops` 上准备证书目录
2. 生成 Harbor CA 与 Harbor 服务端证书
3. 下载 Harbor Offline Installer
4. 将安装包和证书分发到 `harbor` 节点
5. 在 `harbor` 节点安装 `docker.io` 和 `docker-compose-v2`
6. 配置 Harbor HTTPS
7. 执行 Harbor 安装

## 执行命令

先给脚本增加执行权限：

```bash
chmod +x /docker_k8s_2026/k8s/01-k8s-architecture/scripts/02_install_harbor_remote.sh
```

然后执行脚本：

```bash
bash /docker_k8s_2026/k8s/01-k8s-architecture/scripts/02_install_harbor_remote.sh
```

## 你会看到什么

正常情况下，输出会分成四个阶段：

```text
[1/4] 准备本地目录
[2/4] 生成 Harbor CA 与服务端证书
[3/4] 下载 Harbor Offline Installer
[4/4] 在 harbor 节点安装 Harbor
```

最后应该看到 Harbor 容器名称列表，以及：

```text
OK: Harbor 部署完成
```

## 执行后的验证

### 验证 1：检查 Harbor 节点上的容器状态

```bash
ssh root@harbor "docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

预期：

- 可以看到 `harbor-core`
- 可以看到 `harbor-db`
- 可以看到 `harbor-portal`
- 可以看到 `registry`
- 可以看到 `nginx`

### 验证 2：检查 Harbor 健康接口

```bash
curl -k https://harbor.qytk8s.com/api/v2.0/health
```

预期：

- 返回 JSON 结果
- `status` 为 `healthy`

### 验证 3：检查 Harbor Web 页面

在浏览器中访问：

- `https://harbor.qytk8s.com`

使用以下账号登录：

- 用户名：`admin`
- 密码：`Harbor12345`

## 本步完成标准

只要满足下面条件，就可以进入下一步：

- Harbor 容器全部正常启动
- `https://harbor.qytk8s.com` 可访问
- 管理员账号可以登录
- Harbor 健康接口返回正常

## 下一步

下一步进入 Kubernetes 基础镜像预热：

- `docs/04_push_k8s_images.md`
