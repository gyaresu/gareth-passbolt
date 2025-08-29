#!/bin/bash

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

# LDAP Configuration
LDAP_URL="ldap://ldap.local:389"
LDAP_ADMIN_DN="cn=admin,dc=passbolt,dc=local"
LDAP_ADMIN_PASSWORD="P4ssb0lt"
LDAP_BASE_DN="dc=passbolt,dc=local"

# Function for logging with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if all required parameters are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <groupname> <description> [email]"
    echo "Example: $0 developers \"Development Team\" betty@passbolt.com"
    exit 1
fi

GROUPNAME=$1
DESCRIPTION=$2
EMAIL=$3

log "Starting group creation process for group: '$GROUPNAME'"
log "Description: '$DESCRIPTION'"
if [ ! -z "$EMAIL" ]; then
    log "Initial member: '$EMAIL'"
fi

# Verify group name format
if [[ "$GROUPNAME" =~ ^[0-9]+$ ]]; then
    log "ERROR: Group name '$GROUPNAME' appears to be numeric. This may indicate a parsing issue."
    log "Please ensure the group name is a proper string identifier."
    exit 1
fi

# Check if group already exists
log "Checking if group '$GROUPNAME' already exists..."
if docker compose exec ldap ldapsearch -x -H "$LDAP_URL" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "$LDAP_BASE_DN" "(cn=$GROUPNAME)" | grep -q "dn: cn=$GROUPNAME"; then
    log "Group '$GROUPNAME' already exists in LDAP"
    exit 0
fi

# Create LDIF for the new group
LDIF_FILE="/tmp/$GROUPNAME.ldif"
log "Creating LDIF file: $LDIF_FILE"
cat > "$LDIF_FILE" << EOF
dn: cn=$GROUPNAME,ou=groups,dc=passbolt,dc=local
objectClass: groupOfUniqueNames
objectClass: top
cn: $GROUPNAME
description: $DESCRIPTION
EOF

# Add initial member if provided
if [ ! -z "$EMAIL" ]; then
    log "Verifying user '$EMAIL' exists..."
    USER_DN=$(docker compose exec ldap ldapsearch -x -H "$LDAP_URL" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "$LDAP_BASE_DN" "(mail=$EMAIL)" | grep "^dn: " | cut -d' ' -f2-)
    if [ -z "$USER_DN" ]; then
        log "ERROR: User '$EMAIL' does not exist in LDAP"
        rm "$LDIF_FILE"
        exit 1
    fi
    log "Adding user '$EMAIL' as initial member"
    echo "uniqueMember: $USER_DN" >> "$LDIF_FILE"
else
    log "No initial member provided, adding admin as placeholder (LDAP-only user)"
    echo "uniqueMember: cn=admin,dc=passbolt,dc=local" >> "$LDIF_FILE"
fi

# Add the LDIF to LDAP
log "Copying LDIF file to container..."
docker compose cp "$LDIF_FILE" ldap:/tmp/"$GROUPNAME.ldif"
if [ $? -ne 0 ]; then
    log "ERROR: Failed to copy LDIF file to container"
    rm "$LDIF_FILE"
    exit 1
fi

# Add the group to LDAP
log "Adding group to LDAP..."
docker compose exec ldap ldapadd -x -H "$LDAP_URL" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/"$GROUPNAME.ldif"
if [ $? -ne 0 ]; then
    log "ERROR: Failed to add group to LDAP"
    docker compose exec ldap rm /tmp/"$GROUPNAME.ldif"
    rm "$LDIF_FILE"
    exit 1
fi

# Verify group was created correctly
log "Verifying group creation..."
if ! docker compose exec ldap ldapsearch -x -H "$LDAP_URL" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "$LDAP_BASE_DN" "(cn=$GROUPNAME)" | grep -q "dn: cn=$GROUPNAME"; then
    log "ERROR: Group verification failed - group not found after creation"
    exit 1
fi

# Clean up LDIF files
log "Cleaning up temporary files..."
docker compose exec ldap rm /tmp/"$GROUPNAME.ldif"
rm "$LDIF_FILE"

if [ ! -z "$EMAIL" ]; then
    log "SUCCESS: Group '$GROUPNAME' added to LDAP with user '$EMAIL'"
else
    log "SUCCESS: Group '$GROUPNAME' added to LDAP (empty group)"
fi

# Final verification
log "Final group details:"
docker compose exec ldap ldapsearch -x -H "$LDAP_URL" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "$LDAP_BASE_DN" "(cn=$GROUPNAME)" | grep -E "^(cn|description|member):" 