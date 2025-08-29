#!/bin/bash

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

if [ $# -ne 1 ]; then
    echo "Usage: $0 <email>"
    echo "Example: $0 betty@passbolt.com"
    exit 1
fi

EMAIL=$1
USERNAME=$(echo "$EMAIL" | cut -d@ -f1)

# Check if user exists
if ! docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "dc=passbolt,dc=local" "(mail=$EMAIL)" | grep -q "dn: "; then
    echo "Error: User '$EMAIL' does not exist in LDAP"
    exit 1
fi

# Remove the user from LDAP
echo "Removing user '$EMAIL' from LDAP..."
docker compose exec ldap ldapdelete -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt "cn=$USERNAME,ou=users,dc=passbolt,dc=local"

if [ $? -ne 0 ]; then
    echo "Error: Failed to remove user from LDAP"
    exit 1
fi

# Verify user removal
echo "Verifying user removal..."
if docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "dc=passbolt,dc=local" "(mail=$EMAIL)" | grep -q "dn: "; then
    echo "Error: User '$EMAIL' still exists in LDAP after removal"
    exit 1
fi

echo "User '$EMAIL' removed from LDAP" 