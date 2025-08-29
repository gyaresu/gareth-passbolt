#!/bin/bash

# Generate TLS certificates for SMTP4Dev
# This script creates self-signed certificates for local SMTP testing

set -e

CERT_DIR="smtp4dev/certs"
CERT_PASSWORD="changeme"

echo "Generating TLS certificates for SMTP4Dev..."

# Create certificates directory
mkdir -p "$CERT_DIR"

# Generate private key and certificate
echo "Creating private key and certificate..."
openssl req -x509 -newkey rsa:4096 \
  -keyout "$CERT_DIR/tls.key" \
  -out "$CERT_DIR/tls.crt" \
  -days 365 -nodes \
  -subj "/CN=smtp.local"

# Create PKCS12 bundle
echo "Creating PKCS12 bundle..."
openssl pkcs12 -export \
  -out "$CERT_DIR/tls.pfx" \
  -inkey "$CERT_DIR/tls.key" \
  -in "$CERT_DIR/tls.crt" \
  -passout pass:"$CERT_PASSWORD"

# Set proper permissions
chmod 600 "$CERT_DIR/tls.key"
chmod 644 "$CERT_DIR/tls.crt"
chmod 600 "$CERT_DIR/tls.pfx"

echo "Certificates generated successfully:"
echo "  - Private key: $CERT_DIR/tls.key"
echo "  - Certificate: $CERT_DIR/tls.crt"
echo "  - PKCS12 bundle: $CERT_DIR/tls.pfx"
echo "  - Password: $CERT_PASSWORD"
echo ""
echo "Next steps:"
echo "1. Restart the Docker services: docker compose down && docker compose up -d"
echo "2. Check SMTP4Dev logs: docker compose logs smtp4dev"
echo "3. Test email sending in Passbolt"

