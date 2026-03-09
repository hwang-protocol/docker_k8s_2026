# 第 1 步：预热 Cilium 制品到 Harbor 与 ops HTTP

## 本步目标

在正式安装 `Cilium` 之前，先把第二章所需的关键制品准备到本地环境中。

这一步完成后，希望达到下面的状态：

- `Cilium 1.19.1` Helm chart 已下载到 `ops`
- `cilium CLI` 与 `hubble CLI` 已安装到 `ops`
- `Harbor` 中已经存在公共项目 `cilium`
- `Cilium`、`Hubble` 与第二章 demo 镜像已经推送到 `harbor.qytk8s.com/cilium`
- 第二章的 values 与后续 YAML 可以继续通过 `http://ops:9000/02-cloud-native-networking/` 发布

## 为什么要先做这一步

第二章强调：

- 安装以 `Helm` 为主
- 镜像尽量全本地化
- 课堂执行尽量不依赖公网

因此在真正安装 `Cilium` 之前，应该先把下面几类制品准备好：

1. `Helm chart`
2. `cilium CLI`
3. `hubble CLI`
4. `Cilium` 主线镜像
5. 第二章 demo 镜像

这样做的目的，是把课堂上的不确定性前置消化掉，后续安装和验证过程会更顺畅。

## 本步固定版本

本课程在第二章统一冻结：

- Cilium：`1.19.1`
- Helm Chart：`1.19.1`
- cilium CLI：`v0.19.1`
- hubble CLI：`v1.18.6`

## Harbor 项目规划

第二章统一使用 Harbor 公共项目：

- 项目名称：`cilium`
- Harbor 地址：`harbor.qytk8s.com`

第二章中涉及的核心镜像和 demo 镜像都统一推送到：

```text
harbor.qytk8s.com/cilium
```

## 对应脚本

本步对应脚本：

- `k8s/02-cloud-native-networking/scripts/01_prepare_cilium_artifacts.sh`

这个脚本会完成：

1. 在 `ops` 上准备第二章 `artifacts/` 与 `tmp/` 目录
2. 通过 Harbor API 创建公共项目 `cilium`
3. 下载 `Cilium 1.19.1` Helm chart
4. 安装 `cilium CLI`
5. 安装 `hubble CLI`
6. 在 `harbor` 节点拉取上游镜像并推送到 Harbor
7. 在所有 Kubernetes 节点预拉第二章关键镜像

## 执行命令

先给脚本增加执行权限：

```bash
chmod +x /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/01_prepare_cilium_artifacts.sh
```

然后执行：

```bash
bash /docker_k8s_2026/k8s/02-cloud-native-networking/scripts/01_prepare_cilium_artifacts.sh
```

## 你会看到什么

脚本会分成 7 个阶段：

```text
[1/7] 准备本地目录
[2/7] 创建 Harbor 项目
[3/7] 下载 Helm chart
[4/7] 安装 cilium CLI
[5/7] 安装 hubble CLI
[6/7] 在 harbor 节点拉取并推送镜像
[7/7] 在所有 Kubernetes 节点预拉镜像
```

随后会按镜像逐个输出：

```text
源镜像：quay.io/cilium/cilium:v1.19.1
目标镜像：harbor.qytk8s.com/cilium/cilium:v1.19.1
```

最后应看到：

```text
OK: 第二章 Cilium 制品预热完成
```

## 执行后的验证

### 验证 1：检查 Harbor 项目

```bash
curl -k -u 'admin:Harbor12345' https://harbor.qytk8s.com/api/v2.0/projects | jq '.[] | select(.name=="cilium")'
```

预期：

- 可以看到 `cilium` 项目
- 项目为公共项目

### 验证 2：检查镜像仓库列表

```bash
curl -k -u 'admin:Harbor12345' "https://harbor.qytk8s.com/api/v2.0/projects/cilium/repositories?page=1&page_size=30"
```

预期：

- 可以看到 `cilium`
- 可以看到 `operator-generic`
- 可以看到 `hubble-relay`
- 可以看到 `hubble-ui`
- 可以看到 `hubble-ui-backend`
- 可以看到 `certgen`
- 可以看到第二章 demo 镜像

### 验证 3：检查 Helm chart 文件

```bash
ls -lh /docker_k8s_2026/k8s/02-cloud-native-networking/artifacts/cilium-1.19.1.tgz
```

预期：

- 文件存在
- 文件大小正常显示

### 验证 4：检查节点已缓存 Cilium 镜像

```bash
for node in cp01 cp02 cp03 wk-app01 wk-app02 wk-edge01 wk-obs01; do
  echo "===== ${node} ====="
  ssh root@${node} "crictl --runtime-endpoint unix:///run/containerd/containerd.sock images | grep harbor.qytk8s.com/cilium/cilium"
done
```

预期：

- 每台节点都能看到 `harbor.qytk8s.com/cilium/cilium:v1.19.1`

### 验证 5：检查 cilium CLI

```bash
cilium version --client
```

预期：

- 能看到 `v0.19.1`

### 验证 6：检查 hubble CLI

```bash
hubble version
```

预期：

- 能看到 `v1.18.6`

## 本步完成标准

只要满足下面条件，就可以进入下一步：

- Harbor 项目 `cilium` 已创建
- 第二章所需镜像已推送到 Harbor
- Kubernetes 各节点已经预拉关键镜像
- Helm chart 已在 `ops` 本地保存
- `cilium CLI` 与 `hubble CLI` 已可直接使用

## 下一步

下一步进入 `Cilium` 安装：

- `docs/03_install_cilium.md`
