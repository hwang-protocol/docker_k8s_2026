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

## 笔记 / 疑问

（自己补充）
