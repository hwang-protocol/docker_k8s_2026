# 第 7 步：课堂手动测试清单

## 本步目标

这一节不再安装新组件，而是专门服务课堂讲解。

原则很简单：

- 环境用自动化脚本提前铺好
- 理论讲解时，再运行短小的手动测试脚本
- 让“配置变化”和“访问现象”一一对应

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

## 建议的课堂节奏

### 1. 先讲入口增强

先运行：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/01_test_https_ingress.sh
```

### 2. 再讲 JWT

再运行：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/02_test_jwt_auth.sh
```

### 3. 再讲服务间 mTLS 与授权

再运行：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/03_test_mesh_authz.sh
```

### 4. 再讲流量治理

先看 50/50：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/04_test_weighted_routing.sh
```

再看超时：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/05_test_timeout_retry.sh
```

最后讲故障注入：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/06_test_fault_injection.sh
```

## 使用建议

- 每次跑完故障类或灰度类测试后，建议执行：

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/99_reset_baseline.sh
```

- 不建议在课堂开始前就长期挂着 `50/50` 或故障注入策略
- `04`、`05`、`06` 这三个脚本都修改同一个 `VirtualService`，课堂演示时必须串行运行，不要并行

## 下一步

进入第五章最终验收：

- `docs/09_verify.md`
