# K8s 第 5 章：安全与零信任（Istio Ambient）

- **状态：** ✅ 完成（主线全部通过；扩展的流量治理测试部分和课程预期不符，原因见下）
- **日期：** 2026-11-24
- **课程原文：** [k8s/05-security-and-zero-trust/docs/](../k8s/05-security-and-zero-trust/docs/)

## 结果

主线 5 个脚本（01 → 02 → 03 → 04 → 07）一次全部成功。

| 验证项 | 结果 |
|---|---|
| Istio 1.29.0 Ambient | `istiod` × 1；`ztunnel` 是 DaemonSet，7 个节点各一个 |
| 入口 | Istio Ingress Gateway 拿到 VIP `10.1.1.62`，`https://secure-app.qytk8s.com/public` → 200 |
| mTLS | `PeerAuthentication mesh-demo-strict`：`STRICT` |

**JWT（入口层）：**

| 请求 | 结果 | 说明 |
|---|---|---|
| 无 token → `/public` | 200 | 公开路径 |
| 无 token → `/hello` | 403 | 需要登录 |
| 错误 token → `/hello` | 401 | token 校验失败 |
| user token → `/hello` | 200 | |
| user token → `/headers` | 403 | 需要 `role=admin` |
| admin token → `/headers` | 200 | |

**网格内授权（waypoint，L7）：** trusted-client `GET /get` → 200，`POST /post` → 403。

**扩展：流量治理（`05_apply_traffic_management.sh` + `manual_tests/04–06`）**

| 测试 | 结果 |
|---|---|
| 50/50 分流 | v1 10 次、v2 10 次 ✅ |
| 第二组权重 | v1 17 次、v2 3 次 ✅ |
| 注入 5 秒延迟（`/hello`） | 200，耗时 5.13 秒 ✅ |
| 超时 `/delay/5`（timeout=2s） | **403**（预期 504） |
| 重试 `/status/503` | **403**（预期 503 + 重试） |
| 注入 503 中断 | **403**（预期 503） |

最后用 `99_reset_baseline.sh` 恢复到 100% → v1。

## 和课程原版的区别

**AWS：** 不需要改（VIP `.62` 在第 3 章已经挂到 wk-edge01 上）。

**课程本身的问题：扩展测试被 JWT 授权策略拦截**

`31_authorizationpolicy_ingress_jwt.yaml` 只放行 `/public`、`/hello`、`/headers` 三个路径。超时和重试测试访问的是 `/delay/5`、`/status/503`，在入口就被 403 拒绝了，根本到不了 VirtualService 的超时、重试规则。延迟注入能看到效果，是因为它测的是 `/hello`。

这几个测试应该是在第 4 步（开启 JWT）之前设计的。要让它们按预期工作，可以：

- 在第 4 步之前做这些测试；或者
- 在授权策略里给 `/delay/*`、`/status/*` 加一条 ALLOW 规则。

课程文件保持原样未改。

## 学到的

- **Ambient 模式没有 sidecar**：每个节点一个 `ztunnel`（DaemonSet）负责 L4 的 mTLS 加密和身份认证；需要 L7（按 HTTP 方法、路径授权）时才额外部署 waypoint 代理。所以 Pod 里只有业务容器一个。
- **401 和 403 的区别**：401 = “你是谁我不认识”（token 无效）；403 = “我知道你是谁，但你没权限”（token 有效但角色不对，或者根本没带）。
- **授权策略在流量规则之前执行**：入口先过 AuthorizationPolicy，通过了才走 VirtualService 的路由、超时、重试。上面那些 403 就是这个顺序造成的。

## 完整操作记录

以下都在 ops 上执行。

### 执行主线 5 个脚本

```bash
cd /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts
chmod +x *.sh

# JWT 生成脚本只用 Python 标准库，ops 上的 python3 就够
grep -nE "^import|^from" 98_generate_demo_jwt.py
python3 --version

for s in 01_prepare_istio_artifacts.sh \
         02_install_istio_ambient.sh \
         03_publish_istio_ingress_demo.sh \
         04_enable_jwt_and_mesh_security.sh \
         07_verify_istio_security.sh; do
  timeout 1500 bash "$s" > "/root/ch5-$s.log" 2>&1 </dev/null
  rc=$?
  echo "$s exit=$rc  | $(tail -1 /root/ch5-$s.log)"
  [ $rc -ne 0 ] && { tail -20 "/root/ch5-$s.log"; break; }
done
```

```text
import base64 / hashlib / json / re / subprocess / time / pathlib   ← 全是标准库
Python 3.12.3
01_prepare_istio_artifacts.sh exit=0  | OK: 第五章 Istio 制品预热完成
02_install_istio_ambient.sh exit=0  | OK: Istio Ambient 已安装完成
03_publish_istio_ingress_demo.sh exit=0  | OK: 第五章北向入口与演示应用已发布
04_enable_jwt_and_mesh_security.sh exit=0  | OK: 第五章 JWT、mTLS 与授权策略已启用
07_verify_istio_security.sh exit=0  | OK: 第五章验收通过
```

### 01 准备 Istio 制品

```text
Istio 版本：1.29.0
[3/8] 下载 Istio 离线安装包
[4/8] 安装 istioctl
client version: 1.29.0
[6/8] 整理镜像列表并推送到 Harbor
源镜像：docker.io/istio/pilot:1.29.0-distroless           → harbor.qytk8s.com/istio/pilot:1.29.0-distroless
源镜像：docker.io/istio/proxyv2:1.29.0-distroless         → harbor.qytk8s.com/istio/proxyv2:1.29.0-distroless
源镜像：docker.io/istio/ztunnel:1.29.0-distroless         → harbor.qytk8s.com/istio/ztunnel:1.29.0-distroless
源镜像：docker.io/istio/install-cni:1.29.0-distroless     → harbor.qytk8s.com/istio/install-cni:1.29.0-distroless
源镜像：docker.io/istio/examples-helloworld-v1:1.0        → harbor.qytk8s.com/istio/helloworld-v1:1.0
源镜像：docker.io/istio/examples-helloworld-v2:1.0        → harbor.qytk8s.com/istio/helloworld-v2:1.0
源镜像：docker.io/mccutchen/go-httpbin:v2.15.0            → harbor.qytk8s.com/istio/httpbin:v2.15.0
源镜像：docker.io/curlimages/curl:8.12.1                  → harbor.qytk8s.com/istio/curl:8.12.1
[7/8] 在 Kubernetes 节点预拉镜像
OK: 第五章 Istio 制品预热完成
```

`-distroless` 镜像里没有 shell、没有包管理器，只有程序本身，攻击面更小。

### 02 安装 Istio Ambient

```text
[2/5] 调整 Cilium CNI 共享模式
将 Cilium cni-exclusive 从 true 调整为 false              ← 让 Istio 的 CNI 插件可以和 Cilium 共存
configmap/cilium-config patched
daemonset.apps/cilium restarted
[3/5] 安装 Ambient Profile
WARNING: Istio 1.29.0 may be out of support (EOL) already
✔ Istio core installed ⛵️
✔ CNI installed 🪢
✔ Istiod installed 🧠
✔ Ztunnel installed 🔒
✔ Installation complete The ambient profile has been installed successfully, enjoy Istio without sidecars!
[4/5] 等待核心组件就绪
deployment "istiod" successfully rolled out
daemon set "ztunnel" successfully rolled out
daemon set "istio-cni-node" successfully rolled out
[5/5] 查看 Istio 组件状态
istio-cni-node-...   1/1   Running   （7 个节点各一个）
istiod-6d5878b7f-qtjm6   1/1   Running   wk-app02
```

### 03 发布 Istio 入口和演示应用

```text
[2/8] 生成入口 HTTPS 证书
subject=... CN = secure-app.qytk8s.com
[3/8] 创建 TLS Secret
namespace/istio-ingress created
secret/secure-app-qytk8s-com-tls created
[4/8] 安装 Istio Ingress Gateway
Release "istio-ingressgateway" does not exist. Installing it now.
STATUS: deployed
[5/8] 部署演示工作负载
namespace/mesh-demo created
serviceaccount/trusted-client created            ← 两个 ServiceAccount = 两种身份，后面授权用
serviceaccount/untrusted-client created
deployment.apps/curl-trusted created
deployment.apps/curl-untrusted created
deployment.apps/helloworld-v1 created            ← v1/v2 两个版本，后面流量治理用
deployment.apps/helloworld-v2 created
deployment.apps/httpbin created
deployment.apps/public-whoami created
[6/8] 应用 Gateway 与基础路由
gateway.networking.istio.io/secure-app-gateway created
virtualservice.networking.istio.io/secure-app created
[7/8] 等待 Ingress Gateway 获取 VIP
Istio Ingress VIP 已就绪：10.1.1.62                ← 第 3 章已经挂到 wk-edge01 网卡上的 IP
[8/8] 本机验证 HTTP 跳转与 HTTPS 访问
HTTP/1.1 301 Moved Permanently
location: https://secure-app.qytk8s.com/public
server: istio-envoy
HTTPS HTTP Code: 200
Hostname: public-whoami-d4747f567-pk9l7
```

### 04 开启 JWT、mTLS、L7 授权

```text
[2/6] 检查 Cilium waypoint 前置项
修正 Cilium waypoint 前置项: 开启 bpf-lb-sock-hostns-only=true
configmap/cilium-config patched
daemonset.apps/cilium restarted
[2.5/6] 如有需要，重启 mesh-demo 工作负载
deployment.apps/curl-trusted restarted
...（6 个 Deployment）
[3/6] 生成 JWT 演示材料
已生成：/docker_k8s_2026/k8s/05-security-and-zero-trust/pki/jwks.json      ← 公钥（给 Istio 校验签名）
已生成：/docker_k8s_2026/k8s/05-security-and-zero-trust/pki/user.jwt       ← role=user 的 token
已生成：/docker_k8s_2026/k8s/05-security-and-zero-trust/pki/admin.jwt      ← role=admin 的 token
[4/6] 为 mesh-demo 部署 waypoint
✅ waypoint mesh-demo/waypoint applied
✅ waypoint mesh-demo/waypoint is ready!
✅ namespace mesh-demo labeled with "istio.io/use-waypoint: waypoint"
[5/6] 应用 JWT、mTLS 与 L7 授权策略
requestauthentication.security.istio.io/ingress-jwt created         ← 入口：怎么校验 JWT
authorizationpolicy.security.istio.io/ingress-require-jwt created   ← 入口：哪些路径要 JWT、要什么角色
peerauthentication.security.istio.io/mesh-demo-strict created       ← 网格内：强制 mTLS
authorizationpolicy.security.istio.io/httpbin-waypoint-l7 created   ← 网格内：waypoint 上的 L7 授权
[6/6] 查看安全对象
istio-ingress   authorizationpolicy.security.istio.io/ingress-require-jwt   ALLOW
mesh-demo       authorizationpolicy.security.istio.io/httpbin-waypoint-l7   ALLOW
mesh-demo       peerauthentication.security.istio.io/mesh-demo-strict       STRICT
OK: 第五章 JWT、mTLS 与授权策略已启用
```

网格内的 L7 授权策略（`33_authorizationpolicy_httpbin_waypoint.yaml`）：

```yaml
spec:
  targetRefs:
    - kind: Service
      name: httpbin
  action: ALLOW
  rules:
    - from:                       # 规则 1：入口网关的身份可以访问 httpbin 的任何路径
        - source:
            principals:
              - cluster.local/ns/istio-ingress/sa/istio-ingressgateway
    - from:                       # 规则 2：trusted-client 只能 GET /get
        - source:
            principals:
              - cluster.local/ns/mesh-demo/sa/trusted-client
      to:
        - operation:
            methods: [GET]
            paths: [/get]
```

`principals` 是 mTLS 证书里的身份（SPIFFE ID），由 ServiceAccount 决定，不是 IP。

### 07 验收

```text
[2/7] 查看 Istio 组件
istiod-6d5878b7f-qtjm6   1/1   Running   wk-app02
ztunnel-4fg96            1/1   Running   cp01
ztunnel-7gplw            1/1   Running   cp02
ztunnel-b8rj2            1/1   Running   wk-app02
ztunnel-bq4fb            1/1   Running   wk-obs01
ztunnel-ncfwc            1/1   Running   wk-edge01
ztunnel-nhjgd            1/1   Running   cp03
ztunnel-wdjmm            1/1   Running   wk-app01

[3/7] 验证 public HTTPS 访问
HTTP Code: 200
Hostname: public-whoami-74c4b67f46-d82m8
GET /public HTTP/1.1
Host: secure-app.qytk8s.com
X-Envoy-External-Address: 10.1.1.201
X-Forwarded-For: 10.1.1.201
X-Forwarded-Proto: https

[4/7] 查看演示工作负载
pod/curl-trusted-7fbfdb9f45-jp8tw     1/1   Running        ← 每个 Pod 只有 1 个容器（1/1）：Ambient 模式没有 sidecar
pod/curl-untrusted-7dccc97cc6-bkns9   1/1   Running
pod/helloworld-v1-bfd8db995-nkxzg     1/1   Running
pod/helloworld-v2-6d9b45d76c-8g4l8    1/1   Running
pod/httpbin-7d58fdd788-nmn9j          1/1   Running
pod/public-whoami-74c4b67f46-d82m8    1/1   Running
pod/waypoint-65fcf88bb8-dh8qr         1/1   Running        ← L7 代理，整个命名空间共用一个
service/waypoint   ClusterIP   10.107.47.43   15021/TCP,15008/TCP   ← 15008 = HBONE（ztunnel 之间的 mTLS 隧道端口）

[6/7] 执行 JWT 手动测试
[1/6] 不带 JWT 访问 /public
HTTP Code: 200
[2/6] 不带 JWT 访问 /hello
HTTP Code: 403
[3/6] 带错误 JWT 访问 /hello
HTTP Code: 401
[4/6] 带 user JWT 访问 /hello
HTTP Code: 200
返回内容示例:
Hello version: v1, instance: helloworld-v1-bfd8db995-nkxzg
[5/6] 带 user JWT 访问 /headers
HTTP Code: 403
[6/6] 带 admin JWT 访问 /headers
HTTP Code: 200
返回内容示例:
{
  "headers": {
    "Authorization": ["Bearer eyJhbGciOiJSUzI1NiIs...（已截断）"],
    "Host": ["secure-app.qytk8s.com"],
    "X-Envoy-Decorator-Operation": ["httpbin.mesh-demo.svc.cluster.local:8000/headers*"],
    ...
  }
}

[7/7] 执行网格授权手动测试
手动测试：waypoint 上的 L7 授权
[1/3] trusted-client GET /get
HTTP Code: 200
[2/3] trusted-client POST /post
HTTP Code: 403
[3/3] untrusted-client GET /get
HTTP Code: 403
OK: 第五章验收通过
```

手工发一个带 JWT 的请求，相当于测试脚本里的这一条：

```bash
CA=/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt
TOKEN=$(tr -d '\n' < /docker_k8s_2026/k8s/05-security-and-zero-trust/pki/user.jwt)

curl -s --cacert $CA \
  --resolve secure-app.qytk8s.com:443:10.1.1.62 \
  -H "Authorization: Bearer $TOKEN" \
  -o /dev/null -w "HTTP Code: %{http_code}\n" \
  https://secure-app.qytk8s.com/hello
```

### 扩展：流量治理

```bash
cd /docker_k8s_2026/k8s/05-security-and-zero-trust

bash scripts/05_apply_traffic_management.sh > /root/ch5-05_traffic.log 2>&1 </dev/null
grep -vE "^=+$|^\s*$" /root/ch5-05_traffic.log | sed -n '/\[1\/4\]/,$p'
```

```text
[1/4] 应用 DestinationRule
destinationrule.networking.istio.io/helloworld created              ← 定义 v1、v2 两个子集
[2/4] 应用基线路由（100% -> v1）
virtualservice.networking.istio.io/secure-app configured
[3/4] 查看流量治理对象
destinationrule.networking.istio.io/helloworld   helloworld.mesh-demo.svc.cluster.local
virtualservice.networking.istio.io/secure-app   ["secure-app-gateway"]   ["secure-app.qytk8s.com"]
OK: 第五章流量治理基线已配置
```

```bash
for t in 04_test_weighted_routing.sh 05_test_timeout_retry.sh 06_test_fault_injection.sh; do
  echo "################ $t"
  bash "manual_tests/$t" </dev/null 2>&1 \
    | grep -E "\[|HTTP Code|v1 次数|v2 次数"
done

bash manual_tests/99_reset_baseline.sh </dev/null | tail -1
```

```text
################ 04_test_weighted_routing.sh
v1 次数: 10          ← 50/50
v2 次数: 10
v1 次数: 17          ← 第二组权重（约 90/10）
v2 次数: 3
################ 05_test_timeout_retry.sh
[1/2] 访问 /delay/5，观察 timeout=2s 的效果
HTTP Code: 403 | Total Time: 0.010569s        ← 预期 504，被入口授权策略拦截
[2/2] 访问 /status/503，观察重试场景
HTTP Code: 403 | Total Time: 0.011310s        ← 预期 503，同上
################ 06_test_fault_injection.sh
[1/2] 注入 5 秒延迟
HTTP Code: 200 | Total Time: 5.130480s        ← 延迟注入生效（测的是 /hello）
[2/2] 注入 503 中断
HTTP Code: 403 | Total Time: 0.010617s        ← 预期 503，同上
OK: 已恢复到 100% -> v1 的稳定基线
```

排查 403 的原因，看测试脚本和入口授权策略：

```bash
grep -nE "TOKEN_FILE|request_with_timing \"" manual_tests/05_test_timeout_retry.sh
cat manifests/31_authorizationpolicy_ingress_jwt.yaml
```

```text
TOKEN_FILE="${CHAPTER_DIR}/pki/user.jwt"        ← 用的是 user token
request_with_timing "/delay/5"
request_with_timing "/status/503"

# 入口授权策略只放行三条路径：
#   /public  —— 任何人
#   /hello   —— 带合法 JWT
#   /headers —— 带合法 JWT 且 role=admin
# /delay/*、/status/* 不在任何一条 ALLOW 规则里 → 默认拒绝 → 403
```

## 笔记 / 疑问

（自己补充）
