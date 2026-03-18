# 本步目标

- 理解 **容器与系统服务的相似性**：二者都围绕一个**主进程**运行，主进程一旦结束，服务或容器都会停止。
- 能够通过一键脚本在宿主机上安装并运行 `qyt_error.service`，观察主进程退出后服务停止；可选地以同一 `app.py` 在容器内对照。

# 问题背景

systemd 服务与 Docker 容器在**主进程决定生命周期**上一致：

- **systemd**：`ExecStart` 拉起的进程链的主进程退出后，单元即停止（未配置 `Restart=` 时进入 failed/dead）。
- **Docker**：容器内 **PID 1** 即主进程，其退出则容器退出。

本示例用同一份 `app.py`（`i` 递减至除零崩溃）分别以**系统服务**与**容器**运行，对照“主进程结束则二者都停”。

# 理论说明

- 查 systemd：关注 **`ExecStart` 实际执行的进程**（本例为 `python3 app.py`）退出后，`systemctl status` 是否变为 failed、日志是否记录异常。
- 查容器：关注 **镜像 `CMD` / `ENTRYPOINT`** 对应的进程是否为 PID 1，其退出后容器是否 Exited。

二者运行同一逻辑，便于对照行为。

# 验证方法

**顺序**：步骤 1 安装并启动服务 → 步骤 2、3 查看状态与日志（无严格先后，若要看运行中的倒数打印，宜在步骤 1 完成后尽快执行步骤 3）→ 步骤 4 可选，容器对照。

1. **安装并启动 systemd 服务**  
   在章节目录下执行（需 sudo）：
   ```bash
   cd /docker_k8s_2026/docker/docker_0_intro/diff_service_and_container
   sudo bash deploy_and_start_service.sh
   ```

   **说明（读懂步骤 1 可对照下列原文，执行仅需上方两条命令）**——仓库内 `qyt_error.service` 关键段落：

   ```ini
   [Service]
   User=root
   ExecStart=/usr/bin/bash -c 'cd /docker_compose_swarm/docker_0_basic/diff_service_and_container; python3 app.py'
   ```

   - **`[Service]`**：运行期段；本例未设 `Restart=`，主进程退出后单元失败，不会自动重启。
   - **`ExecStart`**：`bash -c` 内 `cd` 后执行 `python3 app.py`；`cd` 路径为占位，由安装脚本替换为脚本所在目录。
   - **`User=root`**：演示用；生产环境宜使用专用用户。

   **`deploy_and_start_service.sh` 关键段落**：

   ```bash
   set -e
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   SERVICE_NAME="qyt_error.service"
   UNIT_DEST="/etc/systemd/system/${SERVICE_NAME}"

   sed "s|cd [^;]*;|cd ${SCRIPT_DIR};|g" "${SCRIPT_DIR}/qyt_error.service" | sudo tee "${UNIT_DEST}" > /dev/null
   sudo systemctl daemon-reload
   sudo systemctl start "${SERVICE_NAME}"
   ```

   - **`set -e`**：任一步失败即中止，避免单元未写好仍 `start`。
   - **`SCRIPT_DIR`**：脚本所在目录绝对路径，保证找到同目录的 `app.py`。
   - **`sed … | tee`**：把 `ExecStart` 里第一段 `cd …;` 换成 `cd ${SCRIPT_DIR};` 后写入 `/etc/systemd/system/`。
   - **`daemon-reload` + `start`**：加载单元并启动，主进程即 `python3 app.py`。

2. **查看服务状态**（步骤 1 完成后执行，命令结束即返回 shell）  
   ```bash
   systemctl status qyt_error.service
   ```
   可看是否 `active (running)`、主进程 PID、退出后是否 failed。

3. **查看服务日志**（步骤 1 完成后执行；与步骤 2 无先后）  
   ```bash
   journalctl -u qyt_error.service -f
   ```
   按 `Ctrl+C` 结束跟随。主进程除零退出后服务失败，`status` 为 failed，日志中可见倒数打印与 `ZeroDivisionError`。

4. **（可选）容器对照**  
   仍在步骤 1 同一目录：
   ```bash
   docker build -t qyt-error-app .
   docker run --rm qyt-error-app
   ```
   前台运行可直观看 stdout；`--rm` 退出后删容器。主进程除零退出后容器退出，与 systemd 侧对照：**主进程结束则服务/容器都停**。

# 预期结果

- 步骤 1 后短期内 `qyt_error.service` 可为 `active (running)`；`journalctl -u qyt_error.service -f` 可见 19、18、17… 类输出。
- `i` 到 0 触发 `ZeroDivisionError` 后，服务 **failed**，容器（若执行步骤 4）**退出**。

# 通过标准

- 一键脚本完成：写单元、`daemon-reload`、`start`。
- 能观察到主进程退出后：服务 failed、（可选）容器 Exited。
- 能说明：服务与容器均依赖主进程，主进程结束则停止。
