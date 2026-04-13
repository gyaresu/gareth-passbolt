---
name: check-docs
description: Compare passbolt documentation against actual code behavior
model: sonnet
---

# Check Docs

Compare what the passbolt documentation says against what the code actually does. Find discrepancies between docs and implementation.

## Arguments

`$ARGUMENTS` is a docs topic, URL, or feature area to check.

Examples:
- `/check-docs LDAP directory sync configuration`
- `/check-docs SMTP email configuration options`
- `/check-docs MFA setup flow`

## Steps

1. Read the topic in `$ARGUMENTS`.
2. Find the relevant documentation in `/workspaces/passbolt-docs`. Search by topic keywords.
3. Find the corresponding implementation:
   - API code in `/workspaces/passbolt-pro-api`
   - Extension code in `/workspaces/passbolt-browser-extension`
   - UI components in `/workspaces/passbolt-styleguide`
4. Compare:
   - Are documented configuration options still valid?
   - Do documented behaviors match the implementation?
   - Are there undocumented options or behaviors?
   - Are version-specific notes accurate?
5. Produce a discrepancy report:
   - **Matches**: briefly confirm what's accurate
   - **Discrepancies**: list each with file:line references in both the docs and code repos
   - **Missing from docs**: features or options in the code not covered by docs
   - **Outdated in docs**: things documented that no longer exist in the code

## Constraints

- Do NOT modify docs or code. Report only.
- Include file paths and line numbers for both docs and code references.
- If a discrepancy could affect customer support answers, flag it prominently.
- STOP after the report. Do not propose changes.

## Usage

```
/check-docs password expiry policies
/check-docs SSO OIDC configuration
/check-docs RBAC and permission model
```
