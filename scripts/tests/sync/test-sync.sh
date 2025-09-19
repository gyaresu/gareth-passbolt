#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
    fi
}

# Function to extract username from email
get_username() {
    echo "$1" | cut -d@ -f1
}

# Function to verify user exists in LDAP
verify_user_exists() {
    local email=$1
    local username=$(get_username "$email")
    docker compose exec ldap1 ldapsearch -x -H ldap://localhost \
        -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
        -b "dc=passbolt,dc=local" "(cn=$username)" | grep -q "dn: cn=$username,ou=users,dc=passbolt,dc=local"
    return $?
}

# Function to verify user exists in group
verify_user_in_group() {
    local email=$1
    local groupname=$2
    local username=$(get_username "$email")
    docker compose exec ldap1 ldapsearch -x -H ldap://localhost \
        -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
        -b "dc=passbolt,dc=local" "(cn=$groupname)" | grep -q "uniqueMember: cn=$username,ou=users,dc=passbolt,dc=local"
    return $?
}

# Function to add admin as default member to group
add_admin_to_group() {
    local groupname=$1
    local ldif_file="/tmp/add_admin_to_${groupname}.ldif"
    cat > "$ldif_file" << EOF
dn: cn=$groupname,ou=groups,dc=passbolt,dc=local
changetype: modify
add: uniqueMember
uniqueMember: cn=admin,dc=passbolt,dc=local
EOF
    docker compose cp "$ldif_file" "ldap:/tmp/add_admin_to_${groupname}.ldif"
    docker compose exec ldap1 ldapmodify -x -H ldap://localhost \
        -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
        -f "/tmp/add_admin_to_${groupname}.ldif"
    rm -f "$ldif_file"
}

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LDAP_SCRIPTS_DIR="$ROOT_DIR/ldap"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

echo "Starting LDAP Synchronization Tests..."

# Test 1: Create user and verify sync
echo "Test 1: Creating and syncing new user..."
if "$LDAP_SCRIPTS_DIR/users/add.sh" "sync@passbolt.com" "Sync" "Test"; then
    sleep 1  # Give LDAP time to process the change
    if verify_user_exists "sync@passbolt.com"; then
        print_result 0 "User created in LDAP"
    else
        print_result 1 "User not found in LDAP"
    fi
else
    print_result 1 "Failed to create user"
fi
echo "Please verify in Passbolt that sync@passbolt.com appears after sync"

# Test 2: Add user to group and verify sync
echo "Test 2: Adding user to group and syncing..."
if "$LDAP_SCRIPTS_DIR/groups/add.sh" synctest "Sync Test Group" "sync@passbolt.com"; then
    sleep 1  # Give LDAP time to process the change
    if verify_user_in_group "sync@passbolt.com" "synctest"; then
        print_result 0 "User added to group in LDAP"
    else
        print_result 1 "User not found in group"
    fi
else
    print_result 1 "Failed to add user to group"
fi
echo "Please verify in Passbolt that sync@passbolt.com is in synctest group after sync"

# Test 3: Remove user from group and verify sync
echo "Test 3: Removing user from group and syncing..."
# First add admin as a default member to prevent object class violation
if add_admin_to_group "synctest"; then
    sleep 1  # Give LDAP time to process the change
    if "$LDAP_SCRIPTS_DIR/groups/remove-user.sh" "sync@passbolt.com" "synctest"; then
        sleep 1  # Give LDAP time to process the change
        if ! verify_user_in_group "sync@passbolt.com" "synctest"; then
            print_result 0 "User removed from group in LDAP"
        else
            print_result 1 "User still in group"
        fi
    else
        print_result 1 "Failed to remove user from group"
    fi
else
    print_result 1 "Failed to add admin as default member"
fi
echo "Please verify in Passbolt that sync@passbolt.com is no longer in synctest group after sync"

# Test 4: Suspend user and verify sync
echo "Test 4: Suspending user and syncing..."
if "$LDAP_SCRIPTS_DIR/users/remove.sh" "sync@passbolt.com"; then
    sleep 1  # Give LDAP time to process the change
    if ! verify_user_exists "sync@passbolt.com"; then
        print_result 0 "User removed from LDAP"
    else
        print_result 1 "User still exists in LDAP"
    fi
else
    print_result 1 "Failed to remove user"
fi
echo "Please verify in Passbolt that sync@passbolt.com is suspended after sync"

# Test 5: Reactivate user and verify sync
echo "Test 5: Reactivating user and syncing..."
if "$LDAP_SCRIPTS_DIR/users/add.sh" "sync@passbolt.com" "Sync" "Test"; then
    sleep 1  # Give LDAP time to process the change
    if verify_user_exists "sync@passbolt.com"; then
        print_result 0 "User recreated in LDAP"
    else
        print_result 1 "User not found in LDAP"
    fi
else
    print_result 1 "Failed to recreate user"
fi
echo "Please verify in Passbolt that sync@passbolt.com is reactivated after sync"

# Cleanup
echo "Cleaning up test data..."
"$LDAP_SCRIPTS_DIR/users/remove.sh" "sync@passbolt.com"
"$LDAP_SCRIPTS_DIR/groups/remove.sh" synctest

echo "Test complete. Please run a manual sync in Passbolt to verify changes:"
echo "1. Log in to Passbolt as an administrator"
echo "2. Go to Organizational Settings > Users Directory"
echo "3. Click 'Synchronize Now'"
echo ""
echo "Note: These tests require manual verification in Passbolt after each sync."
echo "This helps ensure that the synchronization process is working correctly." 