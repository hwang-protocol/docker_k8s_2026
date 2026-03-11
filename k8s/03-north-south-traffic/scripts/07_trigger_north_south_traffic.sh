#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：07_trigger_north_south_traffic.sh
# 适用场景：配合第三章第 6 步，触发北向流量，供 Hubble UI 观察
# 执行位置：ops 节点
# ==============================================================================

DOMAIN="app.qytk8s.com"
VIP="10.1.1.60"
CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"

main() {
  echo "========================================================="
  echo "开始触发第三章北向演示流量"
  echo "目标域名：${DOMAIN}"
  echo "目标 VIP：${VIP}"
  echo "========================================================="

  echo "[1/3] 触发 HTTP -> HTTPS 重定向"
  curl -I --resolve "${DOMAIN}:80:${VIP}" "http://${DOMAIN}/" || true

  echo
  echo "[2/3] 连续触发 HTTPS 业务访问"
  for i in $(seq 1 8); do
    echo "第 ${i}/8 次访问"
    curl --resolve "${DOMAIN}:443:${VIP}" --cacert "${CA_CERT}" "https://${DOMAIN}/" >/dev/null
    sleep 1
  done

  echo
  echo "[3/3] 触发完成"
  echo "OK: 已生成第三章北向演示流量"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
