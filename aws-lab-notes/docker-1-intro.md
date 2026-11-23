# Docker 第 1 章：简介——服务与容器、可迁移性

- **状态：** ✅ 完成
- **日期：** 2026-11-23
- **课程原文：** [docker/docker_1_intro/](../docker/docker_1_intro/)

## 实验 1：服务和容器都靠主进程活着（`diff_service_and_container`）

同一个 `app.py`（从 20 倒数，到 0 时除以零崩溃），分别作为 systemd 服务和容器运行。

| | systemd 服务 | Docker 容器 |
|---|---|---|
| 刚启动 | `active`，MainPID 3290 | 前台打印倒数 |
| 约 20 秒后 | `failed (Result: exit-code)`，Duration 20.155s | `Exited (1)`，ExitCode=1 |
| 日志 | `journalctl` 里有 `ZeroDivisionError` | `docker run` 输出里有 `ZeroDivisionError` |

**结论：** 主进程一退出，服务和容器都会停止。容器里的 PID 1 就相当于 systemd 单元的 `ExecStart` 进程。

## 实验 2：可迁移性（`flask_in_diff_linux`）

| 步骤 | 结果 |
|---|---|
| `docker build -t collinsctk/flask_in_centos_ubuntu .` | ✅ |
| `docker run -p 8080:8080` 后访问 | `Hello World! I am in QYT container` |
| 推送到仓库 → 删除本地镜像 → 重新拉取并运行 | 同样返回 `Hello World! I am in QYT container` |
| 镜像架构 | `amd64 / linux` |

## 和课程原版的区别

- **没有推送到 Docker Hub。** 课程用的是讲师账号 `collinsctk`，推送需要你自己的 Docker Hub 账号登录。我在同一台机器上起了一个私有仓库 `registry:2`（`localhost:5000`）代替：推上去，删掉本地镜像，再拉下来运行，验证的是同一件事。
- **没有第二台机器。** 课程第 5 步在“另一台机器”上拉取，这里用“删掉本地镜像后重新拉”来模拟。想做得更真实，可以以后开 K8s 集群时，在另一台节点上拉同一个镜像。

## 学到的

- 镜像把“代码 + 依赖 + 运行方式”打包在一起，目标机器只需要容器运行时。
- 可迁移的前提：CPU 架构一致（都是 amd64）、能访问镜像仓库。

## 笔记 / 疑问

（自己补充）
