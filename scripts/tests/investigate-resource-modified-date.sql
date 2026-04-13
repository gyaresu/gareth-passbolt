-- Investigation: Does resource modified date update when secret is updated?
-- READ-ONLY queries to understand the schema and behavior
-- Safe for production - no modifications

-- Step 1: Check the schema of resources and secrets tables
SELECT '===_RESOURCES_TABLE_SCHEMA_===' AS '';
SELECT 
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT,
    EXTRA
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'passbolt' 
  AND TABLE_NAME = 'resources'
  AND COLUMN_NAME IN ('id', 'created', 'modified', 'deleted')
ORDER BY ORDINAL_POSITION;

SELECT '---' AS '';

SELECT '===_SECRETS_TABLE_SCHEMA_===' AS '';
SELECT 
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT,
    EXTRA
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'passbolt' 
  AND TABLE_NAME = 'secrets'
  AND COLUMN_NAME IN ('id', 'resource_id', 'user_id', 'created', 'modified', 'deleted', 'data')
ORDER BY ORDINAL_POSITION;

SELECT '---' AS '';

-- Step 2: Find a resource with secrets to test with
SELECT '===_SAMPLE_RESOURCE_WITH_SECRETS_===' AS '';
SELECT 
    r.id AS resource_id,
    r.created AS resource_created,
    r.modified AS resource_modified,
    COUNT(s.id) AS secret_count,
    MAX(s.created) AS latest_secret_created,
    MAX(s.modified) AS latest_secret_modified
FROM resources r
LEFT JOIN secrets s ON r.id = s.resource_id AND (s.deleted IS NULL OR s.deleted = '0000-00-00 00:00:00')
WHERE (r.deleted IS NULL OR r.deleted = '0000-00-00 00:00:00')
GROUP BY r.id, r.created, r.modified
HAVING secret_count > 0
ORDER BY r.modified DESC
LIMIT 5;

SELECT '---' AS '';

-- Step 3: Check if there's a pattern - do resources with recently modified secrets have updated resource.modified?
SELECT '===_RESOURCE_VS_SECRET_MODIFIED_COMPARISON_===' AS '';
SELECT 
    r.id AS resource_id,
    DATE_FORMAT(r.created, '%Y-%m-%d %H:%i:%s') AS resource_created,
    DATE_FORMAT(r.modified, '%Y-%m-%d %H:%i:%s') AS resource_modified,
    DATE_FORMAT(MAX(s.created), '%Y-%m-%d %H:%i:%s') AS latest_secret_created,
    DATE_FORMAT(MAX(s.modified), '%Y-%m-%d %H:%i:%s') AS latest_secret_modified,
    CASE 
        WHEN MAX(s.modified) > r.modified THEN 'SECRET_NEWER'
        WHEN MAX(s.modified) = r.modified THEN 'SAME_TIME'
        WHEN MAX(s.modified) < r.modified THEN 'RESOURCE_NEWER'
        ELSE 'NO_SECRETS'
    END AS comparison
FROM resources r
LEFT JOIN secrets s ON r.id = s.resource_id AND (s.deleted IS NULL OR s.deleted = '0000-00-00 00:00:00')
WHERE (r.deleted IS NULL OR r.deleted = '0000-00-00 00:00:00')
GROUP BY r.id, r.created, r.modified
HAVING latest_secret_modified IS NOT NULL
ORDER BY latest_secret_modified DESC
LIMIT 10;

SELECT '---' AS '';

-- Step 4: Check action logs for secret update events
SELECT '===_ACTION_LOGS_SECRET_UPDATES_===' AS '';
SELECT 
    id,
    action_id,
    context,
    status,
    DATE_FORMAT(created, '%Y-%m-%d %H:%i:%s') AS log_created
FROM action_logs
WHERE context LIKE '%secret%' 
   OR context LIKE '%password%'
   OR action_id IN (
       SELECT id FROM action_logs 
       WHERE context LIKE '%secret%' OR context LIKE '%password%'
       LIMIT 1
   )
ORDER BY created DESC
LIMIT 20;

SELECT '---' AS '';

-- Step 5: Get action log types related to secrets/resources
SELECT '===_ACTION_LOG_TYPES_===' AS '';
SELECT DISTINCT
    action_id,
    context
FROM action_logs
WHERE context LIKE '%secret%' 
   OR context LIKE '%password%'
   OR context LIKE '%resource%'
ORDER BY action_id
LIMIT 30;


