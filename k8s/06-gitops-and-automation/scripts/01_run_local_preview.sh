#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：01_run_local_preview.sh
# 适用场景：第六章第一阶段，启动 QYTANG NetDevOps 本地预览
# 执行位置：ops 节点
# ==============================================================================

APP_DIR="/docker_k8s_2026/apps/qytang-netdevops"
DATA_DIR="${APP_DIR}/data"
DB_URL="sqlite:///${DATA_DIR}/netdevops.db"
LOG_DIR="/tmp/qytang_netdevops_local"

stop_existing_processes() {
  pkill -f 'frontend/server.py' || true
  pkill -f 'backend.device_service.main:app' || true
  pkill -f 'backend.resource_service.main:app' || true
  pkill -f 'backend.audit_service.main:app' || true
}

start_service() {
  local name="$1"
  local extra_seed="${2:-false}"
  shift 2
  nohup setsid env \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH="${APP_DIR}" \
    QYTANG_AUTO_SEED="${extra_seed}" \
    QYTANG_NETDEVOPS_DB_URL="${DB_URL}" \
    QYTANG_RESOURCE_SERVICE_URL="http://127.0.0.1:8002" \
    QYTANG_AUDIT_SERVICE_URL="http://127.0.0.1:8003" \
    QYTANG_DEVICE_PROXY_URL="http://127.0.0.1:8001/" \
    QYTANG_RESOURCE_PROXY_URL="http://127.0.0.1:8002/" \
    QYTANG_AUDIT_PROXY_URL="http://127.0.0.1:8003/" \
    QYTANG_FRONTEND_HOST="0.0.0.0" \
    QYTANG_FRONTEND_PORT="8080" \
    "$@" >"${LOG_DIR}/${name}.log" 2>&1 </dev/null &
}

wait_for_local_preview() {
  local attempts=20
  local i

  for i in $(seq 1 "${attempts}"); do
    if curl -s --max-time 3 http://127.0.0.1:8080 >/dev/null 2>&1 && \
       curl -s --max-time 3 http://127.0.0.1:8001/healthz >/dev/null 2>&1 && \
       curl -s --max-time 3 http://127.0.0.1:8002/healthz >/dev/null 2>&1 && \
       curl -s --max-time 3 http://127.0.0.1:8003/healthz >/dev/null 2>&1; then
      echo "本地预览已就绪"
      return 0
    fi
    echo "等待本地预览就绪（第 ${i}/${attempts} 次）..."
    sleep 2
  done

  echo "失败: 本地预览未在预期时间内就绪"
  echo "请检查日志: /tmp/qytang_netdevops_local.log"
  return 1
}

start_local_preview() {
  mkdir -p "${DATA_DIR}" "${LOG_DIR}"
  stop_existing_processes

  start_service device-service \
    true \
    "${APP_DIR}/.venv/bin/python" -m uvicorn backend.device_service.main:app --host 0.0.0.0 --port 8001
  start_service resource-service \
    false \
    "${APP_DIR}/.venv/bin/python" -m uvicorn backend.resource_service.main:app --host 0.0.0.0 --port 8002
  start_service audit-service \
    false \
    "${APP_DIR}/.venv/bin/python" -m uvicorn backend.audit_service.main:app --host 0.0.0.0 --port 8003
  start_service frontend \
    false \
    "${APP_DIR}/.venv/bin/python" "${APP_DIR}/frontend/server.py"
}

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
    echo "未找到 .venv，正在创建并安装依赖..."
    if ! python3 -m venv "${APP_DIR}/.venv" 2>/dev/null; then
      echo "需要安装 python3-venv，执行: apt install -y python3-venv"
      apt install -y python3-venv
      rm -rf "${APP_DIR}/.venv"
      python3 -m venv "${APP_DIR}/.venv"
    fi
  fi
  echo "同步 Python 依赖..."
  "${APP_DIR}/.venv/bin/pip" install -q -r "${APP_DIR}/requirements.txt"
  echo "虚拟环境已就绪"

  echo "[3/4] 检查已有进程"
  pgrep -af "qytang-netdevops|backend.*uvicorn|frontend/server.py" || true

  echo "[4/4] 启动或保持本地预览"
  if curl -s http://127.0.0.1:8080 >/dev/null 2>&1 && \
     curl -s http://127.0.0.1:8001/healthz >/dev/null 2>&1; then
    echo "本地预览已在运行，无需重复启动"
  else
    start_local_preview
    echo "已后台启动，日志目录：${LOG_DIR}"
    wait_for_local_preview
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
