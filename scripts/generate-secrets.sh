#!/usr/bin/env bash
set -euo pipefail

CERTS_DIR="$(dirname "$0")/../data/certs"
DAYS=3650
BITS=4096
COUNTRY="AT"
STATE="Vienna"
LOCALITY="Vienna"
ORG="PiBX"
CN="${1:-freepbx.local}"

mkdir -p "$CERTS_DIR"

echo "==> Generating CA key and certificate..."
openssl genrsa -out "$CERTS_DIR/ca-key.pem" "$BITS"
openssl req -new -x509 -nodes -days "$DAYS" \
  -key "$CERTS_DIR/ca-key.pem" \
  -out "$CERTS_DIR/ca-cert.pem" \
  -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/CN=$ORG CA"

echo "==> Generating server key and CSR..."
openssl genrsa -out "$CERTS_DIR/key.pem" "$BITS"
openssl req -new -nodes \
  -key "$CERTS_DIR/key.pem" \
  -out "$CERTS_DIR/server.csr" \
  -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/CN=$CN" \
  -addext "subjectAltName=DNS:$CN,DNS:*.$CN,IP:127.0.0.1"

echo "==> Signing server certificate with CA..."
openssl x509 -req -days "$DAYS" \
  -in "$CERTS_DIR/server.csr" \
  -CA "$CERTS_DIR/ca-cert.pem" \
  -CAkey "$CERTS_DIR/ca-key.pem" \
  -CAcreateserial \
  -out "$CERTS_DIR/cert.pem" \
  -extfile <(printf "subjectAltName=DNS:%s,DNS:*.%s,IP:127.0.0.1\nbasicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth" "$CN" "$CN")

rm -f "$CERTS_DIR/server.csr" "$CERTS_DIR/ca-cert.srl"

chmod 0600 "$CERTS_DIR/key.pem" "$CERTS_DIR/ca-key.pem"
chmod 0644 "$CERTS_DIR/cert.pem" "$CERTS_DIR/ca-cert.pem"

echo ""
echo "==> Done! Certificates generated in $CERTS_DIR"
echo "    cert.pem    - Server certificate"
echo "    key.pem     - Server private key"
echo "    ca-cert.pem - CA certificate (install on clients to trust)"
echo "    ca-key.pem  - CA private key (keep safe)"
echo ""
echo "    CN used: $CN"
echo "    To regenerate with a different CN: $0 your.domain.com"
