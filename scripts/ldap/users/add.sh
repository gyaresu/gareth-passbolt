#!/bin/bash

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

if [ $# -ne 3 ]; then
    echo "Usage: $0 <firstname> <lastname> <email>"
    echo "Example: $0 \"Frances\" \"Test\" \"frances@passbolt.com\""
    exit 1
fi

FIRSTNAME=$1
LASTNAME=$2
EMAIL=$3

# Extract username from email (part before @)
USERNAME=$(echo "$EMAIL" | cut -d@ -f1)

# Get the highest existing employee number and increment by 1
NEXT_EMPLOYEE_NUMBER=$(docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "dc=passbolt,dc=local" "(objectClass=inetOrgPerson)" employeeNumber | grep "employeeNumber:" | cut -d' ' -f2 | sort -n | tail -1)
NEXT_EMPLOYEE_NUMBER=$((NEXT_EMPLOYEE_NUMBER + 1))

# Create LDIF for the new user
LDIF_FILE="/tmp/$USERNAME.ldif"
cat > "$LDIF_FILE" << EOF
dn: cn=$USERNAME,ou=users,dc=passbolt,dc=local
objectClass: inetOrgPerson
objectClass: top
objectClass: organizationalPerson
objectClass: person
cn: $USERNAME
uid: $USERNAME
sn: $LASTNAME
givenName: $FIRSTNAME
mail: $EMAIL
userPassword: $EMAIL
employeeNumber: $NEXT_EMPLOYEE_NUMBER
EOF

# Add the LDIF to LDAP
docker compose cp "$LDIF_FILE" ldap:/tmp/"$USERNAME.ldif"
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy LDIF file to container"
    rm "$LDIF_FILE"
    exit 1
fi

# Add the user to LDAP
docker compose exec ldap ldapadd -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/"$USERNAME.ldif"
if [ $? -ne 0 ]; then
    echo "Error: Failed to add user to LDAP"
    docker compose exec ldap rm /tmp/"$USERNAME.ldif"
    rm "$LDIF_FILE"
    exit 1
fi

# Clean up LDIF files
docker compose exec ldap rm /tmp/"$USERNAME.ldif"
rm "$LDIF_FILE"

echo "User '$EMAIL' added to LDAP"
echo "Note: Users need to activate their accounts in Passbolt before they can be added to groups."