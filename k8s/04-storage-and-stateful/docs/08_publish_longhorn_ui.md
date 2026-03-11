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

## 执行标记

- **执行标记：必须执行**

说明：

- 这一页不是再单独搞一套新的入口
- 它的意义是把第四章的存储 GUI 也统一纳入整门课的北向 HTTPS 体系

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
- Longhorn UI 只是新增了属于自己的域名、监听和转发规则

### 为什么这一页复用第三章的 `app-gateway`

这一节不是再单独搞一套新的 VIP，而是继续复用第三章已经建立的统一入口：

- VIP 仍然是 `10.1.1.60`
- Gateway 仍然是 `gateway-demo/app-gateway`
- Longhorn UI 后端仍然是 `longhorn-system/longhorn-frontend`

只是新增了：

- `longhorn.qytk8s.com`
- `longhorn-http` / `longhorn-https` 监听
- 对 `longhorn-frontend` 的转发规则

这样课程整体风格才统一。

### 本步关键清单

本步会使用下面这份清单：

- `manifests/20_gateway_longhorn_listeners.json`
- `manifests/21_gateway_longhorn_ui.yaml`

这一步现在分成两部分：

- `20_gateway_longhorn_listeners.json`
  - 只定义 Longhorn 自己的两个 listener
  - 由脚本增量注入现有 `app-gateway`
- `21_gateway_longhorn_ui.yaml`
  - 只定义 Longhorn 自己的 `HTTPRoute` 与 `ReferenceGrant`

这样做的目的，是避免第四章在后续章节里重新执行时，误覆盖未来新增的 `netdevops`、`grafana`、`jaeger` 等 listener。

#### `Gateway` 中的 Longhorn 监听

```yaml
- name: longhorn-http
  hostname: longhorn.qytk8s.com
  port: 80
  protocol: HTTP
- name: longhorn-https
  hostname: longhorn.qytk8s.com
  port: 443
  protocol: HTTPS
  tls:
    mode: Terminate
    certificateRefs:
      - kind: Secret
        name: longhorn-qytk8s-com-tls
```

关键字段说明：

- `longhorn.qytk8s.com`
  - 这是第四章固定的 GUI 域名
- `longhorn-qytk8s-com-tls`
  - 这是本页脚本会创建的 TLS Secret

#### `HTTP -> HTTPS` 跳转规则

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

- Longhorn UI 也遵循“80 只负责跳转，443 才承载正式内容”的统一入口模型

#### `HTTPS -> longhorn-frontend` 转发规则

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

## 对应脚本

本步对应脚本：

- `k8s/04-storage-and-stateful/scripts/07_publish_longhorn_ui.sh`

本步会直接消费：

- `manifests/20_gateway_longhorn_listeners.json`
- `manifests/21_gateway_longhorn_ui.yaml`

## 脚本关键任务

### 关键任务 1：为 `longhorn.qytk8s.com` 签发证书并创建 Secret

脚本原始代码：

```bash
DOMAIN="longhorn.qytk8s.com"
SECRET_NAME="longhorn-qytk8s-com-tls"
SECRET_NAMESPACE="gateway-demo"
```

关键介绍：

- Longhorn UI 使用独立域名与独立证书
- Secret 创建在 `gateway-demo`，供现有 `app-gateway` 引用

### 关键任务 2：把 Longhorn listener 增量注入现有 `app-gateway`

脚本原始代码：

```bash
python3 - "${LISTENERS_FILE}" <<'PY'
```

关键介绍：

- 这里读取的是 `manifests/20_gateway_longhorn_listeners.json`
- 脚本只会补齐或更新 `longhorn-http`、`longhorn-https`
- 已存在的其他 listener 会保留，不会被第四章脚本覆盖

### 关键任务 3：应用 Longhorn UI 清单

脚本原始代码：

```bash
kubectl apply -f "${MANIFEST_URL}"
```

关键介绍：

- 这里应用的就是 `manifests/21_gateway_longhorn_ui.yaml`
- Longhorn 相关的 `HTTPRoute` 和 `ReferenceGrant` 都在这份清单里

### 关键任务 4：检查并修正 `EndpointSlice` 标签

脚本原始代码：

```bash
kubectl -n gateway-demo label endpointslice "${slice_name}" \
  kubernetes.io/service-name="${GATEWAY_SERVICE}" --overwrite
```

关键介绍：

- 第四章继续复用第三章统一入口
- 因此这里仍然需要保持 `Cilium Gateway` 与 `MetalLB` 的兼容标签链路

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/07_publish_longhorn_ui.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/07_publish_longhorn_ui.sh
```

## 验证方法

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

```bash
kubectl -n longhorn-system get referencegrant
```

关键看点：

- 重点看是否已经存在允许 `gateway-demo` 访问 `longhorn-frontend` 的授权对象
- 这是跨命名空间后端转发能成立的关键前提

预期结果：

- `longhorn-system` 下能看到：
  - `allow-gateway-demo-to-longhorn-frontend`

```bash
curl -I --resolve longhorn.qytk8s.com:80:10.1.1.60 http://longhorn.qytk8s.com/
```

关键看点：

- 重点看 `HTTP` 是否已经不直接提供页面内容
- 第四章要求它像第三章一样，统一跳转到 `HTTPS`

预期结果：

- 返回状态应为 `301` 或等价的重定向结果
- 响应头里应能看到 `Location: https://longhorn.qytk8s.com/...`

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
- 跨命名空间授权已生效
- `HTTP -> HTTPS` 跳转正常
- `longhorn.qytk8s.com` 已能作为第四章正式 GUI 入口使用

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

## 通过标准

- `longhorn.qytk8s.com` 已能通过 `HTTPS` 访问
- Longhorn UI 已可从 `win2019` 浏览器打开
- 本章 GUI 访问方式与第三章保持完全一致

## 下一步

进入第四章最终验收：

- `docs/09_verify.md`
