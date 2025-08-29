#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Change to project root
cd "$PROJECT_ROOT"

echo -e "\nStarting LDAP Script Tests...\n"

# Function to check if admin user exists
check_admin_exists() {
    if docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "dc=passbolt,dc=local" "(cn=admin)" | grep -q "cn: admin"; then
        return 0
    else
        return 1
    fi
}

# Function to verify user exists
verify_user_exists() {
    local username=$(echo "$1" | cut -d@ -f1)
    if docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "dc=passbolt,dc=local" "(cn=$username)" | grep -q "cn: $username"; then
        return 0
    else
        return 1
    fi
}

# Function to verify group exists
verify_group_exists() {
    if docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "dc=passbolt,dc=local" "(cn=$1)" | grep -q "cn: $1"; then
        return 0
    else
        return 1
    fi
}

# Function to verify user is in group
verify_user_in_group() {
    local username=$(echo "$1" | cut -d@ -f1)
    if docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -b "dc=passbolt,dc=local" "(cn=$2)" uniqueMember | grep -q "uniqueMember: cn=$username"; then
        return 0
    else
        return 1
    fi
}

# Test user management scripts
echo -e "${YELLOW}Testing User Management Scripts...${NC}"
echo "Test: Adding a user with add.sh..."
./scripts/ldap/users/add.sh "Script" "Test User" "script@passbolt.com"
if verify_user_exists "script@passbolt.com"; then
    echo -e "${GREEN}✓ User added successfully${NC}"
else
    echo -e "${RED}✗ Failed to add user${NC}"
fi

# Test group management scripts
echo -e "\n${YELLOW}Testing Group Management Scripts...${NC}"
echo "Test: Creating a group with add.sh..."
./scripts/ldap/groups/add.sh "scriptgroup" "Script Test Group" "script@passbolt.com"
if verify_group_exists "scriptgroup"; then
    echo -e "${GREEN}✓ Group created successfully${NC}"
else
    echo -e "${RED}✗ Failed to create group${NC}"
fi

echo "Test: Adding another user to group with add-user.sh..."
./scripts/ldap/users/add.sh "Script2" "Test User 2" "script2@passbolt.com"
./scripts/ldap/groups/add-user.sh "script2@passbolt.com" "scriptgroup"
if verify_user_in_group "script2@passbolt.com" "scriptgroup"; then
    echo -e "${GREEN}✓ User added to group successfully${NC}"
else
    echo -e "${RED}✗ Failed to add user to group${NC}"
fi

echo "Test: Removing user from group with remove-user.sh..."
./scripts/ldap/groups/remove-user.sh "script2@passbolt.com" "scriptgroup"
if ! verify_user_in_group "script2@passbolt.com" "scriptgroup"; then
    echo -e "${GREEN}✓ User removed from group successfully${NC}"
else
    echo -e "${RED}✗ Failed to remove user from group${NC}"
fi

echo "Test: Removing group with remove.sh..."
./scripts/ldap/groups/remove.sh "scriptgroup"
if ! verify_group_exists "scriptgroup"; then
    echo -e "${GREEN}✓ Group removed successfully${NC}"
else
    echo -e "${RED}✗ Failed to remove group${NC}"
fi

echo "Test: Removing users with remove.sh..."
./scripts/ldap/users/remove.sh "script@passbolt.com"
./scripts/ldap/users/remove.sh "script2@passbolt.com"
if ! verify_user_exists "script@passbolt.com" && ! verify_user_exists "script2@passbolt.com"; then
    echo -e "${GREEN}✓ Users removed successfully${NC}"
else
    echo -e "${RED}✗ Failed to remove users${NC}"
fi

# Test setup scripts
echo -e "\n${YELLOW}Testing Setup Scripts...${NC}"
echo "Test: Creating admin with create-admin.sh..."
if check_admin_exists; then
    echo -e "${YELLOW}✓ Admin user already exists (expected)${NC}"
else
    ./scripts/ldap/setup/create-admin.sh
    if check_admin_exists; then
        echo -e "${GREEN}✓ Admin created successfully${NC}"
    else
        echo -e "${RED}✗ Failed to create admin${NC}"
    fi
fi

echo "Test: Resetting groups with reset-groups.sh..."
./scripts/ldap/setup/reset-groups.sh
if verify_group_exists "passbolt" && verify_group_exists "developers" && verify_group_exists "demoteam"; then
    echo -e "${GREEN}✓ Groups reset successfully${NC}"
else
    echo -e "${RED}✗ Failed to reset groups${NC}"
fi

echo -e "\nTests completed. Please check Passbolt and sync manually to verify changes." 