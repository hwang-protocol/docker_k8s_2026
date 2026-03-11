#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：02_verify_local_preview.sh
# 适用场景：验证 QYTANG NetDevOps 本地预览与 API
# 执行位置：ops 节点
# ==============================================================================

main() {
  echo "========================================================="
  echo "验证 QYTANG NetDevOps 本地预览"
  echo "========================================================="

  echo "[1/5] 前端页面"
  curl -s --max-time 5 -o /tmp/qytang_local_frontend.html -w 'HTTP %{http_code}\n' http://127.0.0.1:8080

  echo "[2/5] 设备服务"
  curl -s --max-time 5 http://127.0.0.1:8001/healthz
  echo

  echo "[3/5] 资源服务"
  curl -s --max-time 5 http://127.0.0.1:8002/healthz
  echo

  echo "[4/5] 审计服务"
  curl -s --max-time 5 http://127.0.0.1:8003/healthz
  echo

  echo "[5/5] Dashboard 汇总"
  curl -s --max-time 5 http://127.0.0.1:8001/api/v1/dashboard/summary
  echo

  echo "OK: 本地预览链路正常"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
