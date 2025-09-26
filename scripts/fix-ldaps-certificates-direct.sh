#!/bin/bash

# Fix LDAPS certificate bundle for Passbolt - Direct Multi-Domain LDAP Approach
# This script extracts certificates from both LDAP servers (ldap1 and ldap2)
# and creates a certificate bundle for Passbolt to use with direct multi-domain LDAP

set -e

echo "Fixing LDAPS certificate bundle for direct multi-domain LDAP..."

# Check if LDAP servers are running
if ! docker compose ps ldap1 | grep -q "Up"; then
    echo "Error: LDAP1 server is not running"
    echo "Please start the LDAP servers first: docker compose up -d ldap1 ldap2"
    exit 1
fi

if ! docker compose ps ldap2 | grep -q "Up"; then
    echo "Error: LDAP2 server is not running"
    echo "Please start the LDAP servers first: docker compose up -d ldap1 ldap2"
    exit 1
fi

# Wait for LDAP servers to be ready
echo "Waiting for LDAP servers to be ready..."
sleep 10

# Create certs directory if it doesn't exist
mkdir -p certs

# Extract certificates from LDAP1
echo "Extracting certificates from LDAP1..."
docker compose exec ldap1 cat /container/service/slapd/assets/certs/ldap.crt > certs/ldap1_server.crt
docker compose exec ldap1 cat /container/service/slapd/assets/certs/ca.crt > certs/ldap1_ca.crt

# Extract certificates from LDAP2
echo "Extracting certificates from LDAP2..."
docker compose exec ldap2 cat /container/service/slapd/assets/certs/ldap.crt > certs/ldap2_server.crt
docker compose exec ldap2 cat /container/service/slapd/assets/certs/ca.crt > certs/ldap2_ca.crt

# Check if we got certificates
if [ ! -s "certs/ldap1_server.crt" ] || [ ! -s "certs/ldap1_ca.crt" ]; then
    echo "Error: Failed to retrieve LDAP1 certificates"
    exit 1
fi

if [ ! -s "certs/ldap2_server.crt" ] || [ ! -s "certs/ldap2_ca.crt" ]; then
    echo "Error: Failed to retrieve LDAP2 certificates"
    exit 1
fi

# Create the certificate bundle with all certificates
echo "Creating certificate bundle with all LDAP certificates..."
cat certs/ldap1_server.crt certs/ldap1_ca.crt certs/ldap2_server.crt certs/ldap2_ca.crt > certs/ldaps_bundle.crt

# Also create individual certificate files for reference
cp certs/ldap1_server.crt certs/ldap1-local.crt
cp certs/ldap2_server.crt certs/ldap2-local.crt

# Clean up temporary files
rm -f certs/ldap1_server.crt certs/ldap1_ca.crt certs/ldap2_server.crt certs/ldap2_ca.crt

# Verify the certificate bundle
echo "Verifying certificate bundle..."
CERT_COUNT=$(grep -c "BEGIN CERTIFICATE" certs/ldaps_bundle.crt)

if [ "$CERT_COUNT" -eq 4 ]; then
    echo "✅ Certificate bundle updated successfully"
    echo "Certificate count: $CERT_COUNT (LDAP1 server + CA, LDAP2 server + CA)"
    echo "LDAP1 Server Certificate: $(openssl x509 -in certs/ldap1-local.crt -text -noout | grep "Subject:" | head -1)"
    echo "LDAP2 Server Certificate: $(openssl x509 -in certs/ldap2-local.crt -text -noout | grep "Subject:" | head -1)"
else
    echo "❌ Error: Certificate bundle is incomplete"
    echo "Expected: 4 certificates (LDAP1 server + CA, LDAP2 server + CA)"
    echo "Found: $CERT_COUNT certificates"
    exit 1
fi

echo ""
echo "Certificate bundle fixed successfully for direct multi-domain LDAP!"
echo "You may need to restart Passbolt to pick up the new certificate:"
echo "  docker compose restart passbolt"
