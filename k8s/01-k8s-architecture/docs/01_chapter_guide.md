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

## 版本冻结

为了确保课程的可复现性和后续章节的兼容性，本课程统一冻结以下版本：

- Kubernetes：`v1.33.9`

本章以及后续章节都统一按这个版本编写，不再变动。

## 当前阶段说明

我们现在先做 **第 1 步：所有节点系统初始化**。

对应文档：

- `docs/02_prepare_os.md`

对应脚本：

- `scripts/01_prepare_os_remote.sh`
