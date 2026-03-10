# 第 5 步：第六章第一阶段验收

## 本步目标

只读验收第六章第一阶段，确认下面 4 类能力已经具备：

- 样板应用目录存在
- 本地预览可访问
- API 正常
- 文档与脚本骨架已就绪

这一页是第六章第一阶段的唯一正式验收页。

也就是说：

- 前面的页面负责设计、讲解和转场
- 正式“是否通过第一阶段”，统一在这一页判断

## 本步脚本

- `k8s/06-gitops-and-automation/scripts/03_verify_chapter6.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/03_verify_chapter6.sh
```

```bash
bash /docker_k8s_2026/k8s/06-gitops-and-automation/scripts/03_verify_chapter6.sh
```

## 验收顺序

1. 集群节点状态
2. 第六章目录结构
3. 样板应用目录结构
4. 本地前端访问
5. 设备服务
6. 资源服务
7. 审计服务
8. 指标接口

## 验证 1：集群节点

### 验证目的

确认第六章仍然建立在稳定的课程集群基础之上。

### 验证方法

```bash
kubectl get nodes -o wide
```

### 预期结果

- 所有节点为 `Ready`

## 验证 2：第六章目录

### 验证目的

确认第六章已具备文档、脚本、清单和制品目录。

### 验证方法

```bash
ls -la /docker_k8s_2026/k8s/06-gitops-and-automation
```

### 预期结果

- `docs/`
- `scripts/`
- `manifests/`
- `artifacts/`

全部存在。

## 验证 3：样板应用目录

### 验证目的

确认应用代码和运行脚本已经落位。

### 验证方法

```bash
ls -la /docker_k8s_2026/apps/qytang-netdevops
```

### 预期结果

- `frontend/`
- `backend/`
- `scripts/`
- `requirements.txt`

全部存在。

## 验证 4：前端页面

### 验证目的

确认浏览器可访问样板应用页面。

### 验证方法

```bash
curl -I http://127.0.0.1:8080
```

### 预期结果

- 返回 `200`

## 验证 5：设备服务

### 验证方法

```bash
curl http://127.0.0.1:8001/healthz
```

### 预期结果

- 返回 `device-service` 健康状态

## 验证 6：资源服务

### 验证方法

```bash
curl http://127.0.0.1:8002/healthz
```

### 预期结果

- 返回 `resource-service` 健康状态

## 验证 7：审计服务

### 验证方法

```bash
curl http://127.0.0.1:8003/healthz
```

### 预期结果

- 返回 `audit-service` 健康状态

## 验证 8：指标接口

### 验证方法

```bash
curl http://127.0.0.1:8001/metrics
```

### 预期结果

- 返回 Prometheus 文本格式指标

## 通过标准

满足下面条件后，第六章第一阶段即可视为完成：

- 第六章教案目录已成型
- `QYTANG NetDevOps` 样板应用可打开
- 3 个后端服务正常
- 指标接口已可访问
- 已具备继续进入 Docker、Gitea、Helm、Argo CD 的基础
