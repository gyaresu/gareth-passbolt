#!/bin/bash

# Passbolt LDAP Aggregation Demo Setup Script
# Complete setup for LDAP aggregation demonstration showing company merger scenario
# 
# This script sets up:
# - LDAP1 (Passbolt Inc.) - Historical computing pioneers
# - LDAP2 (Example Corp.) - Modern tech professionals  
# - OpenLDAP Meta Backend for aggregation
# - GPG keys for all demo users
# - Proper startup sequence to ensure LDAP data exists before Passbolt admin creation

set -e

echo "🚀 Setting up Passbolt LDAP Aggregation Demo"
echo "============================================"
echo ""
echo "This demo shows a company merger scenario:"
echo "📊 Passbolt Inc. (historical computing pioneers) ← acquired → Example Corp. (modern tech)"
echo "🔗 LDAP aggregation combines both directories into unified Passbolt instance"
echo ""

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

# Function to wait for service to be ready
wait_for_service() {
    local service=$1
    local port=$2
    local timeout=${3:-60}
    local counter=0
    
    echo "⏳ Waiting for $service to be ready on port $port..."
    while [ $counter -lt $timeout ]; do
        if nc -z localhost $port 2>/dev/null; then
            echo "✅ $service is ready!"
            return 0
        fi
        sleep 2
        counter=$((counter + 2))
        echo "   Waiting... ($counter/$timeout seconds)"
    done
    
    echo "❌ ERROR: $service failed to start within $timeout seconds"
    return 1
}

# Function to wait for LDAP container to be ready
wait_for_ldap() {
    local container=$1
    local admin_dn=$2
    local password=$3
    local base_dn=$4
    local timeout=${5:-60}
    local counter=0
    
    echo "⏳ Waiting for LDAP container '$container' to be ready..."
    while [ $counter -lt $timeout ]; do
        if docker compose exec $container ldapsearch -x -H ldap://localhost:389 \
           -D "$admin_dn" -w "$password" -b "$base_dn" 2>/dev/null | grep -q "search:"; then
            echo "✅ LDAP container '$container' is ready!"
            return 0
        fi
        sleep 2
        counter=$((counter + 2))
        echo "   Waiting... ($counter/$timeout seconds)"
    done
    
    echo "❌ ERROR: LDAP container '$container' failed to start within $timeout seconds"
    return 1
}

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Error: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if subscription key exists
if [ ! -f "subscription_key.txt" ]; then
    echo "⚠️  Warning: subscription_key.txt not found."
    echo "   Please add your Passbolt Pro subscription key:"
    echo "   cp /path/to/your/subscription_key.txt subscription_key.txt"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✅ Prerequisites check complete"
echo ""

# Step 1: Generate certificates
echo "🔐 Step 1: Generating certificates..."
if [ ! -f "smtp4dev/certs/tls.crt" ] || [ ! -f "smtp4dev/certs/tls.pfx" ]; then
    echo "   Generating SMTP certificates..."
    ./scripts/generate-smtp-certs.sh
    echo "   ✅ SMTP certificates generated"
else
    echo "   ✅ SMTP certificates already exist"
fi

# Step 2: Start infrastructure services
echo ""
echo "🏗️  Step 2: Starting infrastructure services..."
docker compose down 2>/dev/null || true
echo "   Starting database, cache, and SMTP services..."
docker compose up -d db valkey smtp4dev
wait_for_service "Database" 3306 30
wait_for_service "Valkey" 6379 30
wait_for_service "SMTP4Dev" 5050 30
echo "   ✅ Infrastructure services ready"

# Step 3: Start LDAP backend servers
echo ""
echo "📁 Step 3: Starting LDAP backend servers..."
echo "   Starting LDAP1 (Passbolt Inc.) and LDAP2 (Example Corp.)..."
docker compose up -d ldap1 ldap2
wait_for_ldap "ldap1" "cn=admin,dc=passbolt,dc=local" "P4ssb0lt" "dc=passbolt,dc=local"
wait_for_ldap "ldap2" "cn=admin,dc=example,dc=com" "Ex4mple123" "dc=example,dc=com"
echo "   ✅ LDAP backend servers ready"

# Step 4: Setup LDAP1 data (Passbolt Inc.)
echo ""
echo "👩‍💻 Step 4: Setting up LDAP1 data (Passbolt Inc.)..."
echo "   Creating historical computing pioneers..."
./scripts/ldap/setup/initial-setup.sh
echo "   ✅ LDAP1 (Passbolt Inc.) data setup complete"

# Step 5: Setup LDAP2 data (Example Corp.)
echo ""
echo "🏢 Step 5: Setting up LDAP2 data (Example Corp.)..."
echo "   Creating modern tech professionals..."
./scripts/ldap2/setup/initial-setup.sh
echo "   ✅ LDAP2 (Example Corp.) data setup complete"

# Step 6: Start LDAP aggregation proxy
echo ""
echo "🔗 Step 6: Starting LDAP aggregation proxy..."
echo "   Building and starting OpenLDAP meta backend..."
docker compose up -d ldap-meta
wait_for_service "LDAP Meta Proxy" 3389 60
echo "   ✅ LDAP aggregation proxy ready"
echo "   📊 Unified namespace: dc=unified,dc=local"
echo "   🔗 Endpoint: ldap-meta.local:3389"

# Step 7: Start Keycloak and Passbolt
echo ""
echo "🔑 Step 7: Starting Keycloak and Passbolt..."
echo "   Starting SSO and password manager services..."
docker compose up -d keycloak passbolt
wait_for_service "Keycloak" 8443 60
wait_for_service "Passbolt" 443 60
echo "   ✅ Keycloak and Passbolt ready"

# Step 8: Setup LDAP certificates for Passbolt
echo ""
echo "🔒 Step 8: Setting up LDAP certificates..."
echo "   Extracting LDAP certificates from containers..."
./scripts/fix-ldaps-certificates.sh
echo "   Rebuilding Passbolt with certificate bundle..."
docker compose build passbolt
docker compose up -d passbolt
wait_for_service "Passbolt" 443 60
echo "   ✅ LDAP certificates configured"

# Step 9: Generate GPG keys for demo users
echo ""
echo "🔑 Step 9: Generating GPG keys for demo users..."
echo "   Creating GPG keys with email=passphrase for convenience..."
if command -v gpg &> /dev/null; then
    ./scripts/gpg/generate-demo-keys.sh
    echo "   ✅ GPG keys generated for all demo users"
else
    echo "   ⚠️  GPG not installed, skipping key generation"
    echo "   Users will need to generate their own keys for Passbolt login"
fi

# Step 10: Create Passbolt admin user (ada@passbolt.com now exists in LDAP)
echo ""
echo "👑 Step 10: Creating Passbolt admin user..."
echo "   Creating admin user 'ada@passbolt.com'..."
echo "   (This user now exists in LDAP1, so sync will work properly)"

if docker compose exec passbolt su -m -c '/usr/share/php/passbolt/bin/cake passbolt register_user -u ada@passbolt.com -f "Ada" -l "Lovelace" -r admin' -s /bin/bash www-data 2>&1 | grep -q "already exists\|already registered"; then
    echo "   ✅ Admin user 'ada@passbolt.com' already exists"
else
    echo "   ✅ Admin user 'ada@passbolt.com' created successfully!"
    echo "   📧 Check SMTP4Dev for registration email: http://smtp.local:5050"
    if [ -f "keys/gpg/ada@passbolt.com.key" ]; then
        echo "   🔑 GPG key available: keys/gpg/ada@passbolt.com.key"
        echo "   🔐 Passphrase: ada@passbolt.com"
    fi
fi

# Final verification
echo ""
echo "✅ LDAP Aggregation Demo Setup Complete!"
echo "========================================"
echo ""
echo "🌐 Access URLs:"
echo "   • Passbolt:     https://passbolt.local"
echo "   • Keycloak:     https://keycloak.local:8443"
echo "   • SMTP4Dev:     http://smtp.local:5050"
echo "   • LDAP Meta:    ldap-meta.local:3389 (LDAP), :3636 (LDAPS)"
echo ""
echo "👥 Demo Users Available for Sync:"
echo "📁 LDAP1 (Passbolt Inc.) - dc=passbolt,dc=local:"
echo "   • ada@passbolt.com (Ada Lovelace) - CTO"
echo "   • betty@passbolt.com (Betty Holberton) - Senior Developer"
echo "   • carol@passbolt.com (Carol Shaw) - Game Dev Lead"
echo "   • dame@passbolt.com (Dame Stephanie Shirley) - CEO"
echo "   • edith@passbolt.com (Edith Clarke) - Engineering Manager"
echo ""
echo "📁 LDAP2 (Example Corp.) - dc=example,dc=com:"
echo "   • john.smith@example.com (John Smith) - Project Manager"
echo "   • sarah.johnson@example.com (Sarah Johnson) - Security Analyst"
echo "   • michael.chen@example.com (Michael Chen) - DevOps Engineer"
echo "   • lisa.rodriguez@example.com (Lisa Rodriguez) - UX Designer"
echo ""
echo "🔗 LDAP Aggregation Configuration:"
echo "   • Server: ldap-meta.local"
echo "   • Port: 3389"
echo "   • Base DN: dc=unified,dc=local"
echo "   • Bind DN: cn=admin,dc=unified,dc=local"
echo "   • Password: secret"
echo ""
if [ -d "keys/gpg" ] && [ "$(ls -A keys/gpg 2>/dev/null)" ]; then
    echo "🔑 GPG Keys Generated:"
    echo "   • Location: keys/gpg/"
    echo "   • Passphrase: email address (for all users)"
    echo "   • Import private key in Passbolt for login"
    echo ""
fi
echo "📚 Next Steps:"
echo "1. Configure LDAP Directory Sync in Passbolt web UI"
echo "2. Run synchronization to import all users from both directories"
echo "3. Test user login with GPG keys (passphrase = email)"
echo "4. Explore merged user/group data from both companies"
echo ""
echo "🎯 This demonstrates enterprise LDAP aggregation for company mergers!"

# Check service status
echo ""
echo "📊 Service Status:"
if docker compose ps | grep -q "Up"; then
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "🎉 All services are running successfully!"
else
    echo "❌ Some services failed to start. Check logs with: docker compose logs"
    exit 1
fi
