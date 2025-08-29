#!/bin/bash

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

# Function to extract username from email
get_username() {
    echo "$1" | cut -d@ -f1
}

# Create organizational units if they don't exist
echo "Creating organizational units..."
LDIF_FILE="/tmp/ous.ldif"
cat > "$LDIF_FILE" << EOF
dn: ou=users,dc=passbolt,dc=local
objectClass: organizationalUnit
ou: users

dn: ou=groups,dc=passbolt,dc=local
objectClass: organizationalUnit
ou: groups
EOF

docker compose cp "$LDIF_FILE" ldap:/tmp/ous.ldif
docker compose exec ldap ldapadd -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/ous.ldif || true
docker compose exec ldap rm /tmp/ous.ldif
rm "$LDIF_FILE"

# Remove all existing users and groups
echo "Removing all existing users and groups..."
for user in $(docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "ou=users,dc=passbolt,dc=local" "(objectClass=inetOrgPerson)" | grep "cn: " | cut -d' ' -f2); do
    echo "Removing user '$user'..."
    docker compose exec ldap ldapdelete -x -H ldaps://localhost:636 \
        -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
        "cn=$user,ou=users,dc=passbolt,dc=local"
done

for group in $(docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "ou=groups,dc=passbolt,dc=local" "(objectClass=groupOfUniqueNames)" | grep "cn: " | cut -d' ' -f2); do
    echo "Removing group '$group'..."
    docker compose exec ldap ldapdelete -x -H ldaps://localhost:636 \
        -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
        "cn=$group,ou=groups,dc=passbolt,dc=local"
done

# Create initial users
echo "Creating initial users..."

# Betty
echo "Adding Betty..."
cat > /tmp/betty.ldif << EOF
dn: cn=betty,ou=users,dc=passbolt,dc=local
objectClass: inetOrgPerson
objectClass: top
objectClass: organizationalPerson
objectClass: person
cn: betty
sn: Holberton
givenName: Betty
mail: betty@passbolt.com
userPassword: betty@passbolt.com
uid: betty
employeeNumber: 2
EOF
docker compose cp /tmp/betty.ldif ldap:/tmp/betty.ldif
docker compose exec ldap ldapadd -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/betty.ldif || true
docker compose exec ldap rm /tmp/betty.ldif
rm /tmp/betty.ldif

# Carol
echo "Adding Carol..."
cat > /tmp/carol.ldif << EOF
dn: cn=carol,ou=users,dc=passbolt,dc=local
objectClass: inetOrgPerson
objectClass: top
objectClass: organizationalPerson
objectClass: person
cn: carol
sn: Shaw
givenName: Carol
mail: carol@passbolt.com
userPassword: carol@passbolt.com
uid: carol
employeeNumber: 3
EOF
docker compose cp /tmp/carol.ldif ldap:/tmp/carol.ldif
docker compose exec ldap ldapadd -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/carol.ldif || true
docker compose exec ldap rm /tmp/carol.ldif
rm /tmp/carol.ldif

# Dame
echo "Adding Dame..."
cat > /tmp/dame.ldif << EOF
dn: cn=dame,ou=users,dc=passbolt,dc=local
objectClass: inetOrgPerson
objectClass: top
objectClass: organizationalPerson
objectClass: person
cn: dame
sn: Shirley
givenName: Stephanie
mail: dame@passbolt.com
userPassword: dame@passbolt.com
uid: dame
employeeNumber: 4
EOF
docker compose cp /tmp/dame.ldif ldap:/tmp/dame.ldif
docker compose exec ldap ldapadd -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/dame.ldif || true
docker compose exec ldap rm /tmp/dame.ldif
rm /tmp/dame.ldif

# Edith
echo "Adding Edith..."
cat > /tmp/edith.ldif << EOF
dn: cn=edith,ou=users,dc=passbolt,dc=local
objectClass: inetOrgPerson
objectClass: top
objectClass: organizationalPerson
objectClass: person
cn: edith
sn: Clarke
givenName: Edith
mail: edith@passbolt.com
userPassword: edith@passbolt.com
uid: edith
employeeNumber: 5
EOF
docker compose cp /tmp/edith.ldif ldap:/tmp/edith.ldif
docker compose exec ldap ldapadd -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/edith.ldif || true
docker compose exec ldap rm /tmp/edith.ldif
rm /tmp/edith.ldif

echo "Users created. Please wait for Passbolt to sync users before continuing..."
echo "To sync:"
echo "1. Log in to Passbolt as an administrator"
echo "2. Go to Organizational Settings > Users Directory"
echo "3. Click 'Synchronize Now'"
echo "4. Press Enter here when sync is complete"
read -r

# Create new groups
echo "Creating groups..."

# Passbolt group
echo "Adding passbolt group..."
cat > /tmp/passbolt.ldif << EOF
dn: cn=passbolt,ou=groups,dc=passbolt,dc=local
objectClass: groupOfUniqueNames
objectClass: top
cn: passbolt
description: Passbolt Users Group
uniqueMember: cn=betty,ou=users,dc=passbolt,dc=local
uniqueMember: cn=carol,ou=users,dc=passbolt,dc=local
uniqueMember: cn=dame,ou=users,dc=passbolt,dc=local
EOF
docker compose cp /tmp/passbolt.ldif ldap:/tmp/passbolt.ldif
docker compose exec ldap ldapadd -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/passbolt.ldif || true
docker compose exec ldap rm /tmp/passbolt.ldif
rm /tmp/passbolt.ldif

# Developers group
echo "Adding developers group..."
cat > /tmp/developers.ldif << EOF
dn: cn=developers,ou=groups,dc=passbolt,dc=local
objectClass: groupOfUniqueNames
objectClass: top
cn: developers
description: Development Team
uniqueMember: cn=admin,dc=passbolt,dc=local
uniqueMember: cn=dame,ou=users,dc=passbolt,dc=local
EOF
docker compose cp /tmp/developers.ldif ldap:/tmp/developers.ldif
docker compose exec ldap ldapadd -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/developers.ldif || true
docker compose exec ldap rm /tmp/developers.ldif
rm /tmp/developers.ldif

# Demoteam group
echo "Adding demoteam group..."
cat > /tmp/demoteam.ldif << EOF
dn: cn=demoteam,ou=groups,dc=passbolt,dc=local
objectClass: groupOfUniqueNames
objectClass: top
cn: demoteam
description: Demo Team
uniqueMember: cn=betty,ou=users,dc=passbolt,dc=local
uniqueMember: cn=edith,ou=users,dc=passbolt,dc=local
EOF
docker compose cp /tmp/demoteam.ldif ldap:/tmp/demoteam.ldif
docker compose exec ldap ldapadd -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/demoteam.ldif || true
docker compose exec ldap rm /tmp/demoteam.ldif
rm /tmp/demoteam.ldif

# Admins group
echo "Adding admins group..."
cat > /tmp/admins.ldif << EOF
dn: cn=admins,ou=groups,dc=passbolt,dc=local
objectClass: groupOfUniqueNames
objectClass: top
cn: admins
description: Administrators
uniqueMember: cn=admin,dc=passbolt,dc=local
EOF
docker compose cp /tmp/admins.ldif ldap:/tmp/admins.ldif
docker compose exec ldap ldapadd -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/admins.ldif || true
docker compose exec ldap rm /tmp/admins.ldif
rm /tmp/admins.ldif

echo "Groups created. Please run a final sync in Passbolt."
echo "To sync:"
echo "1. Go to Organizational Settings > Users Directory"
echo "2. Click 'Synchronize Now'" 