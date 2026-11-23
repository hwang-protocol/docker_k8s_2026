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

## 笔记 / 疑问

（自己补充）
