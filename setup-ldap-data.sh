#!/bin/bash

# Stop all containers that might be using the volume
echo "Stopping containers..."
docker compose -f docker-compose-pro-current.yaml down

# Remove the existing volumes to start fresh
echo "Removing LDAP volumes..."
docker volume rm pro_working_ldap_data pro_working_ldap_config || true

# Create custom LDIF file
echo "Creating custom LDIF file..."
mkdir -p ldap-data

# Start the LDAP container with the new data
echo "Starting LDAP container..."
docker compose -f docker-compose-pro-current.yaml up -d ldap

# Wait for LDAP to be ready
echo "Waiting for LDAP to be ready..."
for i in {1..30}; do
  echo "Attempt $i to check LDAP server..."
  if docker exec ldap ldapsearch -x -H ldap://localhost:389 -b "dc=passbolt,dc=local" -D "cn=admin,dc=passbolt,dc=local" -w "P4ssb0lt" 2>/dev/null; then
    echo "LDAP server is ready!"
    break
  fi
  echo "LDAP server not ready yet, waiting..."
  sleep 2
done

# Generate a secure password hash using slappasswd
echo "Generating secure password hash..."
PASSWORD_HASH=$(docker exec ldap slappasswd -s "P4ssb0lt" -n)
echo "Generated hash: $PASSWORD_HASH"

# Create LDIF file with the hashed password
cat > ldap-data/01-users.ldif << EOF
# Create organizational unit for users
dn: ou=users,dc=passbolt,dc=local
objectClass: top
objectClass: organizationalUnit
ou: users
description: Passbolt Users

# Create organizational unit for groups
dn: ou=groups,dc=passbolt,dc=local
objectClass: top
objectClass: organizationalUnit
ou: groups
description: Passbolt Groups

# Create Ada user
dn: cn=ada,ou=users,dc=passbolt,dc=local
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: simpleSecurityObject
cn: ada
sn: Ada
givenName: Ada
mail: ada@passbolt.com
userPassword: $PASSWORD_HASH
description: Passbolt User
EOF

# Add the LDIF data using ldapadd
echo "Adding LDAP data..."
docker cp ldap-data/01-users.ldif ldap:/tmp/01-users.ldif
docker exec ldap ldapadd -x -H ldap://localhost:389 -b "dc=passbolt,dc=local" -D "cn=admin,dc=passbolt,dc=local" -w "P4ssb0lt" -f /tmp/01-users.ldif

# Check container logs for any issues
echo "Checking LDAP container logs..."
docker logs ldap

# Verify the data was loaded and show Ada's entry specifically
echo "Verifying Ada's LDAP entry..."
docker exec ldap ldapsearch -x -H ldap://localhost:389 -b "dc=passbolt,dc=local" -D "cn=admin,dc=passbolt,dc=local" -w "P4ssb0lt" "(cn=ada)"

# Test Ada's authentication using ldapwhoami
echo "Testing Ada's authentication with ldapwhoami..."
docker exec ldap ldapwhoami -x -H ldap://localhost:389 -D "cn=ada,ou=users,dc=passbolt,dc=local" -w "P4ssb0lt"

# Test STARTTLS connection
echo "Testing STARTTLS connection..."
docker exec ldap ldapsearch -Z -x -H ldap://localhost:389 -b "dc=passbolt,dc=local" -D "cn=admin,dc=passbolt,dc=local" -w "P4ssb0lt"

# Clean up
rm -rf ldap-data 