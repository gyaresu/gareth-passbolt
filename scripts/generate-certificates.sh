#!/bin/bash

# Define base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
KEYS_DIR="$BASE_DIR/keys"
# LDAP_CERTS_DIR="$BASE_DIR/ldap-certs"  # No longer needed - using LDAP server's own certificates
CONFIG_SSL_DIR="$BASE_DIR/config/ssl"

# Create directories if they don't exist
mkdir -p "$KEYS_DIR"
# mkdir -p "$LDAP_CERTS_DIR"  # No longer needed
mkdir -p "$CONFIG_SSL_DIR"

# --renew: re-sign the existing service certificates with the existing root CA.
# The service certs last 365 days and the root CA ten years, so renewing keeps
# every browser and container that already trusts the root CA working. A full run
# replaces the root CA, which then has to be trusted again everywhere.
if [ "${1:-}" = "--renew" ]; then
    set -e
    renew() {
        local name=$1 extfile=$2
        openssl x509 -req -CA "$KEYS_DIR/rootCA.crt" -CAkey "$KEYS_DIR/rootCA.key" \
          -in "$KEYS_DIR/$name.csr" -out "$KEYS_DIR/$name.crt" -days 365 \
          -CAcreateserial -extfile "$extfile"
        echo "Renewed $name: $(openssl x509 -in "$KEYS_DIR/$name.crt" -noout -enddate)"
    }
    renew keycloak "$CONFIG_SSL_DIR/keycloak_ssl_config.txt"
    renew passbolt "$CONFIG_SSL_DIR/passbolt_ssl_config.txt"
    renew smtp <(printf "subjectAltName=DNS:smtp.local")
    renew traefik <(printf "subjectAltName=DNS:traefik.local")
    cat "$KEYS_DIR/keycloak.crt" "$KEYS_DIR/rootCA.crt" > "$KEYS_DIR/keycloak-chain.crt"
    cat "$KEYS_DIR/passbolt.crt" "$KEYS_DIR/rootCA.crt" > "$KEYS_DIR/passbolt-chain.crt"
    echo "Restart traefik, keycloak and passbolt to serve the renewed certificates."
    exit 0
fi

# Generate Root CA Certificate
echo "Generating Root CA certificate..."
openssl req -x509 -sha256 -days 3650 -newkey rsa:2048 \
  -subj "/C=AU/ST=Tasmania/L=Hobart/O=Passbolt Asia Pacific/OU=Passbolt CA/CN=Passbolt Root CA" \
  -nodes -keyout "$KEYS_DIR/rootCA.key" -out "$KEYS_DIR/rootCA.crt"

# Generate Keycloak Certificate
echo "Generating Keycloak certificate..."
openssl req -newkey rsa:2048 \
  -subj "/C=AU/ST=Tasmania/L=Hobart/O=Passbolt Asia Pacific/OU=Keycloak/CN=keycloak.local" \
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

# LDAP Certificate generation removed - now using LDAP server's own certificates

# Generate Passbolt Certificate
echo "Generating Passbolt certificate..."
openssl req -newkey rsa:2048 \
  -subj "/C=AU/ST=Tasmania/L=Hobart/O=Passbolt Asia Pacific/OU=Department of Digital Shenanigans/CN=passbolt.local" \
  -addext "subjectAltName = DNS:passbolt.local" \
  -nodes -keyout "$KEYS_DIR/passbolt.key" -out "$KEYS_DIR/passbolt.csr"

# Create SSL config file for Passbolt
cat > "$CONFIG_SSL_DIR/passbolt_ssl_config.txt" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = passbolt.local
EOF

# Copy the config file to keys directory for backward compatibility
cp "$CONFIG_SSL_DIR/passbolt_ssl_config.txt" "$KEYS_DIR/"

# Sign Passbolt Certificate with Root CA
openssl x509 -req -CA "$KEYS_DIR/rootCA.crt" -CAkey "$KEYS_DIR/rootCA.key" \
  -in "$KEYS_DIR/passbolt.csr" -out "$KEYS_DIR/passbolt.crt" -days 365 \
  -CAcreateserial -extfile "$CONFIG_SSL_DIR/passbolt_ssl_config.txt"

# Create a proper chain certificate for Keycloak
cat "$KEYS_DIR/keycloak.crt" "$KEYS_DIR/rootCA.crt" > "$KEYS_DIR/keycloak-chain.crt"

# Create a proper chain certificate for Passbolt
cat "$KEYS_DIR/passbolt.crt" "$KEYS_DIR/rootCA.crt" > "$KEYS_DIR/passbolt-chain.crt"

# Generate SMTP Certificate
echo "Generating SMTP certificate..."
openssl req -newkey rsa:2048 \
  -subj "/C=AU/ST=Tasmania/L=Hobart/O=Passbolt Asia Pacific/OU=SMTP/CN=smtp.local" \
  -addext "subjectAltName = DNS:smtp.local" \
  -nodes -keyout "$KEYS_DIR/smtp.key" -out "$KEYS_DIR/smtp.csr"

openssl x509 -req -CA "$KEYS_DIR/rootCA.crt" -CAkey "$KEYS_DIR/rootCA.key" \
  -in "$KEYS_DIR/smtp.csr" -out "$KEYS_DIR/smtp.crt" -days 365 \
  -CAcreateserial -extfile <(printf "subjectAltName=DNS:smtp.local")

# Generate Traefik Certificate
echo "Generating Traefik certificate..."
openssl req -newkey rsa:2048 \
  -subj "/C=AU/ST=Tasmania/L=Hobart/O=Passbolt Asia Pacific/OU=Traefik/CN=traefik.local" \
  -addext "subjectAltName = DNS:traefik.local" \
  -nodes -keyout "$KEYS_DIR/traefik.key" -out "$KEYS_DIR/traefik.csr"

openssl x509 -req -CA "$KEYS_DIR/rootCA.crt" -CAkey "$KEYS_DIR/rootCA.key" \
  -in "$KEYS_DIR/traefik.csr" -out "$KEYS_DIR/traefik.crt" -days 365 \
  -CAcreateserial -extfile <(printf "subjectAltName=DNS:traefik.local")

# LDAP chain certificate creation removed - using LDAP server's own certificates

# Copy the root CA to a location for Passbolt container
cp "$KEYS_DIR/rootCA.crt" "$KEYS_DIR/ca.crt"

echo "Certificate generation complete!"
echo "Root CA: $KEYS_DIR/rootCA.crt"
echo "Keycloak cert: $KEYS_DIR/keycloak.crt"
echo "Keycloak key: $KEYS_DIR/keycloak.key"
echo "Keycloak chain: $KEYS_DIR/keycloak-chain.crt"
echo "Passbolt cert: $KEYS_DIR/passbolt.crt"
echo "Passbolt key: $KEYS_DIR/passbolt.key"
echo "Passbolt chain: $KEYS_DIR/passbolt-chain.crt"
echo "Note: LDAP certificates are now downloaded from the LDAP server automatically" 