-- Quick check: Resource modified date before and after secret update
-- Run this BEFORE updating a secret, note the timestamps, then run again AFTER

-- Replace '<RESOURCE_ID>' with actual resource ID
SET @resource_id = '<RESOURCE_ID>';

SELECT '=== BEFORE SECRET UPDATE ===' AS '';
SELECT 
    r.id AS resource_id,
    DATE_FORMAT(r.created, '%Y-%m-%d %H:%i:%s') AS resource_created,
    DATE_FORMAT(r.modified, '%Y-%m-%d %H:%i:%s') AS resource_modified,
    s.id AS secret_id,
    s.user_id AS secret_user_id,
    DATE_FORMAT(s.created, '%Y-%m-%d %H:%i:%s') AS secret_created,
    DATE_FORMAT(s.modified, '%Y-%m-%d %H:%i:%s') AS secret_modified,
    TIMESTAMPDIFF(SECOND, r.modified, s.modified) AS seconds_diff_resource_vs_secret
FROM resources r
JOIN secrets s ON r.id = s.resource_id
WHERE r.id = @resource_id
  AND (r.deleted IS NULL OR r.deleted = '0000-00-00 00:00:00')
  AND (s.deleted IS NULL OR s.deleted = '0000-00-00 00:00:00');

-- After updating the secret via browser extension, run this again:
-- The resource_modified should change if the system updates it on secret change


