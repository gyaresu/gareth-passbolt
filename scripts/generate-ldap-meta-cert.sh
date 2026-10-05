#!/bin/bash

# Generate the self-signed TLS certificate for the LDAP aggregation proxy (ldap-meta).
# Baked into the ldap-meta image at build time and copied to certs/ldaps_bundle.crt
# so Passbolt trusts the LDAPS endpoint. Regenerated locally; not committed.

set -e

CERT_DIR="certs"

echo "Generating TLS certificate for the LDAP meta proxy..."

mkdir -p "$CERT_DIR"

openssl req -x509 -newkey rsa:4096 \
  -keyout "$CERT_DIR/ldap-meta.key" \
  -out "$CERT_DIR/ldap-meta.crt" \
  -days 3650 -nodes \
  -subj "/CN=ldap-meta.local" \
  -addext "subjectAltName = DNS:ldap-meta.local"

chmod 600 "$CERT_DIR/ldap-meta.key"
chmod 644 "$CERT_DIR/ldap-meta.crt"

echo "Certificate generated:"
echo "  - Private key: $CERT_DIR/ldap-meta.key"
echo "  - Certificate: $CERT_DIR/ldap-meta.crt"
