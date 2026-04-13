-- Check action logs for secret update events
-- This helps understand if action logs can be used as an alternative source for modified dates

-- Recent secret/password related actions
SELECT '=== RECENT SECRET/PASSWORD ACTIONS ===' AS '';
SELECT 
    al.id,
    DATE_FORMAT(al.created, '%Y-%m-%d %H:%i:%s') AS log_created,
    al.action_id,
    al.context,
    al.status,
    -- Try to extract resource_id from context if it's in JSON format
    CASE 
        WHEN al.context LIKE '%"resource_id"%' THEN 
            SUBSTRING_INDEX(SUBSTRING_INDEX(al.context, '"resource_id":"', -1), '"', 1)
        ELSE NULL
    END AS extracted_resource_id
FROM action_logs al
WHERE (al.context LIKE '%secret%' 
   OR al.context LIKE '%password%'
   OR al.context LIKE '%Password%')
  AND al.created >= DATE_SUB(NOW(), INTERVAL 7 DAY)
ORDER BY al.created DESC
LIMIT 20;

SELECT '---' AS '';

-- Count actions by type
SELECT '=== ACTION COUNTS BY TYPE ===' AS '';
SELECT 
    action_id,
    COUNT(*) AS count,
    DATE_FORMAT(MIN(created), '%Y-%m-%d %H:%i:%s') AS first_seen,
    DATE_FORMAT(MAX(created), '%Y-%m-%d %H:%i:%s') AS last_seen
FROM action_logs
WHERE (context LIKE '%secret%' OR context LIKE '%password%' OR context LIKE '%Password%')
  AND created >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY action_id
ORDER BY count DESC;

SELECT '---' AS '';

-- Check if we can correlate action logs with resource modified dates
SELECT '=== ACTION LOGS VS RESOURCE MODIFIED (Sample) ===' AS '';
SELECT 
    r.id AS resource_id,
    DATE_FORMAT(r.modified, '%Y-%m-%d %H:%i:%s') AS resource_modified,
    DATE_FORMAT(MAX(al.created), '%Y-%m-%d %H:%i:%s') AS latest_action_log,
    COUNT(al.id) AS action_count,
    TIMESTAMPDIFF(SECOND, r.modified, MAX(al.created)) AS seconds_diff
FROM resources r
LEFT JOIN action_logs al ON al.context LIKE CONCAT('%', r.id, '%')
WHERE (r.deleted IS NULL OR r.deleted = '0000-00-00 00:00:00')
  AND al.created >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY r.id, r.modified
HAVING action_count > 0
ORDER BY ABS(seconds_diff) ASC
LIMIT 10;


