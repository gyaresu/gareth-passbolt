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
    docker compose exec ldap ldapsearch -x -H ldap://localhost \
        -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
        -b "dc=passbolt,dc=local" "(cn=$username)" | grep -q "dn: cn=$username,ou=users,dc=passbolt,dc=local"
    return $?
}

# Function to verify user exists in group
verify_user_in_group() {
    local email=$1
    local groupname=$2
    local username=$(get_username "$email")
    docker compose exec ldap ldapsearch -x -H ldap://localhost \
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
    docker compose exec ldap ldapmodify -x -H ldap://localhost \
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

echo "Starting LDAP Integration Tests..."

# Test 1: Create test user
echo "Test 1: Creating test user 'testuser@passbolt.com'..."
if "$LDAP_SCRIPTS_DIR/users/add.sh" "testuser@passbolt.com" "Test" "User"; then
    sleep 1  # Give LDAP time to process the change
    if verify_user_exists "testuser@passbolt.com"; then
        print_result 0 "Test user created successfully"
    else
        print_result 1 "Failed to verify user creation"
    fi
else
    print_result 1 "Failed to create test user"
fi

# Test 2: Create test group
echo "Test 2: Creating test group 'testgroup'..."
if "$LDAP_SCRIPTS_DIR/groups/add.sh" testgroup "Test Group" "testuser@passbolt.com"; then
    sleep 1  # Give LDAP time to process the change
    if verify_user_in_group "testuser@passbolt.com" "testgroup"; then
        print_result 0 "Test group created successfully"
    else
        print_result 1 "Failed to verify group creation"
    fi
else
    print_result 1 "Failed to create test group"
fi

# Test 3: Add another user to group
echo "Test 3: Adding admin to testgroup..."
if add_admin_to_group "testgroup"; then
    sleep 1  # Give LDAP time to process the change
    if docker compose exec ldap ldapsearch -x -H ldap://localhost \
        -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
        -b "dc=passbolt,dc=local" "(cn=testgroup)" | grep -q "uniqueMember: cn=admin,dc=passbolt,dc=local"; then
        print_result 0 "Admin added to group successfully"
    else
        print_result 1 "Failed to verify admin addition to group"
    fi
else
    print_result 1 "Failed to add admin to group"
fi

# Test 4: Remove test user from group
echo "Test 4: Removing testuser@passbolt.com from testgroup..."
if "$LDAP_SCRIPTS_DIR/groups/remove-user.sh" "testuser@passbolt.com" "testgroup"; then
    sleep 1  # Give LDAP time to process the change
    if ! verify_user_in_group "testuser@passbolt.com" "testgroup"; then
        print_result 0 "User removed from group successfully"
    else
        print_result 1 "Failed to verify user removal from group"
    fi
else
    print_result 1 "Failed to remove user from group"
fi

# Test 5: Remove test group
echo "Test 5: Removing testgroup..."
if "$LDAP_SCRIPTS_DIR/groups/remove.sh" "testgroup"; then
    sleep 1  # Give LDAP time to process the change
    if ! docker compose exec ldap ldapsearch -x -H ldap://localhost \
        -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
        -b "dc=passbolt,dc=local" "(cn=testgroup)" | grep -q "dn: cn=testgroup,ou=groups,dc=passbolt,dc=local"; then
        print_result 0 "Test group removed successfully"
    else
        print_result 1 "Failed to verify group removal"
    fi
else
    print_result 1 "Failed to remove test group"
fi

# Test 6: Remove test user
echo "Test 6: Removing testuser@passbolt.com..."
if "$LDAP_SCRIPTS_DIR/users/remove.sh" "testuser@passbolt.com"; then
    sleep 1  # Give LDAP time to process the change
    if ! verify_user_exists "testuser@passbolt.com"; then
        print_result 0 "Test user removed successfully"
    else
        print_result 1 "Failed to verify user removal"
    fi
else
    print_result 1 "Failed to remove test user"
fi

echo "Tests completed. Please check Passbolt and sync manually to verify changes." 