#!/bin/bash
# Setup Passbolt (full stack with LDAP aggregation, Keycloak, Traefik)
#
# Configuration via environment variables:
#   ENABLE_RSYSLOG=true   - Enable rsyslog audit logging sidecar
#   SKIP_KEYCLOAK=true    - Skip Keycloak SSO service
#
set -e

echo "Setting up Passbolt"
echo "==================="
echo ""

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

# Configuration from environment variables
ENABLE_RSYSLOG="${ENABLE_RSYSLOG:-false}"
SKIP_KEYCLOAK="${SKIP_KEYCLOAK:-false}"

# Build docker compose command with optional profiles
COMPOSE_CMD="docker compose"
if [ "$ENABLE_RSYSLOG" = "true" ]; then
    COMPOSE_CMD="docker compose --profile audit"
    echo "Configuration: Rsyslog audit logging ENABLED"
else
    echo "Configuration: Rsyslog audit logging disabled (set ENABLE_RSYSLOG=true to enable)"
fi

if [ "$SKIP_KEYCLOAK" = "true" ]; then
    echo "Configuration: Keycloak SSO DISABLED"
else
    echo "Configuration: Keycloak SSO enabled"
fi
echo ""

# Function to wait for service to be ready
wait_for_service() {
    local service=$1
    local port=$2
    local timeout=${3:-60}
    local counter=0

    echo "Waiting for $service to be ready on port $port..."
    while [ $counter -lt $timeout ]; do
        if nc -z localhost $port 2>/dev/null; then
            echo "✓ $service is ready!"
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

    echo "Waiting for LDAP container '$container' to be ready..."
    while [ $counter -lt $timeout ]; do
        if docker compose exec $container ldapsearch -x -H ldap://localhost:389 \
           -D "$admin_dn" -w "$password" -b "$base_dn" 2>/dev/null | grep -q "search:"; then
            echo "✓ LDAP container '$container' is ready!"
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
echo "Checking prerequisites..."

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

# Check if subscription key exists
if [ ! -f "subscription_key.txt" ]; then
    echo "Warning: subscription_key.txt not found."
    echo "   Please add your Passbolt Pro subscription key:"
    echo "   cp /path/to/your/subscription_key.txt subscription_key.txt"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✓ Prerequisites check complete"
echo ""

# Step 1: Generate certificates
echo "Step 1: Generating certificates..."
if [ ! -f "keys/passbolt.crt" ] || [ ! -f "keys/keycloak.crt" ]; then
    echo "   Generating SSL certificates..."
    ./scripts/generate-certificates.sh
    echo "✓ SSL certificates generated"
else
    echo "✓ SSL certificates already exist"
fi

# Ensure ldaps_bundle.crt exists (copy from pre-generated ldap-meta cert)
if [ ! -f "certs/ldaps_bundle.crt" ]; then
    echo "   Creating LDAPS certificate bundle..."
    cp certs/ldap-meta.crt certs/ldaps_bundle.crt
    echo "✓ LDAPS certificate bundle created"
fi

if [ ! -f "smtp4dev/certs/tls.crt" ] || [ ! -f "smtp4dev/certs/tls.pfx" ]; then
    echo "   Generating SMTP certificates..."
    ./scripts/generate-smtp-certs.sh
    echo "✓ SMTP certificates generated"
else
    echo "✓ SMTP certificates already exist"
fi

# Step 2: Start infrastructure services
echo ""
echo "Step 2: Starting infrastructure services..."
$COMPOSE_CMD down 2>/dev/null || true
echo "   Starting database, cache, and SMTP services..."
$COMPOSE_CMD up -d db valkey smtp4dev
wait_for_service "Database" 3306 30
wait_for_service "Valkey" 6379 30
wait_for_service "SMTP4Dev SMTP" 465 30
echo "✓ Infrastructure services ready"

# Step 3: Start LDAP backend servers
echo ""
echo "Step 3: Starting LDAP backend servers..."
echo "   Starting LDAP1 (Passbolt Inc.) and LDAP2 (Example Corp.)..."
$COMPOSE_CMD up -d ldap1 ldap2
wait_for_ldap "ldap1" "cn=admin,dc=passbolt,dc=local" "P4ssb0lt" "dc=passbolt,dc=local"
wait_for_ldap "ldap2" "cn=admin,dc=example,dc=com" "Ex4mple123" "dc=example,dc=com"
echo "✓ LDAP backend servers ready"

# Step 4: Setup LDAP1 data (Passbolt Inc.)
echo ""
echo "Step 4: Setting up LDAP1 data (Passbolt Inc.)..."
echo "   Creating historical computing pioneers..."
export COMPOSE_FILE=docker-compose.yaml
./scripts/ldap/setup/initial-setup.sh
echo "✓ LDAP1 (Passbolt Inc.) data setup complete"

# Step 5: Setup LDAP2 data (Example Corp.)
echo ""
echo "Step 5: Setting up LDAP2 data (Example Corp.)..."
echo "   Creating modern tech professionals..."
./scripts/ldap2/setup/initial-setup.sh
echo "✓ LDAP2 (Example Corp.) data setup complete"
unset COMPOSE_FILE

# Step 6: Start LDAP aggregation proxy
echo ""
echo "Step 6: Starting LDAP aggregation proxy..."
echo "   Building and starting OpenLDAP meta backend..."
$COMPOSE_CMD up -d ldap-meta
wait_for_service "LDAP Meta Proxy" 3389 60
echo "✓ LDAP aggregation proxy ready"
echo "   📊 Unified namespace: dc=unified,dc=local"
echo "   🔗 Endpoint: ldap-meta.local:3636 (LDAPS)"

# Step 7: Start remaining services (Keycloak optional, Passbolt, Traefik)
echo ""
echo "Step 7: Starting Passbolt and Traefik..."
if [ "$SKIP_KEYCLOAK" = "true" ]; then
    echo "   Skipping Keycloak (SKIP_KEYCLOAK=true)"
    $COMPOSE_CMD up -d passbolt traefik
else
    echo "   Starting Keycloak, Passbolt, and Traefik..."
    $COMPOSE_CMD up -d keycloak passbolt traefik
    wait_for_service "Keycloak" 443 60
fi
wait_for_service "Passbolt" 443 60

# Wait for Passbolt to complete initialization (migrations, etc.)
echo "Waiting for Passbolt to complete initialization..."
PASSBOLT_READY=false
for i in {1..60}; do
    if curl -sk https://passbolt.local/healthcheck/status.json 2>/dev/null | grep -q '"status":"success"'; then
        PASSBOLT_READY=true
        break
    fi
    sleep 2
    echo "   Waiting for Passbolt health check... ($((i*2))/120 seconds)"
done

if [ "$PASSBOLT_READY" = "true" ]; then
    echo "✓ Passbolt is fully initialized"
else
    echo "⚠️  Passbolt health check timed out, continuing anyway..."
fi
echo "✓ Services ready"

# Step 8: Generate GPG keys for demo users
echo ""
echo "Step 8: Generating GPG keys for demo users..."
echo "   Creating GPG keys with email=passphrase for convenience..."
if command -v gpg &> /dev/null; then
    ./scripts/gpg/generate-demo-keys.sh
    echo "✓ GPG keys generated for all demo users"
else
    echo "   ⚠️  GPG not installed, skipping key generation"
    echo "   Users will need to generate their own keys for Passbolt login"
fi

# Step 9: Create Passbolt admin user (ada@passbolt.com now exists in LDAP)
echo ""
echo "Step 9: Creating Passbolt admin user..."
echo "   Creating admin user 'ada@passbolt.com'..."
echo "   (This user now exists in LDAP1, so sync will work properly)"

REGISTER_OUTPUT=$(docker compose exec -u www-data passbolt /usr/share/php/passbolt/bin/cake passbolt register_user -u ada@passbolt.com -f "Ada" -l "Lovelace" -r admin 2>&1)

if echo "$REGISTER_OUTPUT" | grep -q "already exists\|already registered"; then
    echo "✓ Admin user 'ada@passbolt.com' already exists"
    echo "   To get a new registration link, run:"
    echo "   docker compose exec -u www-data passbolt /usr/share/php/passbolt/bin/cake passbolt recover_user -u ada@passbolt.com --create"
else
    echo "✓ Admin user 'ada@passbolt.com' created successfully!"
    # Extract and display the registration link
    REGISTER_LINK=$(echo "$REGISTER_OUTPUT" | grep -o 'https://[^ ]*')
    if [ -n "$REGISTER_LINK" ]; then
        echo ""
        echo "   🔗 Registration link:"
        echo "   $REGISTER_LINK"
        echo ""
    fi
    if [ -f "keys/gpg/ada@passbolt.com.key" ]; then
        echo "   🔑 GPG key available: keys/gpg/ada@passbolt.com.key"
        echo "   🔐 Passphrase: ada@passbolt.com"
    fi
fi

# Step 10: LDAP synchronization setup
echo ""
echo "Step 10: LDAP synchronization setup..."
echo ""
echo "   ┌─────────────────────────────────────────────────────────────────┐"
echo "   │  IMPORTANT: Manual LDAP Configuration Required                  │"
echo "   └─────────────────────────────────────────────────────────────────┘"
echo ""
echo "   LDAP Directory Sync must be configured through the Passbolt web UI."
echo "   It cannot be configured via environment variables."
echo ""
echo "   Steps to configure:"
echo "   1. Go to https://passbolt.local"
echo "   2. Log in as ada@passbolt.com (passphrase: ada@passbolt.com)"
echo "   3. Go to Administration > Directory Synchronization"
echo "   4. Configure LDAP settings:"
echo "      - Host: ldap-meta.local"
echo "      - Port: 636 (LDAPS)"
echo "      - Base DN: dc=unified,dc=local"
echo "      - Username: cn=admin,dc=unified,dc=local"
echo "      - Password: secret"
echo "      - Use SSL: true"
echo "   5. Test connection and run synchronization"
echo ""
echo "   Manual sync command (after web UI configuration):"
echo "   docker compose exec passbolt su -s /bin/bash -c \"/usr/share/php/passbolt/bin/cake directory_sync all --persist --quiet\" www-data"
echo ""
echo "✓ LDAP synchronization instructions provided"

# Final verification
echo ""
echo "✓ Setup Complete!"
echo "================="
echo ""
echo "Access URLs:"
echo "   - Passbolt:          https://passbolt.local"
if [ "$SKIP_KEYCLOAK" != "true" ]; then
    echo "   - Keycloak:          https://keycloak.local"
fi
echo "   - SMTP4Dev:          https://smtp.local"
echo "   - Traefik Dashboard: https://traefik.local"
echo "   - LDAP Meta:         ldap-meta.local:3389 (LDAP), :3636 (LDAPS)"
echo ""
echo "Demo Users:"
echo "LDAP1 (Passbolt Inc.) - dc=passbolt,dc=local:"
echo "   - ada@passbolt.com (Ada Lovelace) - CTO"
echo "   - betty@passbolt.com (Betty Holberton) - Senior Developer"
echo "   - carol@passbolt.com (Carol Shaw) - Game Dev Lead"
echo "   - dame@passbolt.com (Dame Stephanie Shirley) - CEO"
echo "   - edith@passbolt.com (Edith Clarke) - Engineering Manager"
echo ""
echo "LDAP2 (Example Corp.) - dc=example,dc=com:"
echo "   - john.smith@example.com (John Smith) - Project Manager"
echo "   - sarah.johnson@example.com (Sarah Johnson) - Security Analyst"
echo "   - michael.chen@example.com (Michael Chen) - DevOps Engineer"
echo "   - lisa.rodriguez@example.com (Lisa Rodriguez) - UX Designer"
echo ""
echo "LDAP Aggregation Configuration:"
echo "   - Server: ldap-meta.local"
echo "   - Port: 636 (LDAPS)"
echo "   - Base DN: dc=unified,dc=local"
echo "   - Bind DN: cn=admin,dc=unified,dc=local"
echo "   - Password: secret"
echo ""
if [ -d "keys/gpg" ] && [ "$(ls -A keys/gpg 2>/dev/null)" ]; then
    echo "GPG Keys Generated:"
    echo "   - Location: keys/gpg/"
    echo "   - Passphrase: email address (for all users)"
    echo "   - Import private key in Passbolt for login"
    echo ""
fi
echo "Traefik Configuration:"
echo "   - HTTP → HTTPS redirect enabled"
echo "   - Security headers middleware applied"
echo "   - TLS 1.2+ with strong cipher suites"
echo "   - Docker service discovery enabled"
echo ""
if [ "$ENABLE_RSYSLOG" = "true" ]; then
    echo "Rsyslog Audit Logging:"
    echo "   - Syslog logs: logs/passbolt/syslog.log"
    echo "   - Filter: grep 'passbolt-audit' logs/passbolt/syslog.log"
    echo ""
fi
echo "Next Steps:"
echo "1. Configure LDAP Directory Sync in Passbolt web UI (see instructions above)"
echo "2. Run synchronization to import all users from both directories"
echo "3. Test user login with GPG keys (passphrase = email)"
echo "4. Explore Traefik dashboard at https://traefik.local"
echo ""

# Check service status
echo ""
echo "Service Status:"
if $COMPOSE_CMD ps | grep -q "Up"; then
    $COMPOSE_CMD ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "All services are running successfully."
else
    echo "Some services failed to start. Check logs with: docker compose logs"
    exit 1
fi
