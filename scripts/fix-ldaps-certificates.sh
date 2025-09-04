#!/bin/bash

# Fix LDAPS certificate bundle for Passbolt
# This script extracts the correct CA certificate from the LDAP server
# and updates the certificate bundle used by Passbolt

set -e

echo "Fixing LDAPS certificate bundle..."

# Check if LDAP container is running
if ! docker compose ps ldap | grep -q "Up"; then
    echo "Error: LDAP container is not running"
    echo "Please start the LDAP container first: docker compose up -d ldap"
    exit 1
fi

# Wait for LDAP to be ready
echo "Waiting for LDAP server to be ready..."
sleep 30

# Get the actual certificate from the LDAP server using LDAPS
echo "Extracting certificate from LDAP server using LDAPS..."
echo "" | openssl s_client -connect ldap.local:636 -servername ldap.local -showcerts 2>/dev/null | \
  awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' > certs/ldap_server_chain.crt

# Check if we got certificates
if [ ! -s "certs/ldap_server_chain.crt" ]; then
    echo "Error: Failed to retrieve LDAP certificates"
    echo "Make sure the LDAP container is running and accessible"
    exit 1
fi

# Copy the certificate to the bundle (for STARTTLS, we use the server certificate directly)
echo "Updating certificate bundle..."
cp certs/ldap_server_chain.crt certs/ldap-local.crt
cp certs/ldap-local.crt certs/ldaps_bundle.crt

# Clean up temporary files
rm -f certs/ldap_server_chain.crt certs/cert*.crt

# Verify the certificate bundle
echo "Verifying certificate bundle..."
CERT_SUBJECT=$(openssl x509 -in certs/ldaps_bundle.crt -text -noout | grep -A 5 -B 5 "Subject:" | grep "Subject:")

if echo "$CERT_SUBJECT" | grep -q "ldap.local"; then
    echo "✅ Certificate bundle updated successfully"
    echo "LDAP Certificate: $CERT_SUBJECT"
else
    echo "❌ Error: Certificate bundle does not contain the correct LDAP certificate"
    echo "Expected: Subject containing ldap.local"
    echo "Found: $CERT_SUBJECT"
    exit 1
fi

echo ""
echo "Certificate bundle fixed successfully!"
echo "You may need to restart Passbolt to pick up the new certificate:"
echo "  docker compose restart passbolt"
