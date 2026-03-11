#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：03_verify_observability.sh
# 适用场景：第七章最终验收，验证指标、Grafana 和 Jaeger Trace 基线
# 执行位置：ops 节点
# ==============================================================================

CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
GRAFANA_DOMAIN="grafana.qytk8s.com"
GRAFANA_VIP="10.1.1.60"
JAEGER_DOMAIN="jaeger.qytk8s.com"
JAEGER_VIP="10.1.1.60"
NETDEVOPS_DOMAIN="netdevops.qytk8s.com"
NETDEVOPS_VIP="10.1.1.60"

get_demo_device_id() {
  curl --resolve "${NETDEVOPS_DOMAIN}:443:${NETDEVOPS_VIP}" \
    --cacert "${CA_CERT}" \
    -s "https://${NETDEVOPS_DOMAIN}/api/device/api/v1/devices" | python3 -c '
import json
import sys

items = json.load(sys.stdin)
if not items:
    raise SystemExit("未获取到设备清单")
print(items[0]["id"])
'
}

verify_multiservice_trace() {
  local device_id="$1"
  local attempt
  for attempt in $(seq 1 10); do
    if curl --resolve "${JAEGER_DOMAIN}:443:${JAEGER_VIP}" \
      --cacert "${CA_CERT}" \
      -s "https://${JAEGER_DOMAIN}/api/traces?service=frontend&lookback=15m&limit=50" | python3 -c '
import json
import sys

device_id = sys.argv[1]
payload = json.load(sys.stdin)
required = {"frontend", "device-service", "resource-service", "audit-service"}

for trace in payload.get("data", []):
    spans = trace.get("spans", [])
    ops = [span.get("operationName", "") for span in spans]
    processes = trace.get("processes", {})
    services = {
        processes.get(span.get("processID", ""), {}).get("serviceName", "unknown")
        for span in spans
    }
    if (
        required.issubset(services)
        and any("device.get_detail.aggregate" in op for op in ops)
        and any("resource.list_device_interfaces" in op for op in ops)
        and any("audit.list_audits" in op for op in ops)
    ):
        print("Trace ID:", trace.get("traceID"))
        print("Span Count:", len(spans))
        print("Services:", ", ".join(sorted(services)))
        raise SystemExit(0)

raise SystemExit("未找到包含 frontend/device/resource/audit 的完整 Trace")
' "${device_id}"; then
      return 0
    fi
    sleep 3
  done
  return 1
}

main() {
  echo "========================================================="
  echo "验证第七章可观测性环境"
  echo "========================================================="

  echo "[1/6] 查看 monitoring 命名空间核心资源"
  kubectl get ns monitoring observability 2>/dev/null || true
  kubectl -n monitoring get pods,svc 2>/dev/null || true
  kubectl -n observability get pods,svc 2>/dev/null || true

  echo "[2/6] 查看业务 /metrics 入口"
  kubectl -n qytang-netdevops get servicemonitor,pods 2>/dev/null || true

  echo "[3/6] 查看 Prometheus Targets"
  kubectl -n monitoring get servicemonitor,prometheus 2>/dev/null || true

  echo "[4/6] 验证 Grafana 与 Jaeger 正式入口"
  curl --resolve "${GRAFANA_DOMAIN}:443:${GRAFANA_VIP}" \
    --cacert "${CA_CERT}" \
    -I -s "https://${GRAFANA_DOMAIN}/login" | sed -n '1,5p'
  curl --resolve "${JAEGER_DOMAIN}:443:${JAEGER_VIP}" \
    --cacert "${CA_CERT}" \
    -I -s "https://${JAEGER_DOMAIN}/" | sed -n '1,5p'

  echo "[5/6] 生成一轮演示流量并检查 Jaeger 服务名"
  local device_id
  device_id="$(get_demo_device_id)"
  echo "使用设备 ID: ${device_id}"
  curl --resolve "${NETDEVOPS_DOMAIN}:443:${NETDEVOPS_VIP}" \
    --cacert "${CA_CERT}" \
    -s "https://${NETDEVOPS_DOMAIN}/api/device/api/v1/dashboard/summary" >/dev/null
  curl --resolve "${NETDEVOPS_DOMAIN}:443:${NETDEVOPS_VIP}" \
    --cacert "${CA_CERT}" \
    -s "https://${NETDEVOPS_DOMAIN}/api/device/api/v1/devices/${device_id}" >/dev/null
  sleep 3
  curl --resolve "${JAEGER_DOMAIN}:443:${JAEGER_VIP}" \
    --cacert "${CA_CERT}" \
    -s "https://${JAEGER_DOMAIN}/api/services" | python3 -c 'import json,sys; services=json.load(sys.stdin).get("data", []); print("Jaeger services:", ", ".join(services[:10]))'
  verify_multiservice_trace "${device_id}"

  echo "[6/6] 输出检查建议"
  echo "1. 登录 https://${GRAFANA_DOMAIN}"
  echo "2. 查看 QYT NetDevOps 总览大盘"
  echo "3. 查看 Kubernetes 基础监控大盘"
  echo "4. 登录 https://${JAEGER_DOMAIN}"
  echo "5. 查看 Trace 瀑布图与关键 span"
  echo "OK: 第七章验收命令执行完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
