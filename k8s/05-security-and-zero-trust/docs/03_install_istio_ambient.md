# 第 2 步：安装 Istio Ambient 基础能力

## 本步目标

在不替换现有 `Cilium` 数据平面的前提下，为集群新增：

- `istiod`
- `ztunnel`
- `istio-cni`

本步完成后，集群具备第五章后续所需的服务身份与 `mTLS` 运行基础。

## 本步脚本

- `k8s/05-security-and-zero-trust/scripts/02_install_istio_ambient.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/02_install_istio_ambient.sh
```

```bash
bash /docker_k8s_2026/k8s/05-security-and-zero-trust/scripts/02_install_istio_ambient.sh
```

## 这一步做了什么

脚本会：

1. 自动检查并恢复集群连通性
2. 使用 `IstioOperator` 覆盖文件安装 `Ambient` Profile
3. 等待 `istiod`、`ztunnel` 和 `istio-cni` 收敛
4. 检查关键 CRD 与基础组件状态

## 执行后的检查

```bash
kubectl -n istio-system get pods -o wide
```

```bash
kubectl get crd | grep istio.io
```

```bash
istioctl version
```

## 预期

- `istiod` 为 `Running`
- `ztunnel` 在各个工作节点上正常运行
- `istio-cni` 相关组件正常

## 理论讲解点

这一节建议你重点讲：

- `Ambient` 和 sidecar 模式的差异
- `ztunnel` 为什么只负责 L4，而不是全部 L7
- 为什么第五章能在保留 `Cilium` 的前提下继续叠加 `Istio`

## 下一步

进入第 3 步，发布新的 `Istio Ingress Gateway` 与演示应用：

- `docs/04_publish_istio_ingress.md`
