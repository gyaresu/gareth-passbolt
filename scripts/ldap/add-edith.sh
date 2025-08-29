#!/bin/bash

# Create LDIF for Edith Clarke
cat > edith.ldif << 'EOF'
dn: cn=edith@passbolt.com,ou=users,dc=passbolt,dc=local
objectClass: inetOrgPerson
objectClass: posixAccount
cn: edith@passbolt.com
uid: edith@passbolt.com
sn: Clarke
givenName: Edith
mail: edith@passbolt.com
userPassword: edith@passbolt.com
uidNumber: 1004
gidNumber: 100
homeDirectory: /home/edith
loginShell: /bin/bash

# Add Edith to the passbolt group
dn: cn=passbolt,ou=groups,dc=passbolt,dc=local
changetype: modify
add: uniqueMember
uniqueMember: cn=edith@passbolt.com,ou=users,dc=passbolt,dc=local
EOF

# Add the LDIF to LDAP
docker compose cp edith.ldif ldap:/tmp/edith.ldif
docker compose exec ldap ldapadd -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/edith.ldif

# Clean up local LDIF file
rm edith.ldif
