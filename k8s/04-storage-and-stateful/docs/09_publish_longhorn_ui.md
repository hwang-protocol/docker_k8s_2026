# 第 8 步：发布 Longhorn UI

## 本步目标

把 `Longhorn UI` 正式纳入课程统一北向访问方式：

- `win2019`
- `HTTPS`
- 域名访问
- 复用第三章已经跑通的 `MetalLB + Gateway API`

本章固定访问地址：

```text
https://longhorn.qytk8s.com
```

---

## 执行标记

- **执行标记：必须执行**

说明：

- 这一页不是再单独搞一套新的入口
- 它的意义是把第四章的存储 GUI 也统一纳入整门课的北向 HTTPS 体系

---

## 问题背景

从这门课的整体风格看，后续所有 GUI 都不能只停留在：

- `kubectl port-forward`
- `ClusterIP`
- 仅集群内访问

而是要统一落实为：

- 从 `win2019` 浏览器访问
- 使用业务域名
- 使用 `HTTPS`

Longhorn UI 也必须遵守这个规则。

---

## 理论说明

### Longhorn UI 发布链路图

```mermaid
flowchart LR
  browser[win2019 浏览器]
  dns[longhorn.qytk8s.com]
  vip[10.1.1.60]
  gateway[gateway-demo<br/>app-gateway]
  route[HTTPRoute]
  grant[ReferenceGrant]
  svc[longhorn-system<br/>longhorn-frontend]

  browser --> dns
  dns --> vip
  vip --> gateway
  gateway --> route
  route --> grant
  grant --> svc
```

这张图说明：

- 第四章没有单独再分配一个新 VIP
- 而是继续复用第三章已经建立好的统一入口
- Longhorn UI 只是新增了属于自己的域名、专用 listener、路由和转发规则

### 为什么这一页复用第三章的 `app-gateway`

这一节不是再单独搞一套新的 VIP，而是继续复用第三章已经建立的统一入口：

- VIP 仍然是 `10.1.1.60`
- Gateway 仍然是 `gateway-demo/app-gateway`
- Longhorn UI 后端仍然是 `longhorn-system/longhorn-frontend`

只是新增了：

- `longhorn.qytk8s.com`
- `app-gateway` 下专门服务 `longhorn.qytk8s.com` 的 `longhorn-http/longhorn-https` listener
- 对 `longhorn-frontend` 的转发规则
- 跨命名空间访问 `longhorn-frontend` 所需的 `ReferenceGrant`

这样课程整体风格才统一。

这里要特别分清：

- 对外入口 IP 仍然是同一个 `10.1.1.60`
- 但进入 `Gateway` 之后，真正区分不同业务的依据已经不是 IP
- 而是 `Gateway` 在七层根据域名进行路由转发

也就是说：

- `app.qytk8s.com` 会被转发到 `whoami`
- `longhorn.qytk8s.com` 会被转发到 `longhorn-frontend`

### 本步关键清单

本步会使用下面这份清单：

- `manifests/21_gateway_longhorn_ui.yaml`

但要注意：

- `21_gateway_longhorn_ui.yaml` 只负责新增：
  - Longhorn UI 的两个 `HTTPRoute`
  - `ReferenceGrant`
- `app-gateway` 上那 4 个最终 listener 结构，不是直接写死在这份清单里
- 它来自脚本里的 `reconcile_gateway_listeners`

这一页继续复用第三章已经存在的：

- 同一个 VIP：`10.1.1.60`
- 同一个 Gateway：`gateway-demo/app-gateway`

但不会再把 `longhorn.qytk8s.com` 塞进第三章原有的 `app.qytk8s.com` 那组 listener。

这里采用的是更稳定的做法：

- `app.qytk8s.com`
  - 继续使用原来的 `http/https` listener
- `longhorn.qytk8s.com`
  - 新增自己的 `longhorn-http/longhorn-https` listener

这样做的意义是：

- 仍然只用同一个 VIP
- 仍然只用同一个 Gateway
- 但每个域名有自己独立的 `80/443` listener 和自己的证书
- 这样更符合当前这套 `Cilium Gateway` 的实际行为，也更稳定

#### `HTTP -> HTTPS` 跳转规则

- 来源文件：`manifests/21_gateway_longhorn_ui.yaml`
- 对象类型：`HTTPRoute`

```yaml
kind: HTTPRoute
metadata:
  name: longhorn-http-redirect
spec:
  parentRefs:
    - name: app-gateway
      sectionName: longhorn-http
```

关键字段说明：

- Longhorn UI 使用自己的 `longhorn-http` listener
- 并遵循“80 只负责跳转，443 才承载正式内容”的统一入口模型

#### `HTTPS -> longhorn-frontend` 转发规则

- 来源文件：`manifests/21_gateway_longhorn_ui.yaml`
- 对象类型：`HTTPRoute`

```yaml
kind: HTTPRoute
metadata:
  name: longhorn-https-backend
spec:
  parentRefs:
    - name: app-gateway
      sectionName: longhorn-https
  rules:
    - backendRefs:
        - name: longhorn-frontend
          namespace: longhorn-system
          port: 80
```

关键字段说明：

- 后端 Service 位于 `longhorn-system`
- 因此这一页必须补 `ReferenceGrant`
- `ReferenceGrant` 必须创建在被访问的命名空间，也就是 `longhorn-system`

---

## 对应脚本

本步对应脚本：

- `k8s/04-storage-and-stateful/scripts/07_publish_longhorn_ui.sh`

本步会直接消费：

- `manifests/21_gateway_longhorn_ui.yaml`

---

## 脚本关键任务

### 关键任务 1：为 `longhorn.qytk8s.com` 签发证书并创建 Secret

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
DOMAIN="longhorn.qytk8s.com"
SECRET_NAME="longhorn-qytk8s-com-tls"
SECRET_NAMESPACE="gateway-demo"
```

关键介绍：

- Longhorn UI 使用独立域名与独立证书
- Secret 创建在 `gateway-demo`，供现有 `app-gateway` 引用

### 关键任务 2：应用 Longhorn UI 清单

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
kubectl apply -f "${MANIFEST_URL}"
```

关键介绍：

- 这里应用的就是 `manifests/21_gateway_longhorn_ui.yaml`
- Longhorn 相关的 `HTTPRoute` 和 `ReferenceGrant` 都在这份清单里
- `HTTPRoute` 会明确绑定到：
  - `longhorn-http`
  - `longhorn-https`
- `ReferenceGrant` 创建在 `longhorn-system`

### 关键任务 3：为 Longhorn UI 增加专用 listener

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
reconcile_gateway_listeners
```

来源方式：

- 来源文件：`scripts/07_publish_longhorn_ui.sh`
- 说明：这里不是静态 YAML，而是脚本运行时动态改写 `gateway-demo/app-gateway`

关键介绍：

- 脚本会把 `app-gateway` 的 listener 收敛成固定 4 个：
  - `http`
  - `https`
  - `longhorn-http`
  - `longhorn-https`
- 其中：
  - `app.qytk8s.com` 继续使用 `http/https`
  - `longhorn.qytk8s.com` 使用 `longhorn-http/longhorn-https`
- 两个域名继续复用同一个 VIP，但不共用同一个 HTTPS listener

脚本收敛后的最终 listener 结构可以概括成：

```yaml
listeners:
  - name: http
    hostname: app.qytk8s.com
  - name: https
    hostname: app.qytk8s.com
  - name: longhorn-http
    hostname: longhorn.qytk8s.com
  - name: longhorn-https
    hostname: longhorn.qytk8s.com
```

### 关键任务 4：检查并修正 `EndpointSlice` 标签

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
kubectl -n gateway-demo label endpointslice "${slice_name}" \
  kubernetes.io/service-name="${GATEWAY_SERVICE}" --overwrite
```

关键介绍：

- 第四章继续复用第三章统一入口
- 因此这里仍然需要保持 `Cilium Gateway` 与 `MetalLB` 的兼容标签链路

---

## 执行命令

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选预处理命令</strong><br/>
如果脚本已具备执行权限，这一步可以跳过。
</div>

```bash
chmod +x /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/07_publish_longhorn_ui.sh
```

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #ea4335; border-radius: 6px; background: rgba(234,67,53,0.10); margin: 8px 0;">
<strong>❗ 本步必须粘贴执行</strong><br/>
下面命令是本步主线必跑命令。
</div>

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/07_publish_longhorn_ui.sh
```

---

## 验证方法

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #ea4335; border-radius: 6px; background: rgba(234,67,53,0.10); margin: 8px 0;">
<strong>❗ 本步必须粘贴执行</strong><br/>
下面命令是本步主线必跑命令，用于验证网关与路由对象。
</div>

```bash
kubectl get gateway,httproute -n gateway-demo
```

关键看点：

- 重点不是把 `gateway-demo` 下所有对象都逐行看完
- 而是确认和 Longhorn UI 直接相关的对象已经出现：
  - `app-gateway`
  - `longhorn-http-redirect`
  - `longhorn-https-backend`
- 这说明第四章已经把 Longhorn UI 的北向入口对象补进现有网关体系

预期结果：

- `gateway-demo` 下能看到 `app-gateway`
- `gateway-demo` 下能看到：
  - `longhorn-http-redirect`
  - `longhorn-https-backend`

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #ea4335; border-radius: 6px; background: rgba(234,67,53,0.10); margin: 8px 0;">
<strong>❗ 本步必须粘贴执行</strong><br/>
下面命令是本步主线必跑命令，用于验证跨命名空间授权。
</div>

```bash
kubectl -n longhorn-system get referencegrant
```

关键看点：

- 重点看是否已经存在允许 `gateway-demo` 访问 `longhorn-frontend` 的授权对象
- 这是跨命名空间后端转发能成立的关键前提

预期结果：

- `longhorn-system` 下能看到：
  - `allow-gateway-demo-to-longhorn-frontend`

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #ea4335; border-radius: 6px; background: rgba(234,67,53,0.10); margin: 8px 0;">
<strong>❗ 本步必须粘贴执行</strong><br/>
下面命令是本步主线必跑命令，用于验证 HTTP 到 HTTPS 跳转。
</div>

```bash
curl -I --resolve longhorn.qytk8s.com:80:10.1.1.60 http://longhorn.qytk8s.com/
```

关键看点：

- 重点看 `HTTP` 是否已经不直接提供页面内容
- 第四章要求它像第三章一样，统一跳转到 `HTTPS`

预期结果：

- 返回状态应为 `301` 或等价的重定向结果
- 响应头里应能看到 `Location: https://longhorn.qytk8s.com/...`

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #ea4335; border-radius: 6px; background: rgba(234,67,53,0.10); margin: 8px 0;">
<strong>❗ 本步必须粘贴执行</strong><br/>
下面命令是本步主线必跑命令，用于验证 Longhorn UI HTTPS 访问。
</div>

```bash
curl -I --resolve longhorn.qytk8s.com:443:10.1.1.60 --cacert /docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt https://longhorn.qytk8s.com/
```

关键看点：

- 重点看 `HTTPS` 是否已经能正常返回页面响应
- 这里同时也在验证：
  - `Gateway` 的 `443` listener
  - `TLS Secret`
  - 跨命名空间转发
  - Harbor CA 信任链

预期结果：

- 返回 `200 OK`
- 说明 `longhorn.qytk8s.com` 已经能够通过 HTTPS 正常访问

通过这一组验证后，应形成下面的判断：

- Longhorn UI 的北向入口对象已创建完成
- `app-gateway` 已同时承载：
  - `app.qytk8s.com`
  - `longhorn.qytk8s.com`
- 且两个域名使用的是各自独立的 listener
- 跨命名空间授权已生效
- `HTTP -> HTTPS` 跳转正常
- `longhorn.qytk8s.com` 已能作为第四章正式 GUI 入口使用

---

## win2019 侧要求

在 `win2019 DNS` 中新增：

```text
longhorn.qytk8s.com  ->  10.1.1.60
```

并确保把 Harbor CA 导入到：

```text
受信任的根证书颁发机构
```

之后即可从浏览器访问：

```text
https://longhorn.qytk8s.com
```

---

## 通过标准

- `longhorn.qytk8s.com` 已能通过 `HTTPS` 访问
- Longhorn UI 已可从 `win2019` 浏览器打开
- 本章 GUI 访问方式与第三章保持完全一致

---

## 下一步

进入第 9 步，执行第四章最终验收：

- `docs/10_verify.md`
