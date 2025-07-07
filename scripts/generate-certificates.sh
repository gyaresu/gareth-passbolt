#!/bin/bash

# Define base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
KEYS_DIR="$BASE_DIR/keys"
LDAP_CERTS_DIR="$BASE_DIR/ldap-certs"
CONFIG_SSL_DIR="$BASE_DIR/config/ssl"

# Create directories if they don't exist
mkdir -p "$KEYS_DIR"
mkdir -p "$LDAP_CERTS_DIR"
mkdir -p "$CONFIG_SSL_DIR"

# Generate Root CA Certificate
echo "Generating Root CA certificate..."
openssl req -x509 -sha256 -days 3650 -newkey rsa:2048 \
  -subj "/C=LU/ST=Luxembourg/L=Esch-Sur-Alzette/O=Passbolt CA/OU=Passbolt CA/CN=Passbolt Root CA" \
  -nodes -keyout "$KEYS_DIR/rootCA.key" -out "$KEYS_DIR/rootCA.crt"

# Generate Keycloak Certificate
echo "Generating Keycloak certificate..."
openssl req -newkey rsa:2048 \
  -subj "/C=LU/ST=Luxembourg/L=Esch-Sur-Alzette/O=Passbolt/OU=Keycloak/CN=keycloak.local" \
  -addext "subjectAltName = DNS:keycloak.local" \
  -nodes -keyout "$KEYS_DIR/keycloak.key" -out "$KEYS_DIR/keycloak.csr"

# Create SSL config file for Keycloak
cat > "$CONFIG_SSL_DIR/keycloak_ssl_config.txt" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = keycloak.local
EOF

# Copy the config file to keys directory for backward compatibility
cp "$CONFIG_SSL_DIR/keycloak_ssl_config.txt" "$KEYS_DIR/"

# Sign Keycloak Certificate with Root CA
openssl x509 -req -CA "$KEYS_DIR/rootCA.crt" -CAkey "$KEYS_DIR/rootCA.key" \
  -in "$KEYS_DIR/keycloak.csr" -out "$KEYS_DIR/keycloak.crt" -days 365 \
  -CAcreateserial -extfile "$CONFIG_SSL_DIR/keycloak_ssl_config.txt"

# Generate LDAP Certificate
echo "Generating LDAP certificate..."
openssl req -newkey rsa:2048 \
  -subj "/C=LU/ST=Luxembourg/L=Esch-Sur-Alzette/O=Passbolt/OU=LDAP/CN=ldap.local" \
  -addext "subjectAltName = DNS:ldap.local" \
  -nodes -keyout "$LDAP_CERTS_DIR/ldap.key" -out "$LDAP_CERTS_DIR/ldap.csr"

# Create SSL config file for LDAP
cat > "$CONFIG_SSL_DIR/ldap_ssl_config.txt" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = ldap.local
EOF

# Copy the config file to ldap-certs directory for backward compatibility
cp "$CONFIG_SSL_DIR/ldap_ssl_config.txt" "$LDAP_CERTS_DIR/"

# Sign LDAP Certificate with Root CA
openssl x509 -req -CA "$KEYS_DIR/rootCA.crt" -CAkey "$KEYS_DIR/rootCA.key" \
  -in "$LDAP_CERTS_DIR/ldap.csr" -out "$LDAP_CERTS_DIR/ldap.crt" -days 365 \
  -CAcreateserial -extfile "$CONFIG_SSL_DIR/ldap_ssl_config.txt"

# Create a proper chain certificate for Keycloak
cat "$KEYS_DIR/keycloak.crt" "$KEYS_DIR/rootCA.crt" > "$KEYS_DIR/keycloak-chain.crt"

# Create a proper chain certificate for LDAP
cat "$LDAP_CERTS_DIR/ldap.crt" "$KEYS_DIR/rootCA.crt" > "$LDAP_CERTS_DIR/ldap-chain.crt"

# Copy the root CA to a location for Passbolt container
cp "$KEYS_DIR/rootCA.crt" "$KEYS_DIR/ca.crt"

echo "Certificate generation complete!"
echo "Root CA: $KEYS_DIR/rootCA.crt"
echo "Keycloak cert: $KEYS_DIR/keycloak.crt"
echo "Keycloak key: $KEYS_DIR/keycloak.key"
echo "Keycloak chain: $KEYS_DIR/keycloak-chain.crt"
echo "LDAP cert: $LDAP_CERTS_DIR/ldap.crt"
echo "LDAP key: $LDAP_CERTS_DIR/ldap.key"
echo "LDAP chain: $LDAP_CERTS_DIR/ldap-chain.crt" 