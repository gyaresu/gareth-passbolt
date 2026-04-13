#!/bin/bash
# Test script to reproduce "duplicate users before activation" bug
# Usage: ./scripts/tests/test-duplicate-user-bug.sh
#
# This test simulates the customer issue reported by Enzy AMGHAR where:
# - Users are added to AD enrollment group
# - Cron job runs directory sync
# - Some users receive TWO enrollment emails
# - TWO accounts created in database (same username/email)
#
# Root cause hypothesis: Race condition during directory sync

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

# Test user details
TEST_USER_CN="andrea"
TEST_USER_EMAIL="andrea.abrante@passbolt.com"
TEST_USER_FIRST="Andrea"
TEST_USER_LAST="Abrante"
ENROL_GROUP="passbolt-enrolment"
TEAM_GROUP="passbolt-team-sigp"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Duplicate User Bug Reproduction Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Test user: $TEST_USER_EMAIL"
echo "Enrollment group: $ENROL_GROUP"
echo "Team group: $TEAM_GROUP"
echo ""

# Function: Check user count in DB (non-deleted users only)
check_user_count() {
    local count=$(docker compose exec -T db mariadb -u passbolt -pP4ssb0lt passbolt -N -e \
        "SELECT COUNT(*) FROM users WHERE username = '$TEST_USER_EMAIL' AND (deleted IS NULL OR deleted = '0000-00-00 00:00:00');")
    echo "$count" | tr -d '[:space:]'
}

# Function: Show all test users
show_test_users() {
    echo -e "${YELLOW}Users matching '$TEST_USER_EMAIL':${NC}"
    docker compose exec -T db mariadb -u passbolt -pP4ssb0lt passbolt -e \
        "SELECT id, username, active, deleted, created, modified FROM users WHERE username LIKE '%andrea%' ORDER BY created;" 2>/dev/null || echo "No users found"
}

# Function: Run directory sync
run_sync() {
    local label="$1"
    echo -e "${YELLOW}Running sync: $label${NC}"
    docker compose exec passbolt su -s /bin/bash -c \
        "/usr/share/php/passbolt/bin/cake directory_sync all --persist" www-data 2>&1 | head -30
}

# Function: Check for duplicates
check_duplicates() {
    docker compose exec -T db mariadb -u passbolt -pP4ssb0lt passbolt -N -e \
        "SELECT COUNT(*) FROM (SELECT username FROM users WHERE (deleted IS NULL OR deleted = '0000-00-00 00:00:00') GROUP BY username HAVING COUNT(*) > 1) AS dupes;"
}

# ============================================
# Phase 1: Cleanup
# ============================================
echo -e "${YELLOW}Phase 1: Cleanup existing test data${NC}"

# Remove user from Passbolt DB (soft delete)
echo "  Soft-deleting any existing test user from database..."
docker compose exec -T db mariadb -u passbolt -pP4ssb0lt passbolt -e \
    "UPDATE users SET deleted = NOW() WHERE username = '$TEST_USER_EMAIL';" 2>/dev/null || true

# Remove from LDAP
echo "  Removing test user from LDAP..."
docker compose exec ldap1 ldapdelete -x -H ldaps://localhost:636 \
    -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
    "cn=$TEST_USER_CN,ou=users,dc=passbolt,dc=local" 2>/dev/null || true

echo "  Removing test groups from LDAP..."
docker compose exec ldap1 ldapdelete -x -H ldaps://localhost:636 \
    -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
    "cn=$ENROL_GROUP,ou=groups,dc=passbolt,dc=local" 2>/dev/null || true
docker compose exec ldap1 ldapdelete -x -H ldaps://localhost:636 \
    -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
    "cn=$TEAM_GROUP,ou=groups,dc=passbolt,dc=local" 2>/dev/null || true

echo -e "${GREEN}  Cleanup complete${NC}"
sleep 2

# ============================================
# Phase 2: Create LDAP entries
# ============================================
echo ""
echo -e "${YELLOW}Phase 2: Creating LDAP user and groups${NC}"

# Create user LDIF
cat > /tmp/test_user.ldif << EOF
dn: cn=$TEST_USER_CN,ou=users,dc=passbolt,dc=local
objectClass: inetOrgPerson
objectClass: top
objectClass: organizationalPerson
objectClass: person
cn: $TEST_USER_CN
sn: $TEST_USER_LAST
givenName: $TEST_USER_FIRST
mail: $TEST_USER_EMAIL
userPassword: test123
uid: $TEST_USER_CN
employeeNumber: 99
EOF

# Create enrolment group LDIF
cat > /tmp/enrol_group.ldif << EOF
dn: cn=$ENROL_GROUP,ou=groups,dc=passbolt,dc=local
objectClass: groupOfUniqueNames
objectClass: top
cn: $ENROL_GROUP
description: Passbolt User Enrolment Group
uniqueMember: cn=$TEST_USER_CN,ou=users,dc=passbolt,dc=local
EOF

# Create team group LDIF
cat > /tmp/team_group.ldif << EOF
dn: cn=$TEAM_GROUP,ou=groups,dc=passbolt,dc=local
objectClass: groupOfUniqueNames
objectClass: top
cn: $TEAM_GROUP
description: SIGP Team Group
uniqueMember: cn=$TEST_USER_CN,ou=users,dc=passbolt,dc=local
EOF

# Add to LDAP
echo "  Adding test user to LDAP..."
docker compose cp /tmp/test_user.ldif ldap1:/tmp/test_user.ldif
docker compose exec ldap1 ldapadd -x -H ldaps://localhost:636 \
    -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/test_user.ldif

echo "  Adding enrollment group to LDAP..."
docker compose cp /tmp/enrol_group.ldif ldap1:/tmp/enrol_group.ldif
docker compose exec ldap1 ldapadd -x -H ldaps://localhost:636 \
    -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/enrol_group.ldif

echo "  Adding team group to LDAP..."
docker compose cp /tmp/team_group.ldif ldap1:/tmp/team_group.ldif
docker compose exec ldap1 ldapadd -x -H ldaps://localhost:636 \
    -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt -f /tmp/team_group.ldif

echo -e "${GREEN}  LDAP entries created${NC}"

# Verify LDAP
echo ""
echo "  Verifying LDAP user:"
docker compose exec ldap1 ldapsearch -x -H ldaps://localhost:636 \
    -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
    -b "dc=passbolt,dc=local" "(cn=$TEST_USER_CN)" cn mail 2>/dev/null | grep -E "^(dn|cn|mail):" || echo "  User verification failed"

# ============================================
# Phase 3: Baseline check
# ============================================
echo ""
echo -e "${YELLOW}Phase 3: Baseline check${NC}"
BASELINE_COUNT=$(check_user_count)
echo "  Active users with email '$TEST_USER_EMAIL' before sync: $BASELINE_COUNT"

# ============================================
# Phase 4: First sync
# ============================================
echo ""
echo -e "${YELLOW}Phase 4: First directory sync (should create user)${NC}"
run_sync "First sync"
sleep 3

AFTER_FIRST=$(check_user_count)
echo ""
echo -e "  User count after first sync: ${BLUE}$AFTER_FIRST${NC}"
show_test_users

# ============================================
# Phase 5: Second sync (WITHOUT activating)
# ============================================
echo ""
echo -e "${YELLOW}Phase 5: Second directory sync (user NOT activated)${NC}"
echo -e "${RED}  NOTE: The user has NOT been activated - testing for duplicate creation${NC}"
run_sync "Second sync (user pending)"
sleep 3

AFTER_SECOND=$(check_user_count)
echo ""
echo -e "  User count after second sync: ${BLUE}$AFTER_SECOND${NC}"
show_test_users

# ============================================
# Phase 6: Concurrent sync test
# ============================================
echo ""
echo -e "${YELLOW}Phase 6: Concurrent sync test (race condition simulation)${NC}"
echo "  Running 5 syncs in parallel to trigger race condition..."

# Clean up any test user first to test fresh creation race
docker compose exec -T db mariadb -u passbolt -pP4ssb0lt passbolt -e \
    "DELETE FROM users WHERE username = '$TEST_USER_EMAIL';" 2>/dev/null || true

# Short delay to ensure cleanup is committed
sleep 1

# Launch 5 concurrent syncs
for i in {1..5}; do
    docker compose exec passbolt su -s /bin/bash -c \
        "/usr/share/php/passbolt/bin/cake directory_sync all --persist" www-data > /tmp/sync_$i.log 2>&1 &
    echo "    Started sync process $i (PID: $!)"
done

echo "  Waiting for all sync processes to complete..."
wait
sleep 3

AFTER_CONCURRENT=$(check_user_count)
echo ""
echo -e "  User count after concurrent syncs: ${BLUE}$AFTER_CONCURRENT${NC}"
show_test_users

# ============================================
# Phase 7: Results
# ============================================
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}           TEST RESULTS${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

TOTAL_DUPLICATES=$(check_duplicates)

if [ "$AFTER_CONCURRENT" -gt 1 ]; then
    echo -e "${RED}BUG REPRODUCED: $AFTER_CONCURRENT duplicate users created!${NC}"
    echo ""
    echo "Evidence of duplicate users:"
    docker compose exec -T db mariadb -u passbolt -pP4ssb0lt passbolt -e "
    SELECT
        id,
        username,
        active,
        deleted,
        created,
        TIMESTAMPDIFF(SECOND, LAG(created) OVER (ORDER BY created), created) as seconds_since_prev
    FROM users
    WHERE username = '$TEST_USER_EMAIL'
    ORDER BY created;
    "
    echo ""
    echo -e "${YELLOW}Analysis:${NC}"
    echo "  - Multiple user records exist for the same email"
    echo "  - Check 'seconds_since_prev' to determine if race condition (< 5s)"
    echo "  - This confirms the bug reported by customer"
elif [ "$AFTER_FIRST" -eq 1 ] && [ "$AFTER_SECOND" -eq 1 ] && [ "$AFTER_CONCURRENT" -eq 1 ]; then
    echo -e "${GREEN}No duplicates created - bug NOT reproduced${NC}"
    echo ""
    echo "The bug may require:"
    echo "  - Higher concurrency (more parallel processes)"
    echo "  - Multiple Passbolt nodes/containers"
    echo "  - Specific database timing conditions"
    echo "  - Different Passbolt version"
else
    echo -e "${YELLOW}Unexpected state: $AFTER_CONCURRENT users${NC}"
fi

# Show any duplicates in the entire database
echo ""
echo -e "${YELLOW}Checking for any duplicates in entire database:${NC}"
docker compose exec -T db mariadb -u passbolt -pP4ssb0lt passbolt -e "
SELECT
    username,
    COUNT(*) as count,
    GROUP_CONCAT(active ORDER BY created) as active_states,
    MIN(created) as first_created,
    MAX(created) as last_created,
    TIMESTAMPDIFF(SECOND, MIN(created), MAX(created)) as seconds_between
FROM users
WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
GROUP BY username
HAVING COUNT(*) > 1;
" 2>/dev/null || echo "No duplicates found in database"

# Cleanup temp files
rm -f /tmp/test_user.ldif /tmp/enrol_group.ldif /tmp/team_group.ldif /tmp/sync_*.log

echo ""
echo -e "${YELLOW}Test complete.${NC}"
echo ""
echo "Next steps:"
echo "  1. Check SMTP4Dev for enrollment emails: https://smtp.local"
echo "  2. Review sync logs: docker compose logs passbolt | grep -i sync"
echo "  3. To cleanup: ./scripts/tests/test-duplicate-user-bug.sh --cleanup"
