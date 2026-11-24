# Docker 第 5 章：Dockerfile 关键指令

- **状态：** ✅ 完成
- **日期：** 2026-11-23
- **课程原文：** [docker/docker_5_DockerFile/dockerfile.md](../docker/docker_5_DockerFile/dockerfile.md)

## 结果

### ENV / WORKDIR / CMD / LABEL / EXPOSE（`df-demo:env`）

```
Labels={"course":"docker2026","maintainer":"collinsctk"}
Env=[..., "APP_NAME=dockerfile-demo","APP_ENV=prod","APP_PORT=8080"]
ExposedPorts={"8080/tcp":{}}
Cmd=["./hello.sh"]
WorkingDir=/app
```

- 直接运行：打印 `APP_ENV=prod`、`APP_PORT=8080`、`PWD=/app`，然后容器退出（Exited 0）。
- `-e APP_ENV=test -e APP_PORT=9090`：运行时覆盖成功，`APP_NAME` 不变。

### ENTRYPOINT 和 CMD（`df-demo:entry`）

| 运行方式 | 实际执行 | 结果 |
|---|---|---|
| `docker run df-demo:entry` | ENTRYPOINT + CMD 默认参数 baidu | `status_code=200` |
| `docker run df-demo:entry https://www.jd.com` | 参数**替换了 CMD**，ENTRYPOINT 不变 | jd.com，`status_code=200` |
| `docker run --entrypoint curl df-demo:entry -I -s https://www.baidu.com` | 整个入口被换成 curl | `HTTP/1.1 200 OK` |

### COPY 和 ADD

| Dockerfile | 容器里看到的 |
|---|---|
| `COPY site /data/site` | `/data/site/index.html` |
| `COPY site.tar.gz /data/` | `/data/site.tar.gz`（原样复制，不解压） |
| `ADD site.tar.gz /data/` | `/data/index.html`（**自动解压**了） |

## 和课程原版的区别

没有区别。

## 完整操作记录

以下命令都在 `k8s-docker` 上执行。

### 0. 准备：进入实验目录，打包 ADD 实验要用的压缩包

```bash
cd /docker_k8s_2026/docker/docker_5_DockerFile/lab

tar -czf site.tar.gz -C site .
tar -tzf site.tar.gz
```

```text
./
./index.html
```

### 1–3. ENV / WORKDIR / CMD / LABEL / EXPOSE：构建并查看镜像元数据

```bash
docker build -q -t df-demo:env -f Dockerfile.env .

docker image inspect df-demo:env --format '
Labels={{json .Config.Labels}}
Env={{json .Config.Env}}
ExposedPorts={{json .Config.ExposedPorts}}
Cmd={{json .Config.Cmd}}
WorkingDir={{.Config.WorkingDir}}'
```

```text
Labels={"course":"docker2026","maintainer":"collinsctk"}
Env=["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","APP_NAME=dockerfile-demo","APP_ENV=prod","APP_PORT=8080"]
ExposedPorts={"8080/tcp":{}}
Cmd=["./hello.sh"]
WorkingDir=/app
```

Dockerfile 里的每条指令都变成了镜像的元数据：`LABEL` → Labels，`ENV` → Env，`EXPOSE` → ExposedPorts，`CMD` → Cmd，`WORKDIR` → WorkingDir。

### 5. 直接运行

```bash
docker run --name df-env-demo df-demo:env
docker ps -a --filter name='^/df-env-demo$' --format '{{.Names}} {{.Status}}'
```

```text
hello from Dockerfile
APP_NAME=dockerfile-demo
APP_ENV=prod
APP_PORT=8080
PWD=/app
df-env-demo Exited (0) Less than a second ago
```

`hello.sh` 打印完就结束，主进程退出，所以容器是 `Exited (0)`，和第 1 章“容器靠主进程活着”是同一个道理。

### 6. 运行时用 `-e` 覆盖 ENV

```bash
docker run --rm -e APP_ENV=test -e APP_PORT=9090 df-demo:env
```

```text
hello from Dockerfile
APP_NAME=dockerfile-demo     ← 没覆盖的保持原值
APP_ENV=test                 ← 被覆盖
APP_PORT=9090                ← 被覆盖
PWD=/app
```

### 7–10. ENTRYPOINT 和 CMD 的配合

```bash
docker build -q -t df-demo:entry -f Dockerfile.entrypoint .
docker image inspect df-demo:entry --format '
Entrypoint={{json .Config.Entrypoint}}
Cmd={{json .Config.Cmd}}'
```

```text
Entrypoint=["python3","/app/entrypoint_demo.py"]
Cmd=["https://www.baidu.com"]
```

三种运行方式对比：

```bash
# 8. 不带参数：ENTRYPOINT + CMD（CMD 作为默认参数）
docker run --rm df-demo:entry

# 9. 带一个参数：参数替换掉 CMD，ENTRYPOINT 不变
docker run --rm df-demo:entry https://www.jd.com

# 10. --entrypoint：整个入口换掉，后面的参数传给新入口
docker run --rm --entrypoint curl df-demo:entry -I -s https://www.baidu.com | head -1
```

```text
sys.argv=['/app/entrypoint_demo.py', 'https://www.baidu.com']
url=https://www.baidu.com
status_code=200

sys.argv=['/app/entrypoint_demo.py', 'https://www.jd.com']
url=https://www.jd.com
status_code=200

HTTP/1.1 200 OK
```

`sys.argv` 把规则展示得很直接：实际执行的命令 = `ENTRYPOINT` + （`docker run` 后面的参数，没有就用 `CMD`）。

### 11–13. COPY 和 ADD 的区别

```bash
# 11. COPY 一个目录
docker build -q -t df-demo:copydir -f Dockerfile.copydir .
docker run --rm df-demo:copydir

# 12. COPY 一个 tar.gz
docker build -q -t df-demo:copy -f Dockerfile.copy .
docker run --rm df-demo:copy

# 13. ADD 同一个 tar.gz
docker build -q -t df-demo:add -f Dockerfile.add .
docker run --rm df-demo:add
```

```text
/data/site/index.html      ← COPY 目录：原样复制
/data/site.tar.gz          ← COPY 压缩包：原样复制，不解压
/data/index.html           ← ADD 压缩包：自动解压
```

一般建议优先用 `COPY`，行为更可预期；只有明确需要“自动解压本地 tar”时才用 `ADD`。

### 清理

```bash
docker rm -f df-env-demo
docker rmi df-demo:env df-demo:entry df-demo:copydir df-demo:copy df-demo:add alpine:3.20 python:3.12-alpine

docker images --format '{{.Repository}}:{{.Tag}}' \
  | grep -E '^(df-demo:|alpine:3.20|python:3.12-alpine)' \
  || echo no-experiment-image
```

```text
no-experiment-image
```

## 笔记 / 疑问

（自己补充）
