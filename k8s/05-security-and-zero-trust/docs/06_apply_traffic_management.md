# 第 5 步：配置流量治理基线

## 本步目标

把第五章从“只讲安全”进一步推进到“安全 + 治理”。

本步会建立下面这些基线能力：

- `DestinationRule`
- `subset`
- 基线版本路由
- 负载均衡策略
- 连接池与异常实例剔除参数

## 本步脚本

- `k8s/05-security-and-zero-trust/scripts/05_apply_traffic_management.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/05_apply_traffic_management.sh
```

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/05_apply_traffic_management.sh
```

## 这一步做了什么

脚本会：

1. 对 `helloworld` 定义 `v1`、`v2` 两个 `subset`
2. 设置默认基线路由为 `100% -> v1`
3. 配置 `ROUND_ROBIN`、连接池与 `outlierDetection`
4. 保留 50/50、90/10、超时重试、故障注入等场景清单，供手动测试脚本切换

## 执行后的检查

```bash
kubectl -n mesh-demo get destinationrule,virtualservice
```

```bash
kubectl -n mesh-demo get deploy -l app=helloworld --show-labels
```

## 预期

- `DestinationRule` 已出现
- `VirtualService` 已出现
- 当前基线路由稳定指向 `v1`

## 理论讲解点

这一节建议你重点讲：

- `VirtualService` 负责“流量怎么走”
- `DestinationRule` 负责“目标怎么定义”
- `subset` 是灰度和版本治理的基础
- 课堂基线环境不直接进入 50/50 或故障注入，避免影响后续教学节奏

## 下一步

进入课堂手动测试阶段：

- `docs/08_manual_tests.md`
