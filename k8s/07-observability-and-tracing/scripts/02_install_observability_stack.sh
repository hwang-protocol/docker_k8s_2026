#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：02_install_observability_stack.sh
# 适用场景：第七章第 2 步，安装 Prometheus、Grafana、Jaeger 与 OTel Collector
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/07-observability-and-tracing"
MANIFESTS_DIR="${CHAPTER_DIR}/manifests"
ARTIFACTS_DIR="${CHAPTER_DIR}/artifacts/grafana"
CHAPTER6_DIR="/docker_k8s_2026/k8s/06-gitops-and-automation"

MONITORING_NS="monitoring"
OBS_NS="observability"
GATEWAY_NS="gateway-demo"
APP_NS="qytang-netdevops"

PROM_RELEASE="kps"
JAEGER_RELEASE="jaeger"
OTEL_RELEASE="otel"

PROM_VALUES="${MANIFESTS_DIR}/01_kube_prometheus_stack_values.yaml"
JAEGER_VALUES="${MANIFESTS_DIR}/02_jaeger_values.yaml"
OTEL_VALUES="${MANIFESTS_DIR}/03_otel_collector_values.yaml"
SERVICE_MONITOR_FILE="${MANIFESTS_DIR}/10_qytang_netdevops_servicemonitor.yaml"
LISTENERS_FILE="${MANIFESTS_DIR}/20_gateway_observability_listeners.json"
GATEWAY_FILE="${MANIFESTS_DIR}/21_gateway_observability_https.yaml"

GRAFANA_DOMAIN="grafana.qytk8s.com"
GRAFANA_VIP="10.1.1.60"
TLS_SECRET_NAME="grafana-qytk8s-com-tls"
JAEGER_DOMAIN="jaeger.qytk8s.com"
JAEGER_VIP="10.1.1.60"
JAEGER_TLS_SECRET_NAME="jaeger-qytk8s-com-tls"
APP_IMAGE_TAG="v0.2.3"
GATEWAY_SERVICE="cilium-gateway-app-gateway"

CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
CA_KEY="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.key"
PKI_DIR="${CHAPTER_DIR}/pki"

install_helm() {
  if command -v helm &>/dev/null; then
    echo "Helm 已安装: $(helm version --short)"
    return 0
  fi

  echo "正在安装 Helm …"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  helm version --short
}

prepare_helm_repos() {
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo add jaegertracing https://jaegertracing.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1
}

prepare_namespaces() {
  kubectl create namespace "${MONITORING_NS}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl create namespace "${OBS_NS}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl create namespace "${GATEWAY_NS}" --dry-run=client -o yaml | kubectl apply -f -
}

prepare_local_pki() {
  mkdir -p "${PKI_DIR}"
}

generate_domain_cert() {
  local domain="$1"
  local key_file="${PKI_DIR}/${domain}.key"
  local csr_file="${PKI_DIR}/${domain}.csr"
  local cert_file="${PKI_DIR}/${domain}.crt"
  local ext_file="${PKI_DIR}/${domain}.ext"

  cat >"${ext_file}" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${domain}
EOF

  openssl genrsa -out "${key_file}" 4096
  openssl req -new -sha256 \
    -key "${key_file}" \
    -out "${csr_file}" \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=QYT/OU=K8S/CN=${domain}"

  openssl x509 -req -sha256 \
    -in "${csr_file}" \
    -CA "${CA_CERT}" \
    -CAkey "${CA_KEY}" \
    -CAcreateserial \
    -out "${cert_file}" \
    -days 3650 \
    -extfile "${ext_file}"
}

create_tls_secret() {
  local secret_name="$1"
  local domain="$2"

  kubectl -n "${GATEWAY_NS}" create secret tls "${secret_name}" \
    --cert "${PKI_DIR}/${domain}.crt" \
    --key "${PKI_DIR}/${domain}.key" \
    --dry-run=client -o yaml | kubectl apply -f -
}

install_prometheus_stack() {
  helm upgrade --install "${PROM_RELEASE}" prometheus-community/kube-prometheus-stack \
    --namespace "${MONITORING_NS}" \
    --create-namespace \
    -f "${PROM_VALUES}" \
    --wait
}

cleanup_legacy_tempo() {
  if helm -n "${OBS_NS}" status tempo >/dev/null 2>&1; then
    helm -n "${OBS_NS}" uninstall tempo
  fi
}

install_jaeger() {
  helm upgrade --install "${JAEGER_RELEASE}" jaegertracing/jaeger \
    --namespace "${OBS_NS}" \
    --create-namespace \
    -f "${JAEGER_VALUES}" \
    --wait
}

install_otel_collector() {
  helm upgrade --install "${OTEL_RELEASE}" open-telemetry/opentelemetry-collector \
    --namespace "${OBS_NS}" \
    --create-namespace \
    -f "${OTEL_VALUES}" \
    --wait
}

apply_service_monitor() {
  kubectl apply -f "${SERVICE_MONITOR_FILE}"
}

apply_gateway() {
  upsert_gateway_listeners
  kubectl apply -f "${GATEWAY_FILE}"
}

label_gateway_endpointslice() {
  local attempts=30
  local slice_name=""
  local i

  for i in $(seq 1 "${attempts}"); do
    slice_name=$(kubectl -n "${GATEWAY_NS}" get endpointslice -l io.cilium.gateway/owning-gateway=app-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -n "${slice_name}" ]]; then
      kubectl -n "${GATEWAY_NS}" label endpointslice "${slice_name}" \
        kubernetes.io/service-name="${GATEWAY_SERVICE}" --overwrite
      echo "已为 EndpointSlice ${slice_name} 补充 kubernetes.io/service-name label"
      return 0
    fi
    echo "等待 Gateway EndpointSlice 生成（第 ${i}/${attempts} 次）…"
    sleep 3
  done

  echo "失败: 未找到 Gateway 对应的 EndpointSlice"
  kubectl get endpointslice -n "${GATEWAY_NS}" || true
  return 1
}

upsert_gateway_listeners() {
  python3 - "${LISTENERS_FILE}" <<'PY'
import json
import subprocess
import sys

listeners_path = sys.argv[1]
with open(listeners_path, "r", encoding="utf-8") as fh:
    desired = json.load(fh)
desired_by_name = {item["name"]: item for item in desired}

raw = subprocess.check_output(
    ["kubectl", "get", "gateway", "-n", "gateway-demo", "app-gateway", "-o", "json"],
    text=True,
)
obj = json.loads(raw)
listeners = obj["spec"].get("listeners", [])
new_listeners = []
seen = set()

for item in listeners:
    name = item.get("name")
    if name in desired_by_name:
        new_listeners.append(desired_by_name[name])
        seen.add(name)
    else:
        new_listeners.append(item)

for item in desired:
    if item["name"] not in seen:
        new_listeners.append(item)

if listeners == new_listeners:
    print("Observability listeners 已存在，无需更新 app-gateway")
    sys.exit(0)

obj["spec"]["listeners"] = new_listeners
meta = obj["metadata"]
for key in ["creationTimestamp", "generation", "resourceVersion", "uid", "managedFields"]:
    meta.pop(key, None)
obj.pop("status", None)

subprocess.run(
    ["kubectl", "replace", "-f", "-"],
    input=json.dumps(obj),
    text=True,
    check=True,
)
print("已将 Observability listeners 增量注入 app-gateway，现有其他 listeners 保持不变")
PY
}

apply_dashboard_configmap() {
  local configmap_name="$1"
  local source_file="$2"

  kubectl -n "${MONITORING_NS}" create configmap "${configmap_name}" \
    --from-file="$(basename "${source_file}")=${source_file}" \
    --dry-run=client -o yaml \
    | kubectl label --local -f - grafana_dashboard=1 app.kubernetes.io/part-of=qytang-observability -o yaml \
    | kubectl apply -f -
}

apply_dashboards() {
  apply_dashboard_configmap grafana-dashboard-qytang-overview \
    "${ARTIFACTS_DIR}/dashboards/qytang-netdevops-overview.json"
  apply_dashboard_configmap grafana-dashboard-k8s-overview \
    "${ARTIFACTS_DIR}/dashboards/k8s-platform-overview.json"
  apply_dashboard_configmap grafana-dashboard-trace-overview \
    "${ARTIFACTS_DIR}/dashboards/qytang-trace-overview.json"
}

wait_for_https_endpoint() {
  local domain="$1"
  local vip="$2"
  local path="$3"
  local attempts=30
  local i

  for i in $(seq 1 "${attempts}"); do
    if curl --resolve "${domain}:443:${vip}" \
      --cacert "${CA_CERT}" \
      -I -s "https://${domain}${path}" >/dev/null 2>&1; then
      echo "HTTPS 入口已就绪：https://${domain}"
      return 0
    fi
    echo "等待 ${domain} 入口就绪（第 ${i}/${attempts} 次）…"
    sleep 5
  done

  echo "失败: ${domain} 入口未在预期时间内就绪"
  kubectl -n "${GATEWAY_NS}" get gateway,httproute,svc || true
  return 1
}

release_observability_app() {
  echo "同步最新应用源码到 Gitea …"
  bash "${CHAPTER6_DIR}/scripts/10_push_qytang_netdevops_repo.sh"

  echo "构建并推送启用可观测能力的新镜像 …"
  IMAGE_TAG="${APP_IMAGE_TAG}" bash "${CHAPTER6_DIR}/scripts/11_build_and_push_images_remote.sh"

  echo "等待业务 Deployment 滚动完成 …"
  kubectl -n "${APP_NS}" rollout status deploy/frontend --timeout=600s
  kubectl -n "${APP_NS}" rollout status deploy/device-service --timeout=600s
  kubectl -n "${APP_NS}" rollout status deploy/resource-service --timeout=600s
  kubectl -n "${APP_NS}" rollout status deploy/audit-service --timeout=600s
}

main() {
  echo "========================================================="
  echo "开始安装第七章可观测性栈"
  echo "Grafana 域名：${GRAFANA_DOMAIN}"
  echo "Jaeger 域名：${JAEGER_DOMAIN}"
  echo "========================================================="

  echo "[0/11] 集群连通性检查与恢复"
  bash "${CHAPTER_DIR}/scripts/00_check_and_recover_cluster.sh"

  echo "[1/11] 安装 Helm（如未安装）"
  install_helm

  echo "[2/11] 准备 Helm 仓库"
  prepare_helm_repos

  echo "[3/11] 发布启用可观测能力的新应用版本"
  release_observability_app

  echo "[4/11] 准备命名空间"
  prepare_namespaces

  echo "[5/11] 生成 Grafana 与 Jaeger 正式域名证书"
  prepare_local_pki
  generate_domain_cert "${GRAFANA_DOMAIN}"
  generate_domain_cert "${JAEGER_DOMAIN}"
  create_tls_secret "${TLS_SECRET_NAME}" "${GRAFANA_DOMAIN}"
  create_tls_secret "${JAEGER_TLS_SECRET_NAME}" "${JAEGER_DOMAIN}"

  echo "[6/11] 安装 kube-prometheus-stack"
  install_prometheus_stack

  echo "[7/11] 安装 Jaeger"
  cleanup_legacy_tempo
  install_jaeger

  echo "[8/11] 安装 OpenTelemetry Collector"
  install_otel_collector

  echo "[9/11] 应用 ServiceMonitor 与 Grafana Gateway"
  apply_service_monitor
  apply_gateway

  echo "[9.5/11] 处理 Cilium Gateway 与 MetalLB 的 EndpointSlice 兼容标签"
  label_gateway_endpointslice

  echo "[10/11] 下发 Grafana 自定义大盘"
  apply_dashboards

  echo "[11/11] 等待 Grafana 与 Jaeger 正式入口就绪"
  wait_for_https_endpoint "${GRAFANA_DOMAIN}" "${GRAFANA_VIP}" "/login"
  wait_for_https_endpoint "${JAEGER_DOMAIN}" "${JAEGER_VIP}" "/"

  echo "Grafana 地址: https://${GRAFANA_DOMAIN}"
  echo "Jaeger 地址: https://${JAEGER_DOMAIN}"
  echo "Grafana 默认用户名: admin"
  echo "Grafana 默认密码: Cisc0123"
  echo "验证命令:"
  echo "curl --resolve ${GRAFANA_DOMAIN}:443:${GRAFANA_VIP} --cacert ${CA_CERT} https://${GRAFANA_DOMAIN}/login -I"
  echo "curl --resolve ${JAEGER_DOMAIN}:443:${JAEGER_VIP} --cacert ${CA_CERT} https://${JAEGER_DOMAIN}/ -I"
  echo "OK: 第七章可观测性栈安装完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
