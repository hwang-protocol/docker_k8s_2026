# Docker 数据持久化

## 本文目标

- 说明 Docker 为什么需要数据持久化。
- 掌握两种最常见的数据持久化方式：宿主机目录挂载与具名卷。
- 通过一条连续实验主线，理解官方镜像默认卷、具名卷与宿主机目录挂载之间的区别。

## 本文主线

本章围绕以下 3 个问题展开：

1. 为什么容器里的数据会丢
2. 两种最常见的数据持久化方式
   - 宿主机目录挂载
   - 具名卷
3. 一个课堂中容易忽略但实际使用中必须知道的点
   - 有些官方镜像即使你没写 `-v`，也可能已经自动创建了卷

其中，本文专门使用 `postgres` 来演示“未显式指定挂载，但容器实际已经带卷”的现象。

## 实验说明

为了避免误删你机器上其他无关的容器和镜像，本文只清理和本实验有关的对象：

- 容器名：`pg-demo`
- 容器名：`app-demo`
- 具名卷：`pgdata_demo`
- 宿主机目录：`/data/pg_bind_demo`
- 配置文件：`/docker_k8s_2026/docker/docker_4_data/nginx.conf`
- 镜像：`postgres:16`
- 镜像：`nginx:1.29.6`

也就是说：

- 开始前，把这些实验对象清到空
- 结束后，再把这些实验对象清到空

下面穿插的原始输出来自一次真实实验，时间为 `2026-03-16`。

## 1. 为什么容器里的数据会丢

Docker 容器运行时，除了镜像本身的只读层，还会有一层容器自己的可写层。

如果没有额外挂载，容器里新建文件、修改配置、写入数据，默认都会落在这一层。

问题在于：

- 容器停止，不会立刻丢数据
- 但容器一旦被删除，这层数据通常也就跟着没了

> Note
> 容器处于 `stopped` 或 `exited` 状态时，容器可写层里的数据通常还在。
> 真正容易导致这层数据消失的动作，是删除容器，而不是停止容器。

所以容器里如果有数据库数据、上传文件、日志、证书、配置文件，就不能只放在容器自己的可写层里。

这也是为什么我们需要数据持久化。

## 2. 两种主流持久化方式

生产里真正最常用的，只有两种：

### 2.1 宿主机目录挂载

基本写法：

```bash
docker run -d \
  --name app-demo \
  -v /data/app:/app/data \
  nginx:1.29.6
```

含义：

- 宿主机目录：`/data/app`
- 容器内目录：`/app/data`

特点：

- 宿主机上能直接看到真实文件
- 方便备份、排查、迁移
- 很适合配置文件、日志目录、上传目录、证书目录

### 2.2 具名卷

基本写法：

```bash
docker run -d \
  --name db-demo \
  -v pgdata_demo:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=123456 \
  postgres:16
```

含义：

- `pgdata_demo` 是卷名
- `/var/lib/postgresql/data` 是容器内目录

特点：

- 不需要你自己先创建宿主机目录
- Docker 负责管理卷
- 很适合数据库数据目录

你可以先记一句最实用的话：

- 配置、日志、上传文件、证书：优先宿主机目录挂载
- 数据库数据：优先具名卷，或者明确指定宿主机目录

## 3. 一个容易忽略的点：有些官方镜像会自动带卷

这一段非常重要。

很多学员会以为：

- 我没有写 `-v`
- 那就说明这个容器没有卷

但这并不一定对。

像 `postgres` 这样的官方镜像，镜像作者往往已经把数据目录设计成卷了。

这意味着：

- 你虽然没写 `-v`
- Docker 仍然可能帮你自动创建一个卷

这个卷通常就是匿名卷。

匿名卷不是不能用，但它有几个明显问题：

- 名字随机，不直观
- 不方便备份和迁移
- 不方便统一管理
- 新手很容易“用上了，但自己还不知道”

所以生产里不要依赖默认匿名卷，而是要自己显式写出来。

官方文档也明确提到了这一点。

参考：

- Docker Hub 官方页面：[postgres - Official Image](https://hub.docker.com/_/postgres)

在 `PGDATA` 相关说明里，官方原文提到：

> The Dockerfile of the image declares a volume at `/var/lib/postgresql/data` and if no data volume is mounted there, then `docker run` will automatically create an anonymous volume. [该镜像的 Dockerfile 在 `/var/lib/postgresql/data` 上声明了一个卷；如果该路径上没有挂载数据卷，那么执行 `docker run` 时会自动创建一个匿名卷。]

## 4. 主线实验：从空开始，跑到空结束

下面开始整章最重要的一段实操。

### 第一步：先把实验环境清到空

```bash
docker rm -f pg-demo >/dev/null 2>&1 || true
docker rm -f app-demo >/dev/null 2>&1 || true
docker volume rm pgdata_demo >/dev/null 2>&1 || true
sudo rm -rf /data/pg_bind_demo
docker rmi postgres:16 >/dev/null 2>&1 || true
docker rmi nginx:1.29.6 >/dev/null 2>&1 || true
```

说明：

- 这里只清理本文实验相关对象
- 不会去删除你机器上其他无关的容器和镜像

### 第二步：拉取镜像

```bash
docker pull postgres:16
```

原始输出节选：

```text
16: Pulling from library/postgres
492b703419dc: Pulling fs layer
70f3de31936a: Pulling fs layer
358db71ef364: Pulling fs layer
bf7abec98810: Pulling fs layer
206356c42440: Pulling fs layer
...
47a54adc815e: Pull complete
bf7abec98810: Pull complete
83f6062afc2f: Pull complete
386413bac3c6: Pull complete
492b703419dc: Pull complete
dfababee9022: Pull complete
Digest: sha256:78df81b1442dcc764c1104154da7162635e40cfffe67579c42a1c1b96dfc209c
Status: Downloaded newer image for postgres:16
docker.io/library/postgres:16
```

关键看点：

- `Pulling fs layer` 说明镜像按层下载
- `Digest` 是镜像摘要，可用于确认镜像内容
- `Status: Downloaded newer image for postgres:16` 说明这次是从空环境成功拉取

到这里为止，实验环境里只有一张镜像：

- `postgres:16`

### 第三步：先做一个“没写 -v，但其实已经有卷”的实验

先直接启动一个 `postgres` 容器，不写任何挂载：

```bash
docker run -d \
  --name pg-demo \
  -e POSTGRES_PASSWORD=123456 \
  postgres:16
```

等待数据库就绪：

```bash
until docker exec pg-demo pg_isready -U postgres >/dev/null 2>&1; do
  sleep 1
done
echo ready
```

原始输出：

```text
ready
```

现在查看挂载信息：

```bash
docker inspect -f '{{range .Mounts}}{{println .Type .Name .Source "->" .Destination}}{{end}}' pg-demo
```

原始输出：

```text
volume b3100950f07ad6fbb54d3a51b0d96a3382e3dab29c2f9a40751f74eeb53ec185 /var/lib/docker/volumes/b3100950f07ad6fbb54d3a51b0d96a3382e3dab29c2f9a40751f74eeb53ec185/_data -> /var/lib/postgresql/data
```

关键看点：

- 你没有写 `-v`
- 但 `Mounts` 里已经出现了 `volume`
- 这说明 `postgres` 已经自动带出了一个卷
- 这个卷的名字通常是一串随机值，这就是匿名卷

再看一下当前卷列表：

```bash
docker volume ls
```

原始输出：

```text
DRIVER    VOLUME NAME
local     b3100950f07ad6fbb54d3a51b0d96a3382e3dab29c2f9a40751f74eeb53ec185
```

### 第四步：删除容器，但不要删卷

先把匿名卷名字记下来：

```bash
AUTO_VOL=$(docker inspect -f '{{range .Mounts}}{{.Name}}{{end}}' pg-demo)
echo "$AUTO_VOL"
```

然后删除容器：

```bash
docker rm -f pg-demo
```

原始输出：

```text
pg-demo
```

再看卷是否还在：

```bash
docker volume ls
```

原始输出：

```text
DRIVER    VOLUME NAME
local     b3100950f07ad6fbb54d3a51b0d96a3382e3dab29c2f9a40751f74eeb53ec185
```

你会发现：

- 容器没了
- 但卷还在

这正是匿名卷容易让新手困惑的地方：

- 你没显式管理它
- 它却默默存在了

所以这一步的结论是：

- 默认匿名卷确实能保数据
- 但生产里不建议依赖它

### 第五步：把刚才的匿名卷清掉

```bash
docker volume rm "$AUTO_VOL"
```

到这里，匿名卷实验结束。

### 第六步：改成生产更常用的写法一，显式指定具名卷

现在我们明确地告诉 Docker：

- 不要随机卷
- 我就要一个名字叫 `pgdata_demo` 的卷

启动容器：

```bash
docker run -d \
  --name pg-demo \
  -e POSTGRES_PASSWORD=123456 \
  -v pgdata_demo:/var/lib/postgresql/data \
  postgres:16
```

等待数据库就绪：

```bash
until docker exec pg-demo pg_isready -U postgres >/dev/null 2>&1; do
  sleep 1
done
echo ready
```

原始输出：

```text
ready
```

写入一条测试数据：

```bash
docker exec -i pg-demo psql -U postgres -d postgres -c \
"create table if not exists demo(id int primary key, note text);
 insert into demo values (1, 'named volume') on conflict (id) do nothing;
 select * from demo;"
```

这段命令里实际做了 3 件事：

- `create table if not exists demo(...)`
  如果表不存在，就先创建一张测试表
- `insert into ... on conflict (id) do nothing`
  插入一条测试数据；如果主键 `id=1` 已经存在，就跳过，避免重复执行时报错
- `select * from demo`
  把当前表里的数据查出来，直接验证写入是否成功

原始输出：

```text
CREATE TABLE
INSERT 0 1
 id |     note     
----+--------------
  1 | named volume
(1 row)
```

查看卷：

```bash
docker volume ls
```

原始输出：

```text
DRIVER    VOLUME NAME
local     pgdata_demo
```

再看挂载信息：

```bash
docker inspect -f '{{range .Mounts}}{{println .Type .Name .Source "->" .Destination}}{{end}}' pg-demo
```

原始输出：

```text
volume pgdata_demo /var/lib/docker/volumes/pgdata_demo/_data -> /var/lib/postgresql/data
```

这时候你会看到 `pgdata_demo`，名字是你自己定义的，不再是随机 ID。

关键看点：

- `volume pgdata_demo ... -> /var/lib/postgresql/data` 说明这次已经不是匿名卷，而是显式指定的具名卷
- 具名卷的好处是名字固定，后续备份、迁移、清理都更方便

### 第七步：删除容器，再用同一个具名卷重新启动

删除旧容器：

```bash
docker rm -f pg-demo
```

原始输出：

```text
pg-demo
```

重新启动：

这里虽然是一个新容器，但挂载的仍然是同一个具名卷 `pgdata_demo`，所以数据库数据仍然会从这个卷里读取。

```bash
docker run -d \
  --name pg-demo \
  -e POSTGRES_PASSWORD=123456 \
  -v pgdata_demo:/var/lib/postgresql/data \
  postgres:16
```

等待数据库就绪：

```bash
until docker exec pg-demo pg_isready -U postgres >/dev/null 2>&1; do
  sleep 1
done
echo ready
```

原始输出：

```text
ready
```

再查一次刚才的数据：

```bash
docker exec -i pg-demo psql -U postgres -d postgres -c "select * from demo;"
```

原始输出：

```text
 id |     note     
----+--------------
  1 | named volume
(1 row)
```

如果还能查到刚才的记录，就说明：

- 容器虽然删了又重建
- 但数据没有丢
- 因为数据保存在具名卷里

关键看点：

- 重新启动后仍然能查询到 `named volume`，说明数据不在容器可写层里，而在卷里

### 第八步：清掉具名卷实验

```bash
docker rm -f pg-demo
docker volume rm pgdata_demo
```

原始输出：

```text
pg-demo
pgdata_demo
```

到这里，具名卷实验也结束了。

### 第九步：改成生产更常用的写法二，宿主机目录挂载

现在我们再看另一种常见做法：

- 不让 Docker 管随机目录
- 也不只记一个卷名
- 而是明确把数据落到宿主机的固定目录

先准备宿主机目录：

```bash
sudo mkdir -p /data/pg_bind_demo
ls -ld /data/pg_bind_demo
```

原始输出节选：

```text
drwxr-xr-x 2 root root 4096 Mar 16 16:52 /data/pg_bind_demo
```

启动容器：

```bash
docker run -d \
  --name pg-demo \
  -e POSTGRES_PASSWORD=123456 \
  -v /data/pg_bind_demo:/var/lib/postgresql/data \
  postgres:16
```

等待数据库就绪：

```bash
until docker exec pg-demo pg_isready -U postgres >/dev/null 2>&1; do
  sleep 1
done
echo ready
```

原始输出：

```text
ready
```

写入一条测试数据：

```bash
docker exec -i pg-demo psql -U postgres -d postgres -c \
"create table if not exists demo_bind(id int primary key, note text);
 insert into demo_bind values (1, 'bind mount') on conflict (id) do nothing;
 select * from demo_bind;"
```

原始输出：

```text
CREATE TABLE
INSERT 0 1
 id |    note    
----+------------
  1 | bind mount
(1 row)
```

现在从宿主机上能明确知道数据目录在哪里：

```bash
ls /data/pg_bind_demo
```

原始输出节选：

```text
PG_VERSION
base
global
pg_commit_ts
pg_dynshmem
pg_hba.conf
pg_ident.conf
pg_logical
pg_multixact
pg_notify
```

再看挂载信息：

```bash
docker inspect -f '{{range .Mounts}}{{println .Type .Name .Source "->" .Destination}}{{end}}' pg-demo
```

原始输出：

```text
bind  /data/pg_bind_demo -> /var/lib/postgresql/data
```

这就是宿主机目录挂载和具名卷最大的一个体验差异：

- 具名卷：Docker 管理，名字清楚，但宿主机路径不直接暴露
- 宿主机目录挂载：路径完全由你自己决定

关键看点：

- `bind /data/pg_bind_demo -> /var/lib/postgresql/data` 说明这次数据目录直接绑定到了宿主机固定路径
- 宿主机可以直接看到真实文件，这对排查和备份很直观

### 第十步：删除容器，再挂载同一宿主机目录重新启动

```bash
docker rm -f pg-demo
```

原始输出：

```text
pg-demo
```

重新启动：

这里虽然重新创建了容器，但挂载的仍然是同一个宿主机目录 `/data/pg_bind_demo`，所以数据仍然会从这个目录读取。

```bash
docker run -d \
  --name pg-demo \
  -e POSTGRES_PASSWORD=123456 \
  -v /data/pg_bind_demo:/var/lib/postgresql/data \
  postgres:16
```

等待数据库就绪：

```bash
until docker exec pg-demo pg_isready -U postgres >/dev/null 2>&1; do
  sleep 1
done
echo ready
```

原始输出：

```text
ready
```

再查一次数据：

```bash
docker exec -i pg-demo psql -U postgres -d postgres -c "select * from demo_bind;"
```

原始输出：

```text
 id |    note    
----+------------
  1 | bind mount
(1 row)
```

如果还能查到数据，就说明：

- 容器删了
- 数据仍然保存在宿主机目录 `/data/pg_bind_demo`

关键看点：

- 重建容器后仍能查到 `bind mount` 这条记录，说明数据确实保留在宿主机目录里

### 第十一步：补一个更贴近实际的 `ro` 只读挂载实验

很多时候只读挂载的不是普通文本文件，而是配置文件。

例如 `nginx` 配置文件、证书文件、静态资源描述文件，都很适合只读挂载。

本文目录里已经准备了一个 `nginx.conf`：

```bash
grep 'X-Course-Version\|docker data ro' /docker_k8s_2026/docker/docker_4_data/nginx.conf
```

原始输出：

```text
        add_header X-Course-Version "v1" always;
            return 200 "docker data ro v1\n";
```

现在启动一个 `nginx` 容器，把这个配置文件只读挂载进去：

```bash
docker run -d \
  --name app-demo \
  -p 38081:80 \
  -v /docker_k8s_2026/docker/docker_4_data/nginx.conf:/etc/nginx/nginx.conf:ro \
  nginx:1.29.6
```

先从宿主机访问它，确认当前生效的是 `v1` 配置：

```bash
curl -i http://127.0.0.1:38081
```

原始输出：

```text
HTTP/1.1 200 OK
Server: nginx/1.29.6
Date: Mon, 16 Mar 2026 12:58:30 GMT
Content-Type: text/plain
Content-Length: 18
Connection: keep-alive
X-Course-Version: v1

docker data ro v1
```

再尝试在容器里直接修改这个配置文件：

```bash
docker exec app-demo sh -c "echo '# changed' >> /etc/nginx/nginx.conf"
```

原始输出：

```text
sh: 1: cannot create /etc/nginx/nginx.conf: Read-only file system
```

这说明：

- 容器内能够读取这个配置文件
- 但不能直接在容器里改它

接着在宿主机上修改配置内容，把它从 `v1` 改成 `v2`：

```bash
sed -i 's/X-Course-Version "v1"/X-Course-Version "v2"/; s/docker data ro v1/docker data ro v2/' /docker_k8s_2026/docker/docker_4_data/nginx.conf
grep 'X-Course-Version\|docker data ro' /docker_k8s_2026/docker/docker_4_data/nginx.conf
```

原始输出：

```text
        add_header X-Course-Version "v2" always;
            return 200 "docker data ro v2\n";
```

重启容器，让 `nginx` 重新加载配置：

```bash
docker restart app-demo
until curl -s http://127.0.0.1:38081 >/dev/null 2>&1; do
  sleep 1
done
echo ready
curl -i http://127.0.0.1:38081
```

原始输出：

```text
app-demo
ready
HTTP/1.1 200 OK
Server: nginx/1.29.6
Date: Mon, 16 Mar 2026 12:58:32 GMT
Content-Type: text/plain
Content-Length: 18
Connection: keep-alive
X-Course-Version: v2

docker data ro v2
```

如果再到容器里查看这个配置文件，也会看到现在已经是 `v2`：

```bash
docker exec app-demo grep 'X-Course-Version\|docker data ro' /etc/nginx/nginx.conf
```

原始输出：

```text
        add_header X-Course-Version "v2" always;
            return 200 "docker data ro v2\n";
```

最后把配置改回 `v1`：

```bash
sed -i 's/X-Course-Version "v2"/X-Course-Version "v1"/; s/docker data ro v2/docker data ro v1/' /docker_k8s_2026/docker/docker_4_data/nginx.conf
grep 'X-Course-Version\|docker data ro' /docker_k8s_2026/docker/docker_4_data/nginx.conf
```

原始输出：

```text
        add_header X-Course-Version "v1" always;
            return 200 "docker data ro v1\n";
```

关键看点：

- `:ro` 表示这个挂载点在容器内只读
- 容器内不能直接修改 `/etc/nginx/nginx.conf`
- 但宿主机上的源文件仍然可以修改
- 宿主机修改后，容器重启并重新加载配置，就能看到效果变化
- 作为教材实验，最后要把宿主机配置恢复到初始状态，这样下次才能从同一个起点重新刷

实验结束后，把 `app-demo` 容器清理掉：

```bash
docker rm -f app-demo
```

原始输出：

```text
app-demo
```

### 第十二步：把实验环境清回空

```bash
docker rm -f pg-demo >/dev/null 2>&1 || true
docker rm -f app-demo >/dev/null 2>&1 || true
docker volume rm pgdata_demo >/dev/null 2>&1 || true
sudo rm -rf /data/pg_bind_demo
docker rmi postgres:16 >/dev/null 2>&1 || true
docker rmi nginx:1.29.6 >/dev/null 2>&1 || true
```

最终验证：

```bash
docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | rg '^(pg-demo)\b' || true
docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | rg '^(app-demo)\b' || true
docker volume ls --format '{{.Name}}' | rg '^(pgdata_demo)$' || true
docker images --format '{{.Repository}}:{{.Tag}}' | rg '^postgres:16$' || true
docker images --format '{{.Repository}}:{{.Tag}}' | rg '^nginx:1.29.6$' || true
test -d /data/pg_bind_demo && echo exists || echo missing
```

原始输出：

```text
missing
```

到这里，本实验再次回到空：

- 没有实验容器
- 没有实验卷
- 没有实验目录
- 没有实验镜像

关键看点：

- 前 5 条检查命令没有任何输出，说明已经没有实验容器、实验卷和实验镜像
- 最后一条输出 `missing`，说明 `/data/pg_bind_demo` 目录也已经删除

## 5. 最后给出一套最实用的选择建议

### 什么时候用具名卷

优先用于：

- PostgreSQL
- MySQL
- Redis
- 其他需要持久化数据目录的服务

优点：

- 写法简单
- Docker 管理方便
- 比匿名卷更可控

### 什么时候用宿主机目录挂载

优先用于：

- 配置文件
- 日志目录
- 上传目录
- 证书目录
- 你明确希望数据落到某个宿主机路径时

优点：

- 宿主机路径明确
- 排查、备份、迁移更直观

### 什么时候不要依赖默认匿名卷

不建议在生产里把关键数据托付给默认匿名卷，因为：

- 你没显式声明它
- 名字随机
- 后续清理和迁移不直观
- 团队成员接手时容易看不懂

更好的习惯是：

- 数据库：显式写具名卷或宿主机目录
- 重要目录：不要依赖镜像默认行为

## 通过标准

- 能说清楚为什么容器删除后数据会丢
- 知道 Docker 里最常用的两种持久化方式是宿主机目录挂载和具名卷
- 知道 `postgres` 这类官方镜像即使不写 `-v`，也可能自动带出匿名卷
- 知道为什么生产里不要依赖默认匿名卷
- 能独立完成“具名卷保存数据库数据”和“宿主机目录挂载保存数据库数据”两条实验
