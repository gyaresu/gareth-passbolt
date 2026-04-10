---
name: verify
description: Verify a claim or support answer against passbolt source code
---

# Verify

Verify a technical claim against the actual passbolt source code. Use this when you need to confirm whether a statement about passbolt behavior is accurate before including it in a customer response or internal communication.

## Arguments

`$ARGUMENTS` is the claim or statement to verify.

Examples:
- `/verify password expiry is enforced server-side`
- `/verify LDAP sync updates the modified date on resources`
- `/verify SSO login bypasses MFA`

## Steps

1. Read the claim in `$ARGUMENTS` and identify which area of passbolt it relates to (API, browser extension, docs).
2. Identify the relevant repo(s) under `/workspaces/`:
   - `passbolt-pro-api` for server-side behavior (PHP/CakePHP)
   - `passbolt-browser-extension` for client-side behavior (JavaScript)
   - `passbolt-docs` for documentation claims
   - `passbolt-styleguide` for UI components
3. Search for the relevant code. Read the actual implementation, not just comments or config.
4. Cross-reference between repos if the claim spans client and server (e.g. "does the extension send X to the API?").
5. Produce a verdict: **Confirmed**, **Denied**, or **Partially correct** with file:line references to the actual code.

## Constraints

- Do NOT modify any code. This is read-only verification.
- Do NOT speculate. If you cannot find the relevant code, say so. Do not guess.
- Always include file paths and line numbers for evidence.
- If the claim is about behavior that depends on configuration or feature flags, note that.
- STOP after producing the verdict. Do not suggest fixes or changes.

## Usage

```
/verify the browser extension caches MFA provider settings
/verify resource.modified updates when a secret is changed
/verify SCIM provisioning creates users with active status
```
