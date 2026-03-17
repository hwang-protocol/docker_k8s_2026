#!/bin/sh
set -eu

apk add --no-cache openssl >/dev/null

mkdir -p /output/ca /output/nginx /output/elasticsearch /output/kibana /output/filebeat
cp /ca/ca.cer /output/ca/ca.crt
SERIAL_FILE=/output/ca/ca.srl
[ -f "$SERIAL_FILE" ] || echo "1000" > "$SERIAL_FILE"

generate_cert() {
  name="$1"
  common_name="$2"
  alt_names="$3"
  target_dir="/output/$name"

  mkdir -p "$target_dir"
  echo "generating certificate for $common_name"

  cat > "$target_dir/openssl.cnf" <<EOF
[ req ]
distinguished_name = dn
req_extensions = req_ext
prompt = no

[ dn ]
CN = ${common_name}

[ req_ext ]
subjectAltName = ${alt_names}
extendedKeyUsage = serverAuth, clientAuth
keyUsage = digitalSignature, keyEncipherment
EOF

  openssl genrsa -out "$target_dir/tls.key" 2048 >/dev/null 2>&1
  openssl req -new \
    -key "$target_dir/tls.key" \
    -out "$target_dir/tls.csr" \
    -config "$target_dir/openssl.cnf" >/dev/null 2>&1
  openssl x509 -req \
    -in "$target_dir/tls.csr" \
    -CA /ca/ca.cer \
    -CAkey /ca/ca-key.pem \
    -CAserial "$SERIAL_FILE" \
    -out "$target_dir/tls.crt" \
    -days 825 \
    -sha256 \
    -extensions req_ext \
    -extfile "$target_dir/openssl.cnf" >/dev/null 2>&1

  cp /ca/ca.cer "$target_dir/ca.crt"
  chmod 644 "$target_dir/tls.key" "$target_dir/tls.crt" "$target_dir/ca.crt"
  rm -f "$target_dir/tls.csr" "$target_dir/openssl.cnf"
}

generate_cert nginx "www.qytdocker2026.com" "DNS:www.qytdocker2026.com,DNS:nginx"
generate_cert elasticsearch "es01.qytdocker2026.com" "DNS:es01.qytdocker2026.com,DNS:elasticsearch,DNS:localhost,IP:127.0.0.1"
generate_cert kibana "kibana01.qytdocker2026.com" "DNS:kibana01.qytdocker2026.com,DNS:kibana,DNS:localhost,IP:127.0.0.1"
generate_cert filebeat "filebeat01.qytdocker2026.com" "DNS:filebeat01.qytdocker2026.com,DNS:filebeat"
echo "all certificates generated under /output"
