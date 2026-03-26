# 第六章理论：GitOps、Helm 与 Argo CD

## 本节目标

完成这一节后，应该先建立下面几个最基础的认识：

- 什么是 `GitOps`
- 什么是 `Helm`
- 什么是 `values.yaml`
- 什么是 `Argo CD`
- 第六章要打通的完整交付链路是什么

## 什么是 GitOps

`GitOps` 可以先记成一句最短的话：

**用 Git 中声明的目标状态，持续驱动集群达到这个状态。**

```mermaid
flowchart LR
  git[Git 中的目标状态]
  sync[持续同步]
  cluster[Kubernetes 实际状态]

  git --> sync --> cluster
```

可以先把 `GitOps` 理解成一句话：

- 用 Git 中声明的目标状态，持续驱动集群收敛到这个状态

它更接近**声明式**，关注的是“最终想要什么”，而不是“刚刚执行了什么命令”。

课堂上也可以把 Git 提交先理解成一份“愿望清单”：

- 前端镜像应使用哪个 `tag`
- 前端副本数应该是多少
- 应用应该部署到哪个命名空间

### GitOps 和手工发布的区别

```mermaid
flowchart LR
  subgraph left[手工发布]
    direction TB
    cmd[kubectl / helm 手工执行]
    live[集群当前状态]
    cmd --> live
  end

  subgraph right[GitOps]
    direction TB
    desired[Git 中的目标状态]
    controller[Argo CD]
    actual[集群实际状态]
    desired --> controller --> actual
  end
```

- 手工发布更接近**命令式**：人手工执行 `kubectl` 或 `helm`，直接推动集群当前状态发生变化
- GitOps 更接近**声明式**：先把目标状态写进 Git，再由 `Argo CD` 持续把集群实际状态收敛到这个目标状态

## 什么是 Helm

`Helm` 可以先理解成：

**Kubernetes 的应用打包与模板化工具。**

它解决的问题是：

- 一个应用往往不只一份 YAML
- 同一套应用在不同环境里，只有少数字段不同
- 这些差异不应该靠复制很多份 YAML 来维护

所以 `Helm` 的作用是：

- 把一组 Kubernetes 资源打成一个 `Chart`
- 把可变化的部分抽成参数
- 再根据参数渲染出最终 YAML

```mermaid
flowchart LR
  chart[Helm Chart 模板]
  values[values.yaml 参数]
  render[渲染]
  yaml[最终 Kubernetes YAML]

  chart --> render
  values --> render
  render --> yaml
```

## 什么是 values.yaml

`values.yaml` 是 `Helm Chart` 的参数文件。

它可以先理解成：

**这套应用部署时要填入的配置值。**

例如常见内容有：

- 镜像仓库
- 镜像 tag
- 副本数
- Service 类型
- Ingress / Gateway 域名
- 资源限制

所以关系可以先记成：

```text
Chart = 模板骨架
values.yaml = 具体参数
最终渲染结果 = 真正提交到 Kubernetes 的 YAML
```

### `Chart` 和 `values.yaml` 为什么要分开

```mermaid
flowchart TD
  chart[同一套 Chart]
  lab[values-lab.yaml]
  prod[values-prod.yaml]
  labResult[实验环境渲染结果]
  prodResult[生产环境渲染结果]

  chart --> lab --> labResult
  chart --> prod --> prodResult
```

- 应用模板通常是一套
- 环境差异主要放在不同的 `values` 文件里

## 一个真实的 Chart 与 values 案例

第六章直接用本章自己的 `QYT NetDevOps` 来看最容易理解。

来源文件：

- [deployments.yaml](/docker_k8s_2026/apps/qytang-netdevops/deploy/helm/qytang-netdevops/templates/deployments.yaml)
- [values-lab.yaml](/docker_k8s_2026/apps/qytang-netdevops/deploy/helm/qytang-netdevops/values-lab.yaml)

文件类型：

- `deployments.yaml`
  - `Helm` 模板文件
- `values-lab.yaml`
  - `Helm values` 参数文件

例如前端 `Deployment` 模板里写的是：

```yaml
kind: Deployment
metadata:
  name: frontend
  namespace: {{ .Values.namespace }}
spec:
  replicas: {{ .Values.frontend.replicaCount }}
  template:
    spec:
      containers:
        - name: frontend
          image: "{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}"
```

而实验环境的 `values-lab.yaml` 里写的是：

```yaml
namespace: qytang-netdevops

frontend:
  replicaCount: 1
  image:
    repository: harbor.qytk8s.com/qytang-netdevops/frontend
    tag: v0.2.3
```

这两份文件结合起来后，学员最应该看懂的是：

- `{{ .Values.namespace }}`
  - 会被替换成 `qytang-netdevops`
- `{{ .Values.frontend.replicaCount }}`
  - 会被替换成 `1`
- `{{ .Values.frontend.image.repository }}`
  - 会被替换成 `harbor.qytk8s.com/qytang-netdevops/frontend`
- `{{ .Values.frontend.image.tag }}`
  - 会被替换成 `v0.2.3`

也就是说，最后渲染出来的结果更像这样：

```yaml
kind: Deployment
metadata:
  name: frontend
  namespace: qytang-netdevops
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: frontend
          image: harbor.qytk8s.com/qytang-netdevops/frontend:v0.2.3
```

这就是 `Helm` 在这一章里最核心的作用：

- 模板里先写“可变化的位置”
- `values` 里再填“这次部署到底用什么值”
- 最后得到真正提交到 Kubernetes 的 YAML

```mermaid
flowchart LR
  template[templates/deployments.yaml]
  values[values-lab.yaml]
  render[Helm 渲染]
  result[frontend Deployment 最终 YAML]

  template --> render
  values --> render
  render --> result
```

## 什么是 Argo CD

先看官方口径：

- 官网原文：
  - `Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.`
- 官网地址：
  - `https://argo-cd.readthedocs.io/`
- 中文可以先理解成：
  - `Argo CD` 是一个面向 Kubernetes 的**声明式 GitOps 持续交付工具**
- GitHub 项目主页也把它定义成：
  - 面向 Kubernetes 的声明式持续交付项目
- GitHub 地址：
  - `https://github.com/argoproj/argo-cd`

放到第六章的课堂语境里，可以先把它理解成：

- `Argo CD` 是负责盯住 Git 目标状态、并持续把它同步到 Kubernetes 的 GitOps 控制器

它主要负责：

- 拉取 Git 仓库
- 识别其中的 `Helm` / YAML / Kustomize 内容
- 渲染并应用到集群
- 持续比较 Git 与集群的差异

它不负责：

- 编写业务代码
- 构建镜像
- 推送镜像到仓库

```mermaid
flowchart LR
  repo[Git 仓库]
  watch[监听仓库变化]
  argocd[Argo CD]
  cluster[Kubernetes]

  repo --> watch --> argocd --> cluster
```

- 它不是“代码仓库”
- 它也不是“镜像仓库”
- 它是“把 Git 里的部署目标同步到集群”的控制器

常见触发方式有两种：

- 仓库轮询
  - 定时检查 Git 是否发生变化
- Webhook
  - Git 仓库在提交后主动通知 `Argo CD`

对课堂来说，先记住一句最短的话就够了：

**`Argo CD` 的触发点来自 Git 变化，而不是来自 Harbor。**

## Git、Harbor、Helm、Argo CD 各自做什么

| 组件 | 主要职责 | 不负责什么 |
|---|---|---|
| Git 仓库 | 保存源码与部署目标状态 | 不保存镜像二进制 |
| Harbor | 保存镜像本体 | 不负责同步集群 |
| Helm | 组织模板与参数 | 不持续监控集群 |
| Argo CD | 把 Git 里的目标状态同步到集群 | 不编译代码、不构建镜像 |

## 第六章最终要打通的完整链路

```mermaid
flowchart TD
  user[操作者]
  local[本地应用目录<br/>源码 Helm Chart values]
  script[发布脚本]
  gitea[Gitea 发布仓<br/>保存源码 Chart values Application]
  gitnode[git 节点构建环境]
  harbor[Harbor 镜像仓库]
  argocd[Argo CD]
  cluster[Kubernetes 集群]
  browser[浏览器访问]

  user -->|1. 手工修改代码或 Chart values| local
  user -->|2. 手工执行脚本| script
  local -->|3. 脚本读取源码与部署配置| script
  script -->|4. 提交源码或配置变更| gitea
  script -->|5. 在 git 节点构建镜像| gitnode
  gitnode -->|6. docker push 到 Harbor| harbor
  script -->|7. 回写 values 中的镜像 tag 并再次提交| gitea
  gitea -->|8. Webhook 或轮询发现 Git 变化| argocd
  argocd -->|9. 同步目标状态到集群| cluster
  harbor -->|10. 节点按镜像地址拉取镜像| cluster
  cluster -->|11. 浏览器访问最终结果| browser
```

按主线理解即可：

1. 人先修改代码、`Chart` 或 `values`
2. 人手工执行发布脚本
3. 脚本提交 Git，并在 `git` 节点构建镜像、推送到 `Harbor`
4. 脚本回写 `values` 里的镜像 `tag`，再次提交到 `Gitea`
5. `Argo CD` 发现 Git 变化后，把目标状态同步到集群
6. 集群按镜像地址从 `Harbor` 拉取镜像，浏览器最终访问发布结果

这里最关键的边界是：

- 脚本既会提交 Git，也会构建并推送镜像
- 真正触发集群更新的，仍然是 Git 中目标状态发生变化

## 第六章最终发布结果长什么样

```mermaid
flowchart TD
  browser[浏览器访问域名]
  gateway[正式业务入口]
  pod[前后端 Pod]
  image[Harbor 镜像]
  git[Git 中的 Helm values / Application]
  argocd[Argo CD]

  browser --> gateway --> pod
  image --> pod
  git --> argocd --> pod
```

- 用户最终看到的是业务入口和页面
- 但页面背后同时依赖两类交付输入：
  - 来自 Harbor 的镜像
  - 来自 Git 的部署配置
- `Argo CD` 负责把 Git 中的部署配置落实成集群状态

## 第六章里的 GitOps 到底是什么形态

这一章里的 GitOps，不是“代码一提交就全自动上线”的完整版流水线，而是更适合课堂理解的形态：

- 人手工触发发布脚本
- Git 保存声明式部署目标
- Harbor 保存镜像
- Argo CD 根据 Git 把目标状态同步到集群

## 这一页先记住的最短结论

- 第六章主线可以直接记成一句话：
  - 代码和部署目标进 Git，镜像进 Harbor，配置由 Helm 组织，再由 Argo CD 同步到集群

## 下一步

进入应用设计、本地联调与工程化资产：

- `docs/02_app_design_and_local_preview.md`
