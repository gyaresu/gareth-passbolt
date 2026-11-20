#!/bin/bash

# Rewrite the LDAP1 group members as unified DNs, in place, on a stack set up
# before initial-setup.sh wrote them that way. Only the groups' uniqueMember
# values change; users are not touched.
#
# Do not re-run initial-setup.sh for this: it deletes and recreates the users,
# which gives them new entryUUIDs, and the next directory sync then deletes the
# passbolt accounts and re-adds them as new users who must complete setup again.
#
# The memberships below mirror initial-setup.sh. Run directory sync afterwards.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

UNIFIED_USERS_DN="ou=users,dc=passbolt,dc=unified,dc=local"

# set_members GROUP USER...
set_members() {
    local group=$1
    shift
    echo "Setting members of '$group': $*"
    {
        echo "dn: cn=$group,ou=groups,dc=passbolt,dc=local"
        echo "changetype: modify"
        echo "replace: uniqueMember"
        for user in "$@"; do
            echo "uniqueMember: cn=$user,$UNIFIED_USERS_DN"
        done
    } | docker compose exec -T ldap1 ldapmodify -x -H ldaps://localhost:636 \
        -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt
}

set_members passbolt ada betty carol dame edith
set_members developers ada betty carol
set_members demoteam betty edith
set_members admins ada dame

echo "Group members updated. Run directory sync to pick them up."
