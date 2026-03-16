# Dockerfile 关键指令

## 本文目标

- 理解 Dockerfile 最常用的关键指令。
- 掌握和 Dockerfile 配套使用的常用命令。
- 通过一条连续实验主线，讲清 `CMD`、`ENTRYPOINT`、`ENV`、`COPY`、`ADD` 这些最容易混淆的内容。

## 先建立一个直观印象

讲 Dockerfile 时，可以先用下面这种方式建立直觉：

- `FROM`
  这个镜像的基础是谁。
- `RUN`
  构建镜像时要执行什么命令。
- `COPY`
  把构建目录里的文件复制进镜像。
- `ADD`
  也能把文件放进镜像，但功能比 `COPY` 多一点。
- `WORKDIR`
  后续命令默认在哪个目录下执行。
- `EXPOSE`
  这个镜像打算使用哪个端口。
- `CMD`
  容器启动后，默认执行什么命令。
- `LABEL`
  给镜像补充维护信息或课程信息。

## 先记住和 Dockerfile 配套的常用命令

这一章最常用的命令主要有 4 个：

1. `docker build`
   根据 Dockerfile 构建镜像。
2. `docker run`
   基于镜像启动容器，验证效果。
3. `docker image inspect`
   查看镜像配置，例如 `Env`、`Cmd`、`Entrypoint`、`ExposedPorts`。
4. `docker rm` / `docker rmi`
   清理实验容器和镜像。

## 实验说明

为了避免误删你机器上其他无关的容器和镜像，本文只清理和本实验有关的对象：

- 容器名：`df-env-demo`
- 镜像：`df-demo:env`、`df-demo:entry`、`df-demo:copydir`、`df-demo:copy`、`df-demo:add`、`alpine:3.20`、`python:3.12-alpine`

## 实验准备

以下所有命令均在**实验目录**下执行。实验目录即包含 `Dockerfile.env`、`hello.sh`、`Dockerfile.entrypoint`、`entrypoint_demo.py`、`Dockerfile.copydir`、`Dockerfile.copy`、`Dockerfile.add` 以及用于生成 `site.tar.gz` 的 `site/` 目录的那一层；若使用本仓库，则为 `docker/docker_5_DockerFile/lab`。进入实验目录后，先生成 COPY/ADD 实验所需的压缩包（若已有 `site.tar.gz` 可跳过）：

```bash
cd docker/docker_5_DockerFile/lab   # 按你的实际路径调整
tar -czf site.tar.gz -C site .
```

这条命令的含义是：

- `-c`
  创建一个新的压缩包。
- `-z`
  使用 `gzip` 压缩。
- `-f site.tar.gz`
  把结果文件名指定为 `site.tar.gz`。
- `-C site .`
  先切到 `site` 目录，再把这个目录下的内容打包进去。

所以这条命令的整体作用就是：

- 把 `site/` 目录里的内容打成一个名为 `site.tar.gz` 的压缩包

确认压缩包内容（可选）：

```bash
tar -tzf site.tar.gz
```

应看到 `./` 与 `./index.html`。

## 1. 先做一个最小可运行镜像

### 第一步：先把实验环境清到空

```bash
docker rm -f df-env-demo >/dev/null 2>&1 || true
docker rmi df-demo:env df-demo:entry df-demo:copydir df-demo:copy df-demo:add alpine:3.20 python:3.12-alpine >/dev/null 2>&1 || true
docker ps -a --format '{{.Names}}' | grep -E '^df-env-demo$' || echo no-experiment-container
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^(df-demo:(env|entry|copydir|copy|add)|alpine:3.20|python:3.12-alpine)$' || echo no-experiment-image
```

原始输出：

```text
no-experiment-container
no-experiment-image
```

说明：

- 这里只清理本文实验相关对象
- 不会去删除你机器上其他无关的容器和镜像

### 第二步：准备第一个 Dockerfile，先把基础指令串起来

先看文件 `Dockerfile.env`：

```dockerfile
FROM alpine:3.20

LABEL maintainer="collinsctk" course="docker2026"

WORKDIR /app

COPY hello.sh /app/hello.sh

RUN chmod +x /app/hello.sh

ENV APP_NAME=dockerfile-demo \
    APP_ENV=prod \
    APP_PORT=8080

EXPOSE 8080

CMD ["/app/hello.sh"]
```

配套脚本 `hello.sh`：

```sh
#!/bin/sh
echo "hello from Dockerfile"
echo "APP_NAME=$APP_NAME"
echo "APP_ENV=$APP_ENV"
echo "APP_PORT=$APP_PORT"
echo "PWD=$(pwd)"
```

这一组指令正好能把最常用的几个点一次串起来：

- `FROM alpine:3.20`
  指定基础镜像。
- `LABEL ...`
  给镜像补充维护信息或课程信息。
- `WORKDIR /app`
  后续默认工作目录切到 `/app`。
- `COPY hello.sh /app/hello.sh`
  把脚本复制进镜像。
- `RUN chmod +x /app/hello.sh`
  在构建时给脚本执行权限。
- `ENV ...`
  设置镜像默认环境变量。
- `EXPOSE 8080`
  声明镜像打算使用 `8080` 端口。
- `CMD ["/app/hello.sh"]`
  指定容器启动后的默认命令。

### 第三步：构建第一个镜像

```bash
docker build --progress=plain -t df-demo:env -f Dockerfile.env .
```

其中：

- `--progress=plain`
  表示用普通文本方式输出构建过程，方便在终端里逐步查看，也方便课堂记录原始输出。

它不是必须参数。

- 不写也能正常构建
- 这里只是为了让输出更直观

原始输出节选：

```text
#1 [internal] load build definition from Dockerfile.env
#1 transferring dockerfile: 287B done
#2 [internal] load metadata for docker.io/library/alpine:3.20
#5 [1/4] FROM docker.io/library/alpine:3.20@sha256:a4f4213abb84c497377b8544c81b3564f313746700372ec4fe84653e4fb03805
#6 [internal] load build context
#7 [2/4] WORKDIR /app
#8 [3/4] COPY hello.sh /app/hello.sh
#9 [4/4] RUN chmod +x /app/hello.sh
#10 exporting to image
#10 naming to docker.io/library/df-demo:env done
```

关键看点：

- `FROM`、`WORKDIR`、`COPY`、`RUN` 都直接出现在构建过程里
- `RUN chmod +x /app/hello.sh` 是在构建阶段执行，不是容器启动后执行
- 最后一行 `naming to docker.io/library/df-demo:env` 说明镜像已经构建成功

### 第四步：用 `docker image inspect` 看镜像配置

```bash
docker image inspect df-demo:env --format $'Labels={{json .Config.Labels}}\nEnv={{json .Config.Env}}\nExposedPorts={{json .Config.ExposedPorts}}\nCmd={{json .Config.Cmd}}\nWorkingDir={{.Config.WorkingDir}}'
```

原始输出：

```text
Labels={"course":"docker2026","maintainer":"collinsctk"}
Env=["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","APP_NAME=dockerfile-demo","APP_ENV=prod","APP_PORT=8080"]
ExposedPorts={"8080/tcp":{}}
Cmd=["/app/hello.sh"]
WorkingDir=/app
```

关键看点：

- `Labels=...` 对应 Dockerfile 里的 `LABEL`
- `Env=...` 对应 Dockerfile 里的 `ENV`
- `ExposedPorts={"8080/tcp":{}}` 对应 Dockerfile 里的 `EXPOSE`
- `Cmd=["/app/hello.sh"]` 对应 Dockerfile 里的 `CMD`
- `WorkingDir=/app` 对应 Dockerfile 里的 `WORKDIR`

这里也顺手记住：

- `EXPOSE` 只是镜像元数据里的端口声明
- 它不会自动把端口发布到宿主机
- 真正发布端口，还是要在 `docker run` 时写 `-p`

### 第五步：运行这个镜像，观察 `ENV`、`WORKDIR`、`CMD`

```bash
docker run --name df-env-demo df-demo:env
```

原始输出：

```text
hello from Dockerfile
APP_NAME=dockerfile-demo
APP_ENV=prod
APP_PORT=8080
PWD=/app
```

关键看点：

- `APP_NAME`、`APP_ENV`、`APP_PORT` 都来自 Dockerfile 里的 `ENV`
- `PWD=/app` 说明容器启动时默认工作目录已经是 `WORKDIR /app`
- 直接执行的就是 `CMD ["/app/hello.sh"]`

再看一下这个容器的状态：

```bash
docker ps -a --filter name='^/df-env-demo$' --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

原始输出：

```text
NAMES         IMAGE         STATUS
df-env-demo   df-demo:env   Exited (0) About a minute ago
```

关键看点：

- `CMD` 执行完之后，容器就会退出
- 这不是镜像坏了，而是默认命令已经正常执行完成了

### 第六步：继续做一个 `ENV` 覆盖实验

```bash
docker run --rm -e APP_ENV=test -e APP_PORT=9090 df-demo:env
```

原始输出：

```text
hello from Dockerfile
APP_NAME=dockerfile-demo
APP_ENV=test
APP_PORT=9090
PWD=/app
```

关键看点：

- Dockerfile 里的 `ENV` 是默认值
- `docker run -e` 可以在启动容器时覆盖它
- 镜像里的默认值和运行时传入的值，要区分开来看

## 2. 单独讲透 `CMD` 和 `ENTRYPOINT`

这一段是 Dockerfile 里最容易绕的部分。

先看文件 `Dockerfile.entrypoint`：

```dockerfile
FROM python:3.12-alpine

WORKDIR /app

COPY entrypoint_demo.py /app/entrypoint_demo.py

RUN pip install requests \
    && apk add --no-cache curl

ENTRYPOINT ["python3", "/app/entrypoint_demo.py"]

CMD ["https://www.baidu.com"]
```

配套脚本 `entrypoint_demo.py`：

```python
import sys

import requests

if __name__ == "__main__":
    if len(sys.argv) > 1:
        target = sys.argv[1]
    else:
        target = "https://www.qytang.com"

    req_result = requests.get(target, timeout=10)

    print(f"sys.argv={sys.argv}")
    print(f"url={target}")
    print(f"status_code={req_result.status_code}")
```

这个脚本本身没有复杂逻辑，它只是做两件事：

- 把 Python 程序收到的参数打印出来
- 再发起一次 HTTP 请求，并把最终访问的 URL 和状态码打印出来

这样做的目的很直接：

- 看容器启动时，Python 程序最后到底收到了什么参数
- 用最直观的方式观察 `ENTRYPOINT` 和 `CMD` 是怎么组合在一起的

这里的 `sys.argv` 可以直接理解成：

- Python 程序启动时收到的参数列表

例如：

- 如果容器内部实际执行的效果接近于 `python3 /app/entrypoint_demo.py https://www.baidu.com`
  那么 `sys.argv` 里就会看到 `https://www.baidu.com`
- 如果容器内部实际执行的效果接近于 `python3 /app/entrypoint_demo.py https://www.qytang.com`
  那么 `sys.argv` 里就会看到 `https://www.qytang.com`

所以这段脚本的作用，本质上就是把：

- `ENTRYPOINT` 后面到底跟了什么参数
- `CMD` 有没有作为默认参数传进来

直接打印给你看。

这个实验的目标只有一个：

- 看清 `ENTRYPOINT` 和 `CMD` 到底是“谁是主程序，谁是默认参数”

### 第七步：构建 `ENTRYPOINT` 实验镜像

```bash
docker build --progress=plain -t df-demo:entry -f Dockerfile.entrypoint .
```

原始输出节选：

```text
#1 [internal] load build definition from Dockerfile.entrypoint
#2 [internal] load metadata for docker.io/library/python:3.12-alpine
#6 [1/4] FROM docker.io/library/python:3.12-alpine@sha256:7747d47f92cfca63a6e2b50275e23dba8407c30d8ae929a88ddd49a5d3f2d331
#7 [2/4] WORKDIR /app
#8 [3/4] COPY entrypoint_demo.py /app/entrypoint_demo.py
#9 [4/4] RUN pip install requests     && apk add --no-cache curl
#9 8.258 Successfully installed certifi-2026.2.25 charset_normalizer-3.4.6 idna-3.11 requests-2.32.5 urllib3-2.6.3
#9 11.82 (10/10) Installing curl (8.17.0-r1)
#10 exporting to image
#10 naming to docker.io/library/df-demo:entry done
```

再查看镜像配置：

```bash
docker image inspect df-demo:entry --format $'Entrypoint={{json .Config.Entrypoint}}\nCmd={{json .Config.Cmd}}\nWorkingDir={{.Config.WorkingDir}}'
```

原始输出：

```text
Entrypoint=["python3","/app/entrypoint_demo.py"]
Cmd=["https://www.baidu.com"]
WorkingDir=/app
```

关键看点：

- `Entrypoint=["python3","/app/entrypoint_demo.py"]` 表示容器启动时默认执行的是这个 Python 程序
- `Cmd=["https://www.baidu.com"]` 表示默认给这个程序再传入一个参数 `https://www.baidu.com`

把它们拼在一起看，容器内部的实际执行效果接近：

```bash
python3 /app/entrypoint_demo.py https://www.baidu.com
```

这里表达的是容器内部的执行效果，不是让你在宿主机终端里直接敲这条命令。

### 第八步：第一次运行，不额外传参

```bash
docker run --rm df-demo:entry
```

原始输出：

```text
sys.argv=['/app/entrypoint_demo.py', 'https://www.baidu.com']
url=https://www.baidu.com
status_code=200
```

说明：

- 没有额外传参时，`CMD ["https://www.baidu.com"]` 会作为参数传给 `ENTRYPOINT`

### 第九步：第二次运行，手工传入一个新参数

```bash
docker run --rm df-demo:entry https://www.qytang.com
```

原始输出：

```text
sys.argv=['/app/entrypoint_demo.py', 'https://www.qytang.com']
url=https://www.qytang.com
status_code=200
```

说明：

- 运行容器时追加的 `https://www.qytang.com`，替换掉了原来的 `CMD ["https://www.baidu.com"]`
- 但 `ENTRYPOINT` 仍然没有变

### 第十步：第三次运行，直接改掉入口命令

```bash
docker run --rm --entrypoint curl df-demo:entry -I -s https://www.baidu.com
```

原始输出：

```text
HTTP/1.1 200 OK
Cache-Control: private, no-cache, no-store, proxy-revalidate, no-transform
Content-Length: 0
Content-Type: text/html
Pragma: no-cache
Server: bfe
Date: Mon, 16 Mar 2026 14:29:35 GMT
```

关键看点：

- `ENTRYPOINT` 更像固定主程序
- `CMD` 更像这个主程序的默认参数
- `docker run 镜像名 新参数`，通常覆盖的是 `CMD`
- `docker run --entrypoint ...`，才是在强行改入口命令
- 这一条命令里，原来的 Python 入口已经完全没有执行，而是直接改成了 `curl`

你可以先记一句最实用的话：

- 想给容器一个固定入口，优先考虑 `ENTRYPOINT`
- 想给这个入口提供默认参数，使用 `CMD`

## 3. 再做一个 `COPY` 和 `ADD` 的对比实验

这一段只讲一个最有价值的区别：

- `COPY` 是普通复制
- `ADD` 在处理本地压缩包时，会自动解压

依赖前面实验准备中生成的 `site.tar.gz`。可再次确认压缩包内容：

```bash
tar -tzf site.tar.gz
```

原始输出：

```text
./
./index.html
```

### 第十一步：先看 `COPY` 目录

文件 `Dockerfile.copydir`：

```dockerfile
FROM alpine:3.20

WORKDIR /data

COPY site /data/site

CMD ["sh", "-c", "find /data -maxdepth 3 -type f | sort"]
```

构建镜像：

```bash
docker build --progress=plain -t df-demo:copydir -f Dockerfile.copydir .
```

原始输出节选：

```text
#1 [internal] load build definition from Dockerfile.copydir
#4 [internal] load build context
#5 [1/3] FROM docker.io/library/alpine:3.20@sha256:a4f4213abb84c497377b8544c81b3564f313746700372ec4fe84653e4fb03805
#6 [2/3] WORKDIR /data
#7 [3/3] COPY site /data/site
#8 exporting to image
#8 naming to docker.io/library/df-demo:copydir done
```

运行镜像：

```bash
docker run --rm df-demo:copydir
```

原始输出：

```text
/data/site/index.html
```

关键看点：

- `COPY` 不只能复制单个文件，也可以直接复制整个目录
- `site` 目录在镜像里会变成 `/data/site`
- 这类写法很常见，例如把源码目录、静态文件目录、配置目录整体复制进镜像

### 第十二步：再看 `COPY` 普通复制压缩包

文件 `Dockerfile.copy`：

```dockerfile
FROM alpine:3.20

WORKDIR /data

COPY site.tar.gz /data/

CMD ["sh", "-c", "find /data -maxdepth 2 -type f | sort"]
```

构建镜像：

```bash
docker build --progress=plain -t df-demo:copy -f Dockerfile.copy .
```

原始输出节选：

```text
#1 [internal] load build definition from Dockerfile.copy
#4 [internal] load build context
#5 [1/3] FROM docker.io/library/alpine:3.20@sha256:a4f4213abb84c497377b8544c81b3564f313746700372ec4fe84653e4fb03805
#6 [2/3] WORKDIR /data
#7 [3/3] COPY site.tar.gz /data/
#8 exporting to image
#8 naming to docker.io/library/df-demo:copy done
```

运行镜像：

```bash
docker run --rm df-demo:copy
```

原始输出：

```text
/data/site.tar.gz
```

关键看点：

- `COPY` 做的就是普通复制
- 压缩包还是压缩包，没有自动展开

### 第十三步：再用 `ADD`

文件 `Dockerfile.add`：

```dockerfile
FROM alpine:3.20

WORKDIR /data

ADD site.tar.gz /data/

CMD ["sh", "-c", "find /data -maxdepth 2 -type f | sort"]
```

构建镜像：

```bash
docker build --progress=plain -t df-demo:add -f Dockerfile.add .
```

原始输出节选：

```text
#1 [internal] load build definition from Dockerfile.add
#4 [internal] load build context
#5 [1/3] FROM docker.io/library/alpine:3.20@sha256:a4f4213abb84c497377b8544c81b3564f313746700372ec4fe84653e4fb03805
#6 [2/3] WORKDIR /data
#7 [3/3] ADD site.tar.gz /data/
#8 exporting to image
#8 naming to docker.io/library/df-demo:add done
```

运行镜像：

```bash
docker run --rm df-demo:add
```

原始输出：

```text
/data/index.html
```

关键看点：

- 这里压缩包已经自动展开了
- 这正是 `ADD` 和 `COPY` 最值得记住的区别

这一段最后记一句就够了：

- 日常默认优先用 `COPY`
- 只有在确实需要“自动解压本地压缩包”时，再考虑 `ADD`

## 4. 最后收成几条最实用的结论

### 4.1 `FROM`

- 每个 Dockerfile 都要先有基础镜像
- 它决定了后续环境从哪里开始

### 4.2 `RUN` 和 `CMD` 不是一回事

- `RUN` 是构建镜像时执行
- `CMD` 是容器启动时默认执行

### 4.3 `WORKDIR`

- 它等价于“后续默认切到哪个目录工作”
- 比在多行里反复写 `cd` 更清晰

### 4.4 `ENV`

- 适合放镜像默认环境变量
- 运行容器时可以用 `-e` 覆盖

### 4.5 `COPY` 和 `ADD`

- 默认优先 `COPY`
- 只有需要自动解压本地压缩包时，再考虑 `ADD`

### 4.6 `EXPOSE`

- 只是镜像里的端口声明
- 不等于真正对外开放端口

### 4.7 `CMD` 和 `ENTRYPOINT`

- `ENTRYPOINT` 适合固定主程序
- `CMD` 适合提供默认参数

## 5. 把实验环境清回空

```bash
docker rm -f df-env-demo >/dev/null 2>&1 || true
docker rmi df-demo:env df-demo:entry df-demo:copydir df-demo:copy df-demo:add alpine:3.20 python:3.12-alpine >/dev/null 2>&1 || true
docker ps -a --format '{{.Names}}' | grep -E '^df-env-demo$' || echo no-experiment-container
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^(df-demo:(env|entry|copydir|copy|add)|alpine:3.20|python:3.12-alpine)$' || echo no-experiment-image
```

原始输出：

```text
no-experiment-container
no-experiment-image
```

到这里，本实验再次回到空：

- 没有实验容器
- 没有实验镜像

## 通过标准

- 能说清楚 `FROM`、`RUN`、`WORKDIR`、`COPY`、`ENV`、`CMD` 的基本作用
- 知道 `EXPOSE` 只是声明端口，不等于真正发布端口
- 知道可以用 `LABEL` 给镜像补充维护信息
- 能说明 `ENTRYPOINT` 和 `CMD` 的关系
- 能说明为什么日常应优先使用 `COPY`，而不是默认用 `ADD`
