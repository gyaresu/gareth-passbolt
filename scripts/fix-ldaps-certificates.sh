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

# Extract the server certificate from the LDAP container
echo "Extracting server certificate from LDAP container..."
docker compose exec ldap cat /container/service/slapd/assets/certs/ldap.crt > certs/ldap_server.crt

# Extract the CA certificate from the LDAP container
echo "Extracting CA certificate from LDAP container..."
docker compose exec ldap cat /container/service/slapd/assets/certs/ca.crt > certs/ldap_ca.crt

# Check if we got certificates
if [ ! -s "certs/ldap_server.crt" ] || [ ! -s "certs/ldap_ca.crt" ]; then
    echo "Error: Failed to retrieve LDAP certificates from container"
    echo "Make sure the LDAP container is running and accessible"
    exit 1
fi

# Create the certificate bundle with both server and CA certificates
echo "Creating certificate bundle with server and CA certificates..."
cat certs/ldap_server.crt certs/ldap_ca.crt > certs/ldaps_bundle.crt

# Also create the ldap-local.crt for backward compatibility
cp certs/ldap_server.crt certs/ldap-local.crt

# Clean up temporary files
rm -f certs/ldap_server.crt certs/ldap_ca.crt

# Verify the certificate bundle
echo "Verifying certificate bundle..."
CERT_COUNT=$(grep -c "BEGIN CERTIFICATE" certs/ldaps_bundle.crt)
SERVER_CERT_SUBJECT=$(openssl x509 -in certs/ldaps_bundle.crt -text -noout | grep -A 2 -B 2 "Subject:" | head -3 | grep "Subject:")

if [ "$CERT_COUNT" -eq 2 ] && echo "$SERVER_CERT_SUBJECT" | grep -q "ldap.local"; then
    echo "✅ Certificate bundle updated successfully"
    echo "Certificate count: $CERT_COUNT (server + CA)"
    echo "LDAP Server Certificate: $SERVER_CERT_SUBJECT"
    echo "CA Certificate: CN=docker-light-baseimage"
else
    echo "❌ Error: Certificate bundle is incomplete or incorrect"
    echo "Expected: 2 certificates (server + CA), server subject containing ldap.local"
    echo "Found: $CERT_COUNT certificates, server subject: $SERVER_CERT_SUBJECT"
    exit 1
fi

echo ""
echo "Certificate bundle fixed successfully!"
echo "You may need to restart Passbolt to pick up the new certificate:"
echo "  docker compose restart passbolt"
