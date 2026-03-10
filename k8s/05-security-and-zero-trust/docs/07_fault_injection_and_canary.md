# 第 6 步：高级场景说明 - 灰度、超时、重试与故障注入

## 本步目标

这一节不再继续铺基础环境，而是专门解释第五章后半段最有“课堂效果”的几个高级场景：

- 50/50 权重路由
- 90/10 灰度发布
- 超时
- 重试
- 延迟注入
- `503` 中断注入

这些场景都不建议直接写死进基线环境，而是通过 `manual_tests/` 中的脚本临时切换和观察。

## 为什么这一节要单独拆出来

如果把故障注入、50/50 路由、90/10 灰度都直接放进“一把梭”环境里，会带来两个问题：

1. 课堂基线状态不稳定
2. 学员看不到“修改前”和“修改后”的对比

因此第五章采用下面的方式：

- 自动化脚本先把稳定基线环境铺好
- 课堂上再用短脚本切换到高级场景
- 讲完后用 `manual_tests/99_reset_baseline.sh` 恢复基线

## 功能单元划分

本节建议拆成 6 个治理主题依次说明：

1. `subset`
2. `50/50` 权重路由
3. `90/10` 灰度发布
4. `timeout`
5. `retry`
6. `fault injection`

每个主题均采用统一结构：

1. 问题背景
2. 理论说明
3. 验证方法
4. 预期结果

## 7.1 subset

### 问题背景

如果目标服务没有版本子集，后续无法描述“把多少流量发给哪个版本”。

### 理论说明

`subset` 是灰度与版本治理的基础抽象。  
只有在 `DestinationRule` 中先建立 `v1`、`v2` 这样的子集定义，后续 `VirtualService` 才能进行权重分流。

### 验证方法

```bash
kubectl -n mesh-demo get destinationrule helloworld -o yaml
```

关键字段示意：

```yaml
spec:
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
```

关键看点：

- 看 `spec.subsets`
  - 确认存在 `v1` 与 `v2`
- 看 `subsets[].labels`
  - 确认每个子集都通过标签与具体版本工作负载对应
- 本命令主要用于验证“灰度发布的版本基础是否已经建立”

### 预期结果

- `DestinationRule` 中存在 `v1` 与 `v2` 两个子集

## 7.2 50/50 权重路由

### 问题背景

课程中需要先展示最直观的流量分流效果，使学员理解“同一个入口请求可以被动态分给不同版本”。

### 理论说明

`50/50` 是最容易观察到的权重治理场景。  
它用于说明 `VirtualService` 能够按比例将请求分发到多个 `subset`。

### 验证方法

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/04_test_weighted_routing.sh
```

### 预期结果

- 多次访问 `/hello` 后，`v1` 与 `v2` 均会出现
- 两者数量大致接近

## 7.3 90/10 灰度发布

### 问题背景

实际生产中的灰度发布通常不是平均分流，而是先给新版本很小比例流量。

### 理论说明

`90/10` 用于说明发布过程中的渐进式放量策略。  
它比 `50/50` 更接近真实生产中的 canary 发布方式。

### 验证方法

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/04_test_weighted_routing.sh
```

### 预期结果

- 大多数请求进入 `v1`
- 少量请求进入 `v2`

## 7.4 timeout

### 问题背景

如果后端响应过慢，而入口始终无限等待，调用端体验会迅速恶化。

### 理论说明

`timeout` 的作用，是为请求设置可接受的最大等待时间。  
当后端超出该时间仍未完成响应，入口将主动结束请求。

### 验证方法

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/05_test_timeout_retry.sh
```

### 预期结果

- `/delay/5` 不再等待 5 秒完整返回
- 返回结果表现为超时失败

## 7.5 retry

### 问题背景

部分失败属于瞬时失败。如果每次失败都立即返回给调用端，会造成不必要的请求失败。

### 理论说明

`retry` 用于在满足条件时自动重新尝试请求，从而提高系统对瞬时故障的容忍能力。

### 验证方法

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/05_test_timeout_retry.sh
```

### 预期结果

- 可以看到与普通失败请求不同的重试相关行为
- 文档与脚本中的时间和返回结果能够体现治理生效

## 7.6 fault injection

### 问题背景

如果不主动制造异常，就很难在课堂中稳定展示系统在故障场景下的行为。

### 理论说明

`fault injection` 用于人为制造延迟或错误码，以验证入口、上游服务和治理策略在异常场景下的表现。

### 验证方法

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/manual_tests/06_test_fault_injection.sh
```

### 预期结果

- 延迟注入时，请求耗时明显增加
- `503` 中断注入时，请求直接返回错误码

## 推荐顺序

推荐按下面顺序理解和验证：

1. 先讲 `subset`
2. 再讲 `50/50`
3. 再讲 `90/10`
4. 再讲 `timeout`
5. 再讲 `retry`
6. 最后讲 `fault injection`

## 理论总结

- 灰度和故障注入都属于“流量治理”的范畴，不是安全策略
- 安全负责“谁能访问”
- 治理负责“流量如何到达、如何表现、出问题时会怎样”

## 下一步

进入课堂手动测试清单：

- `docs/08_manual_tests.md`
