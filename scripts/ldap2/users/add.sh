#!/bin/bash

# Add user to LDAP2 (Example Corp) directory
# Usage: ./add.sh <firstname> <lastname> <email>

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

if [ $# -ne 3 ]; then
    echo "Usage: $0 <firstname> <lastname> <email>"
    echo "Example: $0 \"Alex\" \"Thompson\" \"alex.thompson@example.com\""
    exit 1
fi

FIRSTNAME=$1
LASTNAME=$2
EMAIL=$3

# Extract username from email (part before @)
USERNAME=$(echo "$EMAIL" | cut -d@ -f1)

# LDAP2 Configuration (Example Corp)
LDAP_CONTAINER="ldap2"
LDAP_URL="ldap://localhost:389"
LDAP_ADMIN_DN="cn=admin,dc=example,dc=com"
LDAP_ADMIN_PASSWORD="Ex4mple123"
LDAP_BASE_DN="dc=example,dc=com"
LDAP_USERS_DN="ou=people,dc=example,dc=com"

# Get the highest existing employee number and increment by 1
NEXT_EMPLOYEE_NUMBER=$(docker compose exec $LDAP_CONTAINER ldapsearch -x -H $LDAP_URL -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "$LDAP_BASE_DN" "(objectClass=inetOrgPerson)" employeeNumber | grep "employeeNumber:" | cut -d' ' -f2 | sort -n | tail -1)
NEXT_EMPLOYEE_NUMBER=$((NEXT_EMPLOYEE_NUMBER + 1))

# Create full name for CN
FULL_NAME="$FIRSTNAME $LASTNAME"

# Create LDIF for the new user
LDIF_FILE="/tmp/$USERNAME.ldif"
cat > "$LDIF_FILE" << EOF
dn: cn=$FULL_NAME,$LDAP_USERS_DN
objectClass: inetOrgPerson
objectClass: top
objectClass: organizationalPerson
objectClass: person
cn: $FULL_NAME
uid: $USERNAME
sn: $LASTNAME
givenName: $FIRSTNAME
mail: $EMAIL
userPassword: $EMAIL
employeeNumber: $NEXT_EMPLOYEE_NUMBER
description: Example Corp employee
EOF

# Add the LDIF to LDAP
docker compose cp "$LDIF_FILE" $LDAP_CONTAINER:/tmp/"$USERNAME.ldif"
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy LDIF file to container"
    rm "$LDIF_FILE"
    exit 1
fi

# Add the user to LDAP
docker compose exec $LDAP_CONTAINER ldapadd -x -H $LDAP_URL -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/"$USERNAME.ldif"
if [ $? -ne 0 ]; then
    echo "Error: Failed to add user to LDAP2"
    docker compose exec $LDAP_CONTAINER rm /tmp/"$USERNAME.ldif"
    rm "$LDIF_FILE"
    exit 1
fi

# Clean up LDIF files
docker compose exec $LDAP_CONTAINER rm /tmp/"$USERNAME.ldif"
rm "$LDIF_FILE"

echo "User '$EMAIL' added to LDAP2 (Example Corp)"
echo "Full name: $FULL_NAME"
echo "Employee number: $NEXT_EMPLOYEE_NUMBER"
echo "Note: Users will be available through LDAP aggregation for Passbolt sync."
