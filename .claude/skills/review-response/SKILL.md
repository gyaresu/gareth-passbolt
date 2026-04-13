---
name: review-response
description: Validate a draft customer response against the team's tone and HTML format rules
model: sonnet
---

# Review Response

Check a draft customer response (HTML or markdown) against the documented tone, terminology, and format rules. Report PASS or FIXES NEEDED with specific line-pointed issues. Does NOT auto-edit the file; the user decides whether to apply each fix.

## Arguments

`$ARGUMENTS` is a path to the draft file (typically under `/home/vscode/passbolt_responses/`), or the literal draft text if no file exists yet.

Examples:
- `/review-response /home/vscode/passbolt_responses/ldap-sync-2026-04-13.html`
- `/review-response /home/vscode/passbolt_responses/forum-question-2026-04-13.md`

## Steps

1. Resolve `$ARGUMENTS`: if it's a path, Read the file; otherwise treat as inline draft text.
2. Detect format: HTML (presence of `<div`, `<br`, `<ul`, etc.) or markdown.
3. Run all applicable checks below. For each violation, record:
   - The rule name
   - The exact offending text
   - The suggested fix
   - Line number (if file) or character index (if inline)
4. Output verdict at the top: `PASS` (no issues) or `FIXES NEEDED (N issues)`.
5. Group issues by category (Tone, Terminology, HTML structure, Verification).

## Checks

### Tone
- Greeting starts with `G'day [first name]` (or no greeting at all if customer name unknown). Flag any other greeting (`Hi`, `Hello`, `Dear`).
- No flattery: `great question`, `the good news is`, `important point`, `happy to`, `glad to`, `appreciate`, `great to see`.
- No sign-off: `Cheers`, `Regards`, `Best`, `Thanks`, `--` followed by a name. The user's email signature handles closing.
- No emdashes (`—`), no double dashes (`--`), no arrows (`->`, `=>`, `→`, `←`).

### Terminology
- `passbolt` is always lowercase. Flag any `Passbolt` (except in `passbolt.com`, file paths, or proper nouns like product titles in screenshots).
- Admin panel: `Organisation Settings`, NOT `Administration`.
- Config file: `passbolt.php`, NOT `passbolt.conf`.
- Diagnostics: `status-report`, NOT `healthcheck`.
- Docs domain: `passbolt.com/docs`, NOT `help.passbolt.com` (deprecated).

### HTML structure (only if format is HTML)
- Outer wrapper `<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size: 14px; line-height: 1.5;">` is present.
- No `<p>` or content `<div>` for paragraphs (paragraphs use `<br><br>` separators). Outer wrapper `<div>` is fine.
- No `<br>` immediately before `<ul>` or immediately after `</ul>` (the list margin handles spacing).
- No external CSS links, no `<style>` blocks, no font imports.
- No `<h1>`/`<h2>`/`<h3>` (use `<b>` for emphasis instead).
- Documentation links are bare URLs in the text, not wrapped in `<a href>` with link text.

### Verification (heuristic)
- Flag any sentence that makes a specific technical claim (version numbers, file paths, config keys, behavior under conditions) without a nearby URL, file:line citation, or qualifier (`per the docs`, `confirmed in <repo>`).
- These are FLAGS not failures: the reviewer cannot verify; user must confirm.

## Output format

```
## Review: <filename or inline>

**Verdict:** PASS | FIXES NEEDED (N issues)

### Tone
- L42: "Passbolt" → use lowercase "passbolt"
- L57: "Happy to help with..." → drop, sign-off and flattery not used

### Terminology
- L88: "Administration → LDAP" → "Organisation Settings → LDAP"

### HTML structure
- L12: `<br>` before `<ul>` → remove

### Verification (please confirm)
- L34: "directory sync runs every 60 minutes by default" — no citation, please verify
```

If PASS:
```
## Review: <filename>

**Verdict:** PASS

All tone, terminology, and structure checks passed. No verification flags raised.
```

## Constraints

- Do NOT modify the draft file. Report only.
- Do NOT speculate about whether technical claims are true; only flag missing citations for the user to verify.
- Do NOT re-grade the substance of the response (whether the answer is correct, complete, helpful). Only check the rules above.
- If the input is empty or unreadable, say so and stop.

## Usage

```
/review-response /home/vscode/passbolt_responses/ldap-sync-email-aliases-2026-04-13.html
/review-response /home/vscode/passbolt_responses/sso-keycloak-2026-04-12.html
```
