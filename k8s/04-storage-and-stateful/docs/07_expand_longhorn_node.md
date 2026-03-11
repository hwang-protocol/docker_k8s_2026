# 第 6 步：把第 4 个节点加入 Longhorn

## 本步目标

把：

- `wk-edge01`

作为第 4 个 Longhorn 节点加入集群。

## 执行标记

- **执行标记：必须执行**

说明：

- 这一页的重点不是“再装一次 Longhorn”
- 而是验证 Longhorn 节点可以在系统运行后继续扩容

## 问题背景

如果一开始就把 4 个节点全部纳入 `Longhorn`，学员往往只能看到“装好了”。

但把第 4 个节点放到后面单独加入，会更容易讲清楚：

- Longhorn 节点不是一次性写死的
- 存储节点可以后续扩容
- Kubernetes 节点加入存储池，本质上是一个独立动作

这对理解生产中的“容量扩展”很重要。

## 理论说明

### 第 4 个节点加入前后关系图

```mermaid
flowchart LR
  stage1[初始 3 节点<br/>wk-app01 wk-app02 wk-obs01]
  volume[Longhorn 卷]
  stage2[扩容后 4 节点<br/>+ wk-edge01]

  stage1 --> volume
  volume --> stage2
```

这张图强调的是：

- 第四章先把 3 节点主线跑稳
- 然后再单独展示“存储池可以继续变大”

### 为什么这一步仍然通过节点标签和注解完成

这一节继续沿用第四章的统一风格：

- 不在 Longhorn UI 里手工点盘
- 仍然通过 Kubernetes 节点标签与注解完成

这样更适合教材化，也更方便和第 4 步安装逻辑形成对照。

## 对应脚本

本步对应脚本：

- `k8s/04-storage-and-stateful/scripts/05_expand_longhorn_node.sh`

## 脚本关键任务

### 关键任务 1：给 `wk-edge01` 打默认磁盘标签与注解

脚本原始代码：

```bash
kubectl label node "${TARGET_NODE}" node.longhorn.io/create-default-disk=config --overwrite
kubectl annotate node "${TARGET_NODE}" node.longhorn.io/default-disks-config="${DISK_CONFIG}" --overwrite
```

关键介绍：

- 让 `wk-edge01` 按照第四章统一路径 `/var/lib/longhorn` 创建默认数据盘

### 关键任务 2：等待 Longhorn 自动识别新节点磁盘

脚本原始代码：

```bash
disk_path="$(kubectl -n longhorn-system get nodes.longhorn.io "${TARGET_NODE}" -o yaml 2>/dev/null \
  | awk '/path: /{print $2; exit}')"
```

关键介绍：

- 脚本会先等 Longhorn 自动识别
- 如果识别成功，这一步就结束

### 关键任务 3：必要时补充 Longhorn Node CR

脚本原始代码：

```bash
kubectl -n longhorn-system patch nodes.longhorn.io "${TARGET_NODE}" --type merge -p '{
  "spec": {
    "allowScheduling": true,
    "disks": {
      "disk-sdb": {
        "path": "/var/lib/longhorn"
      }
    }
  }
}'
```

关键介绍：

- 如果自动识别超时，脚本会补一个更直接的 `Node CR` 配置
- 但目标仍然不变：让 `wk-edge01` 成为 Longhorn 可调度节点

## 执行命令

```bash
chmod +x /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/05_expand_longhorn_node.sh
```

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/05_expand_longhorn_node.sh
```

## 验证方法

```bash
kubectl -n longhorn-system get nodes.longhorn.io
```

关键看点：

- 重点看 Longhorn 节点数量是否已经从前面的 3 个变成 4 个
- 列表里应该新增：
  - `wk-edge01`
- 这一步最重要的是确认“扩容动作已经被 Longhorn 接住”，不是只看命令有没有执行完

预期结果：

- `nodes.longhorn.io` 列表中能看到：
  - `wk-app01`
  - `wk-app02`
  - `wk-obs01`
  - `wk-edge01`
- Longhorn 节点总数达到 4
- `wk-edge01` 处于可用、可调度状态

```bash
kubectl -n longhorn-system get nodes.longhorn.io wk-edge01 -o yaml
```

关键看点：

- 重点不是把整份 YAML 从头读到尾
- 而是只抓下面 3 类关键信息：
  - `spec.allowScheduling`
  - 磁盘路径 `/var/lib/longhorn`
  - Longhorn 是否已经在这个节点下创建出磁盘对象

预期结果：

- `spec.allowScheduling: true`
- 输出中能看到磁盘路径 `/var/lib/longhorn`
- Longhorn 已经把这块路径识别成 `wk-edge01` 的可用数据盘

通过这一组验证后，应形成下面的判断：

- `wk-edge01` 已经正式加入 Longhorn 存储池
- 第四章“先 3 节点、再扩到第 4 个节点”的主线已经完成

## 通过标准

- `wk-edge01` 已被 Longhorn 正常识别
- 集群中的 Longhorn 节点数达到 4

## 下一步

进入第 8 步，把 Longhorn UI 正式发布为 `win2019 + HTTPS + 域名` 访问方式：

- `docs/08_publish_longhorn_ui.md`
