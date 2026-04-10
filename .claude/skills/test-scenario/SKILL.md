---
name: test-scenario
description: Test a scenario against the running passbolt stack
---

# Test Scenario

Run a test scenario against the live passbolt stack. The devcontainer has network access to all stack services: passbolt, keycloak, ldap-meta, db, valkey, smtp4dev.

## Arguments

`$ARGUMENTS` is the scenario to test.

Examples:
- `/test-scenario verify LDAP sync pulls users from both directories`
- `/test-scenario check that SSO login redirects correctly`
- `/test-scenario confirm audit logs capture secret access events`

## Steps

1. Read the scenario in `$ARGUMENTS`.
2. Plan the test: what API calls, database queries, or service interactions are needed.
3. List the services involved and how to reach them directly from this container:
   - **passbolt API**: `curl -sk https://passbolt.local`
   - **Database**: `mariadb -h db -u passbolt -pP4ssb0lt passbolt -e "SQL HERE"`
   - **LDAP**: `ldapsearch -x -H ldap://ldap-meta.local:389 -b "dc=unified,dc=local" "(filter)"`
   - **Keycloak**: `curl -sk https://keycloak.local`
   - **Valkey**: `curl -s http://valkey:6379` (or install redis-cli if needed)
   - **Email**: `curl -sk https://smtp.local`
4. Execute the test steps. For each step, record:
   - What was done
   - Expected result
   - Actual result
   - Pass/Fail
5. Produce a test report with results.

## Constraints

- Default to **read-only** operations. If the test requires writing data (creating users, updating passwords, etc.), describe what you'd do and ASK before executing.
- Do not modify stack configuration without asking.
- If a test requires authentication (API key, JWT), explain how to obtain credentials.
- Store test results in the MCP memory service if they reveal important behavior.
- Note: `curl` from inside the devcontainer uses self-signed certs, so use `-k` flag for HTTPS.

## Usage

```
/test-scenario verify that creating a resource via API generates an action log entry
/test-scenario check LDAP meta backend returns users from both ldap1 and ldap2
/test-scenario test email delivery for user invitation flow
```
