# Docker Compose 基础实验

## 本实验目标

本实验使用 3 个服务搭建一个最小但完整的 Compose 项目：

- `nginx`
- `app`（Flask）
- `redis`

这也是一个很经典的三层思路：

- `nginx` 可以理解为入口层
- `app`（Flask）可以理解为应用层
- `redis` 可以理解为数据层

这个实验不追求业务复杂度，而是用于把 Docker Compose 最常见的 5 个知识点一次讲清楚：

1. 卷
2. 网络
3. 用户权限
4. 环境变量
5. 自动启动

## 1. 实验拓扑

```mermaid
flowchart LR
  Browser[浏览器或 curl] -->|8080| Nginx[nginx]
  Nginx -->|backend 网络| App[flask app]
  App -->|backend 网络| Redis[redis]

  subgraph frontend 网络
    Nginx
  end

  subgraph backend 网络
    Nginx
    App
    Redis
  end

  Redis --> RedisData[(redisdata 卷)]
```

这里的 `frontend` 和 `backend` 都是 **网络名**，不是“前端应用”和“后端应用”的名字。  
Compose 里经常会用这种命名方式来表达通信边界，所以第一次看到时很容易误解。

从教学角度，这张图至少能说明 3 件事：

- `nginx` 是入口服务，所以它同时连接 `frontend` 网络和 `backend` 网络
- `app` 和 `redis` 不需要对宿主机开放端口
- Redis 的数据应放在卷中持久化

## 2. 实验目录

```text
lab/basic/
├── .env
├── docker-compose.yaml
├── app/
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
└── nginx/
    └── default.conf
```

## 3. Compose 文件

本实验的核心文件如下：

```yaml
services:
  nginx:
    image: nginx:1.29.1
    depends_on:
      app:
        condition: service_healthy
    ports:
      - "${WEB_PORT}:80"
    restart: unless-stopped
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - frontend
      - backend

  app:
    build:
      context: ./app
    depends_on:
      redis:
        condition: service_healthy
    environment:
      APP_NAME: "${APP_NAME}"
      APP_ENV: "${APP_ENV}"
      APP_PORT: "${APP_PORT}"
      CACHE_HOST: "${CACHE_HOST}"
      CACHE_PORT: "${CACHE_PORT}"
    expose:
      - "${APP_PORT}"
    healthcheck:
      test: ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:${APP_PORT}/healthz')\""]
      interval: 10s
      timeout: 3s
      retries: 10
      start_period: 5s
    restart: unless-stopped
    user: "10001:10001"
    networks:
      - backend

  redis:
    image: redis:8.2.3-alpine
    command: ["redis-server", "--appendonly", "yes"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 10
    restart: unless-stopped
    volumes:
      - redisdata:/data
    networks:
      - backend

volumes:
  redisdata:

networks:
  frontend:
  backend:
```

文件位置：

- [docker-compose.yaml](/docker_k8s_2026/docker/docker_6_compose/lab/basic/docker-compose.yaml)

## 4. 先读 Compose，再读代码

这一节按照教材思路，从 Compose 结构反过来理解整个项目。

### 4.1 `nginx` 服务

先看 `nginx` 在 Compose 文件中的定义：

```yaml
nginx:
  image: nginx:1.29.1
  depends_on:
    app:
      condition: service_healthy
  ports:
    - "${WEB_PORT}:80"
  restart: unless-stopped
  volumes:
    - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
  networks:
    - frontend
    - backend
```

在这个实验里，`nginx` 作为外部入口，配置上主要体现为 4 个特点：

- 使用公开镜像 `nginx:1.29.1`
- 通过 `ports` 把宿主机 `8080` 映射到容器 `80`
- 通过 `bind mount` 挂载自定义配置文件
- 连接两个网络：`frontend` 网络表示入口侧的网络边界，`backend` 网络用于访问后端服务

这里最值得讲清楚的是 `ports` 和 `networks` 的区别。  
在这个实验里，`nginx` 既要对宿主机提供访问入口，也要把请求转发给 `app`，所以示例中把它同时放进了 `frontend` 和 `backend`。

两者的区别可以直接概括为：

- `ports` 决定宿主机如何访问容器
- `networks` 决定容器之间如何互相访问

### 4.2 `app` 服务

先看 `app` 在 Compose 文件中的定义：

```yaml
app:
  build:
    context: ./app
  depends_on:
    redis:
      condition: service_healthy
  environment:
    APP_NAME: "${APP_NAME}"
    APP_ENV: "${APP_ENV}"
    APP_PORT: "${APP_PORT}"
    CACHE_HOST: "${CACHE_HOST}"
    CACHE_PORT: "${CACHE_PORT}"
  expose:
    - "${APP_PORT}"
  healthcheck:
    test: ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:${APP_PORT}/healthz')\""]
    interval: 10s
    timeout: 3s
    retries: 10
    start_period: 5s
  restart: unless-stopped
  user: "10001:10001"
  networks:
    - backend
```

这里能先看出几件事：

- `app` 不是直接使用现成镜像，而是通过 `build` 本地构建
- 它依赖 `redis` 的健康状态
- 它通过 `environment` 接收运行参数
- 它只加入 `backend`，不直接对宿主机开放入口

再看它实际使用的 Dockerfile：

```dockerfile
FROM python:3.12-alpine

WORKDIR /app

RUN addgroup -S appgroup && adduser -S -G appgroup -u 10001 appuser

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY app.py /app/app.py

CMD ["python", "/app/app.py"]
```

文件位置：

- [Dockerfile](/docker_k8s_2026/docker/docker_6_compose/lab/basic/app/Dockerfile)

这里可以顺带讲两个 Compose 概念。

第一，`build` 与 `image` 并不对立。  
在同一个 Compose 文件里，某些服务可以用现成镜像，某些服务可以现场构建。

第二，`user: "10001:10001"` 是一个非常实用的安全实践。  
它说明容器里的应用不必默认以 root 身份运行。

### 4.3 `redis` 服务

先看 `redis` 在 Compose 文件中的定义：

```yaml
redis:
  image: redis:8.2.3-alpine
  command: ["redis-server", "--appendonly", "yes"]
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    timeout: 3s
    retries: 10
  restart: unless-stopped
  volumes:
    - redisdata:/data
  networks:
    - backend
```

从这段定义里，最值得先注意的是两点：

```yaml
command: ["redis-server", "--appendonly", "yes"]
volumes:
  - redisdata:/data
```

第一，Redis 开启了 AOF 持久化；第二，数据目录挂到了具名卷 `redisdata`。  
这正是 Compose 中“卷”的最典型用法。  
对学生来说，要建立这样一个认识：

- 配置文件常常用 bind mount
- 数据目录常常用具名卷

## 5. 应用代码说明

### 5.1 Flask 程序

应用代码如下（关键处已加注释，便于理解与 Compose 的配合）：

```python
"""
Compose 基础实验：Flask 应用。
从环境变量读取 Redis 地址与运行配置，供 Compose 通过 environment 注入。
"""
import os

import redis
from flask import Flask, jsonify


app = Flask(__name__)

# 从环境变量读取配置，未设置时使用默认值；Compose 会在容器内注入这些变量
CACHE_HOST = os.getenv("CACHE_HOST", "redis")   # Redis 主机，Compose 中写服务名 redis 即可解析
CACHE_PORT = int(os.getenv("CACHE_PORT", "6379"))
APP_NAME = os.getenv("APP_NAME", "compose-basic-demo")
APP_ENV = os.getenv("APP_ENV", "prod")
APP_PORT = int(os.getenv("APP_PORT", "5000"))


def get_cache():
    """返回 Redis 客户端；decode_responses=True 使 get/incr 得到 str 而非 bytes。"""
    return redis.Redis(host=CACHE_HOST, port=CACHE_PORT, decode_responses=True)


@app.get("/")
def index():
    """首页：自增 Redis 中的计数，并返回当前配置与点击数（用于验证环境变量与连通性）。"""
    cache = get_cache()
    hits = cache.incr("compose_basic_hits")  # 键不存在时会先设为 0 再自增，得到 1
    return jsonify(
        {
            "app_name": APP_NAME,
            "app_env": APP_ENV,
            "cache_host": CACHE_HOST,
            "cache_port": CACHE_PORT,
            "hits": hits,
        }
    )


@app.get("/healthz")
def healthz():
    """健康检查：能连上 Redis 并 ping 通即返回 ok，供 Compose healthcheck 调用。"""
    cache = get_cache()
    cache.ping()
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=APP_PORT)  # 监听所有网卡，便于容器内被 Nginx 反代
```

文件位置：

- [app.py](/docker_k8s_2026/docker/docker_6_compose/lab/basic/app/app.py)

**关键注释说明**：模块顶部的 docstring 说明“从环境变量读配置”；各 `os.getenv` 旁注明由 Compose 注入；`get_cache`、`index`、`healthz` 的 docstring 说明用途及与 Compose（健康检查、服务名解析）的关系。本实验的教学重点是 Compose 环境变量，不是 Flask 本身。

这段代码明显依赖：

- `CACHE_HOST`
- `CACHE_PORT`
- `APP_NAME`
- `APP_ENV`
- `APP_PORT`

这些变量并没有写死在代码里，而是由 Compose 注入。

### 5.2 `.env` 文件

```env
WEB_PORT=8080
APP_NAME=compose-basic-demo
APP_ENV=prod
APP_PORT=5000
CACHE_HOST=redis
CACHE_PORT=6379
```

文件位置：

- [.env](/docker_k8s_2026/docker/docker_6_compose/lab/basic/.env)

这里可以配合官方文档解释：`.env` 不是随便放的文本文件，而是 Compose 变量替换的重要组成部分。

### 5.3 Nginx 反向代理配置

```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://app:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

文件位置：

- [default.conf](/docker_k8s_2026/docker/docker_6_compose/lab/basic/nginx/default.conf)

这段配置体现了 Compose 自带服务发现的价值。  
这里的 `proxy_pass http://app:5000;` 直接用了服务名 `app`，而不是手工查 IP。

## 6. 这个实验要讲透的 5 个 Compose 知识点

### 6.1 卷

本实验中出现了两种挂载方式：

- bind mount：`./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro`
- named volume：`redisdata:/data`

**关键看点**

- 配置文件通常用 bind mount，更直观，方便编辑
- 数据目录通常用具名卷，适合持久化
- `:ro` 表示只读挂载，这是一种值得强调的习惯

### 6.2 网络

本实验定义了两个网络：

- `frontend`
- `backend`

其中：

- `nginx` 连接两个网络
- `app` 和 `redis` 只连接 `backend`

这种设计比“所有服务都放进一个网络”更有教学价值，因为它能更直观地表达网络边界。

**关键看点**

- `nginx` 作为入口层，要同时面向外部和内部
- `redis` 不需要暴露端口，也不需要进入 `frontend` 网络
- Compose 网络本身就能承载服务发现

### 6.3 用户权限

`app` 服务用了：

```yaml
user: "10001:10001"
```

这说明容器中的业务进程可以用普通用户身份运行。  
虽然 `Dockerfile` 里创建了 `appuser`，但运行时仍然通过 Compose 再次明确指定用户，这种写法更直观。

**关键看点**

- “容器里运行”不代表就必须是 root
- Compose 可以把安全策略写进运行时配置

### 6.4 环境变量

Compose 通过 `environment` 把 `.env` 中的变量传给容器。

这带来的好处有两个：

- 应用代码不必写死参数
- 实验环境修改端口或运行模式时不需要改代码

### 6.5 自动启动

三个服务都用了：

```yaml
restart: unless-stopped
```

这是教学里值得保留的一个设置，因为它很贴近真实项目。  
当 Docker 服务重启后，只要没有人为停止，容器会自动拉起。

## 7. 配置检查命令

`docker compose config` 不是启动实验的必需步骤，但在教学和排错时很有价值。  
它可以用来查看变量替换后的最终配置：

```bash
cd /docker_k8s_2026/docker/docker_6_compose/lab/basic
docker compose config
```

这条命令的价值在于：

- 检查 `.env` 是否被正确替换
- 检查 YAML 语法是否正确
- 检查最终端口、卷、网络定义是否符合预期

如果只想直接启动实验，也可以直接执行下一节的 `docker compose up -d`。

## 8. 启动实验

```bash
cd /docker_k8s_2026/docker/docker_6_compose/lab/basic
docker compose up -d
```

第一次执行时，通常会看到类似下面的输出：

```text
✔ Image redis:8.2.3-alpine Pulled
✔ Image nginx:1.29.1       Pulled
✔ Image basic-app          Built
✔ Network basic_backend    Created
✔ Network basic_frontend   Created
✔ Volume basic_redisdata   Created
✔ Container basic-redis-1  Healthy
✔ Container basic-app-1    Healthy
✔ Container basic-nginx-1  Started
```

这段输出可以按 4 类来理解：

- `Image ... Pulled`
  表示 Compose 发现本地没有对应镜像，于是从镜像仓库拉取了 `redis` 和 `nginx` 的官方镜像。
- `Image basic-app Built`
  表示 `app` 服务不是直接使用现成镜像，而是根据当前目录下的 Dockerfile 本地构建出了一个镜像；`basic-app` 这个名字是 Compose 自动生成的。
- `Network ... Created`、`Volume ... Created`
  表示 Compose 根据文件里的定义，自动创建了项目需要的网络和具名卷。这里的 `basic_` 是项目名前缀，默认来自当前目录名 `basic`。
- `Container ... Healthy`、`Started`
  表示容器已经被创建并启动。其中 `redis` 和 `app` 配置了 `healthcheck`，所以会显示 `Healthy`；`nginx` 没有定义健康检查，因此这里只显示 `Started`。

这段输出也顺手说明了 Compose 的几个特点：

- 不需要手工先执行 `docker network create`
- 不需要手工先执行 `docker volume create`
- 需要拉镜像、构建镜像、建网络、建卷、起容器时，Compose 会按依赖顺序自动完成

如果再次执行 `docker compose up -d`，通常就不会再看到 `Pulled`、`Built`、`Created` 这些步骤，因为对应资源已经存在；Compose 会尽量复用已有资源，只在配置或镜像发生变化时重建。

## 9. 实验验证

### 9.1 查看服务状态

执行：

```bash
docker compose ps
```

示例输出：

```text
NAME            IMAGE                COMMAND                  SERVICE   CREATED       STATUS                 PORTS
basic-app-1     basic-app            "python /app/app.py"     app       2 hours ago   Up 2 hours (healthy)   5000/tcp
basic-nginx-1   nginx:1.29.1         "/docker-entrypoint.…"   nginx     2 hours ago   Up 2 hours             0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
basic-redis-1   redis:8.2.3-alpine   "docker-entrypoint.s…"   redis     2 hours ago   Up 2 hours (healthy)   6379/tcp
```

**关键看点**

- `app` 和 `redis` 都显示为 `healthy`
- 只有 `nginx` 发布了宿主机端口
- `app` 只暴露容器端口，没有对宿主机做 `ports` 映射

### 9.2 访问业务接口

命令：

```bash
curl -s http://127.0.0.1:8080/
```

示例输出：

```json
{"app_env":"prod","app_name":"compose-basic-demo","cache_host":"redis","cache_port":6379,"hits":2}
```

这个结果说明：

- Nginx 反代正常
- Flask 应用运行正常
- 应用已经成功连接 Redis
- `CACHE_HOST=redis` 的服务名解析是正常的

### 9.3 查看日志

命令：

```bash
docker compose logs --tail=20 app nginx redis
```

实际输出节选：

```text
nginx-1  | /docker-entrypoint.sh: Configuration complete; ready for start up
nginx-1  | 2026/03/17 03:14:30 [notice] 1#1: nginx/1.29.1
app-1    | 127.0.0.1 - - [17/Mar/2026 04:49:29] "GET / HTTP/1.0" 200 -
redis-1  | 1:M 17 Mar 2026 03:14:13.169 * Ready to accept connections tcp
nginx-1  | 172.18.0.1 - - [17/Mar/2026:04:49:29 +0000] "GET / HTTP/1.1" 200 99 "-" "curl/8.5.0" "-"
```

**关键看点**

- `redis` 已经进入 `Ready to accept connections`
- `app` 收到了来自 `nginx` 的请求
- `nginx` 记录了来自宿主机 `curl` 的访问

## 10. 这个实验体现了哪些 Compose 思路

### 10.1 入口层与业务层分离

即使是一个很小的实验，也不宜把 Web 服务和业务逻辑塞进同一个容器。  
拆分成 `nginx + app` 后，反向代理与应用本身的职责更清晰。

### 10.2 用健康检查配合依赖关系

Compose 官方文档反复强调：  
容器启动了，不代表服务已经就绪。

本实验中：

- `redis` 通过 `redis-cli ping` 判断健康
- `app` 通过访问 `/healthz` 判断健康
- `nginx` 等待 `app` 健康后再启动

这就是一个很典型的 Compose 实战写法。

### 10.3 把“运行方式”写进项目

Compose 最大的教学价值之一，就是把一个项目的运行方式文档化、代码化。  
当其他同学拿到项目目录后，只要执行：

```bash
docker compose up -d
```

就可以复现同样的实验环境。

## 11. 常见错误与排错思路

### 11.1 访问 `8080` 失败

先检查：

```bash
docker compose ps
docker compose logs nginx
```

重点看：

- 端口是否发布成功
- Nginx 配置是否挂载成功

### 11.2 `app` 无法连接 Redis

先检查：

```bash
docker compose logs app redis
```

重点看：

- `CACHE_HOST` 是否还是 `redis`
- `redis` 是否已经健康

### 11.3 改了 `.env` 却没生效

启动前先执行：

```bash
docker compose config
```

先看最终展开后的配置，再决定是否需要重建容器。

## 12. 本实验小结

这个基础实验虽然简单，但已经完整覆盖了 Compose 的核心日常能力：

- `build` 和 `image`
- `ports`
- `volumes`
- `networks`
- `environment`
- `depends_on`
- `healthcheck`
- `restart`
- `user`

如果能够真正看懂这个实验，再进入完整实验时，注意力就不会停留在 YAML 结构本身，而会转向“如何用 Compose 组织一个更真实的系统”。

## 13. 清空环境

本实验应以空环境开始、以空环境结束。验证完成后，在项目目录停止并删除容器与网络：

```bash
cd /docker_k8s_2026/docker/docker_6_compose/lab/basic
docker compose down
```

如需同时删除本实验的命名卷（如 `basic_redisdata`），可加 `-v`：

```bash
docker compose down -v
```

执行后可用 `docker ps`、`docker network ls` 确认无 `basic-*` 容器和 `basic_*` 网络，环境即已还原。
