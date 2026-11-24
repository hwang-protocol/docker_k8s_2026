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

## 完整操作记录

以下命令都在实验机 `k8s-docker` 上执行（`ssh k8s-docker` 登录后）。

### 实验 1：同一个程序，作为 systemd 服务 vs 作为容器

**1.1 作为 systemd 服务运行，观察 20 秒内的变化**

```bash
cd /docker_k8s_2026/docker/docker_1_intro/diff_service_and_container

# 课程提供的脚本：生成 qyt_error.service 并启动
sudo bash deploy_and_start_service.sh

# 刚启动 3 秒：服务在运行，记下主进程 PID
sleep 3
systemctl is-active qyt_error.service
systemctl show qyt_error.service -p MainPID --value

# 再等 20 秒：app.py 倒数到 0 时除以零崩溃
sleep 20
systemctl is-active qyt_error.service
systemctl status qyt_error.service --no-pager | sed -n 1,4p
journalctl -u qyt_error.service --no-pager -o cat | tail -8
```

```text
已安装并启动 qyt_error.service，工作目录: /docker_k8s_2026/docker/docker_1_intro/diff_service_and_container
--- t+3s
active
3290
--- t+23s
failed
× qyt_error.service - qyt error service
     Loaded: loaded (/etc/systemd/system/qyt_error.service; disabled; preset: enabled)
     Active: failed (Result: exit-code) since Mon 2026-11-23 14:24:18 UTC; 2s ago
   Duration: 20.155s
0
Traceback (most recent call last):
  File "/docker_k8s_2026/docker/docker_1_intro/diff_service_and_container/app.py", line 14, in <module>
    result = 100/i
             ~~~^~
ZeroDivisionError: division by zero
qyt_error.service: Main process exited, code=exited, status=1/FAILURE
qyt_error.service: Failed with result 'exit-code'.
```

**1.2 同一个程序打成镜像，作为容器运行**

```bash
# 同一目录下有 Dockerfile
docker build -q -t qyt-error-app .

# 前台运行，计时
start=$(date +%s)
docker run --name qyt-err qyt-error-app 2>&1 | tail -5
echo "ran $(( $(date +%s) - start ))s"

# 容器状态和退出码
docker ps -a --filter name=qyt-err --format "{{.Names}} {{.Status}}"
docker inspect qyt-err --format "ExitCode={{.State.ExitCode}}"

docker rm qyt-err
```

```text
sha256:5a1e52b95f457a928f7af8c3874bf10afdff1061fbd0e01a63f042775330ca86
0
Traceback (most recent call last):
  File "app.py", line 14, in <module>
    result = 100/i
ZeroDivisionError: division by zero
ran 20s
qyt-err Exited (1) Less than a second ago
ExitCode=1
```

两边的表现完全一样：都运行约 20 秒，都以退出码 1 结束。服务用 `systemctl status` 和 `journalctl` 看，容器用 `docker ps -a` 和 `docker logs` 看。

### 实验 2：可迁移性

**2.1 构建并运行 Flask 镜像**

```bash
cd /docker_k8s_2026/docker/docker_1_intro/flask_in_diff_linux

docker build -t collinsctk/flask_in_centos_ubuntu .

docker run -d --rm --name flask1 -p 8080:8080 collinsctk/flask_in_centos_ubuntu
sleep 3
curl -s http://localhost:8080/
docker stop flask1
```

```text
#8 unpacking to docker.io/collinsctk/flask_in_centos_ubuntu:latest 0.3s done
#8 DONE 1.2s
Hello World! I am in QYT container
```

**2.2 推到仓库 → 删掉本地镜像 → 重新拉取运行（用本机私有仓库代替 Docker Hub）**

```bash
# 起一个私有镜像仓库，监听 5000 端口
docker run -d --name registry -p 5000:5000 --restart unless-stopped registry:2
sleep 2

# 打上仓库地址的标签并推送
docker tag collinsctk/flask_in_centos_ubuntu localhost:5000/flask_in_centos_ubuntu
docker push -q localhost:5000/flask_in_centos_ubuntu

# 删掉本地所有 flask 镜像，确认真的没了
docker rmi -f collinsctk/flask_in_centos_ubuntu localhost:5000/flask_in_centos_ubuntu
docker images --format "{{.Repository}}" | grep -c flask

# 从仓库重新拉下来运行
docker pull -q localhost:5000/flask_in_centos_ubuntu
docker run -d --rm --name flask2 -p 8080:8080 localhost:5000/flask_in_centos_ubuntu
sleep 3
curl -s http://localhost:8080/
docker stop flask2

docker image inspect localhost:5000/flask_in_centos_ubuntu --format "arch={{.Architecture}} os={{.Os}}"
```

```text
localhost:5000/flask_in_centos_ubuntu:latest
0                                             ← 本地 flask 镜像数为 0
localhost:5000/flask_in_centos_ubuntu:latest
Hello World! I am in QYT container            ← 从仓库拉回来，照样能跑
arch=amd64 os=linux
```

如果要按课程原样推到 Docker Hub，命令是：

```bash
docker login                                          # 用你自己的 Docker Hub 账号
docker tag collinsctk/flask_in_centos_ubuntu <你的用户名>/flask_in_centos_ubuntu
docker push <你的用户名>/flask_in_centos_ubuntu
```

## 笔记 / 疑问

（自己补充）
