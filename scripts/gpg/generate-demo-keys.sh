#!/bin/bash

# Generate ECC GPG keys for all demo users
# Uses modern Ed25519/Curve25519 elliptic curve cryptography
# Passphrase = email address for demo convenience
# This enables users to log into Passbolt with their demo credentials

set -e

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

# Create GPG keys directory
mkdir -p keys/gpg

echo "Generating GPG keys for demo users..."
echo "Note: Passphrase for each key = email address (for demo convenience)"

# Demo users from both directories
# Format: email:name pairs
DEMO_USERS="
ada@passbolt.com:Ada Lovelace
betty@passbolt.com:Betty Holberton
carol@passbolt.com:Carol Shaw
dame@passbolt.com:Dame Stephanie Shirley
edith@passbolt.com:Edith Clarke
john.smith@example.com:John Smith
sarah.johnson@example.com:Sarah Johnson
michael.chen@example.com:Michael Chen
lisa.rodriguez@example.com:Lisa Rodriguez
"

# Function to generate GPG key for a user
generate_user_key() {
    local email=$1
    local name=$2
    local key_file="keys/gpg/${email}.key"
    local pub_file="keys/gpg/${email}.pub"
    
    echo "Generating GPG key for $name ($email)..."
    
    # Create GPG batch file for automated key generation (using modern ECC)
    cat > /tmp/gpg_batch_${email//[@.]/_} << EOF
%echo Generating ECC GPG key for $name
Key-Type: EDDSA
Key-Curve: Ed25519
Subkey-Type: ECDH
Subkey-Curve: Curve25519
Name-Real: $name
Name-Email: $email
Expire-Date: 1y
Passphrase: $email
%commit
%echo ECC GPG key generated for $name
EOF

    # Generate the key
    gpg --batch --generate-key /tmp/gpg_batch_${email//[@.]/_}
    
    # Export private key
    gpg --batch --yes --pinentry-mode loopback --passphrase "$email" \
        --armor --export-secret-keys "$email" > "$key_file"
    
    # Export public key
    gpg --batch --yes --armor --export "$email" > "$pub_file"
    
    # Clean up batch file
    rm /tmp/gpg_batch_${email//[@.]/_}
    
    echo "✅ Generated ECC GPG key for $name"
    echo "   Private key: $key_file"
    echo "   Public key: $pub_file"
    echo "   Key type: Ed25519/Curve25519 (ECC)"
    echo "   Passphrase: $email"
    echo ""
}

# Generate keys for all demo users
echo "$DEMO_USERS" | while IFS=: read -r email name; do
    # Skip empty lines
    [ -z "$email" ] && continue
    
    # Check if key already exists
    if [ -f "keys/gpg/${email}.key" ]; then
        echo "⏭️  GPG key for $name ($email) already exists, skipping..."
        continue
    fi
    
    generate_user_key "$email" "$name"
done

echo "ECC GPG key generation complete!"
echo ""
echo "Generated modern ECC keys for:"
echo "📁 LDAP1 (Passbolt Inc.):"
echo "   - Ada Lovelace (ada@passbolt.com)"
echo "   - Betty Holberton (betty@passbolt.com)"
echo "   - Carol Shaw (carol@passbolt.com)"
echo "   - Dame Stephanie Shirley (dame@passbolt.com)"
echo "   - Edith Clarke (edith@passbolt.com)"
echo ""
echo "📁 LDAP2 (Example Corp.):"
echo "   - John Smith (john.smith@example.com)"
echo "   - Sarah Johnson (sarah.johnson@example.com)"
echo "   - Michael Chen (michael.chen@example.com)"
echo "   - Lisa Rodriguez (lisa.rodriguez@example.com)"
echo ""
echo "🔐 Key Details:"
echo "   • Algorithm: Ed25519 (EdDSA) + Curve25519 (ECDH)"
echo "   • Security: Modern elliptic curve cryptography"
echo "   • Performance: Faster than RSA, smaller key size"
echo "   • Passphrase: email address (for demo convenience)"
echo "📂 Keys stored in: keys/gpg/"
echo ""
echo "Next steps:"
echo "1. Users can import their private keys into Passbolt"
echo "2. Use email address as passphrase during import"
echo "3. Test login with aggregated LDAP users"
echo "4. Enjoy modern ECC cryptography performance!"
