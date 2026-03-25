# 第 6 步：为 `wk-edge01` 启用 Longhorn 默认数据盘

## 本步目标

为已被 Longhorn 识别的 `wk-edge01` 启用默认数据盘。

---

## 执行标记

- **执行标记：必须执行**

说明：

- 这一页的重点不是“再装一次 Longhorn”
- 而是验证 Longhorn 可以在系统运行后，把一个已被识别的节点进一步补齐为带默认数据盘的可用存储节点

---

## 问题背景

这一页单独处理 `wk-edge01` 的默认数据盘，目的是把下面两件事分开看清：

- `wk-edge01` 可能早已被 Longhorn 识别成节点对象
- 但默认数据盘仍然可以在后续单独启用

---

## 理论说明

### 主线关系图

```mermaid
flowchart LR
  stage1[初始 3 节点<br/>wk-app01 wk-app02 wk-obs01]
  volume[Longhorn 卷]
  stage2[启用后<br/>wk-edge01 完成默认数据盘初始化]

  stage1 --> volume
  volume --> stage2
```

这张图强调的是：

- 第四章先把 3 节点主线跑稳
- 然后再单独展示“已识别节点也可以后续启用默认数据盘”
- 这一页仍然通过 Kubernetes 节点标签与注解完成，不在 Longhorn UI 里手工点盘

---

## 对应脚本

本步对应脚本：

- `k8s/04-storage-and-stateful/scripts/05_expand_longhorn_node.sh`

---

## 脚本关键任务

### 关键任务 1：给 `wk-edge01` 打默认磁盘标签与注解

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
kubectl label node "${TARGET_NODE}" node.longhorn.io/create-default-disk=config --overwrite
kubectl annotate node "${TARGET_NODE}" node.longhorn.io/default-disks-config="${DISK_CONFIG}" --overwrite
```

关键介绍：

- 让 `wk-edge01` 按照第四章统一路径 `/var/lib/longhorn` 创建默认数据盘

### 关键任务 2：等待 Longhorn 自动识别新节点磁盘

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

```bash
disk_path="$(kubectl -n longhorn-system get nodes.longhorn.io "${TARGET_NODE}" -o yaml 2>/dev/null \
  | awk '/path: /{print $2; exit}')"
```

关键介绍：

- 脚本会先等 Longhorn 自动识别
- 如果识别成功，这一步就结束

### 关键任务 3：必要时补充 Longhorn Node CR

脚本原始代码：

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选查看代码</strong><br/>
下面代码为脚本原始逻辑，用于理解本步实现，不需要单独执行。
</div>

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
- 但目标仍然不变：让 `wk-edge01` 成为真正带默认数据盘的 Longhorn 可调度节点

---

## 执行命令

### 1. 扩容前先看 `wk-edge01` 的关键字段

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #ea4335; border-radius: 6px; background: rgba(234,67,53,0.10); margin: 8px 0;">
<strong>❗ 本步必须粘贴执行</strong><br/>
下面命令是本步主线必跑命令，用于先看扩容前的节点状态。
</div>

```bash
kubectl -n longhorn-system get nodes.longhorn.io wk-edge01 -o yaml \
  | egrep 'allowScheduling: true|disks: \\{\\}|diskStatus: \\{\\}'
```

关键看点：

- 这一页前后真正要对比的，就是这几个关键行
- 如果此时还能看到：
  - `disks: {}`
  - `diskStatus: {}`
  - 就说明它还没有完成默认数据盘初始化

<div style="padding: 10px 14px; border: 1px solid #666; border-left: 4px solid #8ab4f8; border-radius: 6px; background: rgba(138,180,248,0.08); margin: 8px 0;">
<strong>ℹ️ 可选预处理命令</strong><br/>
如果脚本已具备执行权限，这一步可以跳过。
</div>

```bash
chmod +x /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/05_expand_longhorn_node.sh
```

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #ea4335; border-radius: 6px; background: rgba(234,67,53,0.10); margin: 8px 0;">
<strong>❗ 本步必须粘贴执行</strong><br/>
下面命令是本步主线必跑命令。
</div>

```bash
bash /docker_k8s_2026/k8s/04-storage-and-stateful/scripts/05_expand_longhorn_node.sh
```

---

## 验证方法

### 2. 扩容后再看 `wk-edge01` 的关键字段

<div style="padding: 12px 14px; border: 1px solid #666; border-left: 6px solid #ea4335; border-radius: 6px; background: rgba(234,67,53,0.10); margin: 8px 0;">
<strong>❗ 本步必须粘贴执行</strong><br/>
下面命令是本步主线必跑命令，用于确认默认数据盘已经注册成功。
</div>

```bash
kubectl -n longhorn-system get nodes.longhorn.io wk-edge01 -o yaml \
  | egrep 'allowScheduling: true|path: /var/lib/longhorn|diskPath: /var/lib/longhorn|instanceManagerName:|type: Ready|type: Schedulable|status: \"True\"'
```

关键看点：

- 这里只看下面几类关键信息：
  - `allowScheduling: true`
  - `path: /var/lib/longhorn`
  - `diskPath: /var/lib/longhorn`
  - `instanceManagerName: ...`
  - `type: Ready / Schedulable`
  - `status: "True"`
- 前后对比时，重点不是节点对象在不在
- 而是默认数据盘相关字段是否已经出现

预期结果：

- 能看到 `allowScheduling: true`
- 能看到磁盘路径 `/var/lib/longhorn`
- 能看到 `instanceManagerName`
- 能看到 `Ready` 和 `Schedulable` 两类状态都为 `True`

关键字段示意：

```yaml
spec:
  allowScheduling: true
  disks:
    default-disk-<auto-id>:
      allowScheduling: true
      path: /var/lib/longhorn
status:
  diskStatus:
    default-disk-<auto-id>:
      diskPath: /var/lib/longhorn
      instanceManagerName: instance-manager-<id>
      conditions:
        - type: Ready
          status: "True"
        - type: Schedulable
          status: "True"
```

说明：

- `default-disk-<auto-id>` 是 Longhorn 自动生成的磁盘名，不是固定字符串
- `instance-manager-<id>` 里的这一串 ID 也是运行时自动生成的，不需要记忆；这里只需确认 Longhorn 已经为这块磁盘关联到了一个 `instance-manager`
- 如果这里只看到 `disks: {}` 或 `diskStatus: {}`，说明 `wk-edge01` 虽然已经被 Longhorn 识别成节点对象，但还没有完成默认数据盘初始化
- 第 6 步脚本真正补齐的，就是把 `/var/lib/longhorn` 注册成 `wk-edge01` 的默认数据盘

---

## 通过标准

- `wk-edge01` 已完成默认数据盘初始化
- `wk-edge01` 的 Longhorn Node 对象中能够看到 `/var/lib/longhorn`

---

## 下一步

进入第 7 步，用真实 `MongoDB ReplicaSet` 案例理解 `StatefulSet`：

- `docs/08_statefulset_intro.md`
