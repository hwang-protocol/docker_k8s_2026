# 第 3 步：发布 Istio Ingress Gateway 与演示应用

## 本步目标

新增第五章专用北向入口，并保持第三章入口不动。

本步完成后，应达到下面状态：

- 新域名：`secure-app.qytk8s.com`
- 新 VIP：`10.1.1.62`
- 新入口：`Istio Ingress Gateway`
- 演示命名空间：`mesh-demo`
- 演示应用：`helloworld`、`httpbin`、`curl-trusted`、`curl-untrusted`、`public-whoami`

---

## 执行标记

- **执行标记：必须执行**

---

## 问题背景

第三章已经讲清楚了“服务如何发布出去”，第五章不应该把重点放在迁移旧入口上。

因此这里采用：

- 第三章入口继续保留
- 第五章新增独立入口

这样你上课时就可以明确对比：

- `Cilium Gateway API`：基础发布
- `Istio Ingress Gateway`：安全与治理增强

---

## 理论说明

### 北向入口流量图

```mermaid
flowchart LR
    user[外部客户端] --> dns[secure-app.qytk8s.com]
    dns --> vip[MetalLB VIP<br/>10.1.1.62]
    vip --> ingress[Istio Ingress Gateway]

    ingress --> publicPath[路径 /public]
    ingress --> helloPath[路径 /hello]
    ingress --> httpbinPath[路径 /get 等]

    publicPath --> publicSvc[public-whoami]
    helloPath --> helloSvc[helloworld]
    httpbinPath --> httpbinSvc[httpbin]
```

这张图要配合下面 4 句话：

- 用户不是直接访问 Pod，而是先访问域名
- 域名解析到 `MetalLB` 提供的 VIP `10.1.1.62`
- `MetalLB` 把这个 VIP 绑定给 `Istio Ingress Gateway`
- 三个后端都可以经由这个入口对外访问，但分流依据是不同的 URL 路径

这里要特别区分：

- `public-whoami`
  - 是本步最重要的公开对照路径，用来先验证“入口 + HTTPS + 路由”已经正常
- `helloworld`
  - 也能通过入口访问，但在主线里主要用于 `JWT` 保护后的受控访问验证
- `httpbin`
  - 也能通过入口访问，但主线里主要用于后续服务间访问控制验证

### 为什么要保留 `/public` 这条路径

第五章后面会逐步引入：

- `JWT`
- 入口授权
- 服务间安全

如果一开始所有入口都直接加保护，课堂上就少了一个非常稳定的对照组。

因此这里保留：

- `/public`

它的作用是：

- 用来证明“入口和 HTTPS 本身已经正常”
- 作为后续 `JWT` 前后行为对照

### 本步关键清单

本步核心配置来自下面几份文件：

- `manifests/91_ingress_gateway_values.yaml`
- `manifests/20_secure_app_gateway.yaml`
- `manifests/21_virtualservice_baseline.yaml`

### 这三份文件之间是什么关系

```mermaid
flowchart TD
    values[91_ingress_gateway_values.yaml<br/>Helm values]
    gateway[20_secure_app_gateway.yaml<br/>Gateway]
    vs[21_virtualservice_baseline.yaml<br/>VirtualService]

    lb[Istio Ingress Gateway Service<br/>LoadBalancer 10.1.1.62]
    tls[TLS Secret<br/>secure-app-qytk8s-com-tls]
    host[域名<br/>secure-app.qytk8s.com]

    publicPath[路径 /public]
    helloPath[路径 /hello]
    httpbinPath[路径 /get 等]

    publicSvc[public-whoami]
    helloSvc[helloworld]
    httpbinSvc[httpbin]

    values --> lb
    gateway --> lb
    gateway --> tls
    gateway --> host
    vs --> gateway

    vs --> publicPath
    vs --> helloPath
    vs --> httpbinPath

    publicPath --> publicSvc
    helloPath --> helloSvc
    httpbinPath --> httpbinSvc
```

这张图建议按下面顺序理解：

1. `91_ingress_gateway_values.yaml`
   - 先把 `Istio Ingress Gateway` 这个入口组件安装出来
   - 并通过 `LoadBalancer` 让它拿到 `10.1.1.62`
2. `20_secure_app_gateway.yaml`
   - 再告诉这个入口“监听哪个域名、哪个端口、用哪张证书”
3. `21_virtualservice_baseline.yaml`
   - 最后告诉入口“不同路径分别转发到哪个后端服务”

如果用最短的话概括这三份文件的分工，就是：

- `91_ingress_gateway_values.yaml`
  - 创建入口组件
- `20_secure_app_gateway.yaml`
  - 定义入口监听规则
- `21_virtualservice_baseline.yaml`
  - 定义入口后的七层分流规则

这里补一句命名理解：

- 这一节里 `istio-ingressgateway`、`secure-app-gateway` 这类名字，沿用了 `Istio` 入口语义命名
- 它们不是 Kubernetes 关键字，而是普通资源名
- 目的不是炫技，而是让学员后面看官方文档时更容易对得上术语

#### Ingress Gateway 的 Helm values

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>YAML 文件：</strong><code>manifests/91_ingress_gateway_values.yaml</code><br/>
<strong>本页重点对象：</strong><code>Ingress Gateway Helm values</code><br/>
<strong>作用：</strong>安装第五章专用的 <code>Istio Ingress Gateway</code>，并让它以 <code>LoadBalancer</code> 方式固定获得 <code>10.1.1.62</code>
</div>

```yaml
global:
  hub: harbor.qytk8s.com/istio
  tag: 1.29.0

service:
  type: LoadBalancer
  annotations:
    metallb.io/address-pool: edge-pool
    metallb.io/loadBalancerIPs: 10.1.1.62
```

关键字段说明：

- `hub` / `tag`
  - 入口镜像仍然走 Harbor
- `type: LoadBalancer`
  - 让 `MetalLB` 为入口分配 VIP
- `metallb.io/loadBalancerIPs: 10.1.1.62`
  - 明确固定第五章入口地址

#### Istio Gateway

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>YAML 文件：</strong><code>manifests/20_secure_app_gateway.yaml</code><br/>
<strong>本页重点对象：</strong><code>Gateway</code><br/>
<strong>作用：</strong>定义 <code>secure-app.qytk8s.com</code> 的入口监听规则，包括 <code>80 -> 443</code> 跳转与 <code>TLS Secret</code> 引用
</div>

```yaml
kind: Gateway
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
      tls:
        httpsRedirect: true
    - port:
        number: 443
      tls:
        mode: SIMPLE
        credentialName: secure-app-qytk8s-com-tls
```

关键字段说明：

- `selector: istio: ingressgateway`
  - 说明这份 `Gateway` 绑定的是第五章新装的入口网关
- `httpsRedirect: true`
  - 让 `80` 只负责跳转
- `credentialName`
  - 指向本步脚本创建的 TLS Secret

#### 基线路由 `VirtualService`

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>YAML 文件：</strong><code>manifests/21_virtualservice_baseline.yaml</code><br/>
<strong>本页重点对象：</strong><code>VirtualService</code><br/>
<strong>作用：</strong>定义第五章入口后的七层路径分流，把 <code>/public</code>、<code>/hello</code>、<code>/get</code> 等路径分别转发到不同后端
</div>

```yaml
kind: VirtualService
spec:
  hosts:
    - secure-app.qytk8s.com
  gateways:
    - secure-app-gateway
  http:
    - name: public
    - name: hello
    - name: httpbin-get
```

关键字段说明：

- `public`
  - 作为“入口和 HTTPS 正常”的对照路径
- `hello`
  - 为后续 `JWT` 保护后的入口访问准备路径
- `httpbin-get`
  - 为后续服务间访问控制相关验证准备入口

---

## 对应脚本

- `k8s/05-security-and-zero-trust/scripts/03_publish_istio_ingress_demo.sh`

---

## 脚本关键任务

### 关键任务 1：为 `secure-app.qytk8s.com` 签发证书

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
DOMAIN="secure-app.qytk8s.com"
SECRET_NAME="secure-app-qytk8s-com-tls"
SECRET_NAMESPACE="istio-ingress"
VIP="10.1.1.62"
```

关键介绍：

- 第五章入口使用自己的域名和独立证书
- TLS Secret 创建在 `istio-ingress`

### 关键任务 2：安装 `Istio Ingress Gateway`

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
helm upgrade --install istio-ingressgateway "${chart_dir}" \
  -n istio-ingress \
  --create-namespace \
  -f "${INGRESS_VALUES}" \
  --wait
```

关键介绍：

- 这里消费的是 `91_ingress_gateway_values.yaml`
- 安装出来的是第五章专用入口，不影响第三章已有入口

### 关键任务 3：部署演示工作负载

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
kubectl apply -f "${NAMESPACE_URL}"
kubectl apply -f "${CLIENTS_URL}"
kubectl apply -f "${HELLOWORLD_URL}"
kubectl apply -f "${HTTPBIN_URL}"
kubectl apply -f "${PUBLIC_WHOAMI_URL}"
```

关键介绍：

- 第五章不是只装入口，还要同时准备后续 `JWT`、`mTLS`、治理演示需要的工作负载

### 关键任务 4：应用入口 `Gateway` 和基线路由

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
kubectl apply -f "${GATEWAY_URL}"
kubectl apply -f "${VIRTUALSERVICE_URL}"
```

关键介绍：

- 这里把第五章自己的域名监听和路径转发规则落到集群里

---

## 执行命令

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选预处理命令</strong><br/>
如果脚本已具备执行权限，这一步可以跳过。
</div>

```bash
chmod +x /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/03_publish_istio_ingress_demo.sh
```

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #ea4335; border-radius: 6px; background: rgba(234,67,53,0.10); margin: 8px 0;">
<strong>❗ 本步必须粘贴执行</strong><br/>
下面命令是本步主线必跑命令。
</div>

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/03_publish_istio_ingress_demo.sh
```

---

## 验证方法

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
kubectl -n istio-ingress get pods,svc -o wide
```

关键看点：

- 重点看 `istio-ingressgateway`
- Service 类型应为 `LoadBalancer`
- 外部地址应为 `10.1.1.62`

预期结果：

- `istio-ingressgateway` Pod 正常
- `istio-ingressgateway` Service 获得 `10.1.1.62`

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
kubectl -n mesh-demo get pods,svc
```

关键看点：

- 重点看演示工作负载是否都已就绪：
  - `helloworld-v1`
  - `helloworld-v2`
  - `httpbin`
  - `public-whoami`
  - `curl-trusted`
  - `curl-untrusted`

预期结果：

- `mesh-demo` 中相关 Pod 与 Service 都已出现

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
curl -I --resolve secure-app.qytk8s.com:80:10.1.1.62 http://secure-app.qytk8s.com/public
```

关键看点：

- 重点看 `HTTP -> HTTPS` 是否已经生效
- 不需要读取正文

预期结果：

- 返回 `301` 或 `302`

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看命令</strong><br/>
下面命令用于查看当前状态。
</div>

```bash
curl --resolve secure-app.qytk8s.com:443:10.1.1.62 \
  --cacert /docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt \
  https://secure-app.qytk8s.com/public
```

关键看点：

- 重点看 `HTTPS` 是否可访问
- 返回正文里应能看到 `public-whoami`

预期结果：

- `HTTPS` 返回 `200`
- `/public` 路径能正常访问

---

## win2019 侧要求

在 `win2019 DNS` 中新增：

```text
secure-app.qytk8s.com  ->  10.1.1.62
```

并确保已经导入 Harbor CA 根证书。

访问时还要注意：

- 浏览器验证建议直接打开：
  - `https://secure-app.qytk8s.com/public`
- 如果只访问根路径：
  - `https://secure-app.qytk8s.com/`
  - 很可能看到 `404`
  - 这是因为当前基线路由先暴露的是 `/public`、`/hello`、`/get`、`/headers`、`/delay`、`/status`

在 `win2019` 浏览器里，当前这一步可以直接打开测试的地址包括：

- `https://secure-app.qytk8s.com/public`
  - 验证入口、证书、HTTPS 与基础路由
- `https://secure-app.qytk8s.com/hello`
  - 验证 `helloworld`
- `https://secure-app.qytk8s.com/get`
  - 验证 `httpbin`
- `https://secure-app.qytk8s.com/headers`
  - 验证 `httpbin`
- `https://secure-app.qytk8s.com/status/200`
  - 验证 `httpbin`
- `https://secure-app.qytk8s.com/delay/3`
  - 验证 `httpbin`

当前这一步里，下面这些地址出现 `404` 或不适合作为浏览器验证，都属于正常现象：

- `https://secure-app.qytk8s.com/`
- `https://secure-app.qytk8s.com/httpbin`
- `https://secure-app.qytk8s.com/post`

---

## 通过标准

满足下面条件后，本步即可视为完成：

- `Istio Ingress Gateway` 已获得 `10.1.1.62`
- `mesh-demo` 演示环境已就绪
- `HTTP -> HTTPS` 跳转正常
- `HTTPS /public` 已能正常访问

---

## 下一步

进入第 4 步，开启 `JWT` 与服务间安全：

- `docs/05_enable_jwt_and_mesh_security.md`
