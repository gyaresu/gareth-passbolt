#!/bin/bash

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

if [ $# -ne 2 ]; then
    echo "Usage: $0 <email> <groupname>"
    echo "Example: $0 betty@passbolt.com developers"
    exit 1
fi

EMAIL=$1
GROUPNAME=$2
USERNAME=$(echo "$EMAIL" | cut -d@ -f1)

# Check if user exists
if ! docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "dc=passbolt,dc=local" "(mail=$EMAIL)" | grep -q "dn: "; then
    echo "Error: User '$EMAIL' does not exist in LDAP"
    exit 1
fi

# Check if group exists
if ! docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "dc=passbolt,dc=local" "(cn=$GROUPNAME)" | grep -q "dn: cn=$GROUPNAME"; then
    echo "Error: Group '$GROUPNAME' does not exist in LDAP"
    exit 1
fi

# Check if user exists in group
if ! docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "dc=passbolt,dc=local" "(cn=$GROUPNAME)" | grep -q "uniqueMember: cn=$USERNAME,ou=users,dc=passbolt,dc=local"; then
    echo "User '$EMAIL' is not a member of group '$GROUPNAME'"
    exit 0
fi

# Create LDIF for removing user from group
LDIF_FILE="/tmp/remove_$USERNAME_from_$GROUPNAME.ldif"
cat > "$LDIF_FILE" << EOF
dn: cn=$GROUPNAME,ou=groups,dc=passbolt,dc=local
changetype: modify
delete: uniqueMember
uniqueMember: cn=$USERNAME,ou=users,dc=passbolt,dc=local
EOF

# Remove the user from the group
docker compose cp "$LDIF_FILE" ldap:/tmp/remove_$USERNAME_from_$GROUPNAME.ldif
docker compose exec ldap ldapmodify -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/remove_$USERNAME_from_$GROUPNAME.ldif

# Clean up
docker compose exec ldap rm /tmp/remove_$USERNAME_from_$GROUPNAME.ldif
rm "$LDIF_FILE"

echo "User '$EMAIL' removed from group '$GROUPNAME'" 