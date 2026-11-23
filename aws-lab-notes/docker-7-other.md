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

## 笔记 / 疑问

（自己补充）
