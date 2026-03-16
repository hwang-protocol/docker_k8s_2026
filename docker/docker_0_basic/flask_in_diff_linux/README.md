# 本步目标

- 理解本目录中 Flask 应用的镜像构建方式。
- 能够在本目录下执行 `docker build` 构建镜像，并用 `docker run` 运行容器、访问服务。

# 问题背景

本目录包含一个最小 Flask 应用（`app.py`）及用于构建镜像的 `Dockerfile`。镜像基于 `python:3.7-alpine`，在容器内监听 8080 端口。通过构建与运行，可验证“同一份应用在不同 Linux 环境（Alpine 容器）中运行”的效果。

# 理论说明

## Dockerfile 原文

```dockerfile
FROM python:3.7-alpine
ENV FLASK_APP app.py
ENV FLASK_RUN_HOST 0.0.0.0
WORKDIR /
COPY app.py app.py
RUN pip3 install -i https://mirrors.aliyun.com/pypi/simple/ flask
CMD ["flask", "run", "--port", "8080"]
```

## 逐行说明

| 行 | 指令 | 说明 |
|----|------|------|
| 1 | `FROM python:3.7-alpine` | 以官方镜像 `python:3.7-alpine` 为构建基础。Alpine 体积小，内置 Python 3.7，后续所有层在其上叠加。 |
| 2 | `ENV FLASK_APP app.py` | 设置环境变量 `FLASK_APP=app.py`。Flask 的 `flask run` 会据此找到应用入口文件，无需在命令行指定。 |
| 3 | `ENV FLASK_RUN_HOST 0.0.0.0` | 设置 Flask 开发服务器监听地址为 `0.0.0.0`。这样容器内进程监听所有网卡，宿主机通过端口映射才能访问；若为 `127.0.0.1`，则只能在容器内部访问。 |
| 4 | `WORKDIR /` | 将镜像内的工作目录设为根目录 `/`。后续 `COPY`、`RUN` 以及容器启动后的当前目录均在此下（本示例中 `app.py` 被复制到 `/app.py`）。 |
| 5 | `COPY app.py app.py` | 将构建上下文（即 `docker build` 时当前目录）中的 `app.py` 复制到镜像内路径 `app.py`。由于上一步 `WORKDIR /`，目标即 `/app.py`。 |
| 6 | `RUN pip3 install -i https://mirrors.aliyun.com/pypi/simple/ flask` | 在镜像内执行 `pip3 install`，使用阿里云 PyPI 镜像加速，安装 `flask`。该层会写入镜像，构建一次后复用。 |
| 7 | `CMD ["flask", "run", "--port", "8080"]` | 容器启动时的默认命令。使用 JSON 数组形式（exec 形式），在容器内执行 `flask run --port 8080`，即启动 Flask 开发服务器并监听 8080 端口。该进程为容器主进程，退出则容器退出。 |

**补充**：

- **构建**：在包含 `Dockerfile` 和 `app.py` 的目录下执行 `docker build -t <镜像名> .`，按上述顺序执行各层，生成可运行该应用的镜像。
- **运行**：运行容器时需将容器内 8080 端口映射到宿主机（如 `-p 8080:8080`），才能在宿主机访问 Flask 服务。

# 验证方法

## 1. 构建镜像

先切到本目录（使用你机器上的绝对路径），再执行构建：

```bash
cd /docker_k8s_2026/docker/docker_0_basic/flask_in_diff_linux
docker build -t flask-qyt .
```

**关键看点**：

- 必须先进入包含 `Dockerfile` 和 `app.py` 的目录再执行 `docker build`，否则会找不到文件或构建上下文错误。
- `-t flask-qyt` 为镜像打标签，便于后续 `docker run` 使用。
- 末尾 `.` 表示使用当前目录为构建上下文，Docker 会读取当前目录下的 `Dockerfile` 和 `COPY` 所需的 `app.py`。

构建成功时，终端会输出 `Successfully built ...` 和 `Successfully tagged flask-qyt:latest`。

## 2. 运行容器并访问

```bash
docker run --rm -p 8080:8080 flask-qyt
```

**关键看点**：

- `-p 8080:8080`：将容器内 8080 映射到宿主机 8080，便于在宿主机用浏览器或 `curl` 访问。
- `--rm`：容器退出后自动删除。
- 容器在前台运行，终端会输出 Flask 日志；在另一终端或浏览器访问 `http://localhost:8080/` 可看到页面内容。

验证请求示例（在宿主机另一终端执行）：

```bash
curl http://localhost:8080/
```

预期返回：`Hello World! I am in QYT container`。

## 3. 停止容器

在运行容器的终端按 `Ctrl+C`，容器主进程退出，容器随之停止（若使用了 `--rm`，容器会被删除）。

# 预期结果

- `docker build -t flask-qyt .` 成功完成，无报错。
- `docker run --rm -p 8080:8080 flask-qyt` 启动后，访问 `http://localhost:8080/` 得到 `Hello World! I am in QYT container`。
- 容器内 Flask 监听 0.0.0.0:8080，通过端口映射可在宿主机正常访问。

# 通过标准

- 能说明本目录下构建镜像的命令及含义（`docker build -t <镜像名> .`）。
- 能正确使用 `-p 8080:8080` 运行容器并访问 Flask 服务。
- 能说明构建上下文（当前目录）中 `Dockerfile` 与 `app.py` 的作用。
