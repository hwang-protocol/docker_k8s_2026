# Docker 第 3 章：常用命令

- **状态：** ✅ 完成
- **日期：** 2026-11-23
- **课程原文：** [docker/docker_3_cmd/docker_cmd.md](../docker/docker_3_cmd/docker_cmd.md)

## 做了什么

按课程的“一条完整操作链”顺序执行：search → pull → images → run → ps → logs → exec → inspect → stop/start/restart → rm → tag → push → save/load → rmi。

## 结果（节选）

| 命令 | 结果 |
|---|---|
| `docker search nginx` | 官方 `nginx`，21428 星 |
| `docker pull nginx:1.29.6` / `nginx:alpine` | 240 MB / 94.5 MB，alpine 版小很多 |
| `docker run -d -p 38080:80` + `curl` | `<title>Welcome to nginx!</title>` |
| 容器里的系统 | `Debian GNU/Linux 13 (trixie)`，和宿主机的 Ubuntu 无关 |
| `docker logs` | 能看到刚才 curl 的访问记录，来源 `172.17.0.1`（docker0 网桥） |
| `docker inspect -f ...` | `status=running ip=172.17.0.3`，端口映射 38080→80 |
| stop → start → restart | `exited` → `running` → `running` |
| `docker rm`（容器在运行） | 报错 `container is running`，要加 `-f` |
| `docker save` | 导出 63 MB 的 tar，`docker load` 可以恢复 |

## 和课程原版的区别

- **`docker push` 推到本机私有仓库 `localhost:5000`**，没有推到 Docker Hub（需要你自己的账号）。
- **`docker rmi nginx:1.29.6` 没有报“镜像被容器使用”**：因为这个镜像还有另一个标签（`localhost:5000/docker2026_nginx:1.29.6`），`rmi` 只删掉了这个标签名，镜像本身还在，所以不冲突。只有一个标签时，才会看到课程里说的报错。

## 完整操作记录

以下命令都在 `k8s-docker` 上执行，顺序就是课程的操作链。

### 1. search：搜索镜像

```bash
docker search --limit 3 nginx \
  --format "{{.Name}} stars={{.StarCount}} official={{.IsOfficial}}"

# docker search 看不到标签，标签要查 Docker Hub 的 API
curl -s "https://hub.docker.com/v2/repositories/library/nginx/tags/?page_size=5" \
  | python3 -c 'import sys, json; print([i["name"] for i in json.load(sys.stdin)["results"]])'
```

```text
nginx stars=21428 official=[OK]
nginx/nginx-ingress stars=124 official=
nginx/nginx-prometheus-exporter stars=53 official=
['trixie-perl', 'stable-alpine3.24-perl', 'stable-alpine-perl', 'perl', 'mainline-trixie-perl']
```

### 2–3. pull / images：拉取镜像、查看本地镜像

```bash
docker pull -q nginx:1.29.6
docker pull -q nginx:alpine

docker images nginx --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
```

```text
docker.io/library/nginx:1.29.6
docker.io/library/nginx:alpine
REPOSITORY   TAG       IMAGE ID       SIZE
nginx        alpine    fb4658584bd9   94.5MB
nginx        1.29.6    dec7a90bd097   240MB
```

alpine 版只有 94.5 MB，因为基础系统是 Alpine（musl libc），而 `1.29.6` 用的是 Debian。

### 4. run：运行容器

```bash
# 后台运行，宿主机 38080 映射到容器 80
docker run -d --name nginx-lab-demo -p 38080:80 nginx:1.29.6
sleep 1
curl -s http://127.0.0.1:38080 | grep -o "<title>.*</title>"

# 一次性容器：看容器里是什么系统，运行完自动删除（--rm）
docker run --rm nginx:1.29.6 sh -c "head -1 /etc/os-release; nginx -v"

# 带重启策略的容器（后面看 restart policy 用）
docker run -d --name mynginx -p 8080:80 --restart unless-stopped nginx:1.29.6
```

```text
<title>Welcome to nginx!</title>
PRETTY_NAME="Debian GNU/Linux 13 (trixie)"
nginx version: nginx/1.29.6
```

宿主机是 Ubuntu 24.04，容器里却是 Debian 13：容器带着自己的用户态文件系统，只和宿主机共用内核。

### 5. ps：查看运行中的容器

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

```text
NAMES            STATUS                  PORTS
mynginx          Up Less than a second   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
nginx-lab-demo   Up 1 second             0.0.0.0:38080->80/tcp, [::]:38080->80/tcp
registry         Up 50 seconds           0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp
```

### 6. logs：查看容器日志

```bash
curl -sI http://127.0.0.1:38080 | head -1
docker logs --tail 2 nginx-lab-demo
```

```text
HTTP/1.1 200 OK
172.17.0.1 - - [23/Nov/2026:14:26:15 +0000] "GET / HTTP/1.1" 200 896 "-" "curl/8.5.0" "-"
172.17.0.1 - - [23/Nov/2026:14:26:16 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/8.5.0" "-"
```

来源 IP 是 `172.17.0.1`，也就是 docker0 网桥的地址：宿主机发出的请求经过端口映射（DNAT）进入容器时，看起来像从网桥来的。

### 7. exec：在运行中的容器里执行命令

```bash
docker exec nginx-lab-demo ls /usr/share/nginx/html
```

```text
50x.html
index.html
```

### 8. inspect：查看容器详细信息

```bash
docker inspect -f \
  "status={{.State.Status}} ip={{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} ports={{json .NetworkSettings.Ports}}" \
  nginx-lab-demo
```

```text
status=running ip=172.17.0.3 ports={"80/tcp":[{"HostIp":"0.0.0.0","HostPort":"38080"},{"HostIp":"::","HostPort":"38080"}]}
```

### 9–11. stop / start / restart

```bash
docker stop nginx-lab-demo
docker inspect -f "{{.State.Status}}" nginx-lab-demo

docker start nginx-lab-demo
docker inspect -f "{{.State.Status}}" nginx-lab-demo

docker restart nginx-lab-demo
docker inspect -f "{{.State.Status}} restarted_at={{.State.StartedAt}}" nginx-lab-demo

# 重启策略
docker inspect -f "{{.HostConfig.RestartPolicy.Name}}" mynginx
```

```text
exited
running
running restarted_at=2026-11-23T14:26:16.889163411Z
unless-stopped
```

### 12. rm：删除容器

```bash
# 容器还在运行，直接删会报错
docker rm nginx-lab-demo

# -f 强制删除（先停再删）
docker rm -f nginx-lab-demo
```

```text
Error response from daemon: cannot remove container "nginx-lab-demo": container is running: stop the container before removing or force remove
nginx-lab-demo
```

### 13–14. tag / push：打标签并推送（推到本机私有仓库）

```bash
docker tag nginx:1.29.6 localhost:5000/docker2026_nginx:1.29.6
docker push -q localhost:5000/docker2026_nginx:1.29.6

# 查看私有仓库里有哪些镜像
curl -s localhost:5000/v2/_catalog
```

```text
localhost:5000/docker2026_nginx:1.29.6
 Info -> Not all multiplatform-content is present and only the available single-platform image was pushed
{"repositories":["docker2026_nginx","flask_in_centos_ubuntu"]}
```

那条 `Info`：`nginx:1.29.6` 在 Docker Hub 上是多架构镜像（amd64、arm64 等），本机只拉了 amd64 这一份，所以推送的也只有这一份。

### 15. save / load：导出、导入镜像文件（离线传输用）

```bash
cd /tmp
docker save -o nginx_1.29.6.tar localhost:5000/docker2026_nginx:1.29.6
ls -lh nginx_1.29.6.tar | awk '{print $5}'

docker rmi localhost:5000/docker2026_nginx:1.29.6
docker load -i nginx_1.29.6.tar
```

```text
63M
Loaded image: localhost:5000/docker2026_nginx:1.29.6
```

镜像在 `docker images` 里显示 240 MB，导出的 tar 只有 63 MB：`images` 显示的是解压后的大小，tar 里存的是压缩过的层。

### 16. rmi：删除镜像

```bash
# 这时 mynginx 还在用 nginx:1.29.6
docker rmi nginx:1.29.6

docker rm -f mynginx
docker rmi nginx:1.29.6

docker images --format "{{.Repository}}:{{.Tag}}"
rm -f /tmp/nginx_1.29.6.tar
```

```text
Untagged: nginx:1.29.6
Error response from daemon: No such image: nginx:1.29.6
localhost:5000/flask_in_centos_ubuntu:latest
qyt-error-app:latest
nginx:alpine
hello-world:latest
localhost:5000/docker2026_nginx:1.29.6
registry:2
```

- 第一次 `rmi` **没有报“被容器使用”**，而是只删除了 `nginx:1.29.6` 这个标签名（`Untagged`），因为同一个镜像还有另一个标签 `localhost:5000/docker2026_nginx:1.29.6`。
- 第二次 `rmi` 就找不到这个名字了。镜像本体仍然以另一个标签的形式存在。

## 笔记 / 疑问

（自己补充）
