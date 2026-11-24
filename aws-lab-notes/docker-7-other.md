# Docker 第 7 章：其他容器技术（Podman、nerdctl）

- **状态：** ✅ 完成
- **日期：** 2026-11-23
- **课程原文：** [docker/docker_7_other/README.md](../docker/docker_7_other/README.md)

## Podman

| 检查项 | 结果 |
|---|---|
| 版本 | podman 4.9.3，podman-compose 1.0.6（Ubuntu 24.04 软件源） |
| `run / ps / exec / logs / stop / rm` | 全部正常，命令和 docker 基本一样 |
| 没有守护进程 | 容器的父进程是 `conmon`，`conmon` 的父进程是 PID 1，**没有 dockerd 这样的常驻 daemon** |
| `podman compose up -d`（第 6 章基础项目） | ✅ 3 个服务都起来了，`curl :8080` 返回 `hits: 1` |

**细节：** `podman compose` 自己不实现 Compose，而是调用外部程序。这台机器装了 Docker 的 `docker compose`，所以它优先用了这个（输出格式和第 6 章一样），但容器是由 Podman 运行的。在没装 Docker 的机器上，它会改用 `podman-compose`。

## containerd + nerdctl

| 检查项 | 结果 |
|---|---|
| 版本 | nerdctl 2.2.1，buildkit v0.26.3 |
| `run / ps / exec / logs / stop / rm` | 全部正常 |
| 和 Docker 的关系 | 用的是**同一个 containerd**，但在不同的命名空间：nerdctl 用 `default`，Docker 用 `moby`，所以 `docker ps` 和 `nerdctl ps` 互相看不到对方的容器 |
| `nerdctl compose up -d` | ✅ 先启动 `buildkitd` 来构建 app 镜像，3 个服务都起来了，`hits: 1` |

## 和课程原版的区别

- **端口改成了 18080**，因为 8080 当时被别的实验占着，课程用的是 8080。
- **CNI 网络插件：** 课程只解压了 `nerdctl`、`buildkitd`、`buildctl` 三个文件，但 nerdctl 运行容器还需要 CNI 网络插件。这台机器上刚好有，是安装 Podman 时一起装的（`/usr/lib/cni`）。**如果在没装 Podman 的干净机器上只按课程解压这三个文件，可能会因为缺少 CNI 插件而启动不了容器**，到时需要把 full 包里的 `libexec/cni` 也解压出来。这一点没有单独验证。

## 学到的

- Docker、Podman、nerdctl 的命令几乎一样，镜像格式也通用（都是 OCI 标准）。
- 区别主要在架构：Docker 有守护进程 dockerd；Podman 没有守护进程；nerdctl 直接操作 containerd。
- K8s 用的就是 containerd，所以 nerdctl 的这套思路和后面 K8s 章节关系更紧。

## 完整操作记录

以下命令都在 `k8s-docker` 上以 root 执行（`sudo -i`）。

### Podman

**1. 安装**

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y podman podman-compose

podman --version
podman-compose --version | tail -1
```

```text
podman version 4.9.3
podman-compose version 1.0.6
```

**2. 基本命令（和 docker 一样）**

```bash
podman pull -q docker.io/library/nginx:latest
podman run -d --name web -p 18080:80 docker.io/library/nginx:latest
sleep 1

podman ps --format "{{.Names}} {{.Status}} {{.Ports}}"
curl -s localhost:18080 | grep -o "<title>.*</title>"
```

```text
web Up 1 second 0.0.0.0:18080->80/tcp
<title>Welcome to nginx!</title>
```

**3. 没有守护进程：容器的父进程是谁**

```bash
# conmon 是 Podman 给每个容器配的“看护进程”，它的父进程是 PID 1（systemd）
ps -o pid,ppid,comm -C conmon | tail -1
```

```text
  15668       1 conmon
```

对比 Docker：容器进程的父进程是 `containerd-shim`，背后有常驻的 `dockerd` + `containerd`。Podman 没有常驻的守护进程，`podman` 命令执行完就退出了。

**4. exec / logs / stop / rm**

```bash
podman exec web nginx -v </dev/null
podman logs web 2>&1 | tail -1
podman stop -t 2 web
podman rm web
```

```text
nginx version: nginx/1.31.9
10.88.0.1 - - [23/Nov/2026:14:41:33 +0000] "GET / HTTP/1.1" 200 896 "-" "curl/8.5.0" "-"
web
```

访问来源是 `10.88.0.1`：Podman 默认网络是 `10.88.0.0/16`，Docker 是 `172.17.0.0/16`。

**5. 用 Podman 跑第 6 章的 Compose 项目**

```bash
cd /docker_k8s_2026/docker/docker_6_compose/lab/basic

podman compose up -d </dev/null
sleep 15
podman compose ps </dev/null | tail -4
curl -s http://127.0.0.1:8080/
echo

podman compose down -v </dev/null
podman ps -a --format "{{.Names}}" | wc -l
```

```text
 Container basic-app-1 Healthy
 Container basic-nginx-1 Started
NAME            IMAGE                                  COMMAND                  SERVICE   STATUS
basic-app-1     docker.io/library/basic-app:latest     "python /app/app.py"     app       Up 27 seconds
basic-nginx-1   docker.io/library/nginx:1.29.1         "nginx -g daemon off;"   nginx     Up 15 seconds   80/tcp
basic-redis-1   docker.io/library/redis:8.2.3-alpine   "redis-server --appe…"   redis     Up 27 seconds
{"app_env":"prod","app_name":"compose-basic-demo","cache_host":"redis","cache_port":6379,"hits":1}
0
```

输出格式和 `docker compose` 一模一样（`Container ... Healthy`），因为 `podman compose` 发现机器上装了 `docker compose`，就调用了它，但容器实际是由 Podman 运行的。

### containerd + nerdctl

**1. 按课程下载 full 包，只解压 3 个文件**

```bash
cd /tmp
curl -fsSL -o nerdctl-full-2.2.1-linux-amd64.tar.gz \
  https://github.com/containerd/nerdctl/releases/download/v2.2.1/nerdctl-full-2.2.1-linux-amd64.tar.gz
ls -lh nerdctl-full-2.2.1-linux-amd64.tar.gz | awk '{print $5}'

tar -xzf nerdctl-full-2.2.1-linux-amd64.tar.gz -C /usr/local \
  bin/nerdctl bin/buildkitd bin/buildctl

nerdctl --version
buildkitd --version
buildctl --version
```

```text
265M
nerdctl version 2.2.1
buildkitd github.com/moby/buildkit v0.26.3 c70e8e666f8f6ee3c0d83b20c338be5aedeaa97a
buildctl github.com/moby/buildkit v0.26.3 c70e8e666f8f6ee3c0d83b20c338be5aedeaa97a
```

**2. 基本命令**

```bash
nerdctl pull -q nginx:latest
nerdctl run -d --name web -p 18080:80 nginx:latest
sleep 1

nerdctl ps --format "{{.Names}} {{.Status}} {{.Ports}}"
curl -s localhost:18080 | grep -o "<title>.*</title>"
nerdctl exec web nginx -v </dev/null
nerdctl logs web 2>&1 | tail -1
```

```text
web Up 0.0.0.0:18080->80/tcp
<title>Welcome to nginx!</title>
nginx version: nginx/1.31.9
10.4.0.1 - - [23/Nov/2026:14:43:27 +0000] "GET / HTTP/1.1" 200 896 "-" "curl/8.5.0" "-"
```

**3. 和 Docker 共用一个 containerd，但在不同的命名空间**

```bash
nerdctl namespace ls

# CNI 网络插件是从哪来的
ls -d /opt/cni/bin /usr/lib/cni 2>/dev/null

nerdctl stop -t 2 web
nerdctl rm web
```

```text
NAME            CONTAINERS    IMAGES    VOLUMES    LABELS
default         1             1         0               ← nerdctl 的容器
moby            5             13        0               ← Docker 的容器和镜像
moby_history    0             0         0
/usr/lib/cni                                            ← 装 Podman 时一起装的
```

所以 `docker ps` 看不到 nerdctl 起的容器，反过来也一样。K8s 用 containerd 时用的是第三个命名空间 `k8s.io`。

**4. nerdctl compose（需要 buildkitd 来构建 app 镜像）**

```bash
# 启动 BuildKit 守护进程
mkdir -p /run/buildkit
nohup buildkitd --addr unix:///run/buildkit/buildkitd.sock >/tmp/buildkitd.log 2>&1 &
sleep 3

cd /docker_k8s_2026/docker/docker_6_compose/lab/basic
nerdctl compose up -d </dev/null
sleep 20
nerdctl compose ps </dev/null
curl -s http://127.0.0.1:8080/
echo

nerdctl compose down -v </dev/null
nerdctl ps -a -q | wc -l

pkill buildkitd
```

```text
NAME             IMAGE                                   COMMAND                   SERVICE    STATUS     PORTS
basic-nginx-1    docker.io/library/nginx:1.29.1          "/docker-entrypoint.…"    nginx      running    0.0.0.0:8080->80/tcp
basic-app-1      docker.io/library/basic-app:latest      "python /app/app.py"      app        running
basic-redis-1    docker.io/library/redis:8.2.3-alpine    "docker-entrypoint.s…"    redis      running
{"app_env":"prod","app_name":"compose-basic-demo","cache_host":"redis","cache_port":6379,"hits":1}
0
```

`nerdctl compose up` 的日志里能看到，它其实是把 compose 文件翻译成一条条 `nerdctl run ...` 命令来执行的，比如：

```text
nerdctl run -d --name=basic-nginx-1 --net=basic_frontend --net=basic_backend \
  -p=8080:80/tcp --restart=unless-stopped \
  -v=/docker_k8s_2026/.../nginx/default.conf:/etc/nginx/conf.d/default.conf:ro nginx:1.29.1
```

## 笔记 / 疑问

（自己补充）
