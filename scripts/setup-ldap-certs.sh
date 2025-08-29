#!/bin/bash

# Copy custom LDAP certificates to the Docker volume
set -e

echo "Setting up LDAP certificates..."

# Stop LDAP container if running
echo "Stopping LDAP container..."
docker compose stop ldap 2>/dev/null || true

# Create a temporary container to copy files to the volume
echo "Copying certificates to LDAP volume..."
docker run --rm -v ldap_certs:/certs -v $(pwd)/ldap-certs:/source alpine:latest sh -c "
  cp /source/ldap.crt /certs/
  cp /source/ldap.key /certs/
  cp /source/ca.crt /certs/
  chmod 644 /certs/*.crt
  chmod 600 /certs/*.key
  chown 911:911 /certs/*
"

echo "Starting LDAP container..."
docker compose up -d ldap

echo "LDAP certificates setup complete!"
echo "Waiting for LDAP to start..."
sleep 5

echo "Testing LDAP certificate..."
echo "" | openssl s_client -connect localhost:636 -servername ldap.local 2>/dev/null | openssl x509 -text -noout | grep -A 5 -B 5 "Subject:" || echo "Certificate test failed - LDAP may still be starting" 