#!/bin/bash

# Test script to investigate if resource modified date updates when secret is updated
# This script is READ-ONLY and safe to run

set -e

DB_HOST="${DB_HOST:-db}"
DB_USER="${DB_USER:-passbolt}"
DB_PASS="${DB_PASS:-P4ssb0lt}"
DB_NAME="${DB_NAME:-passbolt}"

echo "=== Testing Resource Modified Date on Secret Update ==="
echo ""
echo "This script will help investigate if resource.modified updates when secrets are updated."
echo ""

# Check if we're running in docker or locally
if command -v docker &> /dev/null && docker compose ps 2>/dev/null | grep -q db; then
    echo "Running queries via Docker container..."
    DOCKER_CMD="docker compose exec -T db mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME}"
elif command -v docker &> /dev/null; then
    echo "Docker compose not running. Please start your containers first:"
    echo "  docker compose up -d"
    exit 1
else
    echo "Running queries directly (assuming mysql client is available)..."
    DOCKER_CMD="mysql -h${DB_HOST} -u${DB_USER} -p${DB_PASS} ${DB_NAME}"
fi

echo ""
echo "Step 1: Finding a test resource with secrets..."
echo "----------------------------------------"

cat <<'SQL' | $DOCKER_CMD
SELECT 
    r.id AS resource_id,
    DATE_FORMAT(r.created, '%Y-%m-%d %H:%i:%s') AS resource_created,
    DATE_FORMAT(r.modified, '%Y-%m-%d %H:%i:%s') AS resource_modified,
    COUNT(s.id) AS secret_count,
    DATE_FORMAT(MAX(s.modified), '%Y-%m-%d %H:%i:%s') AS latest_secret_modified
FROM resources r
LEFT JOIN secrets s ON r.id = s.resource_id AND (s.deleted IS NULL OR s.deleted = '0000-00-00 00:00:00')
WHERE (r.deleted IS NULL OR r.deleted = '0000-00-00 00:00:00')
GROUP BY r.id, r.created, r.modified
HAVING secret_count > 0
ORDER BY r.modified DESC
LIMIT 3;
SQL

echo ""
echo "Step 2: Checking if resources with recently modified secrets have updated resource.modified..."
echo "----------------------------------------"

cat <<'SQL' | $DOCKER_CMD
SELECT 
    r.id AS resource_id,
    DATE_FORMAT(r.modified, '%Y-%m-%d %H:%i:%s') AS resource_modified,
    DATE_FORMAT(MAX(s.modified), '%Y-%m-%d %H:%i:%s') AS latest_secret_modified,
    TIMESTAMPDIFF(SECOND, r.modified, MAX(s.modified)) AS seconds_diff,
    CASE 
        WHEN MAX(s.modified) > r.modified THEN 'SECRET_NEWER - Resource modified date NOT updated'
        WHEN MAX(s.modified) = r.modified THEN 'SAME_TIME - Possibly updated together'
        WHEN MAX(s.modified) < r.modified THEN 'RESOURCE_NEWER - Resource updated after secret'
        ELSE 'NO_SECRETS'
    END AS comparison
FROM resources r
LEFT JOIN secrets s ON r.id = s.resource_id AND (s.deleted IS NULL OR s.deleted = '0000-00-00 00:00:00')
WHERE (r.deleted IS NULL OR r.deleted = '0000-00-00 00:00:00')
GROUP BY r.id, r.modified
HAVING latest_secret_modified IS NOT NULL
ORDER BY ABS(TIMESTAMPDIFF(SECOND, r.modified, MAX(s.modified))) DESC
LIMIT 10;
SQL

echo ""
echo "Step 3: Recent action logs related to secrets/resources..."
echo "----------------------------------------"

cat <<'SQL' | $DOCKER_CMD
SELECT 
    DATE_FORMAT(created, '%Y-%m-%d %H:%i:%s') AS log_time,
    action_id,
    SUBSTRING(context, 1, 100) AS context_preview,
    status
FROM action_logs
WHERE (context LIKE '%secret%' OR context LIKE '%password%' OR context LIKE '%resource%')
  AND created >= DATE_SUB(NOW(), INTERVAL 7 DAY)
ORDER BY created DESC
LIMIT 15;
SQL

echo ""
echo "=== Manual Testing Instructions ==="
echo ""
echo "To test if resource.modified updates when a secret is updated:"
echo ""
echo "1. Pick a resource ID from Step 1 above"
echo "2. Record the current resource.modified timestamp"
echo "3. Update the secret for that resource via the browser extension"
echo "4. Run this query to check if resource.modified changed:"
echo ""
echo "   SELECT id, created, modified FROM resources WHERE id = '<RESOURCE_ID>';"
echo ""
echo "5. Compare the modified timestamp before and after the secret update"
echo ""
echo "=== End of Test ==="

