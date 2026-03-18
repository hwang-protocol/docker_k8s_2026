# 主题：容器的可迁移性（Portability）

**可迁移性**在此指：将应用及其依赖打成**镜像**，经镜像仓库分发后，在**另一台已安装容器引擎、且 CPU 架构一致**的机器上，无需复制源码与重复配置运行环境，即可 `pull` 后以相同方式运行并得到一致行为。

本步以最小 Flask 应用为样本，演示：**构建 → 本地校验 → 推送仓库 → 异机拉取运行**，从而验证可迁移性。

# 本步目标

- 理解镜像如何封装运行环境，以及可迁移性依赖的要素（镜像、Registry、架构一致等）。
- 能在本目录完成 `docker build` / `docker run`（含端口映射），确认构建机侧行为正确。
- 能 `docker push` 至 Docker Hub，并在**未参与构建**的机器上 `docker pull` 后运行，用一致访问结果**证明可迁移**。

# 问题背景

本目录含 `app.py` 与 `Dockerfile`，镜像基于 **`python:3.7-alpine`**，监听 **8080**。标签示例为 `collinsctk/flask_in_centos_ubuntu`（名称与宿主机发行版无关，仅作仓库中的标识）。

验证路径对应可迁移性闭环：**构建机**产出镜像并推送；**目标机**仅具备 Docker（及网络拉取权限），不携带本仓库文件，仍能运行同一服务。

# 理论说明

## Dockerfile 原文

```dockerfile
FROM python:3.7-alpine
ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0
WORKDIR /
COPY app.py app.py
RUN pip3 install -i https://mirrors.aliyun.com/pypi/simple/ flask
CMD ["flask", "run", "--port", "8080"]
```

## 逐行说明

| 行 | 指令 | 说明 |
|----|------|------|
| 1 | `FROM python:3.7-alpine` | 构建基础镜像；Alpine 体积小，内含 Python 3.7。 |
| 2 | `ENV FLASK_APP=app.py` | `flask run` 据此加载应用入口。 |
| 3 | `ENV FLASK_RUN_HOST=0.0.0.0` | 监听所有接口；否则仅 `127.0.0.1` 时宿主机无法经 `-p` 访问。 |
| 4 | `WORKDIR /` | 后续 `COPY` 与容器工作目录为 `/`。 |
| 5 | `COPY app.py app.py` | 将构建上下文中的 `app.py` 拷入镜像（即 `/app.py`）。 |
| 6 | `RUN pip3 install ... flask` | 镜像内安装依赖，写入镜像层。 |
| 7 | `CMD ["flask", "run", "--port", "8080"]` | 容器主进程；JSON 数组为 exec 形式；进程退出则容器退出。 |

**构建与运行要点**：`docker build` 须在含 `Dockerfile` 与 `app.py` 的目录执行；`docker run` 需 `-p 8080:8080` 方可在宿主机访问容器内 8080。

**与可迁移性的关系**：依赖与代码写入镜像层后，**目标机只需镜像内容与容器运行时**，不必匹配构建机的 Python/Flask 安装方式；跨机分发依赖 **Registry**（本步为 Docker Hub）。**限制**：目标机与构建机需 **CPU 架构一致**（如均为 `amd64`），否则需多架构镜像或对应平台构建。

# 验证方法

**推荐顺序**：§1～§3 在构建机确认镜像可用；§4 推至仓库（**可迁移的发布环节**）；§5 在**未参与 build、未拷贝本仓库**的目标机仅 `pull`/`run`，与 §2 对照访问结果。§4 需 Docker Hub 账号及 push 权限，标签与 §1 一致。

## 1. 构建镜像

工作目录（可按本机路径调整）：

```bash
cd /docker_k8s_2026/docker/docker_0_intro/flask_in_diff_linux
docker build -t collinsctk/flask_in_centos_ubuntu .
```

**关键看点**：

- 当前目录须同时包含 `Dockerfile` 与 `app.py`；末尾 `.` 为构建上下文。
- `-t collinsctk/flask_in_centos_ubuntu` 为后续 `run` / `push` 所用标签。

成功时可见 `Successfully tagged collinsctk/flask_in_centos_ubuntu:latest`。

## 2. 运行容器并访问

```bash
docker run --rm -p 8080:8080 collinsctk/flask_in_centos_ubuntu
```

**关键看点**：`-p 8080:8080` 做端口映射；`--rm` 退出删容器。容器前台占用终端时，在**另一终端**或浏览器验证：

```bash
curl http://localhost:8080/
```

预期返回：`Hello World! I am in QYT container`。

## 3. 停止容器

在运行 `docker run` 的终端按 `Ctrl+C`，主进程结束，容器停止（`--rm` 时已删除容器实例）。

## 4. 推送到 Docker Hub

前提：§1 已构建出 `collinsctk/flask_in_centos_ubuntu`；Hub 上需存在与标签匹配的命名空间权限（示例使用 `collinsctk/…`，实操时可改为自己的用户名并相应修改 `build -t` 与 `push`）。

**4.1 登录**

```bash
docker login
```

- 会提示使用基于浏览器的登录（或使用 `docker login -u <username>` 命令行凭据）。
- 按提示在浏览器打开 https://login.docker.com/activate，输入终端给出的一次性设备码（如 `PFGV-WFJH`），在网页完成登录。
- 终端显示 `Login Succeeded` 即表示登录成功。
- 凭据会保存在 `~/.docker/config.json`；若需更安全存储可配置 credential helper。

**4.2 推送**

```bash
docker push collinsctk/flask_in_centos_ubuntu
```

默认推送 `latest`，即 `docker.io/collinsctk/flask_in_centos_ubuntu:latest`。成功可见各层 `Pushed` 及 digest。若本地无该镜像，回到 §1 目录执行 `docker build -t collinsctk/flask_in_centos_ubuntu .`。

## 5. 在另一台机器上拉取并运行（可迁移性验证）

在**未执行过上述 build**、也未拷贝本仓库的机器（如 Rocky Linux）上安装 Docker 后：

```bash
docker pull collinsctk/flask_in_centos_ubuntu
docker run --rm -p 8080:8080 collinsctk/flask_in_centos_ubuntu
```

访问 `http://<该机 IP>:8080/` 或 `curl http://localhost:8080/`，应同样得到 `Hello World! I am in QYT container`。与 §2 行为一致，即表明：**同一镜像经 Registry 迁移后，在异机可直接复现运行**（前提：架构一致、网络可达仓库）。

# 预期结果

- §1～§2：构建机在本地证明镜像可运行。
- §4：镜像进入仓库，成为**可分发单元**。
- §5：目标机无源码、无本地 build，仅 pull/run 即得到与 §2 相同的访问结果——**可迁移性成立**。

# 通过标准

- 能说明**可迁移性**的含义：镜像 + Registry + 同架构目标机上的等价运行。
- 能说明 `docker build` 构建上下文与 `-t` 的作用。
- 能使用 `-p 8080:8080` 运行并访问，并说明 `FLASK_RUN_HOST=0.0.0.0` 与映射的关系。
- 能完成 push，并在第二台机器 pull → run，用结果对照说明可迁移性。
