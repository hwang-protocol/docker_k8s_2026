# Docker 第 6 章：Docker Compose

- **状态：** ✅ 完成（基础实验 + TLS/ELK 实验）
- **日期：** 2026-11-23
- **课程原文：** [docker/docker_6_compose/](../docker/docker_6_compose/)

## 实验 1：基础实验（nginx + Flask app + redis）

| 检查项 | 结果 |
|---|---|
| `docker compose config` | ✅ 通过 |
| 启动顺序 | redis 健康 → app 健康 → nginx 启动（`depends_on` + `healthcheck`） |
| `curl http://127.0.0.1:8080/` 三次 | `hits` 依次为 1、2、3 |
| app 以什么用户运行 | `uid=10001(appuser)`，不是 root |
| 服务发现 | app 容器里解析 `redis` → `172.19.0.2`（Compose 内置 DNS） |
| 网络隔离 | 两个网络 `basic_frontend`、`basic_backend`；宿主机连不上 redis 的 6379，因为没有发布端口 |
| `down` 再 `up` | `hits` 变成 4，**数据保存在具名卷里** |
| `down -v` | 卷被删除 |

## 实验 2：TLS + ELK + Nginx

| 服务 | 状态 |
|---|---|
| cert-init | Exited (0)，生成了 4 张证书 |
| elasticsearch | Up (healthy) |
| kibana-auth-init | Exited (0)，`kibana_system password updated` |
| kibana | Up (healthy) |
| nginx | Up |
| filebeat | Up |

镜像总共约 4.7 GB（Elasticsearch 和 Kibana 各约 2 GB），机器内存用了约 2.9 GB。

| 验证项 | 结果 |
|---|---|
| 16.3 HTTPS 首页 `https://www.qytdocker2026.com/` | HTTP 200，证书用课程 CA 校验通过（`ssl_verify=0`），标题“首页 - Compose TLS Demo” |
| 16.4 经 Nginx 反代访问 Kibana | HTTP 200，跳转到 `/login?next=%2F`，就是登录页 |
| 证书 SAN | `DNS:www.qytdocker2026.com, DNS:nginx` |
| 16.5 Nginx 日志写入共享卷 | `access-compose.log` 里有访问记录（含一次 404） |
| 16.6 Filebeat 看到同一个文件 | 内容一致 ✅ |
| 16.7 日志进入 Elasticsearch | 索引 `.ds-filebeat-8.19.0-2026.11.23-000001`，8 条 |

## 和课程原版的区别

- **16.3、16.4 没用 Windows 浏览器访问**，而是在实验机上用 `curl --resolve` 把域名指到 127.0.0.1，并用课程 CA 校验证书，效果一样。要在你的浏览器里看，需要：① 开一条 SSH 隧道把 443 端口带到你电脑；② 改 Windows 的 `hosts`，把两个域名指到 `127.0.0.1`；③ 信任课程的根证书 `docker/docker_6_compose/certs/ca.cer`。后两步会改系统设置，要先征得你同意。
- **16.7 没在 Kibana 网页里建 Data View**，改用 Elasticsearch API 确认日志已经写进去。
- ELK 目前**还在运行**，方便你去浏览器里看；不看的话执行 `docker compose down -v` 清理。

## 完整操作记录

以下命令都在 `k8s-docker` 上执行。

### 实验 1：基础实验（nginx + Flask app + redis）

**1.1 检查配置并启动**

```bash
cd /docker_k8s_2026/docker/docker_6_compose/lab/basic

# 只校验语法，不输出展开后的配置
docker compose config --quiet && echo "config OK"

# --build：构建 app 镜像；--wait：等所有服务健康后才返回
docker compose up -d --build --wait

docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
```

```text
config OK
 Container basic-app-1 Waiting
 Container basic-redis-1 Waiting
 Container basic-nginx-1 Waiting
 Container basic-redis-1 Healthy        ← 先 redis
 Container basic-app-1 Healthy          ← 再 app（depends_on: redis healthy）
 Container basic-nginx-1 Healthy        ← 最后 nginx
SERVICE   STATUS                    PORTS
app       Up 6 seconds (healthy)    5000/tcp
nginx     Up Less than a second     0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
redis     Up 16 seconds (healthy)   6379/tcp
```

只有 nginx 把端口发布到了宿主机（`0.0.0.0:8080`），app 和 redis 只暴露在 compose 内部网络里。

**1.2 访问三次，计数递增**

```bash
for i in 1 2 3; do
  curl -s http://127.0.0.1:8080/
  echo
done

docker compose logs --tail=3 app nginx redis
```

```text
{"app_env":"prod","app_name":"compose-basic-demo","cache_host":"redis","cache_port":6379,"hits":1}
{"app_env":"prod","app_name":"compose-basic-demo","cache_host":"redis","cache_port":6379,"hits":2}
{"app_env":"prod","app_name":"compose-basic-demo","cache_host":"redis","cache_port":6379,"hits":3}

app-1    | 172.19.0.4 - - [23/Nov/2026 14:29:05] "GET / HTTP/1.0" 200 -
redis-1  | 1:M 23 Nov 2026 14:28:48.733 * Ready to accept connections tcp
nginx-1  | 172.19.0.1 - - [23/Nov/2026:14:29:05 +0000] "GET / HTTP/1.1" 200 99 "-" "curl/8.5.0" "-"
```

请求链路：curl → nginx（8080）→ app（5000，日志里来源是 nginx 的 IP `172.19.0.4`）→ redis 计数。

**1.3 app 以什么用户运行**

```bash
docker compose exec -T app id
```

```text
uid=10001(appuser) gid=10001 groups=10001
```

**1.4 服务发现和网络隔离**

```bash
# app 容器里解析服务名 redis
docker compose exec -T app python -c "import socket; print('redis ->', socket.gethostbyname('redis'))" </dev/null

# 宿主机能不能连 redis 的 6379？（没有发布端口）
(echo > /dev/tcp/127.0.0.1/6379) 2>/dev/null \
  && echo "host reaches 6379" \
  || echo "host cannot reach 6379 (not published)"

docker network ls --filter name=basic --format "{{.Name}}"
```

```text
redis -> 172.19.0.2
host cannot reach 6379 (not published)
basic_backend
basic_frontend
```

Compose 自带 DNS：同一网络里的容器用**服务名**就能互相访问，不需要知道 IP。

**1.5 down 再 up，数据还在（具名卷）**

```bash
docker compose down
docker compose up -d --wait
curl -s http://127.0.0.1:8080/
echo
```

```text
{"app_env":"prod","app_name":"compose-basic-demo","cache_host":"redis","cache_port":6379,"hits":4}
```

`down` 删除了容器和网络，但 redis 的数据卷 `redisdata` 还在，所以计数接着从 4 开始。

**1.6 `down -v` 连卷一起删**

```bash
docker compose down -v
docker volume ls -q | grep redisdata || echo "redisdata removed"
```

```text
redisdata removed
```

### 实验 2：TLS + ELK + Nginx

**2.1 启动**

```bash
cd /docker_k8s_2026/docker/docker_6_compose/lab/elastic_tls

docker compose config --quiet && echo "config OK"
docker compose up -d --quiet-pull

# 不要用 --wait（原因见下面“遇到的坑”），过几分钟看状态
docker compose ps -a --format "table {{.Service}}\t{{.Status}}"

docker images --format "{{.Repository}}:{{.Tag}} {{.Size}}" | grep -E "elastic|kibana|filebeat"
free -h | sed -n 2p
```

```text
config OK
SERVICE            STATUS
cert-init          Exited (0) 8 minutes ago     ← 一次性任务：生成证书后正常退出
elasticsearch      Up 8 minutes (healthy)
filebeat           Up 5 minutes
kibana             Up 6 minutes (healthy)
kibana-auth-init   Exited (0) 6 minutes ago     ← 一次性任务：设置 kibana_system 密码
nginx              Up 5 minutes

docker.elastic.co/elasticsearch/elasticsearch:8.19.0 2.08GB
docker.elastic.co/kibana/kibana:8.19.0 2.09GB
docker.elastic.co/beats/filebeat:8.19.0 560MB
Mem:           7.6Gi       2.9Gi       382Mi       3.2Mi       4.7Gi       4.7Gi
```

**2.2 两个初始化任务的日志、证书内容（课程 16.2）**

```bash
docker compose logs --no-log-prefix cert-init kibana-auth-init | tail -7

openssl x509 -in certs/generated/nginx/tls.crt -noout -subject -ext subjectAltName
```

```text
setting kibana_system password
kibana_system password updated
generating certificate for www.qytdocker2026.com
generating certificate for es01.qytdocker2026.com
generating certificate for kibana01.qytdocker2026.com
generating certificate for filebeat01.qytdocker2026.com
all certificates generated under /output
subject=CN = www.qytdocker2026.com
X509v3 Subject Alternative Name:
    DNS:www.qytdocker2026.com, DNS:nginx
```

**2.3 HTTPS 访问首页和 Kibana（课程 16.3、16.4）**

课程是在 Windows 浏览器里访问，这里在实验机上用 curl 代替：
- `--resolve 域名:443:127.0.0.1`：把域名直接指到本机，相当于改了 hosts 文件；
- `--cacert`：用课程的 CA 校验证书，相当于浏览器信任了课程根证书。

```bash
CA=certs/generated/ca/ca.crt

# 首页
curl -s --cacert $CA \
  --resolve www.qytdocker2026.com:443:127.0.0.1 \
  https://www.qytdocker2026.com/ \
  -o /dev/null -w "www: HTTP %{http_code} ssl_verify=%{ssl_verify_result}\n"

curl -s --cacert $CA \
  --resolve www.qytdocker2026.com:443:127.0.0.1 \
  https://www.qytdocker2026.com/ \
  | grep -o "<title>.*</title>"

# 经 nginx 反向代理访问 Kibana
curl -s --cacert $CA \
  --resolve kibana01.qytdocker2026.com:443:127.0.0.1 \
  https://kibana01.qytdocker2026.com/api/status \
  -o /dev/null -w "kibana: HTTP %{http_code} ssl_verify=%{ssl_verify_result}\n"

curl -s --cacert $CA -L \
  --resolve kibana01.qytdocker2026.com:443:127.0.0.1 \
  https://kibana01.qytdocker2026.com/ \
  -o /dev/null -w "kibana login page: HTTP %{http_code} final=%{url_effective}\n"
```

```text
www: HTTP 200 ssl_verify=0                   ← ssl_verify=0 表示证书校验通过
<title>首页 - Compose TLS Demo</title>
kibana: HTTP 200 ssl_verify=0
kibana login page: HTTP 200 final=https://kibana01.qytdocker2026.com/login?next=%2F
```

**2.4 产生几条访问日志，确认 nginx 和 filebeat 看到的是同一个文件（课程 16.5、16.6）**

```bash
# 访问几个页面，包括一个不存在的（产生 404）
for p in / /about.html /docs.html /status.html /nope; do
  curl -s -o /dev/null --cacert $CA \
    --resolve www.qytdocker2026.com:443:127.0.0.1 \
    https://www.qytdocker2026.com$p
done

# nginx 容器写的日志
docker exec compose-elk-nginx-1 sh -c 'tail -n 2 /var/log/nginx/access-compose.log'

# filebeat 容器通过共享卷读同一个文件
docker exec compose-elk-filebeat-1 sh -c 'tail -n 2 /var/log/nginx/access-compose.log' </dev/null
```

```text
172.18.0.1 - - [23/Nov/2026:14:40:35 +0000] "GET /status.html HTTP/1.1" 200 1372 "-" "curl/8.5.0" "-"
172.18.0.1 - - [23/Nov/2026:14:40:35 +0000] "GET /nope HTTP/1.1" 404 153 "-" "curl/8.5.0" "-"

172.18.0.1 - - [23/Nov/2026:14:40:35 +0000] "GET /status.html HTTP/1.1" 200 1372 "-" "curl/8.5.0" "-"
172.18.0.1 - - [23/Nov/2026:14:40:35 +0000] "GET /nope HTTP/1.1" 404 153 "-" "curl/8.5.0" "-"
```

**2.5 日志进入 Elasticsearch（课程 16.7，用 API 代替 Kibana 网页）**

```bash
sleep 15   # 给 filebeat 一点时间发送

ES_CA=/usr/share/elasticsearch/config/certs/ca.crt

# filebeat 的索引和文档数
docker exec compose-elk-elasticsearch-1 curl -s --cacert $ES_CA -u elastic:Cisc0123 \
  "https://127.0.0.1:9200/_cat/indices/*filebeat*?h=index,docs.count&expand_wildcards=all" </dev/null

# 最新一条日志
docker exec compose-elk-elasticsearch-1 curl -s --cacert $ES_CA -u elastic:Cisc0123 \
  "https://127.0.0.1:9200/filebeat-*/_search?size=1&sort=@timestamp:desc&_source=message" </dev/null \
  | grep -o '"message":"[^"]*"'
```

```text
.ds-filebeat-8.19.0-2026.11.23-000001 8
"message":"2026/11/23 14:35:01 [notice] 1#1: OS: Linux 7.0.0-1018-aws"
```

`.ds-` 开头说明 filebeat 8.x 用的是 **data stream**（按时间滚动的索引），不是普通索引。

**2.6 停止（实验结束时）**

```bash
docker compose stop          # 只停不删，下次 docker compose start 就能恢复
# 彻底清理：docker compose down -v
```

### 遇到的坑：`docker compose up --wait` 一直不返回

`--wait` 会等**所有**服务进入 running/healthy 状态。但 `cert-init`、`kibana-auth-init` 是一次性任务，做完就正常退出（`Exited (0)`），永远不会是 running，所以命令一直卡着。服务其实早就起来了，用 `docker compose ps -a` 看状态即可。

## 笔记 / 疑问

（自己补充）
