# 第 5 步：第五章最终验收

## 本步目标

只读验收第五章，确认这条主线已经闭环：

- `Istio Ambient` 正常
- `Istio Ingress Gateway` 正常
- `JWT` 认证正常
- `mTLS` 与服务间授权正常

---

## 执行标记

- **执行标记：只读验收**

说明：

- 本页不再重新部署第五章对象
- 只确认第五章标准结束状态是否已经形成

---

## 本步脚本

- `k8s/05-security-and-zero-trust/scripts/07_verify_istio_security.sh`

---

## 执行命令

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选预处理命令</strong><br/>
如果脚本已具备执行权限，这一步可以跳过。
</div>

```bash
chmod +x /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/07_verify_istio_security.sh
```

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #ea4335; border-radius: 6px; background: rgba(234,67,53,0.10); margin: 8px 0;">
<strong>❗ 本步必须粘贴执行</strong><br/>
下面命令是本步主线必跑命令。
</div>

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/07_verify_istio_security.sh
```

---

## 验收原则

第五章最终验收采用只读方式进行，目的不是重新部署环境，而是确认下面 4 类能力已经稳定闭环：

- `Istio Ambient` 控制面与数据面正常
- 新入口与北向访问正常
- `JWT` 认证与入口授权正常
- `mTLS` 与服务身份授权正常

---

## 验收顺序

1. Kubernetes 节点
2. Istio 组件
3. 新入口与 VIP
4. 演示工作负载
5. 安全对象
6. JWT 手测
7. 网格授权手测

---

## 验证 1：Kubernetes 节点

### 验证目的

确认第五章运行基础仍然稳定，集群不存在节点级异常。

### 验证方法

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
kubectl get nodes -o wide
```

### 关键看点

- 重点不是逐行阅读所有列
- 而是确认所有节点都保持 `Ready`

### 预期结果

- 所有节点为 `Ready`

---

## 验证 2：Istio 组件

### 验证目的

确认 `istiod`、`ztunnel` 和 `Istio Ingress Gateway` 已正常运行，这是第五章所有能力成立的前提。

### 验证方法

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
kubectl -n istio-system get pods -o wide
```

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
kubectl -n istio-ingress get pods,svc -o wide
```

### 关键看点

- `istio-system` 重点看：
  - `istiod`
  - `ztunnel`
- `istio-ingress` 重点看：
  - `istio-ingressgateway`
  - `LoadBalancer` 地址是否为 `10.1.1.62`

### 预期结果

- `istiod` 正常
- `ztunnel` 正常
- `istio-ingressgateway` 正常

---

## 验证 3：新入口

### 验证目的

确认北向入口链路已经闭环，包括：

- 域名解析
- VIP 绑定
- `HTTP -> HTTPS` 跳转
- `HTTPS` 正常访问

### 验证方法

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
curl -I --resolve secure-app.qytk8s.com:80:10.1.1.62 http://secure-app.qytk8s.com/public
```

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
curl --resolve secure-app.qytk8s.com:443:10.1.1.62 --cacert /docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt https://secure-app.qytk8s.com/public
```

### 关键看点

- 第一条命令重点看是否跳到 `HTTPS`
- 第二条命令重点看是否返回 `200`，以及正文中是否出现 `public-whoami`

### 预期结果

- `HTTP` 跳转到 `HTTPS`
- `HTTPS` 返回 `200`
- 返回内容中可看到 `public-whoami`

---

## 验证 4：演示工作负载

### 验证目的

确认第五章用到的演示服务与测试客户端均已准备完成，可用于后续安全验证。

### 验证方法

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
kubectl -n mesh-demo get pods,svc
```

### 关键看点

- 重点看第五章演示组件是否齐全
- 不需要纠结 Pod 的排列顺序，而是确认关键工作负载已经就绪

### 预期结果

- `helloworld-v1`
- `helloworld-v2`
- `httpbin`
- `curl-trusted`
- `curl-untrusted`

全部正常运行。

---

## 验证 5：安全对象

### 验证目的

确认入口认证、入口授权、网格内 `mTLS` 和服务身份授权对象均已创建并生效。

### 验证方法

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
kubectl get requestauthentication,authorizationpolicy,peerauthentication -A
```

### 关键看点

- 重点不是对象数量
- 而是要确认第五章 3 类核心安全对象都已经出现：
  - `RequestAuthentication`
  - `AuthorizationPolicy`
  - `PeerAuthentication`

### 预期结果

- 入口 `JWT` 策略存在
- `mesh-demo` 的 `PeerAuthentication` 存在
- `httpbin` 的授权策略存在

---

## 验证 6：JWT 行为

### 验证目的

确认入口已经同时具备：

- token 校验能力
- 基于身份的访问控制能力

### 验证方法

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/02_test_jwt_auth.sh
```

### 关键看点

- 重点看三种典型结果是否同时出现：
  - 无 token
  - 错 token
  - 正确 token

### 预期结果

- 无 token 请求被拒绝
- 错误 token 请求被拒绝
- 正确 token 请求通过

---

## 验证 7：网格授权行为

### 验证目的

确认网格内部访问已经不再默认放通，而是按服务身份实施最小授权。

### 验证方法

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/03_test_mesh_authz.sh
```

### 关键看点

- 重点看“可信客户端成功、不可信客户端被拒绝”这一对对照是否成立
- 不要把这一条和入口 `JWT` 混淆；这里验证的是服务间身份授权

### 预期结果

- `trusted-client GET /get` 成功
- `trusted-client POST /post` 成功
- `untrusted-client GET /get` 被拒绝

---

## 通过标准

满足下面条件后，第五章即可视为完成：

- 新入口 `secure-app.qytk8s.com` 已可通过 `HTTPS` 访问
- `JWT` 已生效
- `Ambient` 与 `mTLS` 已生效
- 服务身份授权已生效，`waypoint` 已部署完成
- 课堂手动测试脚本能够展示预期效果

---

## 补充说明

- `win2019 DNS` 需要存在 `secure-app.qytk8s.com -> 10.1.1.62`
- `win2019` 需要导入 Harbor CA 根证书
