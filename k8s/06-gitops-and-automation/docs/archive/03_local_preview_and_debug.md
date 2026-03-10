# 第 2 步：本地预览与联调

## 本步目标

把 `QYTANG NetDevOps` 在 `ops` 上直接跑起来，并让浏览器可以访问到页面与 API。

这一阶段的重点不是 Kubernetes，而是：

- 让学员先看到成型的微服务系统
- 让学员先理解前后端和服务间调用关系
- 为后面的 Docker、Gitea、Argo CD 做准备

## 本步脚本

- `k8s/06-gitops-and-automation/scripts/01_run_local_preview.sh`
- `k8s/06-gitops-and-automation/scripts/02_verify_local_preview.sh`

## 当前运行方式

当前本地预览采用：

- 前端静态页面服务：`8080`
- `device-service`：`8001`
- `resource-service`：`8002`
- `audit-service`：`8003`

## 执行命令

```bash
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/01_run_local_preview.sh
```

## 访问地址

在 `win2019` 浏览器中访问：

```text
http://10.1.1.201:8080
```

如需直接访问接口文档：

```text
http://10.1.1.201:8001/docs
http://10.1.1.201:8002/docs
http://10.1.1.201:8003/docs
```

## 这一阶段为什么不先上 Docker

因为第六章第一阶段的任务，是先把应用本身讲清楚。

如果一开始就上 Docker、Helm、Argo CD，学员容易把注意力都放在命令和部署流程上，反而忽略：

- 页面设计
- 服务拆分
- API 结构
- 数据模型
- 服务间调用链

所以本地联调是有教学价值的，不是“偷懒版部署”。

## 联调时要观察什么

### 1. 页面是否正常打开

预期：

- Dashboard 正常加载
- 设备列表可见
- 审计中心可见

### 2. 设备 CRUD 是否正常

预期：

- 能新增设备
- 能编辑设备
- 能删除设备

### 3. 设备详情是否正常

预期：

- 选中设备后能看到基础信息
- 能看到接口列表
- 能看到最近审计

### 4. 服务矩阵是否正常

预期：

- 3 个后端服务均显示为 `RUNNING`

### 5. 指标与日志是否有输出

预期：

- `/metrics` 可访问
- 每次请求都会产生结构化日志

## 关键教学点

### 教学点 1：为什么页面能直接访问远端 API

前端逻辑会自动根据当前浏览器访问地址推导 API 地址。

例如浏览器打开：

```text
http://10.1.1.201:8080
```

前端会自动请求：

```text
http://10.1.1.201:8001
http://10.1.1.201:8002
http://10.1.1.201:8003
```

这比写死 `127.0.0.1` 更适合远程浏览器演示。

### 教学点 2：为什么 Dashboard 最适合后续做 Trace

因为它本身就是聚合入口，会跨多个服务收集数据，所以天然适合：

- 看延迟
- 看调用链
- 看错误传播
- 看服务依赖关系

## 代码对应关系

### 前端服务入口

- `apps/qytang-netdevops/frontend/server.py`

### 本地一键启动脚本

- `apps/qytang-netdevops/scripts/run_local_stack.py`

### 演示数据脚本

- `apps/qytang-netdevops/scripts/seed_demo_data.py`

## 下一步

继续看后续仓库与交付规划：

- `docs/04_git_repo_and_delivery_plan.md`
