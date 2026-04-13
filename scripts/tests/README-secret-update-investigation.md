# Investigation: Resource Modified Date on Secret Update

## Objective

Investigate if the `modified` date on the `resources` table is triggered/updated when there is a secret update in the `secrets` table.

## Background

Customer wants two extra fields added to CSV export:
- **Created** - creation date
- **Updated** - modification date

Current situation:
- Update date on the secret exists but not on the password field specifically
- Need to determine if resource.modified updates when secrets are updated
- If not, we may need to use action logs to generate created/modified dates

## Test Approach

### Method 1: Database Query Analysis

Run the SQL investigation script to check existing data patterns:

```bash
# Via docker compose
docker compose exec -T db mysql -upassbolt -pP4ssb0lt passbolt < scripts/tests/investigate-resource-modified-date.sql

# Or run the test script
./scripts/tests/test-secret-update-resource-modified.sh
```

This will show:
1. Schema of resources and secrets tables
2. Sample resources with their modified dates vs secret modified dates
3. Pattern analysis - do resources with recently modified secrets have updated resource.modified?
4. Action logs related to secret updates

### Method 2: Manual Testing

1. **Find a test resource:**
   ```sql
   SELECT r.id, r.created, r.modified, COUNT(s.id) as secret_count
   FROM resources r
   LEFT JOIN secrets s ON r.id = s.resource_id
   WHERE r.deleted IS NULL
   GROUP BY r.id
   HAVING secret_count > 0
   LIMIT 1;
   ```

2. **Record the current state:**
   ```sql
   SELECT 
       r.id,
       r.created AS resource_created,
       r.modified AS resource_modified,
       s.id AS secret_id,
       s.modified AS secret_modified
   FROM resources r
   JOIN secrets s ON r.id = s.resource_id
   WHERE r.id = '<RESOURCE_ID>';
   ```

3. **Update the secret via browser extension** (edit the password for that resource)

4. **Check if resource.modified changed:**
   ```sql
   SELECT 
       r.id,
       r.modified AS resource_modified_after,
       s.modified AS secret_modified_after
   FROM resources r
   JOIN secrets s ON r.id = s.resource_id
   WHERE r.id = '<RESOURCE_ID>';
   ```

5. **Compare timestamps:**
   - If `resource_modified_after` > `resource_modified` (from step 2): **Resource modified date IS updated**
   - If `resource_modified_after` = `resource_modified` (from step 2): **Resource modified date is NOT updated**

## Expected Results

### Scenario A: Resource modified date IS updated
- When a secret is updated, the resource.modified timestamp also updates
- CSV export can use `resources.created` and `resources.modified` directly
- Simple implementation

### Scenario B: Resource modified date is NOT updated
- When a secret is updated, only `secrets.modified` updates, not `resources.modified`
- Need alternative approach:
  - Use action logs to track secret updates
  - Generate CSV with created/modified from action logs
  - Or implement a trigger/application logic to update resource.modified on secret update

## Files

- `investigate-resource-modified-date.sql` - SQL queries for investigation
- `test-secret-update-resource-modified.sh` - Automated test script
- This README - Documentation

## Next Steps

1. Run the investigation queries
2. Perform manual test via browser extension
3. Document findings
4. If resource.modified is NOT updated, create ticket for implementation
5. Consider action logs approach as alternative for CSV export


