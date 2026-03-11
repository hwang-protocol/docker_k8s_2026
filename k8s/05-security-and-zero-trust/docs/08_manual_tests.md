# 第 7 步：课堂手动测试清单

## 本步目标

这一节不再安装新组件，而是专门服务课堂讲解。

原则很简单：

- 环境用自动化脚本提前铺好
- 理论讲解时，再运行短小的手动测试脚本
- 让“配置变化”和“访问现象”一一对应

## 执行标记

- **执行标记：课堂演示**

说明：

- 这一页的主线不是部署
- 而是把第五章已经铺好的对象，按课堂节奏一个一个验证出来

## 使用原则

手动测试脚本的用途不是替代主流程部署，而是用于：

- 验证某一项配置已经生效
- 对比配置切换前后的差异
- 为课堂展示提供稳定、短小、可重复的观察入口

## 手动测试脚本清单

| 脚本 | 适合讲什么 | 预期现象 |
| :--- | :--- | :--- |
| `manual_tests/01_test_https_ingress.sh` | 新入口、HTTP 跳转、HTTPS | `HTTP -> HTTPS`，`public` 可访问 |
| `manual_tests/02_test_jwt_auth.sh` | `JWT` 认证 | 无 token 拒绝，正确 token 放行 |
| `manual_tests/03_test_mesh_authz.sh` | `mTLS` + 服务身份授权 | `trusted-client` 成功，`untrusted-client` 被拒绝 |
| `manual_tests/04_test_weighted_routing.sh` | 权重路由与负载均衡 | 多次请求可看到 `v1/v2` 分布 |
| `manual_tests/05_test_timeout_retry.sh` | 超时与重试 | 慢请求提前失败，展示治理效果 |
| `manual_tests/06_test_fault_injection.sh` | 故障注入 | 人工制造延迟与 `503` |
| `manual_tests/99_reset_baseline.sh` | 恢复课堂基线 | 回到 `100% -> v1` 的稳定状态 |

## 推荐执行顺序

### 1. 入口增强验证

执行命令：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/01_test_https_ingress.sh
```

对应目标：

- 验证 `HTTP -> HTTPS`
- 验证 `public` 路径可访问

### 2. JWT 验证

执行命令：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/02_test_jwt_auth.sh
```

对应目标：

- 验证无 token、错误 token、正确 token 三种结果

### 3. 服务间安全分层说明

本阶段建议拆成 3 个层次理解：

1. 先讲为什么先有 `waypoint`
2. 再讲为什么要 `PeerAuthentication STRICT`
3. 最后再讲服务身份授权

- `waypoint` 先解决“后续 L7 治理能力挂在哪里”
- `PeerAuthentication STRICT` 先建立“内部通信必须可信”
- `AuthorizationPolicy` 再解决“可信内部流量里谁能访问谁”

### 4. 服务间 mTLS 与授权验证

执行命令：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/03_test_mesh_authz.sh
```

对应目标：

- 验证 `trusted-client` 可访问
- 验证 `untrusted-client` 被拒绝

### 5. 流量治理验证

#### 5.1 权重路由

执行命令：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/04_test_weighted_routing.sh
```

对应目标：

- 观察 `v1/v2` 请求分布变化

#### 5.2 超时与重试

执行命令：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/05_test_timeout_retry.sh
```

对应目标：

- 观察慢请求超时
- 观察失败请求的治理行为

#### 5.3 故障注入

执行命令：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/06_test_fault_injection.sh
```

对应目标：

- 观察延迟注入效果
- 观察 `503` 中断注入效果

## 执行约束

- 每次跑完故障类或灰度类测试后，建议执行：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/99_reset_baseline.sh
```

- 不建议在课堂开始前就长期挂着 `50/50` 或故障注入策略
- `04`、`05`、`06` 这三个脚本都修改同一个 `VirtualService`，课堂演示时必须串行运行，不要并行

## 结果判定

- `01_test_https_ingress.sh` 通过后，应能确认入口链路与证书链路正常
- `02_test_jwt_auth.sh` 通过后，应能确认入口认证与入口授权正常
- `03_test_mesh_authz.sh` 通过后，应能确认网格内部服务身份授权正常
- `04_test_weighted_routing.sh` 通过后，应能确认版本分流能力正常
- `05_test_timeout_retry.sh` 通过后，应能确认超时与重试策略正常
- `06_test_fault_injection.sh` 通过后，应能确认延迟注入与错误注入正常

## 下一步

进入第五章最终验收：

- `docs/09_verify.md`
