-- Diagnostic queries for "duplicate users before activation" bug
-- Customer: Enzy AMGHAR
-- Issue: Users receive TWO enrollment emails, TWO accounts created in database
--
-- Run with: mysql -u passbolt -p passbolt < diagnose-duplicate-users.sql

-- ============================================
-- 1. Find ALL duplicate users (same username/email)
-- ============================================
SELECT '=== DUPLICATE USERS BY USERNAME ===' AS '';

SELECT
    username,
    COUNT(*) as duplicate_count,
    GROUP_CONCAT(id ORDER BY created) as user_ids,
    GROUP_CONCAT(active ORDER BY created) as active_states,
    GROUP_CONCAT(IFNULL(deleted, 'NULL') ORDER BY created) as deleted_states,
    MIN(created) as first_created,
    MAX(created) as last_created,
    TIMESTAMPDIFF(SECOND, MIN(created), MAX(created)) as seconds_between
FROM users
WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
GROUP BY username
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, first_created DESC;

-- ============================================
-- 2. Analyze timing patterns to identify cause
-- ============================================
SELECT '=== TIMING ANALYSIS ===' AS '';

SELECT
    username,
    COUNT(*) as dup_count,
    TIMESTAMPDIFF(SECOND, MIN(created), MAX(created)) as seconds_apart,
    CASE
        WHEN TIMESTAMPDIFF(SECOND, MIN(created), MAX(created)) = 0 THEN 'SAME SECOND - Race condition in single sync'
        WHEN TIMESTAMPDIFF(SECOND, MIN(created), MAX(created)) < 5 THEN 'RACE CONDITION - Concurrent sync processes'
        WHEN TIMESTAMPDIFF(SECOND, MIN(created), MAX(created)) < 60 THEN 'OVERLAPPING SYNC - Processes ran close together'
        WHEN TIMESTAMPDIFF(SECOND, MIN(created), MAX(created)) < 3600 THEN 'MULTIPLE SYNC RUNS - Within same hour'
        ELSE 'SEPARATE SYNC RUNS - Different time periods'
    END as likely_cause
FROM users
WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
GROUP BY username
HAVING COUNT(*) > 1
ORDER BY seconds_apart;

-- ============================================
-- 3. All duplicate user details
-- ============================================
SELECT '=== DUPLICATE USER DETAILS ===' AS '';

SELECT
    u.id,
    u.username,
    u.active,
    u.deleted,
    u.created,
    u.modified,
    CASE
        WHEN g.fingerprint IS NOT NULL THEN 'Has GPG key'
        ELSE 'No GPG key'
    END as gpg_status
FROM users u
LEFT JOIN gpgkeys g ON u.id = g.user_id
WHERE u.username IN (
    SELECT username FROM users
    WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
    GROUP BY username
    HAVING COUNT(*) > 1
)
ORDER BY u.username, u.created;

-- ============================================
-- 4. Check directory_entries for sync metadata
-- ============================================
SELECT '=== DIRECTORY ENTRIES FOR DUPLICATES ===' AS '';

SELECT
    de.id,
    de.foreign_model,
    de.foreign_key,
    de.directory_name,
    de.dn,
    de.created,
    de.modified,
    u.username as passbolt_user,
    u.active as user_active,
    u.created as user_created
FROM directory_entries de
LEFT JOIN users u ON de.foreign_key = u.id
WHERE de.foreign_model = 'Users'
  AND de.directory_name IN (
    SELECT username FROM users
    WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
    GROUP BY username
    HAVING COUNT(*) > 1
  )
ORDER BY de.directory_name, de.created;

-- ============================================
-- 5. Users created within same minute (batch analysis)
-- ============================================
SELECT '=== USERS CREATED IN SAME MINUTE ===' AS '';

SELECT
    DATE_FORMAT(created, '%Y-%m-%d %H:%i') as minute_bucket,
    COUNT(*) as users_created,
    GROUP_CONCAT(username ORDER BY created) as usernames
FROM users
WHERE created > DATE_SUB(NOW(), INTERVAL 30 DAY)
  AND (deleted IS NULL OR deleted = '0000-00-00 00:00:00')
GROUP BY DATE_FORMAT(created, '%Y-%m-%d %H:%i')
HAVING COUNT(*) > 1
ORDER BY minute_bucket DESC
LIMIT 50;

-- ============================================
-- 6. Check action logs for sync operations
-- ============================================
SELECT '=== RECENT DIRECTORY SYNC OPERATIONS ===' AS '';

SELECT
    al.created,
    al.action_id,
    u.username as actor,
    SUBSTRING(al.context, 1, 300) as context_preview
FROM action_logs al
LEFT JOIN users u ON al.user_id = u.id
WHERE al.action_id LIKE '%Directory%'
   OR al.action_id LIKE '%Sync%'
   OR al.action_id LIKE '%UsersAdd%'
   OR al.action_id LIKE '%User%Create%'
ORDER BY al.created DESC
LIMIT 50;

-- ============================================
-- 7. Check for constraint violations potential
-- ============================================
SELECT '=== DATABASE CONSTRAINTS CHECK ===' AS '';

-- Check if username has unique constraint
SELECT
    'users' as table_name,
    CASE
        WHEN COUNT(*) > 0 THEN 'HAS unique constraint on username'
        ELSE 'NO unique constraint on username - VULNERABLE TO DUPLICATES'
    END as constraint_status
FROM information_schema.TABLE_CONSTRAINTS tc
JOIN information_schema.KEY_COLUMN_USAGE kcu
    ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    AND tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
WHERE tc.TABLE_SCHEMA = DATABASE()
  AND tc.TABLE_NAME = 'users'
  AND tc.CONSTRAINT_TYPE = 'UNIQUE'
  AND kcu.COLUMN_NAME = 'username';

-- ============================================
-- 8. Summary statistics
-- ============================================
SELECT '=== SUMMARY ===' AS '';

SELECT
    'Total users' as metric,
    COUNT(*) as value
FROM users
WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
UNION ALL
SELECT
    'Active users',
    COUNT(*)
FROM users
WHERE active = 1 AND (deleted IS NULL OR deleted = '0000-00-00 00:00:00')
UNION ALL
SELECT
    'Pending activation',
    COUNT(*)
FROM users
WHERE active = 0 AND (deleted IS NULL OR deleted = '0000-00-00 00:00:00')
UNION ALL
SELECT
    'Duplicate usernames',
    COUNT(DISTINCT username)
FROM users
WHERE username IN (
    SELECT username FROM users
    WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
    GROUP BY username
    HAVING COUNT(*) > 1
)
AND (deleted IS NULL OR deleted = '0000-00-00 00:00:00')
UNION ALL
SELECT
    'Total duplicate records',
    COUNT(*)
FROM users
WHERE username IN (
    SELECT username FROM users
    WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
    GROUP BY username
    HAVING COUNT(*) > 1
)
AND (deleted IS NULL OR deleted = '0000-00-00 00:00:00');
