#!/bin/bash

# Add group to LDAP2 (Example Corp) directory
# Usage: ./add.sh <groupname> <description> [email]

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

# Function for logging with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if all required parameters are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <groupname> <description> [email]"
    echo "Example: $0 marketing \"Marketing Team\" sarah.johnson@example.com"
    exit 1
fi

GROUPNAME=$1
DESCRIPTION=$2
EMAIL=$3

log "Starting group creation process for LDAP2 group: '$GROUPNAME'"
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
log "Checking if group '$GROUPNAME' already exists in LDAP2..."
if docker compose exec $LDAP_CONTAINER ldapsearch -x -H "$LDAP_URL" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "$LDAP_BASE_DN" "(cn=$GROUPNAME)" | grep -q "dn: cn=$GROUPNAME"; then
    log "Group '$GROUPNAME' already exists in LDAP2"
    exit 0
fi

# Create LDIF for the new group
LDIF_FILE="/tmp/$GROUPNAME.ldif"
log "Creating LDIF file: $LDIF_FILE"
cat > "$LDIF_FILE" << EOF
dn: cn=$GROUPNAME,$LDAP_GROUPS_DN
objectClass: groupOfUniqueNames
objectClass: top
cn: $GROUPNAME
description: $DESCRIPTION
EOF

# Add initial member if provided
if [ ! -z "$EMAIL" ]; then
    log "Verifying user '$EMAIL' exists in LDAP2..."
    USER_DN=$(docker compose exec $LDAP_CONTAINER ldapsearch -x -H "$LDAP_URL" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "$LDAP_BASE_DN" "(mail=$EMAIL)" | grep "^dn: " | cut -d' ' -f2-)
    if [ -z "$USER_DN" ]; then
        log "ERROR: User '$EMAIL' does not exist in LDAP2"
        rm "$LDIF_FILE"
        exit 1
    fi
    log "Adding user '$EMAIL' as initial member"
    echo "uniqueMember: $USER_DN" >> "$LDIF_FILE"
else
    log "No initial member provided, adding admin as placeholder"
    echo "uniqueMember: $LDAP_ADMIN_DN" >> "$LDIF_FILE"
fi

# Add the LDIF to LDAP
log "Copying LDIF file to LDAP2 container..."
docker compose cp "$LDIF_FILE" $LDAP_CONTAINER:/tmp/"$GROUPNAME.ldif"
if [ $? -ne 0 ]; then
    log "ERROR: Failed to copy LDIF file to LDAP2 container"
    rm "$LDIF_FILE"
    exit 1
fi

# Add the group to LDAP
log "Adding group to LDAP2..."
docker compose exec $LDAP_CONTAINER ldapadd -x -H "$LDAP_URL" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/"$GROUPNAME.ldif"
if [ $? -ne 0 ]; then
    log "ERROR: Failed to add group to LDAP2"
    docker compose exec $LDAP_CONTAINER rm /tmp/"$GROUPNAME.ldif"
    rm "$LDIF_FILE"
    exit 1
fi

# Verify group was created correctly
log "Verifying group creation..."
if ! docker compose exec $LDAP_CONTAINER ldapsearch -x -H "$LDAP_URL" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "$LDAP_BASE_DN" "(cn=$GROUPNAME)" | grep -q "dn: cn=$GROUPNAME"; then
    log "ERROR: Group verification failed - group not found after creation"
    exit 1
fi

# Clean up LDIF files
log "Cleaning up temporary files..."
docker compose exec $LDAP_CONTAINER rm /tmp/"$GROUPNAME.ldif"
rm "$LDIF_FILE"

if [ ! -z "$EMAIL" ]; then
    log "SUCCESS: Group '$GROUPNAME' added to LDAP2 with user '$EMAIL'"
else
    log "SUCCESS: Group '$GROUPNAME' added to LDAP2 (empty group)"
fi

# Final verification
log "Final group details:"
docker compose exec $LDAP_CONTAINER ldapsearch -x -H "$LDAP_URL" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "$LDAP_BASE_DN" "(cn=$GROUPNAME)" | grep -E "^(cn|description|uniqueMember):"
