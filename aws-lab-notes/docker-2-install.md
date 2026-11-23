# Docker 第 2 章：安装 Docker

- **状态：** ✅ 完成
- **日期：** 2026-11-23
- **课程原文：** [docker/docker_2_install/install_docker_ubuntu.md](../docker/docker_2_install/install_docker_ubuntu.md)

## 做了什么

按课程步骤，从 Docker 官方 apt 源安装 `docker-ce`、`docker-ce-cli`、`containerd.io`、`docker-buildx-plugin`、`docker-compose-plugin`，把数据目录设为 `/data/docker`，并把 `ubuntu` 用户加进 `docker` 组。

## 结果

| 检查项 | 结果 |
|---|---|
| 系统 | Ubuntu 24.04（noble） |
| `docker version` | Client 29.10.0 / Server 29.10.0 |
| `docker compose version` | v5.8.0 |
| `docker info` | DockerRootDir=`/data/docker`，存储驱动 overlayfs，cgroup v2 + systemd |
| `docker run hello-world` | ✅ `Hello from Docker!` |

版本比课程示例（29.3.0 / v5.1.0）新，结构一样。

## 和课程原版的区别

- **没有配置镜像加速地址。** 课程 `daemon.json` 里有十几个国内镜像站，东京的机器直连 Docker Hub 就很快，而且这些镜像站经常失效。实际写入的是：

  ```json
  { "data-root": "/data/docker" }
  ```

## 笔记 / 疑问

（自己补充）
