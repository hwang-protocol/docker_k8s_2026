# 本步目标

- 理解 **容器与系统服务的相似性**：二者都围绕一个**主进程**运行，主进程一旦结束，服务或容器都会停止。
- 能够通过一键脚本在宿主机上安装并运行 `qyt_error.service`，并观察主进程退出后服务停止的现象。

# 问题背景

systemd 服务和 Docker 容器在“主进程决定生命周期”这一点上是一致的：

- **systemd 服务**：`ExecStart` 启动的是该单元的主进程；主进程退出后，该服务即视为停止（除非配置了 `Restart=` 等策略）。
- **Docker 容器**：容器内 PID 1 的进程即主进程；主进程退出后，容器即退出。

本示例用同一份 `app.py`（循环中 `i` 递减，最终除零崩溃）分别以系统服务和容器方式运行，演示“主进程结束则二者都会停止”。

# 理论说明

- **systemd 服务**：单元文件中 `ExecStart` 指定的命令即主进程；主进程退出则服务进入 failed/dead 状态。
- **Docker 容器**：镜像 `CMD`（或 `ENTRYPOINT`）指定的进程即容器主进程；主进程退出则容器退出。

两者均可运行同一 `app.py`，用于观察：主进程崩溃后，服务停止、容器退出，行为一致。

# 验证方法

1. **安装并启动 systemd 服务（一把梭）**  
   在项目目录下执行（需 root 或 sudo）：
   ```bash
   cd /docker_k8s_2026/docker/docker_0_basic/diff_service_and_container
   sudo bash deploy_and_start_service.sh
   ```
   脚本会将 `qyt_error.service` 的工作目录设为脚本所在目录、安装到 `/etc/systemd/system/`、执行 `daemon-reload` 并 `start` 服务。

2. **查看服务状态与日志**  
   ```bash
   systemctl status qyt_error.service
   journalctl -u qyt_error.service -f
   ```
   运行一段时间后，主进程因除零错误退出，**服务随之停止**（状态 failed）。

3. **（可选）以容器方式运行同一应用**  
   ```bash
   docker build -t qyt-error-app .
   docker run --rm qyt-error-app
   ```
   不加 `-d` 时容器在前台运行，终端会直接看到容器内 stdout（如 19、18、17… 及除零错误）；`--rm` 表示退出后自动删除容器。主进程因除零错误退出后，**容器随之退出**。与上一步对照可知：服务与容器都是“主进程结束则停止”。

# 预期结果

- 执行 `deploy_and_start_service.sh` 后，`qyt_error.service` 处于 `active (running)`，`journalctl` 中可见 `app.py` 的打印（19、18、17…）。
- 当 `i` 减至 0、主进程因 `ZeroDivisionError` 退出后，**服务随之停止**（状态变为 failed）。以容器方式运行同一应用时，主进程退出后**容器随之退出**。二者都说明：主进程结束则服务/容器都会停止。

# 通过标准

- 一键脚本可无交互完成：安装单元文件、reload、start。
- 能观察到主进程退出后，系统服务变为 failed、容器变为 Exited。
- 能说明容器与系统服务的相似点：都有主进程，主进程结束则都会停止。
