#!/bin/bash

# Passbolt Docker Support Setup Script
# This script helps set up the Passbolt development environment

set -e

echo "Setting up Passbolt Docker Support Environment"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if subscription key symlink exists
if [ ! -L "subscription_key.txt" ]; then
    echo "Warning: subscription_key.txt is not a symlink."
    echo "   Please create a symlink to your Passbolt subscription key:"
    echo "   ln -s /path/to/your/subscription_key.txt subscription_key.txt"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if certificate files exist
echo "Checking certificate files..."
missing_certs=()

if [ ! -f "certs/ldaps_bundle.crt" ]; then missing_certs+=("certs/ldaps_bundle.crt"); fi
if [ ! -f "smtp4dev/certs/tls.crt" ]; then missing_certs+=("smtp4dev/certs/tls.crt"); fi
if [ ! -f "smtp4dev/certs/tls.pfx" ]; then missing_certs+=("smtp4dev/certs/tls.pfx"); fi
if [ ! -f "ldap-certs/ldap.crt" ]; then missing_certs+=("ldap-certs/ldap.crt"); fi
if [ ! -f "ldap-certs/ldap.key" ]; then missing_certs+=("ldap-certs/ldap.key"); fi
if [ ! -f "ldap-certs/ca.crt" ]; then missing_certs+=("ldap-certs/ca.crt"); fi

if [ ${#missing_certs[@]} -ne 0 ]; then
    echo "Error: Missing certificate files:"
    for cert in "${missing_certs[@]}"; do
        echo "   - $cert"
    done
    echo ""
    echo "Please ensure all certificate files are present before continuing."
    exit 1
fi

echo "All certificate files found"

# Start the services
echo "Starting Docker services..."
docker compose down 2>/dev/null || true
docker compose up -d

echo "Waiting for services to start..."
sleep 10

# Check if services are running
echo "Checking service status..."
if docker compose ps | grep -q "Up"; then
    echo "Services are running successfully!"
    echo ""
    echo "Access your services:"
echo "   - Passbolt: https://passbolt.local"
echo "   - Keycloak: https://keycloak.local:8443"
echo "   - SMTP4Dev (SMTP testing): http://smtp.local:5050"
echo "   - LDAP: ldap.local:389 (LDAP), ldap.local:636 (LDAPS)"
    echo ""
    echo "For more information, see README.md"
else
    echo "Error: Some services failed to start. Check logs with:"
    echo "   docker compose logs"
    exit 1
fi
