# Docker 第 4 章：数据持久化

- **状态：** ✅ 完成
- **日期：** 2026-11-23
- **课程原文：** [docker/docker_4_data/docker_data.md](../docker/docker_4_data/docker_data.md)

## 结果

| 步骤 | 结果 |
|---|---|
| 3. 不写 `-v` 运行 postgres | 仍然自动生成了一个**匿名卷**（一长串哈希名），挂在 `/var/lib/postgresql/data`，因为镜像里写了 `VOLUME` |
| 4. 删除容器 | 匿名卷**还在**，不会跟着容器删掉，需要手动清理 |
| 6–7. 具名卷 `pgdata_demo` | 建表写入 `named volume`，删掉容器后用同一个卷重建，数据还在 ✅ |
| 9–10. 宿主机目录 `/data/pg_bind_demo` | 写入 `bind mount`，删掉容器后重建，数据还在 ✅；目录属主变成了 `999`（容器里的 postgres 用户） |
| 11. 只读挂载 `nginx.conf:ro` | 容器里写文件报错 `Read-only file system` ✅ |
| 11. 宿主机改配置 | 重启前容器仍是 v1，`docker restart` 之后才变成 v2 |
| 12. 清理 | 容器、卷、目录都删干净了 |

## 一个值得记住的现象（和 inode 有关）

第 11 步用 `sed -i` 改宿主机上的 `nginx.conf`：

| | 值 |
|---|---|
| 改之前的 inode | 1572953 |
| 改之后的 inode | 1573028 |
| 改之后、重启之前，容器里能看到 v2 吗 | **看不到**（0 行） |
| `docker restart` 之后 | 变成 v2 |

`sed -i` 是“写一个新文件再改名覆盖”，所以 inode 变了。容器挂载的是**单个文件**，手里拿的还是旧 inode，所以看不到修改；重启容器时重新挂载，才拿到新文件。

这和面试题“文件改了也保存了，系统却还在用旧的”是同一个原理。**挂载整个目录**就没有这个问题。

## 和课程原版的区别

没有区别，完全按课程步骤执行。

## 完整操作记录

以下命令都在 `k8s-docker` 上执行。先定义两个小函数，后面反复用：

```bash
# 等 postgres 真正可以接受连接（容器刚启动时还在初始化）
waitpg() {
  until docker exec pg-demo pg_isready -U postgres -q 2>/dev/null; do
    sleep 1
  done
  sleep 1
}

# 打印 pg-demo 容器的挂载：类型、卷名、宿主机路径 -> 容器内路径
mounts() {
  docker inspect -f '{{range .Mounts}}{{println .Type .Name .Source "->" .Destination}}{{end}}' pg-demo
}
```

### 1–2. 清理环境，拉取镜像

```bash
docker rm -f pg-demo app-demo 2>/dev/null
docker volume rm pgdata_demo 2>/dev/null
sudo rm -rf /data/pg_bind_demo

docker pull -q postgres:16
```

### 3. 不写 `-v` 运行 postgres，看看数据存在哪

```bash
docker run -d --name pg-demo -e POSTGRES_PASSWORD=123456 postgres:16
mounts
docker volume ls -q | wc -l
```

```text
volume 67e23b7e899fe36b3aae1eeb05c6fcc8a47205ae79212b14cecc88b5f864f92e /data/docker/volumes/67e23b7e.../_data -> /var/lib/postgresql/data
2
```

没写 `-v` 也出现了一个卷：postgres 镜像的 Dockerfile 里写了 `VOLUME /var/lib/postgresql/data`，Docker 自动建了一个**匿名卷**（名字是一串哈希）。

### 4–5. 删容器，匿名卷还在

```bash
AUTO_VOL=$(docker inspect -f '{{range .Mounts}}{{.Name}}{{end}}' pg-demo)

docker rm -f pg-demo
docker volume ls -q | grep -c "$AUTO_VOL"     # 1 = 卷还在

docker volume rm "$AUTO_VOL" && echo removed
```

```text
1
removed
```

匿名卷不会跟着容器删除（除非 `docker rm -v`），时间长了会堆积，要定期 `docker volume prune`。

### 6. 具名卷：写入数据

```bash
docker run -d --name pg-demo \
  -e POSTGRES_PASSWORD=123456 \
  -v pgdata_demo:/var/lib/postgresql/data \
  postgres:16
waitpg

docker exec pg-demo psql -U postgres -d postgres -c "
  create table if not exists demo(id int primary key, note text);
  insert into demo values (1, 'named volume') on conflict (id) do nothing;
" </dev/null

mounts
```

```text
volume pgdata_demo /data/docker/volumes/pgdata_demo/_data -> /var/lib/postgresql/data
```

### 7. 删掉容器，用同一个卷重建，数据还在

```bash
docker rm -f pg-demo

docker run -d --name pg-demo \
  -e POSTGRES_PASSWORD=123456 \
  -v pgdata_demo:/var/lib/postgresql/data \
  postgres:16
waitpg

docker exec pg-demo psql -U postgres -d postgres -c "select * from demo;" </dev/null
```

```text
 id |     note
----+--------------
  1 | named volume
(1 row)
```

### 8. 清理

```bash
docker rm -f pg-demo
docker volume rm pgdata_demo
```

### 9. 绑定挂载：用宿主机目录存数据

```bash
sudo mkdir -p /data/pg_bind_demo
ls -ld /data/pg_bind_demo                     # 挂载前：属主 root

docker run -d --name pg-demo \
  -e POSTGRES_PASSWORD=123456 \
  -v /data/pg_bind_demo:/var/lib/postgresql/data \
  postgres:16
waitpg

docker exec pg-demo psql -U postgres -d postgres -c "
  create table if not exists demo_bind(id int primary key, note text);
  insert into demo_bind values (1, 'bind mount') on conflict (id) do nothing;
" </dev/null

sudo ls /data/pg_bind_demo | head -4           # 宿主机上直接能看到 postgres 的数据文件
ls -ld /data/pg_bind_demo                      # 挂载后：属主变成 999
mounts
```

```text
drwxr-xr-x 2 root root 4096 Nov 23 14:27 /data/pg_bind_demo
PG_VERSION
base
global
pg_commit_ts
drwx------ 19 999 root 4096 Nov 23 14:27 /data/pg_bind_demo
bind  /data/pg_bind_demo -> /var/lib/postgresql/data
```

属主变成 `999`：容器里的 `postgres` 用户 UID 是 999，它初始化数据目录时改了权限。宿主机上没有 UID 999 的用户名，所以只显示数字。

### 10. 删掉容器，用同一个目录重建，数据还在

```bash
docker rm -f pg-demo

docker run -d --name pg-demo \
  -e POSTGRES_PASSWORD=123456 \
  -v /data/pg_bind_demo:/var/lib/postgresql/data \
  postgres:16
waitpg

docker exec pg-demo psql -U postgres -d postgres -c "select * from demo_bind;" </dev/null
```

```text
 id |    note
----+------------
  1 | bind mount
(1 row)
```

### 11. 只读挂载配置文件 + inode 现象

```bash
C=/docker_k8s_2026/docker/docker_4_data/nginx.conf
docker pull -q nginx:1.29.6

# :ro = 只读挂载单个文件
docker run -d --name app-demo -p 38081:80 \
  -v $C:/etc/nginx/nginx.conf:ro \
  nginx:1.29.6
sleep 1
curl -is http://127.0.0.1:38081 | grep -i "x-course\|^docker"

# 容器里改文件：应该被拒绝
docker exec app-demo sh -c "echo '# changed' >> /etc/nginx/nginx.conf" </dev/null
```

```text
X-Course-Version: v1
docker data ro v1
sh: 1: cannot create /etc/nginx/nginx.conf: Read-only file system
```

在宿主机上把配置从 v1 改成 v2，并记录 `sed -i` 前后的 inode：

```bash
ls -i $C | awk '{print "inode before sed:", $1}'
sed -i 's/X-Course-Version "v1"/X-Course-Version "v2"/; s/docker data ro v1/docker data ro v2/' $C
ls -i $C | awk '{print "inode after sed: ", $1}'

# 重启前：容器里的文件有几行包含 v2？
docker exec app-demo grep -c v2 /etc/nginx/nginx.conf </dev/null

# 重启容器后再访问
docker restart app-demo
until curl -s http://127.0.0.1:38081 >/dev/null 2>&1; do sleep 1; done
curl -is http://127.0.0.1:38081 | grep -i "x-course\|^docker"
```

```text
inode before sed: 1572953
inode after sed:  1573028
0                                  ← 重启前容器里还是旧文件
X-Course-Version: v2               ← 重启后才变成 v2
docker data ro v2
```

最后把课程文件改回 v1，保持仓库原样：

```bash
sed -i 's/X-Course-Version "v2"/X-Course-Version "v1"/; s/docker data ro v2/docker data ro v1/' $C
grep 'X-Course\|ro v' $C
```

```text
        add_header X-Course-Version "v1" always;
            return 200 "docker data ro v1\n";
```

### 12. 清理并确认

```bash
docker rm -f pg-demo app-demo
sudo rm -rf /data/pg_bind_demo
docker rmi postgres:16 nginx:1.29.6

docker ps -a --format '{{.Names}}' | grep -E '^(pg-demo|app-demo)$' || echo "no demo containers"
docker volume ls -q | grep -x pgdata_demo || echo "no pgdata_demo"
test -d /data/pg_bind_demo && echo exists || echo missing
```

```text
no demo containers
no pgdata_demo
missing
```

### 遇到的坑：脚本后半段“消失”

第一次执行时，从第 7 步开始的命令都没有输出。原因是整个脚本通过 `ssh k8s-docker 'bash -s' <<EOF` 喂给远端的 bash，而第 6 步的 `docker exec -i ... psql` 带了 `-i`，会读取标准输入，把脚本剩下的内容当作 SQL 吃掉了。解决：去掉 `-i`，并给 `docker exec` 加 `</dev/null`。手工一条条敲命令不会遇到这个问题。

## 笔记 / 疑问

（自己补充）
