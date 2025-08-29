#!/bin/bash

# AD/LDAP User Restore Script for Passbolt
# Usage: ./restore_ad_user.sh [username] [database_name] [mysql_user] [mysql_password]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -ne 4 ]; then
    echo -e "${RED}Usage: $0 [username] [database_name] [mysql_user] [mysql_password]${NC}"
    echo -e "${YELLOW}Example: $0 betty@passbolt.com passbolt passbolt P4ssb0lt${NC}"
    exit 1
fi

USERNAME=$1
DATABASE=$2
MYSQL_USER=$3
MYSQL_PASSWORD=$4

# Functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
}

# MySQL connection function
mysql_exec() {
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$DATABASE" -e "$1" 2>/dev/null
}

# Main script
log "Starting AD/LDAP user restore for: $USERNAME"

# Step 1: Check if user exists
log "Checking if user exists..."
USER_ID=$(mysql_exec "SELECT id FROM users WHERE username = '$USERNAME';" | tail -n +2 | tr -d ' ')

if [ -z "$USER_ID" ]; then
    error "User $USERNAME not found in database"
    exit 1
fi

success "Found user with ID: $USER_ID"

# Step 2: Create backup
BACKUP_FILE="backup_before_restore_$(date +%Y%m%d_%H%M%S).sql"
log "Creating backup: $BACKUP_FILE"
mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$DATABASE" > "$BACKUP_FILE"
success "Backup created: $BACKUP_FILE"

# Step 3: Remove user completely
log "Removing user completely..."

# Delete user record
mysql_exec "DELETE FROM users WHERE username = '$USERNAME';"
success "Deleted user record"

# Delete GPG key
mysql_exec "DELETE FROM gpgkeys WHERE user_id = '$USER_ID';"
success "Deleted GPG key"

# Delete profile
mysql_exec "DELETE FROM profiles WHERE user_id = '$USER_ID';"
success "Deleted profile"

# Remove group memberships
mysql_exec "DELETE FROM groups_users WHERE user_id = '$USER_ID';"
success "Removed group memberships"

# Clear directory entry foreign key
mysql_exec "UPDATE directory_entries SET foreign_key = NULL WHERE foreign_model = 'Users' AND directory_name LIKE '%$USERNAME%';"
success "Cleared directory entry foreign key"

# Step 4: Verify removal
log "Verifying complete removal..."
USER_CHECK=$(mysql_exec "SELECT COUNT(*) FROM users WHERE username = '$USERNAME';" | tail -n +2 | tr -d ' ')

if [ "$USER_CHECK" -eq 0 ]; then
    success "User completely removed from database"
else
    error "User still exists in database"
    exit 1
fi

# Step 5: Check directory entry
log "Checking directory entry status..."
DIR_ENTRY=$(mysql_exec "SELECT foreign_key FROM directory_entries WHERE foreign_model = 'Users' AND directory_name LIKE '%$USERNAME%';" | tail -n +2 | tr -d ' ')

if [ "$DIR_ENTRY" = "NULL" ]; then
    success "Directory entry foreign key cleared"
else
    warning "Directory entry foreign key may not be cleared"
fi

# Step 6: Final instructions
echo ""
success "User restoration completed successfully!"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Go to Passbolt web UI → Users"
echo "2. Find user '$USERNAME' (will appear as pending)"
echo "3. Click 'Resend activation email'"
echo "4. User completes activation and setup"
echo ""
echo -e "${BLUE}Backup file: $BACKUP_FILE${NC}"
echo -e "${BLUE}Directory entry is ready for re-creation${NC}"
