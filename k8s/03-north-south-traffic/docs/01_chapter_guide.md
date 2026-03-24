# 第三章总览：南北向入口、域名与 HTTPS 发布

## 本章目标

第三章的目标是把第二章已经具备东西向能力的集群，推进到**对外正式发布**的状态。

本章结束后，应达到下面状态：

- `MetalLB` 已为裸机集群补齐 `LoadBalancer VIP`
- `Cilium Gateway API` 已启用
- 演示服务可以通过 `app.qytk8s.com` 从集群外访问
- `Hubble UI` 可以通过 `hubble.qytk8s.com` 从集群外访问
- 访问方式统一为 `HTTPS`
- 证书由现有 `Harbor CA` 签发

---

## 问题背景

第二章已经解决：

- 集群内部网络
- Service Discovery
- 可观测性
- 网络策略

第三章要继续解决：

- 集群外部如何访问内部服务
- 谁来分配业务 VIP
- 谁来监听北向 `80/443`
- 谁来处理域名、证书和 HTTPS

因此第三章的重心不是“再装一套网络”，而是“把已经能在集群内运行的服务正式发布出去”。

---

## 理论导读

正式进入操作前，可先阅读：

- `docs/00_north_south_theory.md`

这份文档主要回答：

- `MetalLB` 做什么，不做什么
- `Gateway API` 为什么是第三章主线
- 为什么从这一章开始统一走 `域名 + HTTPS`
- 为什么继续复用 `Harbor CA`

---

## 本章重点边界

第三章只聚焦：

- `LoadBalancer VIP`
- `MetalLB`
- `Gateway API`
- `域名 + HTTPS`

---

## 本章总关系图

```mermaid
flowchart LR
  start[1. 第二章结束状态]
  prep[2. 制品预热<br/>MetalLB / Gateway API / 演示镜像]
  metallb[3. MetalLB<br/>IPAddressPool / L2Advertisement / VIP]
  gateway[4. Cilium Gateway API<br/>GatewayClass / Gateway / HTTPRoute]
  tls[5. TLS 证书<br/>Harbor CA / Secret]
  app[6. 发布 app.qytk8s.com<br/>VIP + 域名 + HTTPS]
  hubble[7. 发布 hubble.qytk8s.com<br/>VIP + 域名 + HTTPS]
  verify[8. 第三章验收<br/>域名 / HTTPS / 页面访问]

  start --> prep
  prep --> metallb
  metallb --> gateway
  gateway --> tls
  tls --> app
  tls --> hubble
  app --> verify
  hubble --> verify
```

这张图对应第三章主线：先准备制品，再补齐 `VIP`、`Cilium Gateway API`、证书与正式发布链路，最后统一验收 `app` 和 `Hubble UI`。

本章里提到的 `Gateway API`，具体实现就是 `Cilium Gateway API`。

---

## 本章学习方式

第三章继续采用“文档主导 + 脚本辅助 + YAML 独立发布”的方式：

1. 登录 `ops`
2. 先看文档，再执行步骤
3. 所有 YAML 继续通过 `http://ops:9000/` 发布
4. 所有镜像继续统一走 `harbor.qytk8s.com`

---

## 执行标记说明

本章采用统一执行标记：

- **必须执行**：从第三章标准起点开始时，默认需要实际执行
- **只读验证**：主要用于检查结果，不会改配置

---

## 本章小单元与对应脚本

| 步骤 | 文档 | 主要任务 | 对应脚本 | 执行标记 |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `02_prepare_north_south_artifacts.md` | 预热 `MetalLB` / `Gateway API` / 演示镜像 | `scripts/01_prepare_north_south_artifacts.sh` | 必须执行 |
| 2 | `03_install_metallb.md` | 安装 `MetalLB`，配置业务 VIP 地址池 | `scripts/02_install_metallb.sh` | 必须执行 |
| 3 | `04_enable_gateway_api.md` | 为现有 `Cilium` 开启 `Gateway API` | `scripts/03_enable_gateway_api.sh` | 必须执行 |
| 4 | `05_issue_tls_certs.md` | 复用 `Harbor CA` 为 `app.qytk8s.com` 签发证书 | `scripts/04_issue_tls_certs.sh` | 必须执行 |
| 5 | `06_publish_gateway_demo.md` | 发布通过 `HTTPS` 访问的演示应用 | `scripts/05_publish_gateway_demo.sh` | 必须执行 |
| 6 | `07_publish_hubble_ui.md` | 发布 `Hubble UI`，并触发第三章北向流量供 UI 观察 | `scripts/06_publish_hubble_ui.sh` / `scripts/07_trigger_north_south_traffic.sh` | 必须执行 |
| 7 | `08_verify.md` | 执行第三章最终验收 | 无 | 只读验证 |

---

## 本章执行顺序

请严格按下面顺序执行：

1. `02_prepare_north_south_artifacts.md`
2. `03_install_metallb.md`
3. `04_enable_gateway_api.md`
4. `05_issue_tls_certs.md`
5. `06_publish_gateway_demo.md`
6. `07_publish_hubble_ui.md`
7. `08_verify.md`

---

## 版本冻结

- Kubernetes：`v1.33.9`
- Cilium：`1.19.1`
- MetalLB：`v0.15.3`
- Gateway API 标准 CRD：`v1.4.1`
- 域名后缀：`qytk8s.com`
- 业务演示域名：`app.qytk8s.com`
- 业务演示 VIP：`10.1.1.60`
- Hubble UI 域名：`hubble.qytk8s.com`
- Hubble UI VIP：`10.1.1.61`

---

## 关键设计冻结

- API 平面继续走 `lb01/lb02 + 10.1.1.10`
- 业务平面改走 `MetalLB VIP`
- 北向入口统一走 `Cilium Gateway API`
- HTTPS 统一由 `Harbor CA` 签发并校验

---

## 下一步

先进入第 1 步，准备第三章所需制品：

- `docs/02_prepare_north_south_artifacts.md`
