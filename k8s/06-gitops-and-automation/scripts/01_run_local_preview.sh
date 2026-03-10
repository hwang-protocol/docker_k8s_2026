#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：01_run_local_preview.sh
# 适用场景：第六章第一阶段，启动 QYTANG NetDevOps 本地预览
# 执行位置：ops 节点
# ==============================================================================

APP_DIR="/docker_k8s_2026/apps/qytang-netdevops"

main() {
  echo "========================================================="
  echo "启动 QYTANG NetDevOps 本地预览"
  echo "========================================================="

  if [[ ! -d "${APP_DIR}" ]]; then
    echo "失败: 应用目录不存在: ${APP_DIR}"
    return 1
  fi

  echo "[1/4] 进入应用目录"
  cd "${APP_DIR}"

  echo "[2/4] 检查虚拟环境"
  if [[ ! -x "${APP_DIR}/.venv/bin/python" ]]; then
    echo "失败: 未找到虚拟环境，请先在 ${APP_DIR} 下准备 .venv"
    return 1
  fi

  echo "[3/4] 检查已有进程"
  pgrep -af "qytang-netdevops|backend.*uvicorn|frontend/server.py" || true

  echo "[4/4] 启动或保持本地预览"
  if curl -s http://127.0.0.1:8080 >/dev/null 2>&1 && \
     curl -s http://127.0.0.1:8001/healthz >/dev/null 2>&1; then
    echo "本地预览已在运行，无需重复启动"
  else
    nohup "${APP_DIR}/.venv/bin/python" "${APP_DIR}/scripts/run_local_stack.py" >/tmp/qytang_netdevops_local.log 2>&1 &
    sleep 5
    echo "已后台启动，日志文件：/tmp/qytang_netdevops_local.log"
  fi

  echo
  echo "Win2019 访问地址："
  echo "  http://10.1.1.201:8080"
  echo
  echo "API 文档地址："
  echo "  http://10.1.1.201:8001/docs"
  echo "  http://10.1.1.201:8002/docs"
  echo "  http://10.1.1.201:8003/docs"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
