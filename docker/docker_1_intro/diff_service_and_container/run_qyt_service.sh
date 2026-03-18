#!/usr/bin/env bash
# 一把梭：从任意目录运行。请将下方改为你机器上的绝对路径后，复制到任意位置执行。
PROJECT_DIR="/docker_k8s_2026/docker/docker_1_intro/diff_service_and_container"

set -e
SERVICE_NAME="qyt_error.service"
UNIT_DEST="/etc/systemd/system/${SERVICE_NAME}"
sed "s|cd [^;]*;|cd ${PROJECT_DIR};|g" "${PROJECT_DIR}/qyt_error.service" | sudo tee "${UNIT_DEST}" > /dev/null
sudo systemctl daemon-reload
sudo systemctl start "${SERVICE_NAME}"
echo "已安装并启动 ${SERVICE_NAME}，工作目录: ${PROJECT_DIR}"
echo "查看状态: systemctl status ${SERVICE_NAME}"
echo "查看日志: journalctl -u ${SERVICE_NAME} -f"
