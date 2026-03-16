#!/usr/bin/env bash
# 一把梭：安装 qyt_error.service 并启动（工作目录自动设为脚本所在目录）
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="qyt_error.service"
UNIT_DEST="/etc/systemd/system/${SERVICE_NAME}"

# 使用脚本所在目录作为工作目录，生成并安装单元文件
sed "s|cd [^;]*;|cd ${SCRIPT_DIR};|g" "${SCRIPT_DIR}/qyt_error.service" | sudo tee "${UNIT_DEST}" > /dev/null
sudo systemctl daemon-reload
sudo systemctl start "${SERVICE_NAME}"
echo "已安装并启动 ${SERVICE_NAME}，工作目录: ${SCRIPT_DIR}"
echo "查看状态: systemctl status ${SERVICE_NAME}"
echo "查看日志: journalctl -u ${SERVICE_NAME} -f"
