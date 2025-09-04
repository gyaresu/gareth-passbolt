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

# Check if SMTP certificate files exist and generate them if missing
echo "Checking SMTP certificate files..."
missing_certs=()

# Only check for SMTP certificates - LDAP certificates are downloaded from the server
if [ ! -f "smtp4dev/certs/tls.crt" ]; then missing_certs+=("smtp4dev/certs/tls.crt"); fi
if [ ! -f "smtp4dev/certs/tls.pfx" ]; then missing_certs+=("smtp4dev/certs/tls.pfx"); fi

if [ ${#missing_certs[@]} -ne 0 ]; then
    echo "Missing SMTP certificate files detected:"
    for cert in "${missing_certs[@]}"; do
        echo "   - $cert"
    done
    echo ""
    echo "Generating SMTP certificates..."
    ./scripts/generate-smtp-certs.sh
    echo "SMTP certificate generation complete!"
else
    echo "All SMTP certificate files found"
fi

echo "Note: Using LDAP with STARTTLS (port 389) - more compatible with PHP LDAP extension"
echo "LDAP certificates will be downloaded from the LDAP server and built into the container"

# Start the services
echo "Starting Docker services..."
docker compose down 2>/dev/null || true
docker compose up -d

echo "Waiting for services to start..."
sleep 10

# Download LDAP server certificate
echo "Downloading LDAP server certificate..."
./scripts/fix-ldaps-certificates.sh

# Restart Passbolt to pick up the new certificate
echo "Restarting Passbolt to pick up new certificate..."
docker compose restart passbolt

# Wait for Passbolt to be ready
echo "Waiting for Passbolt to be ready..."
sleep 15

# Set up LDAP users and groups
echo "Setting up LDAP users and groups..."
./scripts/ldap/setup/initial-setup.sh

# Create admin user if it doesn't exist
echo "Creating Passbolt admin user..."
echo "Creating default admin user 'ada'..."
if docker compose exec passbolt su -m -c '/usr/share/php/passbolt/bin/cake passbolt register_user -u ada@passbolt.com -f "Ada" -l "Lovelace" -r admin' -s /bin/bash www-data 2>&1 | grep -q "already exists\|already registered"; then
    echo "✅ Admin user 'ada' already exists"
else
    echo "✅ Admin user 'ada' created successfully!"
    echo "📧 Check SMTP4Dev (http://smtp.local:5050) for the registration email"
    echo "🔑 Password for the key is: ada@passbolt.com"
fi

# Check if services are running
echo "Checking service status..."
if docker compose ps | grep -q "Up"; then
    echo "Services are running successfully!"
    echo ""
    echo "Access your services:"
echo "   - Passbolt: https://passbolt.local"
echo "   - Keycloak: https://keycloak.local:8443"
echo "   - SMTP4Dev (SMTP testing): http://smtp.local:5050"
echo "   - LDAP: ldap.local:389 (STARTTLS), ldap.local:636 (LDAPS)"
    echo ""
    echo "LDAP users created for sync:"
    echo "   - ada@passbolt.com (admin)"
    echo "   - betty@passbolt.com"
    echo "   - carol@passbolt.com"
    echo "   - dame@passbolt.com"
    echo "   - edith@passbolt.com"
    echo ""
    echo "Configure LDAP directory sync in Passbolt web UI to sync these users."
    echo "For more information, see README.md"
else
    echo "Error: Some services failed to start. Check logs with:"
    echo "   docker compose logs"
    exit 1
fi
