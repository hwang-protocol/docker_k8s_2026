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

这一章最常用的命令主要有 5 个：

1. `docker build`
   根据 Dockerfile 构建镜像。
2. `docker run`
   基于镜像启动容器，验证效果。
3. `docker image inspect`
   查看镜像配置，例如 `Env`、`Cmd`、`Entrypoint`、`ExposedPorts`。
4. `docker history`
   查看镜像分层和每一层对应的指令。
5. `docker rm` / `docker rmi`
   清理实验容器和镜像。

## 实验说明

为了避免误删你机器上其他无关的容器和镜像，本文只清理和本实验有关的对象：

- 容器名：`df-env-demo`、`df-entry-demo`、`df-copy-demo`、`df-add-demo`
- 镜像：`df-demo:env`、`df-demo:entry`、`df-demo:copy`、`df-demo:add`、`alpine:3.20`

也就是说：

- 开始前，把这些实验对象清到空
- 结束后，再把这些实验对象清到空

下面穿插的原始输出来自一次真实实验，时间为 `2026-03-16`。

## 0. 实验准备（一把梭前提）

以下所有命令均在**实验目录**下执行。实验目录即包含 `Dockerfile.env`、`hello.sh`、`Dockerfile.entrypoint`、`entrypoint.sh`、`Dockerfile.copy`、`Dockerfile.add` 以及用于生成 `site.tar.gz` 的 `site/` 目录的那一层；若使用本仓库，则为 `docker/docker_5_DockerFile/lab`。进入实验目录后，先生成 COPY/ADD 实验所需的压缩包（若已有 `site.tar.gz` 可跳过）：

```bash
cd docker/docker_5_DockerFile/lab   # 按你的实际路径调整
tar -czf site.tar.gz -C site .
```

确认压缩包内容（可选）：

```bash
tar -tzf site.tar.gz
```

应看到 `./` 与 `./index.html`。

## 1. 主线实验：从空开始，跑到空结束

### 第一步：先把实验环境清到空

```bash
docker rm -f df-env-demo df-entry-demo df-copy-demo df-add-demo >/dev/null 2>&1 || true
docker rmi df-demo:env df-demo:entry df-demo:copy df-demo:add alpine:3.20 >/dev/null 2>&1 || true
docker ps -a --format '{{.Names}}' | rg '^(df-env-demo|df-entry-demo|df-copy-demo|df-add-demo)$' || echo no-experiment-container
docker images --format '{{.Repository}}:{{.Tag}}' | rg '^(df-demo:(env|entry|copy|add)|alpine:3.20)$' || echo no-experiment-image
```

原始输出：

```text
no-experiment-container
no-experiment-image
```

说明：

- 这里只清理本文实验相关对象
- 不会去删除你机器上其他无关的容器和镜像
- 与第五部分收尾验证格式一致，便于一把梭时头尾对照

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
docker image inspect df-demo:env --format 'Labels={{json .Config.Labels}} Env={{json .Config.Env}} ExposedPorts={{json .Config.ExposedPorts}} Cmd={{json .Config.Cmd}} WorkingDir={{.Config.WorkingDir}}'
```

原始输出：

```text
Labels={"course":"docker2026","maintainer":"collinsctk"} Env=["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","APP_NAME=dockerfile-demo","APP_ENV=prod","APP_PORT=8080"] ExposedPorts={"8080/tcp":{}} Cmd=["/app/hello.sh"] WorkingDir=/app
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

### 第七步：再用 `docker history` 看一次分层

```bash
docker history --no-trunc df-demo:env
```

原始输出节选：

```text
IMAGE                                                                     CREATED          CREATED BY                                                SIZE
sha256:4b81bcf12c1b8256ead210bcd2ffab64a2f2e976aa8118ae9f91344deb02819a   17 seconds ago   CMD ["/app/hello.sh"]                                     0B
<missing>                                                                 17 seconds ago   EXPOSE [8080/tcp]                                         0B
<missing>                                                                 17 seconds ago   ENV APP_NAME=dockerfile-demo APP_ENV=prod APP_PORT=8080   0B
<missing>                                                                 17 seconds ago   RUN /bin/sh -c chmod +x /app/hello.sh # buildkit          12.3kB
<missing>                                                                 18 seconds ago   COPY hello.sh /app/hello.sh # buildkit                    12.3kB
<missing>                                                                 18 seconds ago   WORKDIR /app                                              8.19kB
<missing>                                                                 18 seconds ago   LABEL maintainer=collinsctk course=docker2026             0B
<missing>                                                                 6 weeks ago      ADD alpine-minirootfs-3.20.9-x86_64.tar.gz / # buildkit   8.47MB
```

关键看点：

- `docker history` 能直接把 Dockerfile 指令和镜像层对应起来
- `COPY`、`RUN` 这些通常会形成有体积变化的层
- `ENV`、`EXPOSE`、`CMD` 更多是在写镜像配置，体积常常显示为 `0B`

## 2. 单独讲透 `CMD` 和 `ENTRYPOINT`

这一段是 Dockerfile 里最容易绕的部分。

先看第二个 Dockerfile：

```dockerfile
FROM alpine:3.20

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]

CMD ["default-user"]
```

配套脚本 `entrypoint.sh`：

```sh
#!/bin/sh
echo "ENTRYPOINT received: $*"
```

这个实验的目标只有一个：

- 看清 `ENTRYPOINT` 和 `CMD` 到底是“谁是主命令，谁是默认参数”

### 第八步：构建 `ENTRYPOINT` 实验镜像

```bash
docker build --progress=plain -t df-demo:entry -f Dockerfile.entrypoint .
```

原始输出节选：

```text
#1 [internal] load build definition from Dockerfile.entrypoint
#2 [internal] load metadata for docker.io/library/alpine:3.20
#5 [2/4] WORKDIR /app
#7 [3/4] COPY entrypoint.sh /app/entrypoint.sh
#8 [4/4] RUN chmod +x /app/entrypoint.sh
#9 exporting to image
#9 naming to docker.io/library/df-demo:entry done
```

再查看镜像配置：

```bash
docker image inspect df-demo:entry --format 'Entrypoint={{json .Config.Entrypoint}} Cmd={{json .Config.Cmd}} WorkingDir={{.Config.WorkingDir}}'
```

原始输出：

```text
Entrypoint=["/app/entrypoint.sh"] Cmd=["default-user"] WorkingDir=/app
```

关键看点：

- `Entrypoint=["/app/entrypoint.sh"]` 说明主程序已经固定
- `Cmd=["default-user"]` 说明这里只是默认参数

### 第九步：第一次运行，不额外传参

```bash
docker run --rm df-demo:entry
```

原始输出：

```text
ENTRYPOINT received: default-user
```

说明：

- 没有额外传参时，`CMD ["default-user"]` 会作为参数传给 `ENTRYPOINT`

### 第十步：第二次运行，手工传入一个新参数

```bash
docker run --rm df-demo:entry alice
```

原始输出：

```text
ENTRYPOINT received: alice
```

说明：

- 运行容器时追加的 `alice`，替换掉了原来的 `CMD ["default-user"]`
- 但 `ENTRYPOINT` 仍然没有变

### 第十一步：第三次运行，直接改掉入口命令

```bash
docker run --rm --entrypoint sh df-demo:entry -c 'echo manual shell'
```

原始输出：

```text
manual shell
```

关键看点：

- `ENTRYPOINT` 更像固定主程序
- `CMD` 更像这个主程序的默认参数
- `docker run 镜像名 新参数`，通常覆盖的是 `CMD`
- `docker run --entrypoint ...`，才是在强行改入口命令

你可以先记一句最实用的话：

- 想给容器一个固定入口，优先考虑 `ENTRYPOINT`
- 想给这个入口提供默认参数，使用 `CMD`

## 3. 再做一个 `COPY` 和 `ADD` 的对比实验

这一段只讲一个最有价值的区别：

- `COPY` 是普通复制
- `ADD` 在处理本地压缩包时，会自动解压

依赖第 0 节中在实验目录下生成的 `site.tar.gz`。可再次确认压缩包内容：

```bash
tar -tzf site.tar.gz
```

原始输出：

```text
./
./index.html
```

### 第十二步：先用 `COPY`

Dockerfile：

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

Dockerfile：

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
docker rm -f df-env-demo df-entry-demo df-copy-demo df-add-demo >/dev/null 2>&1 || true
docker rmi df-demo:env df-demo:entry df-demo:copy df-demo:add alpine:3.20 >/dev/null 2>&1 || true
docker ps -a --format '{{.Names}}' | rg '^(df-env-demo|df-entry-demo|df-copy-demo|df-add-demo)$' || echo no-experiment-container
docker images --format '{{.Repository}}:{{.Tag}}' | rg '^(df-demo:(env|entry|copy|add)|alpine:3.20)$' || echo no-experiment-image
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
- 知道 `MAINTAINER` 已经过时，今天更推荐 `LABEL`
- 能说明 `ENTRYPOINT` 和 `CMD` 的关系
- 能说明为什么日常应优先使用 `COPY`，而不是默认用 `ADD`
