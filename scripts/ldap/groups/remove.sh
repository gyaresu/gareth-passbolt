#!/bin/bash

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

# Check if groupname is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <groupname>"
    echo "Example: $0 developers"
    exit 1
fi

GROUPNAME=$1

# Verify group exists
if ! docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "dc=passbolt,dc=local" "(cn=$GROUPNAME)" | grep -q "dn: cn=$GROUPNAME"; then
    echo "Error: Group '$GROUPNAME' does not exist in LDAP"
    exit 1
fi

# Remove the group from LDAP
docker compose exec ldap ldapdelete -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt "cn=$GROUPNAME,ou=groups,dc=passbolt,dc=local"

if [ $? -ne 0 ]; then
    echo "Error: Failed to remove group from LDAP"
    exit 1
fi

# Verify group removal
echo "Verifying group removal..."
if docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "dc=passbolt,dc=local" "(cn=$GROUPNAME)" | grep -q "dn: cn=$GROUPNAME"; then
    echo "Error: Group '$GROUPNAME' still exists in LDAP after removal"
    exit 1
fi

echo "Group '$GROUPNAME' removed from LDAP" 