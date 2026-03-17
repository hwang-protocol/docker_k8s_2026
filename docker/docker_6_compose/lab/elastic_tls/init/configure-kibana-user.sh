#!/bin/sh
set -eu

echo "setting kibana_system password"

curl --silent --fail \
  --cacert /certs/ca.crt \
  -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  -X POST \
  https://es01.qytdocker2026.com:9200/_security/user/kibana_system/_password \
  -d "{\"password\":\"${KIBANA_SYSTEM_PASSWORD}\"}" >/dev/null

echo "kibana_system password updated"
