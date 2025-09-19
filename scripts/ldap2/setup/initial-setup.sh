#!/bin/bash

# LDAP2 (Example Corp) Initial Setup Script
# Sets up users and groups in dc=example,dc=com directory
# Part of the LDAP aggregation demo showing company merger scenario

set -e

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

# LDAP2 Configuration (Example Corp)
LDAP_CONTAINER="ldap2"
LDAP_URL="ldap://localhost:389"
LDAP_ADMIN_DN="cn=admin,dc=example,dc=com"
LDAP_ADMIN_PASSWORD="Ex4mple123"
LDAP_BASE_DN="dc=example,dc=com"
LDAP_USERS_DN="ou=people,dc=example,dc=com"
LDAP_GROUPS_DN="ou=teams,dc=example,dc=com"

# Function to check if LDAP command succeeded
check_ldap_command() {
    if [ $? -ne 0 ]; then
        echo "Error: LDAP command failed"
        exit 1
    fi
}

# Function to verify user exists
verify_user_exists() {
    local username=$1
    docker compose exec $LDAP_CONTAINER ldapsearch -x -H $LDAP_URL \
        -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
        -b "cn=$username,$LDAP_USERS_DN" \
        "(objectClass=inetOrgPerson)" | grep -q "dn: cn=$username"
    check_ldap_command
}

echo "Setting up LDAP2 (Example Corp) directory: $LDAP_BASE_DN"

# Wait for LDAP2 container to be ready
echo "Waiting for LDAP2 container to be ready..."
for i in {1..30}; do
    if docker compose exec $LDAP_CONTAINER ldapsearch -x -H $LDAP_URL -b "$LDAP_BASE_DN" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" 2>/dev/null; then
        echo "LDAP2 server is ready!"
        break
    fi
    echo "Waiting for LDAP2... ($i/30)"
    sleep 2
done

# Create organizational units if they don't exist
echo "Creating organizational units..."
LDIF_FILE="/tmp/ldap2_ous.ldif"
cat > "$LDIF_FILE" << EOF
dn: $LDAP_USERS_DN
objectClass: organizationalUnit
ou: people

dn: $LDAP_GROUPS_DN
objectClass: organizationalUnit
ou: teams
EOF

docker compose cp "$LDIF_FILE" $LDAP_CONTAINER:/tmp/ous.ldif
docker compose exec $LDAP_CONTAINER ldapadd -x -H $LDAP_URL -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/ous.ldif || echo 'Some entries may already exist'
docker compose exec $LDAP_CONTAINER rm /tmp/ous.ldif
rm "$LDIF_FILE"

# Remove existing users and groups (clean slate)
echo "Cleaning existing users and groups..."
for user in $(docker compose exec $LDAP_CONTAINER ldapsearch -x -H $LDAP_URL -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "$LDAP_USERS_DN" "(objectClass=inetOrgPerson)" | grep "cn: " | cut -d' ' -f2 | tr -d '\r'); do
    if [ ! -z "$user" ]; then
        echo "Removing user '$user'..."
        docker compose exec $LDAP_CONTAINER ldapdelete -x -H $LDAP_URL \
            -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
            "cn=$user,$LDAP_USERS_DN" || true
    fi
done

for group in $(docker compose exec $LDAP_CONTAINER ldapsearch -x -H $LDAP_URL -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "$LDAP_GROUPS_DN" "(objectClass=groupOfUniqueNames)" | grep "cn: " | cut -d' ' -f2 | tr -d '\r'); do
    if [ ! -z "$group" ]; then
        echo "Removing group '$group'..."
        docker compose exec $LDAP_CONTAINER ldapdelete -x -H $LDAP_URL \
            -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
            "cn=$group,$LDAP_GROUPS_DN" || true
    fi
done

# Create Example Corp users (acquired company)
echo "Creating Example Corp users..."

# John Smith - Project Manager
echo "Adding John Smith..."
cat > /tmp/john.ldif << EOF
dn: cn=John Smith,$LDAP_USERS_DN
objectClass: inetOrgPerson
objectClass: top
objectClass: organizationalPerson
objectClass: person
cn: John Smith
sn: Smith
givenName: John
mail: john.smith@example.com
userPassword: john.smith@example.com
uid: john.smith
employeeNumber: 101
title: Project Manager
departmentNumber: PM
description: Project Manager - leads cross-functional teams
EOF
docker compose cp /tmp/john.ldif $LDAP_CONTAINER:/tmp/john.ldif
docker compose exec $LDAP_CONTAINER ldapadd -x -H $LDAP_URL -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/john.ldif
check_ldap_command
docker compose exec $LDAP_CONTAINER rm /tmp/john.ldif
rm /tmp/john.ldif
verify_user_exists "John Smith"

# Sarah Johnson - Security Analyst
echo "Adding Sarah Johnson..."
cat > /tmp/sarah.ldif << EOF
dn: cn=Sarah Johnson,$LDAP_USERS_DN
objectClass: inetOrgPerson
objectClass: top
objectClass: organizationalPerson
objectClass: person
cn: Sarah Johnson
sn: Johnson
givenName: Sarah
mail: sarah.johnson@example.com
userPassword: sarah.johnson@example.com
uid: sarah.johnson
employeeNumber: 102
title: Security Analyst
departmentNumber: SEC
description: Security Analyst - protects company assets and data
EOF
docker compose cp /tmp/sarah.ldif $LDAP_CONTAINER:/tmp/sarah.ldif
docker compose exec $LDAP_CONTAINER ldapadd -x -H $LDAP_URL -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/sarah.ldif
check_ldap_command
docker compose exec $LDAP_CONTAINER rm /tmp/sarah.ldif
rm /tmp/sarah.ldif
verify_user_exists "Sarah Johnson"

# Michael Chen - DevOps Engineer
echo "Adding Michael Chen..."
cat > /tmp/michael.ldif << EOF
dn: cn=Michael Chen,$LDAP_USERS_DN
objectClass: inetOrgPerson
objectClass: top
objectClass: organizationalPerson
objectClass: person
cn: Michael Chen
sn: Chen
givenName: Michael
mail: michael.chen@example.com
userPassword: michael.chen@example.com
uid: michael.chen
employeeNumber: 103
title: DevOps Engineer
departmentNumber: ENG
description: DevOps Engineer - bridges development and operations
EOF
docker compose cp /tmp/michael.ldif $LDAP_CONTAINER:/tmp/michael.ldif
docker compose exec $LDAP_CONTAINER ldapadd -x -H $LDAP_URL -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/michael.ldif
check_ldap_command
docker compose exec $LDAP_CONTAINER rm /tmp/michael.ldif
rm /tmp/michael.ldif
verify_user_exists "Michael Chen"

# Lisa Rodriguez - UX Designer
echo "Adding Lisa Rodriguez..."
cat > /tmp/lisa.ldif << EOF
dn: cn=Lisa Rodriguez,$LDAP_USERS_DN
objectClass: inetOrgPerson
objectClass: top
objectClass: organizationalPerson
objectClass: person
cn: Lisa Rodriguez
sn: Rodriguez
givenName: Lisa
mail: lisa.rodriguez@example.com
userPassword: lisa.rodriguez@example.com
uid: lisa.rodriguez
employeeNumber: 104
title: UX Designer
departmentNumber: DES
description: UX Designer - creates intuitive user experiences
EOF
docker compose cp /tmp/lisa.ldif $LDAP_CONTAINER:/tmp/lisa.ldif
docker compose exec $LDAP_CONTAINER ldapadd -x -H $LDAP_URL -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/lisa.ldif
check_ldap_command
docker compose exec $LDAP_CONTAINER rm /tmp/lisa.ldif
rm /tmp/lisa.ldif
verify_user_exists "Lisa Rodriguez"

# Create Example Corp groups
echo "Creating Example Corp groups..."

# Project Teams
echo "Adding project-teams group..."
cat > /tmp/project_teams.ldif << EOF
dn: cn=project-teams,$LDAP_GROUPS_DN
objectClass: groupOfUniqueNames
objectClass: top
cn: project-teams
description: Project Teams - cross-functional project groups
uniqueMember: cn=John Smith,$LDAP_USERS_DN
uniqueMember: cn=Sarah Johnson,$LDAP_USERS_DN
uniqueMember: cn=Michael Chen,$LDAP_USERS_DN
EOF
docker compose cp /tmp/project_teams.ldif $LDAP_CONTAINER:/tmp/project_teams.ldif
docker compose exec $LDAP_CONTAINER ldapadd -x -H $LDAP_URL -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/project_teams.ldif
check_ldap_command
docker compose exec $LDAP_CONTAINER rm /tmp/project_teams.ldif
rm /tmp/project_teams.ldif

# Security Team
echo "Adding security group..."
cat > /tmp/security.ldif << EOF
dn: cn=security,$LDAP_GROUPS_DN
objectClass: groupOfUniqueNames
objectClass: top
cn: security
description: Security Team - information security specialists
uniqueMember: cn=Sarah Johnson,$LDAP_USERS_DN
EOF
docker compose cp /tmp/security.ldif $LDAP_CONTAINER:/tmp/security.ldif
docker compose exec $LDAP_CONTAINER ldapadd -x -H $LDAP_URL -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/security.ldif
check_ldap_command
docker compose exec $LDAP_CONTAINER rm /tmp/security.ldif
rm /tmp/security.ldif

# Operations Team
echo "Adding operations group..."
cat > /tmp/operations.ldif << EOF
dn: cn=operations,$LDAP_GROUPS_DN
objectClass: groupOfUniqueNames
objectClass: top
cn: operations
description: Operations Team - infrastructure and deployment
uniqueMember: cn=Michael Chen,$LDAP_USERS_DN
EOF
docker compose cp /tmp/operations.ldif $LDAP_CONTAINER:/tmp/operations.ldif
docker compose exec $LDAP_CONTAINER ldapadd -x -H $LDAP_URL -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/operations.ldif
check_ldap_command
docker compose exec $LDAP_CONTAINER rm /tmp/operations.ldif
rm /tmp/operations.ldif

# Creative Team
echo "Adding creative group..."
cat > /tmp/creative.ldif << EOF
dn: cn=creative,$LDAP_GROUPS_DN
objectClass: groupOfUniqueNames
objectClass: top
cn: creative
description: Creative Team - design and user experience
uniqueMember: cn=Lisa Rodriguez,$LDAP_USERS_DN
EOF
docker compose cp /tmp/creative.ldif $LDAP_CONTAINER:/tmp/creative.ldif
docker compose exec $LDAP_CONTAINER ldapadd -x -H $LDAP_URL -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/creative.ldif
check_ldap_command
docker compose exec $LDAP_CONTAINER rm /tmp/creative.ldif
rm /tmp/creative.ldif

echo "LDAP2 (Example Corp) setup complete!"
echo ""
echo "Created users:"
echo "  - john.smith@example.com (Project Manager)"
echo "  - sarah.johnson@example.com (Security Analyst)"
echo "  - michael.chen@example.com (DevOps Engineer)"
echo "  - lisa.rodriguez@example.com (UX Designer)"
echo ""
echo "Created groups:"
echo "  - project-teams (John, Sarah, Michael)"
echo "  - security (Sarah)"
echo "  - operations (Michael)"
echo "  - creative (Lisa)"
echo ""
echo "Ready for LDAP aggregation with Passbolt Inc. directory!"
