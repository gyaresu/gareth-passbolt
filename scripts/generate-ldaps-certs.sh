#!/bin/bash

# Generate LDAPS certificate bundle for Passbolt
# This script retrieves the LDAP certificate chain and creates a bundle

set -e

CERT_DIR="certs"
LDAPS_BUNDLE="$CERT_DIR/ldaps_bundle.crt"

echo "Generating LDAPS certificate bundle..."

# Create certificates directory
mkdir -p "$CERT_DIR"

# Retrieve the LDAP certificate chain
echo "Retrieving LDAP certificate chain..."
openssl s_client -connect ldap.local:636 -servername ldap.local -showcerts </dev/null 2>/dev/null | \
  awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' > "$LDAPS_BUNDLE"

# Check if we got certificates
if [ ! -s "$LDAPS_BUNDLE" ]; then
    echo "Error: Failed to retrieve LDAP certificates"
    echo "Make sure the LDAP container is running and accessible"
    exit 1
fi

# Set proper permissions
chmod 644 "$LDAPS_BUNDLE"

echo "LDAPS certificate bundle generated successfully:"
echo "  - Bundle: $LDAPS_BUNDLE"
echo ""
echo "Certificate details:"
openssl x509 -in "$LDAPS_BUNDLE" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After)"

echo ""
echo "Next steps:"
echo "1. Restart the Docker services: docker compose down && docker compose up -d"
echo "2. Configure LDAP directory sync in Passbolt web UI"
echo "3. Test LDAPS connectivity"

