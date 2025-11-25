-- Passbolt MySQL Database Growth Diagnostic
-- READ-ONLY: Only SELECT statements. Safe for production.

-- Largest tables by total size (data + indexes). Focus on tables >100MB.
SELECT '===_LARGEST_TABLES_(Top_20)_===' AS '';
SELECT 
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size_MB',
    ROUND((data_length / 1024 / 1024), 2) AS 'Data_MB',
    ROUND((index_length / 1024 / 1024), 2) AS 'Index_MB',
    table_rows AS 'Rows'
FROM information_schema.tables
WHERE table_schema = 'passbolt'
ORDER BY (data_length + index_length) DESC
LIMIT 20;

SELECT '---' AS '';

-- Action logs table analysis. Even with file logging enabled, Passbolt may still write to database.
-- Check if table size is large and if logs are accumulating rapidly.
SELECT '===_ACTION_LOGS_===' AS '';
SELECT 
    COUNT(*) AS total_logs,
    DATE_FORMAT(MIN(created), '%Y-%m-%dT%H:%i:%s') AS oldest,
    DATE_FORMAT(MAX(created), '%Y-%m-%dT%H:%i:%s') AS newest,
    COUNT(CASE WHEN created >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN 1 END) AS last_30d,
    COUNT(CASE WHEN created >= DATE_SUB(NOW(), INTERVAL 60 DAY) THEN 1 END) AS last_60d
FROM action_logs;
SELECT '---_Table_Size_---' AS '';
SELECT 
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS table_size_mb,
    table_rows AS total_rows
FROM information_schema.tables
WHERE table_schema = 'passbolt' AND table_name = 'action_logs';

SELECT '---' AS '';

-- Soft deletes: records marked as deleted but not removed. These accumulate over time.
-- High percentages (e.g., 50%+) indicate records aren't being purged.
SELECT '===_SOFT_DELETES_===' AS '';
SELECT 
    t.table_name AS 'Table',
    ROUND(((t.data_length + t.index_length) / 1024 / 1024), 2) AS 'Size_MB',
    t.table_rows AS 'Total_Rows'
FROM information_schema.tables t
JOIN information_schema.columns c ON t.table_name = c.table_name AND t.table_schema = c.table_schema
WHERE t.table_schema = 'passbolt' 
  AND c.column_name = 'deleted'
  AND t.table_type = 'BASE TABLE'
ORDER BY (t.data_length + t.index_length) DESC;
SELECT '---_Soft_Delete_Counts_---' AS '';
SELECT 'users' AS table_name, COUNT(*) AS total, SUM(CASE WHEN deleted IS NOT NULL AND deleted != '0000-00-00 00:00:00' THEN 1 ELSE 0 END) AS deleted FROM users
UNION ALL
SELECT 'resources', COUNT(*), SUM(CASE WHEN deleted IS NOT NULL AND deleted != '0000-00-00 00:00:00' THEN 1 ELSE 0 END) FROM resources
UNION ALL
SELECT 'secrets', COUNT(*), SUM(CASE WHEN deleted IS NOT NULL AND deleted != '0000-00-00 00:00:00' THEN 1 ELSE 0 END) FROM secrets
UNION ALL
SELECT 'groups', COUNT(*), SUM(CASE WHEN deleted IS NOT NULL AND deleted != '0000-00-00 00:00:00' THEN 1 ELSE 0 END) FROM groups
UNION ALL
SELECT 'gpgkeys', COUNT(*), SUM(CASE WHEN deleted IS NOT NULL AND deleted != '0000-00-00 00:00:00' THEN 1 ELSE 0 END) FROM gpgkeys;

SELECT '---' AS '';

-- History/versioning tables store change history. Check if these are growing unexpectedly.
SELECT '===_HISTORY_TABLES_===' AS '';
SELECT 
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size_MB',
    table_rows AS 'Rows'
FROM information_schema.tables
WHERE table_schema = 'passbolt' 
  AND (table_name LIKE '%history%' OR table_name LIKE '%version%' OR table_name LIKE '%log%')
ORDER BY (data_length + index_length) DESC;

SELECT '---' AS '';

-- Email queue: stuck or failed emails accumulate here. Check if queue is growing.
SELECT '===_EMAIL_QUEUE_===' AS '';
SELECT 
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size_MB',
    table_rows AS 'Rows'
FROM information_schema.tables
WHERE table_schema = 'passbolt' 
  AND (table_name LIKE '%email%' OR table_name LIKE '%queue%')
ORDER BY (data_length + index_length) DESC;

SELECT '---' AS '';

-- Directory sync metadata from LDAP synchronization. Check if sync data is accumulating.
SELECT '===_DIRECTORY_SYNC_===' AS '';
SELECT 
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size_MB',
    table_rows AS 'Rows'
FROM information_schema.tables
WHERE table_schema = 'passbolt' 
  AND (table_name LIKE '%directory%' OR table_name LIKE '%ldap%' OR table_name LIKE '%sync%')
ORDER BY (data_length + index_length) DESC;

SELECT '---' AS '';

-- BLOB/TEXT columns can store large amounts of data. Check which tables have large binary/text fields.
SELECT '===_BLOB/TEXT_COLUMNS_===' AS '';
SELECT 
    t.table_name AS 'Table',
    c.column_name AS 'Column',
    c.data_type AS 'Type',
    ROUND(((t.data_length + t.index_length) / 1024 / 1024), 2) AS 'Table_Size_MB',
    t.table_rows AS 'Rows'
FROM information_schema.columns c
JOIN information_schema.tables t ON c.table_name = t.table_name AND c.table_schema = t.table_schema
WHERE c.table_schema = 'passbolt'
  AND c.data_type IN ('BLOB', 'MEDIUMBLOB', 'LONGBLOB', 'TEXT', 'MEDIUMTEXT', 'LONGTEXT')
  AND t.table_type = 'BASE TABLE'
ORDER BY (t.data_length + t.index_length) DESC
LIMIT 20;

SELECT '---' AS '';

-- Total InnoDB tablespace usage. Compare this to backup size to identify other sources of growth.
SELECT '===_INNODB_TABLESPACE_SUMMARY_===' AS '';
SELECT 
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Total_MB',
    ROUND(SUM(data_length) / 1024 / 1024, 2) AS 'Data_MB',
    ROUND(SUM(index_length) / 1024 / 1024, 2) AS 'Index_MB'
FROM information_schema.tables
WHERE table_schema = 'passbolt' AND engine = 'InnoDB';

SELECT '---' AS '';

-- Recent growth patterns. Compare last_30d vs last_60d to see if growth is accelerating.
SELECT '===_RECENT_GROWTH_(Last_60_days)_===' AS '';
SELECT 
    'resources' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(CASE WHEN created >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN 1 END) AS last_30d,
    COUNT(CASE WHEN created >= DATE_SUB(NOW(), INTERVAL 60 DAY) THEN 1 END) AS last_60d
FROM resources
UNION ALL
SELECT 
    'secrets',
    COUNT(*),
    COUNT(CASE WHEN created >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN 1 END),
    COUNT(CASE WHEN created >= DATE_SUB(NOW(), INTERVAL 60 DAY) THEN 1 END)
FROM secrets
UNION ALL
SELECT 
    'users',
    COUNT(*),
    COUNT(CASE WHEN created >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN 1 END),
    COUNT(CASE WHEN created >= DATE_SUB(NOW(), INTERVAL 60 DAY) THEN 1 END)
FROM users;

SELECT '---' AS '';

-- V5 encryption migration timeline. Correlate first_created dates with backup size increase.
-- Check if avg_secret_size_bytes increased after v5 migration (v5 may store secrets larger).
SELECT '===_V5_ENCRYPTION_MIGRATION_===' AS '';
SELECT 
    metadata_key_type AS 'Type',
    COUNT(*) AS 'Count',
    DATE_FORMAT(MIN(created), '%Y-%m-%dT%H:%i:%s') AS 'First',
    DATE_FORMAT(MAX(created), '%Y-%m-%dT%H:%i:%s') AS 'Latest'
FROM resources
WHERE metadata_key_type IS NOT NULL
GROUP BY metadata_key_type
ORDER BY MIN(created);
SELECT '---_Secrets_Analysis_---' AS '';
SELECT 
    COUNT(*) AS total_secrets,
    DATE_FORMAT(MIN(created), '%Y-%m-%dT%H:%i:%s') AS oldest,
    DATE_FORMAT(MAX(created), '%Y-%m-%dT%H:%i:%s') AS newest,
    COUNT(CASE WHEN created >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN 1 END) AS last_30d,
    COUNT(CASE WHEN created >= DATE_SUB(NOW(), INTERVAL 60 DAY) THEN 1 END) AS last_60d,
    ROUND(AVG(LENGTH(data)), 0) AS avg_size_bytes,
    ROUND(MAX(LENGTH(data)), 0) AS max_size_bytes,
    ROUND(SUM(LENGTH(data)) / 1024 / 1024, 2) AS total_data_mb
FROM secrets;

SELECT '---' AS '';

-- Daily resource creation pattern. Look for spikes that correlate with backup size increases.
SELECT '===_RESOURCE_GROWTH_BY_DAY_(Last_90_days)_===' AS '';
SELECT 
    DATE(created) AS 'Date',
    COUNT(*) AS 'Created',
    COUNT(CASE WHEN metadata_key_type IS NOT NULL THEN 1 END) AS 'With_Metadata'
FROM resources
WHERE created >= DATE_SUB(NOW(), INTERVAL 90 DAY)
GROUP BY DATE(created)
ORDER BY DATE(created) DESC;

SELECT '---' AS '';

-- Permissions table: sharing resources creates permission records. Check if this is growing rapidly.
SELECT '===_PERMISSIONS_===' AS '';
SELECT 
    COUNT(*) AS total_permissions,
    DATE_FORMAT(MIN(created), '%Y-%m-%dT%H:%i:%s') AS oldest,
    DATE_FORMAT(MAX(created), '%Y-%m-%dT%H:%i:%s') AS newest,
    COUNT(CASE WHEN created >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN 1 END) AS last_30d,
    COUNT(CASE WHEN created >= DATE_SUB(NOW(), INTERVAL 60 DAY) THEN 1 END) AS last_60d
FROM permissions;
SELECT '---_Permission_Tables_---' AS '';
SELECT 
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size_MB',
    table_rows AS 'Rows'
FROM information_schema.tables
WHERE table_schema = 'passbolt' 
  AND (table_name LIKE '%permission%' OR table_name LIKE '%share%' OR table_name LIKE '%access%')
ORDER BY (data_length + index_length) DESC;

SELECT '---' AS '';

-- Binary logs: MySQL 8.0+ enables binary logging by default. If expire_logs_days=0, logs never auto-purge.
-- File-level backups include binary logs (mysqldump does not). Check total size separately as root.
-- Run as root: mysql -u root -p -e "SHOW BINARY LOGS;"
-- Run as root: mysql -u root -p -e "SHOW VARIABLES LIKE 'expire_logs_days';"
-- Run as root: mysql -u root -p -e "SHOW VARIABLES LIKE 'binlog_expire_logs_seconds';"
