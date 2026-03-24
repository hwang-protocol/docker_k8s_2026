# 第 1 步：预热 Cilium 制品到 Harbor 与 ops HTTP

## 本步目标

在正式安装 `Cilium` 之前，先把第二章所需的关键制品准备到本地环境中。

本步完成后，应达到下面状态：

- `Cilium 1.19.1` Helm chart 已下载到 `ops`
- `cilium CLI` 与 `hubble CLI` 已安装到 `ops`
- Harbor 中已经存在公共项目 `cilium`
- `Cilium`、`Hubble` 与第二章 demo 镜像已经推送到 `harbor.qytk8s.com/cilium`
- 第二章所需文件已在 `ops` 本地准备好，后续安装尽量不依赖公网

---

## 执行标记

- **执行标记：必须执行**

第二章后续安装依赖本步准备的 chart、CLI 和镜像；本步的目标是把安装 `Cilium` 所需的制品准备完整。

---

## 理论说明

### 为什么第二章要先做制品预热

先把 chart、CLI 和镜像准备完整，下一步就只专注 `Cilium` 的安装、配置与验收。

### 什么是 Helm

`Helm` 可以理解为 Kubernetes 的包管理工具。

它把一组 Kubernetes 资源和参数组织成一个 `chart`，安装时再结合 `values` 渲染出最终 YAML。

第二章中，`Cilium` 就通过 `Helm chart` 安装，因此本步需要先准备 `Helm` 和固定版本的 `chart`。

### Helm 在这里的意义

`Helm` 体现的是云原生交付方式的一部分：把组件做成可复用、可参数化、可版本化的安装包。

在第二章里，只需要把握一点：`Cilium` 不是靠手工拼接大量 YAML 安装，而是通过 `chart` 和 `values` 统一交付。

### 第二章中会用到的 Helm 命令

第二章会用到下面几条 `Helm` 命令：

| 命令 | 作用 |
| :--- | :--- |
| `helm version --short` | 检查 `Helm` 是否已安装，并确认版本 |
| `helm repo add cilium https://helm.cilium.io/` | 添加 `Cilium` 官方 chart 仓库 |
| `helm repo update` | 更新本地 chart 索引 |
| `helm pull cilium/cilium --version 1.19.1 --destination artifacts/` | 下载固定版本的 `Cilium` chart 到本地 |
| `helm upgrade --install cilium artifacts/cilium-1.19.1.tgz --namespace kube-system --values manifests/cilium-values.yaml` | 在第 2 步中使用本地 chart 和本地 values 安装或升级 `Cilium` |

- 第 1 步主要用到 `repo add`、`repo update`、`pull`
- 第 2 步主要用到 `upgrade --install`
- `manifests/cilium-values.yaml` 在下一步安装时才实际使用，本步只做准备

### 本步制品关系图

```mermaid
flowchart LR
  upstream[上游仓库 / Release]
  step1[1. ops<br/>下载 Helm chart 和 CLI]
  step2[2. Harbor cilium 项目<br/>同步 Cilium / Hubble / demo 镜像]
  step3[3. 所有 Kubernetes 节点<br/>预拉关键镜像]
  step4[4. 下一步安装 Cilium<br/>直接使用本地制品]

  upstream -. 下载来源 .-> step1
  upstream -. 镜像来源 .-> step2
  step1 --> step4
  step2 --> step3 --> step4
```

图中 `1` 到 `4` 就是本步顺序：先在 `ops` 准备 chart 和 CLI，再把镜像同步到 Harbor，并在节点预拉，最后下一步安装直接使用这些本地制品。

### 第二章制品分层

本步制品可分为三类：

- `ops` 本地工具：`helm`、`cilium CLI`、`hubble CLI`
- `ops` 本地文件：`artifacts/`、`manifests/`、本地 values 文件
- Harbor 与节点镜像：`cilium` 项目、课程镜像、各节点预拉缓存

---

## 本步固定版本

本课程第二章统一冻结：

- Cilium：`1.19.1`
- Helm Chart：`1.19.1`
- `cilium CLI`：`v0.19.1`
- `hubble CLI`：`v1.18.6`

`Hubble UI` 课程固定镜像为：

- `harbor.qytk8s.com/cilium/hubble-ui:v0.13.3-qyfix`
- `harbor.qytk8s.com/cilium/hubble-ui-backend:v0.13.3-qyfix`

---

## Harbor 项目规划

第二章统一使用 Harbor 公共项目：

- 项目名称：`cilium`
- Harbor 地址：`harbor.qytk8s.com`

第二章中涉及的核心镜像和 demo 镜像统一推送到：

```text
harbor.qytk8s.com/cilium
```

---

## 对应脚本

本步对应脚本：

- `k8s/02-cloud-native-networking/scripts/01_prepare_cilium_artifacts.sh`

脚本负责下载、安装、下发、预热；安装时真正使用的配置仍保留在项目目录中，例如：

- `artifacts/cilium-1.19.1.tgz`
- `manifests/cilium-values.yaml`
- 后续 demo YAML 文件

---

## 脚本内部在做什么

### 脚本执行主线

1. 准备本地目录
2. 安装 Helm
3. 创建 Harbor 项目
4. 下载 Helm chart
5. 安装 `cilium CLI`
6. 安装 `hubble CLI`
7. 在 `harbor` 节点拉取并推送镜像
8. 在所有 Kubernetes 节点预拉镜像
9. 在 `ops` 上做本地制品检查

### 重要任务 1：准备本地目录

脚本原始代码：

```bash
prepare_local_dirs() {
  mkdir -p "${ARTIFACTS_DIR}" "${TMP_DIR}" "${ARTIFACTS_DIR}/bin"
}
```

这一段的作用是：

- 为第二章的 `artifacts/`、`tmp/`、`bin/` 提前建好目录
- 让后续 chart、CLI 压缩包和二进制文件都有稳定存放位置

### 重要任务 2：安装 Helm

脚本原始代码：

```bash
install_helm() {
  if command -v helm &>/dev/null; then
    echo "Helm 已安装: $(helm version --short)"
    return 0
  fi
  echo "正在安装 Helm …"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  helm version --short
}
```

这一段解决的是：

- `ops` 上后续是否具备 `helm upgrade --install` 的执行能力

### 重要任务 3：创建 Harbor 项目

脚本原始代码：

```bash
create_harbor_project() {
  local http_code

  http_code=$(curl -k -s -o /tmp/harbor_cilium_project_create.json -w '%{http_code}' \
    -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
    -H 'Content-Type: application/json' \
    -X POST \
    "https://${HARBOR_DOMAIN}/api/v2.0/projects" \
    -d "{\"project_name\":\"${HARBOR_PROJECT}\",\"public\":true}")

  if [[ "${http_code}" == "201" || "${http_code}" == "409" ]]; then
    echo "Harbor 项目 ${HARBOR_PROJECT} 已就绪"
  else
    echo "创建 Harbor 项目失败，HTTP 状态码：${http_code}"
    sed -n '1,120p' /tmp/harbor_cilium_project_create.json || true
    exit 1
  fi
}
```

这一段的作用是：

- 通过 Harbor API 创建第二章专用项目 `cilium`
- 若项目已存在，则把它当作正常状态继续执行

### 重要任务 4：下载 Helm chart

脚本原始代码：

```bash
download_helm_chart() {
  if [[ ! -f "${ARTIFACTS_DIR}/cilium-${CILIUM_VERSION}.tgz" ]]; then
    helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
    helm repo update >/dev/null
    helm pull cilium/cilium --version "${CILIUM_VERSION}" --destination "${ARTIFACTS_DIR}"
  fi
}
```

这一段的作用是：

- 将固定版本的 `Cilium` Helm chart 下载到本地 `artifacts/`
- 让下一步安装不再依赖现场联网拉 chart

### 重要任务 5：安装 `cilium CLI`

脚本原始代码：

```bash
install_cilium_cli() {
  if [[ ! -x /usr/local/bin/cilium ]]; then
    curl -fsSL \
      "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz" \
      -o "${ARTIFACTS_DIR}/bin/cilium-linux-${ARCH}.tar.gz"
    tar -xzf "${ARTIFACTS_DIR}/bin/cilium-linux-${ARCH}.tar.gz" -C "${ARTIFACTS_DIR}/bin" cilium
    install -m 0755 "${ARTIFACTS_DIR}/bin/cilium" /usr/local/bin/cilium
  fi
}
```

这一段解决的是：

- 后续 `cilium status`、`cilium connectivity` 等命令是否能直接在 `ops` 上执行

### 重要任务 6：安装 `hubble CLI`

脚本原始代码：

```bash
install_hubble_cli() {
  if [[ ! -x /usr/local/bin/hubble ]]; then
    curl -fsSL \
      "https://github.com/cilium/hubble/releases/download/${HUBBLE_CLI_VERSION}/hubble-linux-${ARCH}.tar.gz" \
      -o "${ARTIFACTS_DIR}/bin/hubble-linux-${ARCH}.tar.gz"
    tar -xzf "${ARTIFACTS_DIR}/bin/hubble-linux-${ARCH}.tar.gz" -C "${ARTIFACTS_DIR}/bin" hubble
    install -m 0755 "${ARTIFACTS_DIR}/bin/hubble" /usr/local/bin/hubble
  fi
}
```

这一段解决的是：

- 后续 `hubble observe` 等命令是否可直接使用

### 重要任务 7：在 Harbor 节点同步镜像，并重建课程修复版 `Hubble UI`

脚本原始代码：

```bash
SOURCE_IMAGES=(
  "quay.io/cilium/cilium:v1.19.1"
  "quay.io/cilium/operator-generic:v1.19.1"
  "quay.io/cilium/hubble-relay:v1.19.1"
  "quay.io/cilium/certgen:v0.3.2"
  "docker.io/traefik/whoami:v1.10.3"
  "docker.io/curlimages/curl:8.12.1"
)

TARGET_IMAGES=(
  "harbor.qytk8s.com/cilium/cilium:v1.19.1"
  "harbor.qytk8s.com/cilium/operator-generic:v1.19.1"
  "harbor.qytk8s.com/cilium/hubble-relay:v1.19.1"
  "harbor.qytk8s.com/cilium/certgen:v0.3.2"
  "harbor.qytk8s.com/cilium/whoami:v1.10.3"
  "harbor.qytk8s.com/cilium/curl:8.12.1"
)
```

以及：

```bash
for index in "${!SOURCE_IMAGES[@]}"; do
  src="${SOURCE_IMAGES[$index]}"
  dst="${TARGET_IMAGES[$index]}"

  docker pull "${src}"
  docker tag "${src}" "${dst}"
  docker push "${dst}"
done

build_qyfix_hubble_ui_images
```

这一段完成的是：

- 普通镜像继续按“拉取 -> 重新打标签 -> 推送 Harbor”的方式同步
- `Hubble UI` 统一使用课程固定镜像标签：
  - `harbor.qytk8s.com/cilium/hubble-ui:v0.13.3-qyfix`
  - `harbor.qytk8s.com/cilium/hubble-ui-backend:v0.13.3-qyfix`
- 脚本会在 `harbor` 节点完成这两张镜像的构建与推送
- 后续第二章安装与第三章发布，统一复用这组镜像

### 重要任务 8：在所有节点预拉镜像

脚本原始代码：

```bash
for image in "${IMAGES[@]}"; do
  echo "预拉镜像：${image}"
  crictl --runtime-endpoint unix:///run/containerd/containerd.sock pull "${image}"
done
```

这一段的作用是：

- 在所有 Kubernetes 节点提前缓存第二章关键镜像
- 减少下一步正式安装时的首次拉取等待

### 重要任务 9：本地制品检查

脚本原始代码：

```bash
verify_local_artifacts() {
  ls -lh "${ARTIFACTS_DIR}/cilium-${CILIUM_VERSION}.tgz"
  cilium version --client
  hubble version
}
```

这一段用于在 `ops` 上立即确认：

- chart 已存在
- `cilium CLI` 已可用
- `hubble CLI` 已可用

---

## 执行命令

先给脚本增加执行权限：

```bash
chmod +x /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/01_prepare_cilium_artifacts.sh
```

然后执行：

```bash
bash /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/01_prepare_cilium_artifacts.sh
```

---

## 验证方法

### 验证 1：检查 Harbor 项目

```bash
curl -k -s -u 'admin:Harbor12345' https://harbor.qytk8s.com/api/v2.0/projects | jq -r '.[] | select(.name=="cilium") | .name'
```

预期结果：

```text
cilium
```

### 验证 2：检查镜像仓库列表

```bash
curl -k -s -u 'admin:Harbor12345' \
  "https://harbor.qytk8s.com/api/v2.0/projects/cilium/repositories?page=1&page_size=30" | jq -r '.[].name'
```

预期结果：

- 输出中应包含：
  - `cilium/cilium`
  - `cilium/operator-generic`
  - `cilium/hubble-relay`
  - `cilium/hubble-ui`
  - `cilium/hubble-ui-backend`
  - `cilium/certgen`
  - `cilium/whoami`
  - `cilium/curl`

关键看点：

- 只看仓库名列表，不需要阅读完整 JSON

### 验证 3：检查 Helm chart 文件

```bash
ls -lh /docker_k8s_2026/k8s/02-cloud-native-networking/artifacts/cilium-1.19.1.tgz
```

预期结果：

- 文件存在
- 文件大小正常显示

### 验证 4：检查 `cilium CLI`

```bash
cilium version --client
```

预期结果：

- 输出中应包含 `v0.19.1`

### 验证 5：检查 `hubble CLI`

```bash
hubble version
```

预期结果：

- 输出中应包含 `v1.18.6`

### 验证 6：检查节点已缓存 Cilium 主镜像

```bash
for node in cp01 cp02 cp03 wk-app01 wk-app02 wk-edge01 wk-obs01; do
  echo "===== ${node} ====="
  ssh root@${node} "crictl --runtime-endpoint unix:///run/containerd/containerd.sock images | grep 'harbor.qytk8s.com/cilium/cilium'"
done
```

预期结果：

- 每台节点都能看到：

```text
harbor.qytk8s.com/cilium/cilium:v1.19.1
```

关键看点：

- 这里只验证关键主镜像是否已缓存
- 不要求把全部镜像逐个人工核对

---

## 通过标准

满足下面条件即可进入下一步：

- Harbor 项目 `cilium` 已创建
- 第二章所需镜像已推送到 Harbor
- 各 Kubernetes 节点已预拉关键镜像
- Helm chart 已在 `ops` 本地保存
- `cilium CLI` 与 `hubble CLI` 已可直接使用

---

## 下一步

下一步进入 `Cilium` 安装：

- `docs/03_install_cilium.md`
