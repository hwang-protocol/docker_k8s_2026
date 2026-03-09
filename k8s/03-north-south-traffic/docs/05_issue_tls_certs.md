# 第 4 步：复用 Harbor CA 签发北向 HTTPS 证书

## 本步目标

使用第一章已经生成的 `Harbor CA`，为第三章业务域名 `app.qytk8s.com` 签发服务端证书，并导入 Kubernetes。

## 为什么这一步放在这里

从第三章开始，我们明确冻结一个原则：

> 以后给学员演示外部访问时，尽量统一走 `域名 + HTTPS`。

因此这里不再临时用：

- `NodeIP:NodePort`
- 浏览器直接点 `http://IP`
- 自签一个完全脱离课程主线的临时证书

而是直接把证书体系纳入课程主线。

## 本步脚本

- `k8s/03-north-south-traffic/scripts/04_issue_tls_certs.sh`

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/03-north-south-traffic/scripts/04_issue_tls_certs.sh
```

```bash
bash /docker_k8s_2026/k8s/03-north-south-traffic/scripts/04_issue_tls_certs.sh
```

## 这一步做了什么

脚本会：

1. 读取第一章保留下来的 `harbor-ca.key` 和 `harbor-ca.crt`
2. 为 `app.qytk8s.com` 生成服务端私钥、CSR 和证书
3. 在 `gateway-demo` 命名空间中创建 `TLS Secret`

## 执行后的检查

```bash
ls -lh /docker_k8s_2026/k8s/03-north-south-traffic/pki/
```

```bash
kubectl get secret -n gateway-demo app-qytk8s-com-tls
```

预期：

- 本地生成了 `app.qytk8s.com.crt`
- 本地生成了 `app.qytk8s.com.key`
- 集群里存在 `app-qytk8s-com-tls`

## win2019 额外动作

为了让浏览器真正信任这个证书，你需要把下面这个文件导入 `win2019` 的“受信任的根证书颁发机构”：

```text
/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt
```

## 本步完成标准

- 域名证书已签发
- Kubernetes TLS Secret 已准备好
- `win2019` 已导入 Harbor CA 根证书

## 下一步

进入第 5 步，正式发布 Gateway API HTTPS 演示应用：

- `docs/06_publish_gateway_demo.md`
