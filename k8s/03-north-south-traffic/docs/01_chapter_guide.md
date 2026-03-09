# 第三章总览：南北向入口、域名与 HTTPS 发布

## 本章目标

第三章的目标是把第二章已经具备东西向能力的集群，推进到 **对外正式发布** 的状态。

本章结束后，应达到下面状态：

- `MetalLB` 已为裸机集群补齐 `LoadBalancer VIP`
- `Cilium Gateway API` 已启用
- 演示服务可以通过 `app.qytk8s.com` 从集群外访问
- 访问方式统一为 `HTTPS`
- 证书由现有 `Harbor CA` 签发

## 本章学习方式

这一章继续采用“文档主导 + 小脚本辅助 + YAML 独立发布”的方式：

1. 登录 `ops`
2. 先看文档，再执行脚本
3. 所有 YAML 继续通过 `http://ops:9000/` 发布
4. 所有镜像继续统一走 `harbor.qytk8s.com`

## 课前理论导读

正式操作前，建议先阅读：

- `docs/00_north_south_theory.md`

它负责先把第三章最容易混淆的几个点讲清楚：

- `MetalLB` 做什么，不做什么
- `Gateway API` 和 `Ingress` 的边界
- 为什么从这一章开始统一走 `域名 + HTTPS`
- 为什么复用 `Harbor CA`

## 本章重点边界

第三章只聚焦：

- `LoadBalancer VIP`
- `MetalLB`
- `Gateway API`
- `域名 + HTTPS`

还不展开：

- JWT
- `mTLS`
- `Istio Ambient`
- 更细粒度服务授权

这些内容放到后续安全章节。

## 本章脚本执行矩阵

| 步骤 | 文档 | 脚本 | 执行标记 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| 0 | （内嵌于步骤 1） | `scripts/00_check_and_recover_cluster.sh` | 自动执行 | 快照恢复后集群检查与恢复 |
| 1 | `02_prepare_north_south_artifacts.md` | `scripts/01_prepare_north_south_artifacts.sh` | 必须执行 | 预热 `MetalLB` / `Gateway API` / 演示镜像 |
| 2 | `03_install_metallb.md` | `scripts/02_install_metallb.sh` | 必须执行 | 安装 `MetalLB`，配置业务 VIP 地址池 |
| 3 | `04_enable_gateway_api.md` | `scripts/03_enable_gateway_api.sh` | 必须执行 | 为现有 `Cilium` 开启 `Gateway API` |
| 4 | `05_issue_tls_certs.md` | `scripts/04_issue_tls_certs.sh` | 必须执行 | 复用 `Harbor CA` 为 `app.qytk8s.com` 签证书 |
| 5 | `06_publish_gateway_demo.md` | `scripts/05_publish_gateway_demo.sh` | 必须执行 | 发布通过 `HTTPS` 访问的演示应用 |
| 6 | `07_verify.md` | 无 | 只读验证 | 第三章最终验收 |

## 本章执行顺序

请严格按下面顺序执行：

0. `00_north_south_theory.md`
1. `02_prepare_north_south_artifacts.md`
2. `03_install_metallb.md`
3. `04_enable_gateway_api.md`
4. `05_issue_tls_certs.md`
5. `06_publish_gateway_demo.md`
6. `07_verify.md`

## 第三章起点状态

第三章开始前，默认你已经完成第二章，并满足下面这些条件：

- 所有节点均为 `Ready`
- `Cilium`、`Hubble` 正常
- 第二章最终验收已经通过
- `ops` 已具备 `kubectl`、`helm`
- `ops` 已提供 `http://ops:9000/`
- `Harbor` 仍然保留，不做快照恢复

## 快照恢复说明

| 节点 | 是否恢复快照 | 说明 |
| :--- | :--- | :--- |
| `ops` | **不恢复** | 保留文档、脚本、证书与制品 |
| `cp01` / `cp02` / `cp03` | 恢复 | 恢复到第二章结束状态 |
| `wk-app01` / `wk-app02` / `wk-edge01` / `wk-obs01` | 恢复 | 恢复到第二章结束状态 |
| `harbor` | **不恢复** | Harbor 数据持久保留，镜像推送为幂等操作 |
| `VyOS` | 保持 | 本章不继续改动 `VyOS` |

## 版本冻结

- Kubernetes：`v1.33.9`
- Cilium：`1.19.1`
- MetalLB：`v0.15.3`
- Gateway API 标准 CRD：`v1.4.1`
- 域名后缀：`qytk8s.com`
- 业务演示域名：`app.qytk8s.com`
- 业务演示 VIP：`10.1.1.60`

## 关键设计冻结

- API 平面继续走 `lb01/lb02 + 10.1.1.10`
- 业务平面改走 `MetalLB VIP`
- 第三章主线只讲 `Gateway API`，不再把 `Ingress` 作为并行主线
- HTTPS 统一由 `Harbor CA` 签发并校验

## 下一步

先进入第 1 步，准备第三章所需制品：

- `docs/02_prepare_north_south_artifacts.md`
