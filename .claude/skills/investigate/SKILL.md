---
name: investigate
description: Diagnose a reported bug by reading source code, git history, and the running stack
---

# Investigate

Investigate a reported bug or unexpected behavior. Read source code across repos, check git history for recent changes, and optionally query the running stack. Produce a diagnostic report and STOP.

## Arguments

`$ARGUMENTS` is the bug description or customer report.

Examples:
- `/investigate users are seeing duplicate entries after LDAP sync`
- `/investigate SSO login redirects to wrong URL after upgrade`
- `/investigate action logs missing for secret updates`

## Steps

1. Read the bug description in `$ARGUMENTS`.
2. Identify which repos and code paths are likely involved.
3. Search for the relevant code in `/workspaces/passbolt-pro-api` and `/workspaces/passbolt-browser-extension`.
4. Check git history (`git log`, `git blame`) on affected files for recent changes that could explain the behavior.
5. If the running stack is available, query it to check current state:
   - Database: `mariadb -h db -u passbolt -pP4ssb0lt passbolt -e "SQL HERE"`
   - API: `curl -sk https://passbolt.local`
   - LDAP: `ldapsearch -x -H ldap://ldap-meta.local:389 -b "dc=unified,dc=local" "(filter)"`
6. Check `/home/vscode/passbolt_responses/findings/` for any previous investigations on similar topics.
7. Produce a diagnostic report:
   - **Affected files** with paths and line numbers
   - **Recent changes** that may be relevant
   - **Root cause** (confirmed or hypothesized, clearly labeled)
   - **Proposed fix** (description only, do not implement)
8. Save a findings summary to `/home/vscode/passbolt_responses/findings/<topic>-<YYYY-MM-DD>.md` with:
   - **Topic**: one-line description
   - **Date**: today's date
   - **Question/Ticket**: the original report from $ARGUMENTS
   - **Finding**: what was determined (root cause, behavior explanation, etc.)
   - **Relevant code paths**: file:line references
   - **Resolution**: proposed fix or "investigation only"

## Constraints

- Do NOT implement any fixes. STOP after the diagnostic report.
- Clearly distinguish between confirmed facts and hypotheses.
- If you need to make changes to the running stack to test, ASK first.
- Always include file:line references for any code you cite.
- Always save a findings summary (step 8) so future investigations can reference it.

## Usage

```
/investigate MFA setup shows old Duo configuration after org settings change
/investigate directory sync creates duplicate users when email changes
/investigate resource modified date not updating on secret change
```
