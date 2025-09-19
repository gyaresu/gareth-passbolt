#!/bin/bash

# OpenLDAP Meta Backend Entrypoint Script
# Starts meta backend proxy for LDAP result aggregation
# 
# This script:
# - Waits for backend LDAP servers (ldap1, ldap2) to be ready
# - Creates necessary runtime directories
# - Starts slapd with meta backend configuration
# - Provides unified LDAP interface for Passbolt synchronization

set -e

echo "Starting OpenLDAP Meta Backend..."

# Wait for backend LDAP servers
wait_for_backend() {
    local host=$1
    local port=$2
    local timeout=60
    local counter=0

    echo "Waiting for $host:$port..."
    while [ $counter -lt $timeout ]; do
        if nc -z -w 5 "$host" "$port" 2>/dev/null; then
            echo "$host:$port ready"
            return 0
        fi
        sleep 2
        counter=$((counter + 2))
    done

    echo "ERROR: $host:$port timeout"
    return 1
}

# Wait for backends
wait_for_backend "ldap1.local" 389
wait_for_backend "ldap2.local" 389

echo "Backend LDAP servers ready"

# Create run directory
mkdir -p /var/run/slapd
chown openldap:openldap /var/run/slapd

echo "Starting OpenLDAP Meta Backend..."
echo "Unified namespace: dc=unified,dc=local"
echo "Passbolt backend: dc=passbolt,dc=unified,dc=local -> dc=passbolt,dc=local"
echo "Company backend: dc=company,dc=unified,dc=local -> dc=company,dc=org"
echo "Bind DN: cn=admin,dc=unified,dc=local"
echo "Listening on ports 389 (LDAP) and 636 (LDAPS)"

# Start slapd in foreground
exec /usr/sbin/slapd -f /etc/ldap/slapd.conf -h "ldap://0.0.0.0:389 ldaps://0.0.0.0:636" -d stats
