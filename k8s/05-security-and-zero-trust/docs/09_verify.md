# 第 8 步：第五章最终验收

## 本步目标

只读验收第五章，确认这条主线已经闭环：

- `Istio Ambient` 正常
- `Istio Ingress Gateway` 正常
- `JWT` 认证正常
- `mTLS` 与服务间授权正常
- 基线流量治理对象正常

## 本步脚本

- `k8s/05-security-and-zero-trust/scripts/07_verify_istio_security.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/07_verify_istio_security.sh
```

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/07_verify_istio_security.sh
```

## 验收原则

第五章最终验收采用只读方式进行，目的不是重新部署环境，而是确认下面 5 类能力已经稳定闭环：

- `Istio Ambient` 控制面与数据面正常
- 新入口与北向访问正常
- `JWT` 认证与入口授权正常
- `mTLS` 与服务身份授权正常
- 流量治理基线对象正常

## 验收顺序

1. Kubernetes 节点
2. Istio 组件
3. 新入口与 VIP
4. 演示工作负载
5. 安全对象
6. JWT 手测
7. 网格授权手测

## 验证 1：Kubernetes 节点

### 验证目的

确认第五章运行基础仍然稳定，集群不存在节点级异常。

### 验证方法

```bash
kubectl get nodes -o wide
```

### 预期结果

- 所有节点为 `Ready`

## 验证 2：Istio 组件

### 验证目的

确认 `istiod`、`ztunnel` 和 `Istio Ingress Gateway` 已正常运行，这是第五章所有能力成立的前提。

### 验证方法

```bash
kubectl -n istio-system get pods -o wide
```

```bash
kubectl -n istio-ingress get pods,svc -o wide
```

### 预期结果

- `istiod` 正常
- `ztunnel` 正常
- `istio-ingressgateway` 正常

## 验证 3：新入口

### 验证目的

确认北向入口链路已经闭环，包括：

- 域名解析
- VIP 绑定
- `HTTP -> HTTPS` 跳转
- `HTTPS` 正常访问

### 验证方法

```bash
curl -I --resolve secure-app.qytk8s.com:80:10.1.1.61 http://secure-app.qytk8s.com/public
```

```bash
curl --resolve secure-app.qytk8s.com:443:10.1.1.61 --cacert /docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt https://secure-app.qytk8s.com/public
```

### 预期结果

- `HTTP` 跳转到 `HTTPS`
- `HTTPS` 返回 `200`
- 返回内容中可看到 `public-whoami`

## 验证 4：演示工作负载

### 验证目的

确认第五章用到的演示服务与测试客户端均已准备完成，可用于后续安全与治理验证。

### 验证方法

```bash
kubectl -n mesh-demo get pods,svc
```

### 预期结果

- `helloworld-v1`
- `helloworld-v2`
- `httpbin`
- `curl-trusted`
- `curl-untrusted`

全部正常运行。

## 验证 5：安全对象

### 验证目的

确认入口认证、入口授权、网格内 `mTLS` 和服务身份授权对象均已创建并生效。

### 验证方法

```bash
kubectl get requestauthentication,authorizationpolicy,peerauthentication -A
```

### 预期结果

- 入口 `JWT` 策略存在
- `mesh-demo` 的 `PeerAuthentication` 存在
- `httpbin` 的授权策略存在

## 验证 6：JWT 行为

### 验证目的

确认入口已经同时具备：

- token 校验能力
- 基于身份的访问控制能力

### 验证方法

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/02_test_jwt_auth.sh
```

### 预期结果

- 无 token 请求被拒绝
- 错误 token 请求被拒绝
- 正确 token 请求通过

## 验证 7：网格授权行为

### 验证目的

确认网格内部访问已经不再默认放通，而是按服务身份实施最小授权。

### 验证方法

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/03_test_mesh_authz.sh
```

### 预期结果

- `trusted-client GET /get` 成功
- `trusted-client POST /post` 成功
- `untrusted-client GET /get` 被拒绝

## 通过标准

满足下面条件后，第五章即可视为完成：

- 新入口 `secure-app.qytk8s.com` 已可通过 `HTTPS` 访问
- `JWT` 已生效
- `Ambient` 与 `mTLS` 已生效
- 服务身份授权已生效，`waypoint` 已部署并可继续承载后续 L7 治理演示
- 流量治理基线对象已就绪
- 课堂手动测试脚本能够展示预期效果

## 补充说明

- `win2019 DNS` 需要存在 `secure-app.qytk8s.com -> 10.1.1.61`
- `win2019` 需要导入 Harbor CA 根证书
