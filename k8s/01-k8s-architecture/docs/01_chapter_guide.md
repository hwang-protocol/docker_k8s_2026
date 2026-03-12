# 第一章总览：Kubernetes 基础架构

## 本章目标

本章的目标不是立刻把所有云原生组件一次性装完，而是先完成一套 **Kubernetes 高可用基础架构**。

本章结束后，应该达到下面的状态：

- `harbor` 已经部署完成
- `lb01` 和 `lb02` 已经提供 `api.qytk8s.com` 的高可用入口
- `cp01`、`cp02`、`cp03` 已组成 3 控制平面集群
- `wk-app01`、`wk-app02`、`wk-edge01`、`wk-obs01` 已加入集群
- 所有 Kubernetes 基础镜像优先从本地 Harbor 获取
- 因为本章暂时**还不安装 CNI**，所以节点最终出现 `NotReady` 是正常现象

## 本章学习方式

这一章采用“**文档主导 + 小脚本辅助**”的方式进行。

也就是说：

1. 你只需要登录 `ops`
2. 按文档顺序一段一段复制命令
3. 每执行一步，都先验证，再继续下一步
4. 如果某一步命令较多，就调用一个小型 Bash 脚本

## 执行标记说明

为了便于你在 `ops` 上直接“贴贴贴”，本章对每个脚本都做执行标记：

- **必须执行**：本轮从第一章重新开始时，默认需要实际执行
- **只读验证**：这一项主要用于检查结果，不会改配置

## 本章脚本执行矩阵

| 步骤 | 文档 | 脚本 | 执行标记 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `02_prepare_os.md` | `scripts/01_prepare_os_remote.sh` | 必须执行 | 在所有 Ubuntu 节点完成系统初始化 |
| 2 | `03_harbor.md` | `scripts/02_install_harbor_remote.sh` | 必须执行 | 部署本课程统一使用的 Harbor 私有镜像仓库 |
| 3 | `04_push_k8s_images.md` | `scripts/03_push_k8s_images_remote.sh` | 必须执行 | 将 Kubernetes 基础镜像推送到 Harbor 的 `k8s` 项目 |
| 4 | `05_loadbalancer.md` | `scripts/04_setup_haproxy_keepalived_remote.sh` | 必须执行 | 需要为控制平面准备统一 VIP 入口 |
| 5 | `06_containerd.md` | `scripts/05_install_containerd_remote.sh` | 必须执行 | 所有 K8s 节点都需要 containerd |
| 6 | `07_containerd_harbor.md` | `scripts/06_config_containerd_harbor_remote.sh` | 必须执行 | 让 containerd 信任 Harbor，并切换 pause 镜像 |
| 7 | `08_kube_tools.md` | `scripts/07_install_kube_tools_remote.sh` | 必须执行 | 安装 kubeadm、kubelet、kubectl |
| 8 | `09_kubeadm_init.md` | `scripts/08_kubeadm_init_remote.sh` | 必须执行 | 初始化第一个控制平面 `cp01` |
| 9 | `10_join_control_planes.md` | `scripts/09_join_control_planes_remote.sh` | 必须执行 | 把 `cp02`、`cp03` 加入控制平面 |
| 10 | `11_join_workers.md` | `scripts/10_join_workers_remote.sh` | 必须执行 | 加入 4 台 Worker，并打标签 |
| 11 | `12_verify.md` | 无 | 只读验证 | 本章最终验收，不改配置 |

## 本章执行顺序

请严格按照下面顺序执行：

1. `02_prepare_os.md`
2. `03_harbor.md`
3. `04_push_k8s_images.md`
4. `05_loadbalancer.md`
5. `06_containerd.md`
6. `07_containerd_harbor.md`
7. `08_kube_tools.md`
8. `09_kubeadm_init.md`
9. `10_join_control_planes.md`
10. `11_join_workers.md`
11. `12_verify.md`

## 课程文件 HTTP 服务

`ops` 节点上运行了一个 nginx 服务，将课程中所有 YAML 清单文件通过 HTTP 发布。

### 服务参数

- 服务地址：`http://ops:9000/`
- 根目录：`/docker_k8s_2026/k8s/`
- 每一章的 YAML 文件统一放在该章的 `manifests/` 目录下

### 安装方式

如果 `ops` 上还没有安装 nginx，执行以下命令：

```bash
apt-get update -y && apt-get install -y nginx
```

写入配置文件：

```bash
cat > /etc/nginx/sites-available/k8s-manifests <<'EOF'
server {
    listen 9000;
    server_name _;

    root /docker_k8s_2026/k8s;
    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
```

启用站点并重启 nginx：

```bash
ln -sf /etc/nginx/sites-available/k8s-manifests /etc/nginx/sites-enabled/k8s-manifests
nginx -t && systemctl restart nginx && systemctl enable nginx
```

### 验证

```bash
curl -s http://ops:9000/01-k8s-architecture/manifests/kubeadm-init-cp01.yaml | head -5
```

预期：

- 能看到 YAML 文件内容的前几行

### 使用方式

- 需要查看 YAML：浏览器访问 `http://ops:9000/` 或查看 `manifests/` 目录
- 脚本中需要下载 YAML：使用 `curl -fsSL http://ops:9000/...`
- 后续 `kubectl apply -f`：直接引用 HTTP 地址

## 版本冻结

为了确保课程的可复现性和后续章节的兼容性，本课程统一冻结以下版本：

- Kubernetes：`v1.33.9`

本章以及后续章节都统一按这个版本编写，不再变动。
