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
sleep 10

# Get the actual certificate chain from the LDAP server
echo "Extracting certificate chain from LDAP server..."
echo "" | openssl s_client -connect localhost:636 -servername ldap.local -showcerts 2>/dev/null | \
  awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' > certs/ldap_server_chain.crt

# Check if we got certificates
if [ ! -s "certs/ldap_server_chain.crt" ]; then
    echo "Error: Failed to retrieve LDAP certificates"
    echo "Make sure the LDAP container is running and accessible"
    exit 1
fi

# Extract the CA certificate (second certificate in the chain)
echo "Extracting CA certificate..."
awk 'split_after==1{n++;split_after=0} /-----END CERTIFICATE-----/ {split_after=1} {print > ("certs/cert" n ".crt")}' certs/ldap_server_chain.crt

# Copy the CA certificate to the bundle
echo "Updating certificate bundle..."
cp certs/cert1.crt certs/ldaps_bundle.crt

# Clean up temporary files
rm -f certs/ldap_server_chain.crt certs/cert*.crt

# Verify the certificate bundle
echo "Verifying certificate bundle..."
CA_SUBJECT=$(openssl x509 -in certs/ldaps_bundle.crt -text -noout | grep -A 5 -B 5 "Subject:" | grep "Subject:")

if echo "$CA_SUBJECT" | grep -q "docker-light-baseimage"; then
    echo "✅ Certificate bundle updated successfully"
    echo "CA Certificate: $CA_SUBJECT"
else
    echo "❌ Error: Certificate bundle does not contain the correct CA certificate"
    echo "Expected: Subject: CN=docker-light-baseimage"
    echo "Found: $CA_SUBJECT"
    exit 1
fi

echo ""
echo "Certificate bundle fixed successfully!"
echo "You may need to restart Passbolt to pick up the new certificate:"
echo "  docker compose restart passbolt"
