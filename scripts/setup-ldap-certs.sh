#!/bin/bash

# Define base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LDAP_CERTS_DIR="$BASE_DIR/ldap-certs"

# Source the .env file to get the project name
if [ -f "$BASE_DIR/.env" ]; then
    export $(grep -v '^#' "$BASE_DIR/.env" | xargs)
fi

# Copy certificates to LDAP volume
docker run --rm -v ${COMPOSE_PROJECT_NAME}_ldap_certs:/certs -v "$LDAP_CERTS_DIR":/source alpine sh -c "\
    rm -f /certs/* && \
    cp /source/ldap.crt /certs/ldap.crt && \
    cp /source/ldap.key /certs/ldap.key && \
    cp /source/ldap-chain.crt /certs/ca.crt && \
    chmod 644 /certs/ldap.crt && \
    chmod 644 /certs/ldap.key && \
    chmod 644 /certs/ca.crt && \
    chown -R 911:911 /certs && \
    ln -sf /certs/ca.crt /certs/ca.pem"

echo "LDAP certificates updated"
docker run --rm -v ${COMPOSE_PROJECT_NAME}_ldap_certs:/certs alpine ls -la /certs 