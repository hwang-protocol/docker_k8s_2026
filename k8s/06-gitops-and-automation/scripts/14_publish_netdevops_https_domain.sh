#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：14_publish_netdevops_https_domain.sh
# 适用场景：为 QYTANG NetDevOps 配置 HTTPS 域名入口
# 执行位置：ops 节点
# ==============================================================================

CHAPTER_DIR="/docker_k8s_2026/k8s/06-gitops-and-automation"
PKI_DIR="${CHAPTER_DIR}/pki/netdevops"
LISTENERS_FILE="${CHAPTER_DIR}/manifests/20_gateway_netdevops_listeners.json"
DOMAIN="netdevops.qytk8s.com"
SECRET_NAME="netdevops-qytk8s-com-tls"
SECRET_NAMESPACE="gateway-demo"
VIP="10.1.1.60"

HARBOR_CA_KEY="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.key"
HARBOR_CA_CERT="/docker_k8s_2026/k8s/01-k8s-architecture/pki/harbor/harbor-ca.crt"
MANIFEST_URL="http://ops:9000/06-gitops-and-automation/manifests/21_gateway_netdevops_https.yaml"
GATEWAY_SERVICE="cilium-gateway-app-gateway"

SERVER_KEY="${PKI_DIR}/${DOMAIN}.key"
SERVER_CSR="${PKI_DIR}/${DOMAIN}.csr"
SERVER_CERT="${PKI_DIR}/${DOMAIN}.crt"
SERVER_EXT="${PKI_DIR}/${DOMAIN}.ext"

prepare_local_dirs() {
  mkdir -p "${PKI_DIR}"
}

generate_server_cert() {
  cat >"${SERVER_EXT}" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
EOF

  openssl genrsa -out "${SERVER_KEY}" 4096
  openssl req -new -sha256 \
    -key "${SERVER_KEY}" \
    -out "${SERVER_CSR}" \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=QYT/OU=K8S/CN=${DOMAIN}"

  openssl x509 -req -sha256 \
    -in "${SERVER_CSR}" \
    -CA "${HARBOR_CA_CERT}" \
    -CAkey "${HARBOR_CA_KEY}" \
    -CAcreateserial \
    -out "${SERVER_CERT}" \
    -days 3650 \
    -extfile "${SERVER_EXT}"
}

create_tls_secret() {
  kubectl -n "${SECRET_NAMESPACE}" create secret tls "${SECRET_NAME}" \
    --cert "${SERVER_CERT}" \
    --key "${SERVER_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

label_gateway_endpointslice() {
  local attempts=30
  local slice_name=""
  local i

  for i in $(seq 1 "${attempts}"); do
    slice_name=$(kubectl -n gateway-demo get endpointslice -l io.cilium.gateway/owning-gateway=app-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -n "${slice_name}" ]]; then
      kubectl -n gateway-demo label endpointslice "${slice_name}" \
        kubernetes.io/service-name="${GATEWAY_SERVICE}" --overwrite
      echo "已为 EndpointSlice ${slice_name} 补充 kubernetes.io/service-name label"
      return 0
    fi
    echo "等待 Gateway EndpointSlice 生成（第 ${i}/${attempts} 次）…"
    sleep 3
  done

  echo "失败: 未找到 Gateway 对应的 EndpointSlice"
  kubectl get endpointslice -n gateway-demo || true
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
    print("NetDevOps listeners 已存在，无需更新 app-gateway")
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
print("已将 NetDevOps listeners 增量注入 app-gateway，现有其他 listeners 保持不变")
PY
}

main() {
  echo "========================================================="
  echo "发布 QYTANG NetDevOps HTTPS 域名入口"
  echo "域名：${DOMAIN}"
  echo "========================================================="

  echo "[1/4] 生成域名证书"
  prepare_local_dirs
  generate_server_cert

  echo "[2/4] 创建 Gateway TLS Secret"
  create_tls_secret

  echo "[3/6] 将 NetDevOps listeners 增量注入 app-gateway"
  upsert_gateway_listeners

  echo "[4/6] 应用 Gateway/HTTPRoute/ReferenceGrant"
  kubectl apply -f "${MANIFEST_URL}"

  echo "[5/6] 处理 Cilium Gateway 与 MetalLB 的 EndpointSlice 兼容标签"
  label_gateway_endpointslice

  echo "[6/6] 输出验证命令"
  echo "curl -I --resolve ${DOMAIN}:80:${VIP} http://${DOMAIN}/"
  echo "curl --resolve ${DOMAIN}:443:${VIP} --cacert ${HARBOR_CA_CERT} https://${DOMAIN}/"
  echo "OK: ${DOMAIN} 已发布到 ${VIP}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
