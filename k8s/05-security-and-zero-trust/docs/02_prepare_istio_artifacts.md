# 第 1 步：预热 Istio 制品与演示镜像

## 本步目标

在真正安装 `Istio` 之前，先把第五章所需制品准备好：

- `istioctl`
- `Istio 1.29.0` 离线安装包
- Harbor 中的 `istio` 项目
- `Istio` 核心平台镜像
- `helloworld`、`httpbin`、`curl` 演示镜像

这样后续安装与课堂演示都会更稳定，不依赖临时公网状态。

---

## 执行标记

- **执行标记：必须执行**

---

## 问题背景

第五章后续步骤同时依赖：

- `Istio CLI`
- `Istio` 控制面镜像
- `Ambient` 相关镜像
- 演示业务镜像

如果这些制品不先冻结：

- 安装时会混入实时下载
- 课堂节奏会被公网抖动打断
- 前后两次刷课结果可能不一致

因此本步的意义不是“先做点准备工作”，而是把第五章的安装与演示基础固定下来。

---

## 理论说明

### 为什么第五章要先做制品预热

这一章和前几章不同，它同时依赖 3 类制品：

- CLI：`istioctl`
- 平台镜像：`pilot`、`proxyv2`、`ztunnel`、`install-cni`
- 业务演示镜像：`helloworld`、`httpbin`、`curl`

这里的 `pilot`、`proxyv2`、`ztunnel`、`install-cni` 都是镜像名，当前省略了完整仓库前缀。可以先这样理解：

| 镜像名 | 主要用途 |
| :--- | :--- |
| `pilot` | `Istio` 控制面镜像，对应当前运行的 `istiod` |
| `proxyv2` | `Envoy` 代理镜像，入口网关和后续 `waypoint` 都会用到 |
| `ztunnel` | `Ambient` 模式下的节点级 `L4` 代理镜像 |
| `install-cni` | `Istio CNI` 安装镜像，用来把网格流量接入节点网络路径 |

本步完成后，`ops` 本地 `artifacts` 目录可以先理解成下面这样：

```text
/docker_k8s_2026/k8s/05-security-and-zero-trust/artifacts/
├── istio-1.29.0/
│   └── bin/
│       └── istioctl
├── istio-source-images-1.29.0.txt
└── istio-harbor-images-1.29.0.txt
```

其中：

- `istio-1.29.0/` 是展开后的 `Istio` 离线安装目录
- `bin/istioctl` 是离线目录里自带的 `CLI`
- 脚本会再把它安装到 `/usr/local/bin/istioctl`
- 两个 `txt` 文件分别记录源镜像列表和 Harbor 目标镜像列表

只有先把它们统一放进本地环境和 Harbor，后面才能做到：

- 安装命令稳定
- 版本固定
- 课堂现场重复性强

### 制品流转关系图

```mermaid
flowchart LR
  subgraph cli[离线包 / CLI 链]
    github[1. GitHub Release]
    ops[2. ops 本地 artifacts<br/>istio-1.29.0 目录]
    bundle[3. Istio 离线安装目录]
    cliTool[4. istioctl<br/>安装到 /usr/local/bin]

    github -->|下载| ops
    ops -->|保留安装包| bundle
    ops -->|安装 CLI| cliTool
  end

  subgraph image[镜像链]
    dockerhub[1. Docker Hub]
    harbor[2. Harbor 项目<br/>istio]
    nodes[3. 各 Kubernetes 节点<br/>预拉镜像]

    dockerhub -->|同步镜像| harbor
    harbor -->|内网拉取| nodes
  end

  install[5. 后续 Istio 安装]
  demo[6. 后续演示工作负载]

  bundle --> install
  cliTool --> install
  nodes --> install
  nodes --> demo
```

这张图说明：

- 左侧是离线包与 `CLI` 链，右侧是镜像链
- `GitHub Release` 只负责 `Istio` 离线包和 `istioctl`
- `Harbor` 只负责承载第五章镜像，不负责提供离线包
- 后续 `Istio` 安装同时依赖：
  - `ops` 本地的 `istioctl` 与离线包
  - 节点已经预拉好的平台镜像
- 后续演示工作负载只走镜像链，不依赖 `GitHub Release`

---

## 对应脚本

- `k8s/05-security-and-zero-trust/scripts/01_prepare_istio_artifacts.sh`

---

## 脚本关键任务

### 关键任务 1：下载并安装 `istioctl`

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
ISTIO_VERSION="1.29.0"
ISTIO_TAR="istio-${ISTIO_VERSION}-linux-amd64.tar.gz"
ISTIO_URL="https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/${ISTIO_TAR}"
```

关键介绍：

- 第五章固定 `Istio 1.29.0`
- `istioctl` 不直接通过包管理器安装，而是和离线包一起冻结

### 关键任务 2：建立 Harbor 镜像项目

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
HARBOR_PROJECT="istio"
```

关键介绍：

- 第五章镜像统一进入 `harbor.qytk8s.com/istio`
- 后续 `Istio` 安装、入口发布和演示应用都依赖这个项目

### 关键任务 3：整理源镜像与目标镜像映射

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
cat >"${SOURCE_IMAGE_LIST}" <<'EOF'
docker.io/istio/pilot:1.29.0-distroless
docker.io/istio/proxyv2:1.29.0-distroless
docker.io/istio/ztunnel:1.29.0-distroless
docker.io/istio/install-cni:1.29.0-distroless
docker.io/istio/examples-helloworld-v1:1.0
docker.io/istio/examples-helloworld-v2:1.0
docker.io/mccutchen/go-httpbin:v2.15.0
docker.io/curlimages/curl:8.12.1
EOF
```

关键介绍：

- 这里同时冻结了平台镜像和演示镜像
- 第五章不是只装 `Istio`，还要保证后面 `JWT`、`mTLS`、流量治理演示有稳定工作负载

### 关键任务 4：把镜像推入 Harbor 并在节点预拉

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
docker pull "\${src}"
docker tag "\${src}" "\${dst}"
docker push "\${dst}"
```

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
crictl --runtime-endpoint unix:///run/containerd/containerd.sock pull "\${image}"
```

关键介绍：

- 先推入 Harbor，再在所有节点预拉
- 这样后续步骤拉取镜像时会直接走内网仓库

---

## 执行命令

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选预处理命令</strong><br/>
如果脚本已具备执行权限，这一步可以跳过。
</div>

```bash
chmod +x /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/01_prepare_istio_artifacts.sh
```

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #ea4335; border-radius: 6px; background: rgba(234,67,53,0.10); margin: 8px 0;">
<strong>❗ 本步必须粘贴执行</strong><br/>
下面命令是本步主线必跑命令。
</div>

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/01_prepare_istio_artifacts.sh
```

---

## 验证方法

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
istioctl version --remote=false
```

关键看点：

- 重点看本地 `istioctl` 是否已经可用
- 这里不要求远端控制面版本，因为当前还没安装 `Istio`

预期结果：

- 能正常输出 `1.29.0`

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
ls -lh /docker_k8s_2026/k8s/05-security-and-zero-trust/artifacts
```

关键看点：

- 重点看是否已经出现：
  - `istio-1.29.0`
  - `istio-source-images-1.29.0.txt`
  - `istio-harbor-images-1.29.0.txt`

预期结果：

- 本地 `artifacts/` 目录中出现第五章所需离线包与镜像清单

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
curl -k -s -u 'admin:Harbor12345' \
  "https://harbor.qytk8s.com/api/v2.0/projects/istio/repositories?page=1&page_size=30" | jq -r '.[].name'
```

关键看点：

- 不需要读原始 JSON
- 重点看 Harbor 中是否已经出现：
  - `istio/pilot`
  - `istio/proxyv2`
  - `istio/ztunnel`
  - `istio/install-cni`
  - `istio/helloworld-v1`
  - `istio/helloworld-v2`
  - `istio/httpbin`
  - `istio/curl`

预期结果：

- Harbor 项目 `istio` 中能看到第五章所需关键仓库

---

## 通过标准

满足下面条件后，本步即可视为完成：

- `istioctl` 已可在 `ops` 上直接使用
- 本地 `artifacts/` 已具备离线包和镜像清单
- Harbor 中已具备第五章所需镜像

---

## 下一步

进入第 2 步，安装 `Istio Ambient`：

- `docs/03_install_istio_ambient.md`
