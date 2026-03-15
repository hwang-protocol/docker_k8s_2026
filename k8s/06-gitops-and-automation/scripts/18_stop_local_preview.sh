#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：18_stop_local_preview.sh
# 适用场景：停止第六章本地预览进程
# 执行位置：ops 节点
# ==============================================================================

stop_existing_processes() {
  pkill -f 'frontend/server.py' || true
  pkill -f 'backend.device_service.main:app' || true
  pkill -f 'backend.resource_service.main:app' || true
  pkill -f 'backend.audit_service.main:app' || true
}

main() {
  echo "========================================================="
  echo "停止 QYTANG NetDevOps 本地预览"
  echo "========================================================="

  echo "[1/2] 停止本地预览相关进程"
  stop_existing_processes

  echo "[2/2] 检查是否仍有残留进程"
  if pgrep -af "qytang-netdevops|backend.*uvicorn|frontend/server.py" >/dev/null 2>&1; then
    echo "WARNING: 仍检测到残留进程，请手工检查："
    pgrep -af "qytang-netdevops|backend.*uvicorn|frontend/server.py" || true
  else
    echo "OK: 本地预览进程已停止"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
