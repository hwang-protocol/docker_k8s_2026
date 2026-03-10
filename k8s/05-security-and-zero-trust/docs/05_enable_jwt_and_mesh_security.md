# 第 4 步：开启 JWT、mTLS 与服务间授权

## 本步目标

在新入口和演示应用已经就绪的基础上，补齐第五章的核心安全能力：

- 入口 `JWT`
- 命名空间 `mTLS`
- `waypoint`
- 服务间 `AuthorizationPolicy`

## 本步脚本

- `k8s/05-security-and-zero-trust/scripts/04_enable_jwt_and_mesh_security.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/04_enable_jwt_and_mesh_security.sh
```

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/04_enable_jwt_and_mesh_security.sh
```

## 这一步做了什么

脚本会按下面顺序执行：

1. 生成第五章演示用 `JWT` 密钥、`jwks.json` 和示例 token
2. 在入口网关上应用 `RequestAuthentication`
3. 在入口网关上应用 `AuthorizationPolicy`
4. 将 `mesh-demo` 命名空间纳入 `waypoint`
5. 对 `mesh-demo` 应用 `PeerAuthentication STRICT`
6. 对 `httpbin` 服务应用基于服务身份的 `AuthorizationPolicy`

## 执行后的检查

```bash
kubectl get requestauthentication,authorizationpolicy,peerauthentication -A
```

```bash
kubectl -n mesh-demo get gateway
```

```bash
ls -lh /docker_k8s_2026/k8s/05-security-and-zero-trust/pki
```

## 预期

- 入口不再允许未认证请求访问受保护路径
- `mesh-demo` 中的服务间流量进入 `mTLS` 严格模式
- `httpbin` 只有被允许的主体才能访问

## 理论讲解点

这一节建议你重点讲：

- `RequestAuthentication` 只负责“验 token”，不直接做放行
- `AuthorizationPolicy` 才负责“谁能访问什么”
- `PeerAuthentication STRICT` 的意义是“网格内默认只信任 mTLS 流量”
- `waypoint` 为什么是第五章后续 L7 治理能力的关键
- 当前课堂稳定版先演示“服务身份授权”，方法级细粒度控制可在此基础上继续扩展

## 下一步

进入第 5 步，配置流量治理基线：

- `docs/06_apply_traffic_management.md`
