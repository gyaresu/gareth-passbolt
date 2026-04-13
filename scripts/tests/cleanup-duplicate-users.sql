-- Cleanup script for duplicate users
-- Customer: Enzy AMGHAR
-- WARNING: Review output carefully before running DELETE commands
--
-- Run with: mysql -u passbolt -p passbolt < cleanup-duplicate-users.sql

-- ============================================
-- 1. Preview duplicates to be cleaned
-- ============================================
SELECT '=== DUPLICATES TO CLEAN (PREVIEW) ===' AS '';

-- For each duplicate set, identify which one to KEEP and which to DELETE
-- Strategy: Keep the OLDEST non-deleted, non-activated record OR the ACTIVATED one
SELECT
    'TO DELETE' as action,
    u.id,
    u.username,
    u.active,
    u.created,
    CASE
        WHEN u.id = keep.keep_id THEN 'KEEP (oldest/activated)'
        ELSE 'DELETE (duplicate)'
    END as recommendation
FROM users u
JOIN (
    -- Subquery to find duplicates
    SELECT username
    FROM users
    WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
    GROUP BY username
    HAVING COUNT(*) > 1
) dups ON u.username = dups.username
JOIN (
    -- Subquery to identify which record to KEEP for each username
    -- Priority: 1) Active user, 2) Oldest created
    SELECT
        username,
        COALESCE(
            (SELECT id FROM users u2 WHERE u2.username = u1.username AND u2.active = 1
             AND (u2.deleted IS NULL OR u2.deleted = '0000-00-00 00:00:00')
             ORDER BY u2.created LIMIT 1),
            (SELECT id FROM users u2 WHERE u2.username = u1.username
             AND (u2.deleted IS NULL OR u2.deleted = '0000-00-00 00:00:00')
             ORDER BY u2.created LIMIT 1)
        ) as keep_id
    FROM users u1
    WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
    GROUP BY username
    HAVING COUNT(*) > 1
) keep ON u.username = keep.username
WHERE u.deleted IS NULL OR u.deleted = '0000-00-00 00:00:00'
ORDER BY u.username, u.created;

-- ============================================
-- 2. Generate DELETE statements (soft delete)
-- ============================================
SELECT '=== GENERATED SOFT DELETE STATEMENTS ===' AS '';

SELECT CONCAT(
    'UPDATE users SET deleted = NOW() WHERE id = ''',
    u.id,
    '''; -- Duplicate of: ', u.username, ' (created: ', u.created, ', active: ', u.active, ')'
) as soft_delete_sql
FROM users u
JOIN (
    SELECT username
    FROM users
    WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
    GROUP BY username
    HAVING COUNT(*) > 1
) dups ON u.username = dups.username
JOIN (
    SELECT
        username,
        COALESCE(
            (SELECT id FROM users u2 WHERE u2.username = u1.username AND u2.active = 1
             AND (u2.deleted IS NULL OR u2.deleted = '0000-00-00 00:00:00')
             ORDER BY u2.created LIMIT 1),
            (SELECT id FROM users u2 WHERE u2.username = u1.username
             AND (u2.deleted IS NULL OR u2.deleted = '0000-00-00 00:00:00')
             ORDER BY u2.created LIMIT 1)
        ) as keep_id
    FROM users u1
    WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
    GROUP BY username
    HAVING COUNT(*) > 1
) keep ON u.username = keep.username
WHERE (u.deleted IS NULL OR u.deleted = '0000-00-00 00:00:00')
  AND u.id != keep.keep_id
ORDER BY u.username;

-- ============================================
-- 3. Also clean up related directory_entries
-- ============================================
SELECT '=== DIRECTORY ENTRIES TO CLEAN ===' AS '';

SELECT CONCAT(
    'DELETE FROM directory_entries WHERE foreign_key = ''',
    u.id,
    '''; -- Entry for duplicate user: ', u.username
) as delete_entry_sql
FROM users u
JOIN (
    SELECT username
    FROM users
    WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
    GROUP BY username
    HAVING COUNT(*) > 1
) dups ON u.username = dups.username
JOIN (
    SELECT
        username,
        COALESCE(
            (SELECT id FROM users u2 WHERE u2.username = u1.username AND u2.active = 1
             AND (u2.deleted IS NULL OR u2.deleted = '0000-00-00 00:00:00')
             ORDER BY u2.created LIMIT 1),
            (SELECT id FROM users u2 WHERE u2.username = u1.username
             AND (u2.deleted IS NULL OR u2.deleted = '0000-00-00 00:00:00')
             ORDER BY u2.created LIMIT 1)
        ) as keep_id
    FROM users u1
    WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
    GROUP BY username
    HAVING COUNT(*) > 1
) keep ON u.username = keep.username
WHERE (u.deleted IS NULL OR u.deleted = '0000-00-00 00:00:00')
  AND u.id != keep.keep_id;

-- ============================================
-- IMPORTANT: Manual verification required
-- ============================================
SELECT '=== IMPORTANT ===' AS '';
SELECT 'Review the generated SQL statements above carefully before executing.' as warning;
SELECT 'Copy the UPDATE statements and run them manually after verification.' as instruction;
SELECT 'Always backup the database before making changes.' as recommendation;
