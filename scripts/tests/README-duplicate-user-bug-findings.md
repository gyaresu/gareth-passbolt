# Duplicate Users Bug Investigation

## Customer Issue Summary

**Customer**: Enzy AMGHAR
**First occurrence**: November 25, 2025
**Recurrence**: January 2025 (affecting 2 more teams)
**Impact**: Blocking production rollout, 100+ users to enroll

### Reported Symptoms
1. Users placed in two AD groups: enrollment group + team assignment group
2. 7:00 AM cron job runs directory sync
3. **Some users** receive TWO enrollment emails
4. TWO accounts created in database (same username/email)
5. User activates ONE account → one activated, one pending
6. Causes: group corruption, inconsistent user state, search issues
7. Not all users affected in same batch
8. Cron logs show TWO successful enrollments for same user

---

## Root Cause Analysis

### Primary Finding: Missing Database Constraint

**The `users` table does NOT have a UNIQUE constraint on the `username` column.**

```sql
-- Current schema (vulnerable):
CREATE TABLE `users` (
  `username` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `role_id` (`role_id`,`username`),  -- NOT UNIQUE, just an index
  KEY `deleted` (`deleted`)
);
```

This allows the database to accept multiple INSERT statements with the same username without raising an error.

### Race Condition Mechanism

When directory sync runs with overlapping processes (concurrent cron jobs, multiple nodes, or rapid successive runs):

```
Timeline:
─────────────────────────────────────────────────────────────
Process A: SELECT * FROM users WHERE username = 'user@example.com'
           → Returns empty (user doesn't exist)

Process B: SELECT * FROM users WHERE username = 'user@example.com'
           → Returns empty (Process A hasn't committed yet)

Process A: INSERT INTO users (username, ...) VALUES ('user@example.com', ...)
           → SUCCESS (no constraint violation)

Process B: INSERT INTO users (username, ...) VALUES ('user@example.com', ...)
           → SUCCESS (no constraint violation - BUG!)
─────────────────────────────────────────────────────────────
Result: 2 users with same email/username
```

### Why Not All Users Are Affected

The race condition window is very small (milliseconds). Only users being processed at the exact moment of overlap are affected. This explains:
- Same batch, some duplicated, some not
- Intermittent/unpredictable behavior
- Issue appears more frequently with larger batches (longer sync time = more overlap potential)

---

## Diagnostic Queries

### 1. Find All Duplicates
```sql
SELECT
    username,
    COUNT(*) as duplicate_count,
    GROUP_CONCAT(id ORDER BY created) as user_ids,
    GROUP_CONCAT(active ORDER BY created) as active_states,
    MIN(created) as first_created,
    MAX(created) as last_created,
    TIMESTAMPDIFF(SECOND, MIN(created), MAX(created)) as seconds_between
FROM users
WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
GROUP BY username
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;
```

### 2. Analyze Timing Patterns
```sql
SELECT
    username,
    COUNT(*) as dup_count,
    TIMESTAMPDIFF(SECOND, MIN(created), MAX(created)) as seconds_apart,
    CASE
        WHEN TIMESTAMPDIFF(SECOND, MIN(created), MAX(created)) < 5 THEN 'RACE CONDITION'
        WHEN TIMESTAMPDIFF(SECOND, MIN(created), MAX(created)) < 60 THEN 'OVERLAPPING SYNC'
        ELSE 'SEPARATE SYNC RUNS'
    END as likely_cause
FROM users
WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
GROUP BY username
HAVING COUNT(*) > 1;
```

If `seconds_apart` is < 5 seconds, this confirms the race condition hypothesis.

---

## Recommended Solutions

### Immediate Mitigation (Customer-Side)

#### 1. Add Cron Lock to Prevent Overlapping Syncs

```bash
# Instead of:
0 7 * * * /path/to/passbolt/bin/cake directory_sync all --persist

# Use flock to prevent concurrent execution:
0 7 * * * /usr/bin/flock -n /tmp/passbolt_sync.lock /path/to/passbolt/bin/cake directory_sync all --persist
```

This ensures only ONE sync process runs at a time.

#### 2. If Using Multiple Nodes/HA Setup

- Ensure cron ONLY runs on ONE node
- Use a distributed lock (Redis, database lock, or shared filesystem lock)
- Or designate a single "sync controller" node

### Permanent Fix (Passbolt Development)

#### Option A: Add Unique Constraint (Recommended)

```sql
-- Add unique constraint to prevent duplicates
ALTER TABLE users ADD UNIQUE INDEX idx_username_unique (username);
```

**Caution**: This will fail if duplicates already exist. Clean up duplicates first.

#### Option B: Application-Level Locking

In the sync code, use database-level locking:
```php
// Use SELECT ... FOR UPDATE to lock the row/check
$existingUser = $this->Users->find()
    ->where(['username' => $ldapUser->email])
    ->modifier('FOR UPDATE')  // Locks the row
    ->first();
```

#### Option C: Use INSERT ... ON DUPLICATE KEY

If unique constraint exists:
```sql
INSERT INTO users (id, username, ...)
VALUES (UUID(), 'user@example.com', ...)
ON DUPLICATE KEY UPDATE modified = NOW();
```

---

## Cleanup Procedure

### Step 1: Identify Duplicates
```sql
SELECT id, username, active, created
FROM users
WHERE username IN (
    SELECT username FROM users
    WHERE deleted IS NULL OR deleted = '0000-00-00 00:00:00'
    GROUP BY username HAVING COUNT(*) > 1
)
ORDER BY username, created;
```

### Step 2: Decide Which to Keep
- **If one is activated**: Keep the activated one
- **If both pending**: Keep the oldest one (first created)
- **If both activated**: Requires manual investigation (data merge may be needed)

### Step 3: Soft-Delete Duplicates
```sql
-- Replace <DUPLICATE_ID> with the actual ID to remove
UPDATE users SET deleted = NOW() WHERE id = '<DUPLICATE_ID>';
```

### Step 4: Clean Directory Entries
```sql
DELETE FROM directory_entries WHERE foreign_key = '<DUPLICATE_ID>';
```

---

## Questions for Customer

1. **Cron Configuration**:
   - Exact crontab entry?
   - Is cron running on multiple servers?
   - Is there any locking mechanism?

2. **Infrastructure**:
   - HA setup with multiple Passbolt nodes?
   - Load balancer configuration?
   - Shared storage between nodes?

3. **Timing Evidence**:
   - What is the `seconds_between` value for duplicates?
   - Are all duplicates from the same sync batch?

---

## Files Created

| File | Purpose |
|------|---------|
| `scripts/tests/diagnose-duplicate-users.sql` | Diagnostic queries to run on customer's database |
| `scripts/tests/cleanup-duplicate-users.sql` | Generate cleanup SQL statements |
| `scripts/tests/test-duplicate-user-bug.sh` | Local reproduction test script |
| `scripts/tests/README-duplicate-user-bug-findings.md` | This document |

---

## Conclusion

The root cause is a **missing UNIQUE constraint on the `users.username` column**, combined with **concurrent sync processes**. This is a schema design issue in Passbolt.

**Short-term**: Customer should implement cron locking (`flock`).
**Long-term**: Passbolt should add a UNIQUE constraint and/or application-level locking.

---

*Investigation Date: January 16, 2026*
