# 在 Ubuntu 上安装 Docker 与 Docker Compose

## 本步目标

- 在 Ubuntu 上通过 Docker 官方 apt 源安装 Docker Engine。
- 安装 Docker Compose 插件，并使用 `docker compose` 命令。
- 完成安装后的基础验证。

## 问题背景

Ubuntu 自带的 `docker.io` 与 Docker 官方版本不是同一套发布渠道，容易与后续实验环境不一致。本步骤统一使用 Docker 官方仓库安装，并同时安装 Compose 插件。

## 理论说明

- `docker-ce` 提供 Docker Engine。
- `docker-ce-cli` 提供 `docker` 命令行。
- `containerd.io` 提供容器运行时。
- `docker-compose-plugin` 提供 `docker compose` 子命令。

本课程后续统一使用 `docker compose`，不是 `docker-compose`。

## 验证方法

### 1. 确认系统版本

当前文档适用于 Docker 官方支持的 Ubuntu 版本，例如 `22.04`、`24.04`。可先执行：

```bash
cat /etc/os-release
```

关键看点：

- `ID=ubuntu`
- `VERSION_ID="22.04"` 或 `VERSION_ID="24.04"`
- `VERSION_CODENAME` 有值，例如 `jammy`、`noble`

### 2. 卸载可能冲突的旧包

```bash
sudo apt remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc || true
```

关键看点：

- 即使部分包未安装，命令也可以继续执行。
- 这里卸载的是冲突包，不会自动删除你后面新安装的 Docker 官方包。

### 3. 添加 Docker 官方 apt 源并安装

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

关键看点：

- 安装包中必须包含 `docker-compose-plugin`。
- 这里安装完成后，后续应使用 `docker compose` 命令。

### 4. 启动 Docker 服务

```bash
sudo systemctl enable --now docker
sudo systemctl status docker
```

预期结果：

- `docker` 服务状态为 `active (running)`。

### 5. 可选：配置数据目录与镜像加速

若需将镜像与容器数据存到指定目录，并配置国内/镜像加速（拉取镜像时走代理镜像站），可执行以下步骤。

**5.1 创建数据目录**

```bash
sudo mkdir -p /data/docker
```

**5.2 写入 daemon 配置**

`data-root` 指定镜像与容器数据的存储路径；`registry-mirrors` 为拉取镜像时使用的镜像加速列表，按顺序尝试。

```bash
sudo tee /etc/docker/daemon.json <<'EOF'
{
    "data-root": "/data/docker",
    "registry-mirrors": [
        "https://hub.xdark.top",
        "https://hub.littlediary.cn",
        "https://dockerpull.org",
        "https://hub.crdz.gq",
        "https://docker.1panel.live",
        "https://docker.unsee.tech",
        "https://docker.m.daocloud.io",
        "https://docker.kejilion.pro",
        "https://registry.dockermirror.com",
        "https://hub.rat.dev",
        "https://dhub.kubesre.xyz",
        "https://docker.nastool.de",
        "https://docker.udayun.com",
        "https://docker.rainbond.cc",
        "https://hub.geekery.cn",
        "https://docker.1panelproxy.com"
    ]
}
EOF
```

**5.3 重载配置并重启 Docker**

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl status docker
```

配置生效后，`docker pull` 会优先通过上述镜像站拉取，镜像与容器数据将存放在 `/data/docker`。

### 6. 验证安装结果

```bash
sudo docker run hello-world
sudo docker compose version
```

关键看点：

- `docker run hello-world` 能成功拉取并运行测试镜像。
- `docker compose version` 能正常输出版本号。
- 命令格式是 `docker compose`，中间是空格，不是 `docker-compose`。

### 7. 可选：允许当前用户直接使用 Docker

```bash
sudo usermod -aG docker "$USER"
```

执行后需要退出当前会话并重新登录。重新登录后可验证：

```bash
docker ps
docker compose version
```

## 预期结果

- `docker --version` 能正常输出版本。
- `docker compose version` 能正常输出版本。
- `docker run hello-world` 能成功运行。
- 后续执行 Compose 编排时，统一使用 `docker compose up -d`。

## 通过标准

- 已从 Docker 官方 apt 源成功安装 `docker-ce`、`docker-ce-cli`、`containerd.io`、`docker-compose-plugin`。
- `docker` 服务已启动并可正常运行容器。
- 能明确区分 `docker compose` 与 `docker-compose`，并在后续实验中使用前者。
