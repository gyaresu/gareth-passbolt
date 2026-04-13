---
name: draft-response
description: Draft a customer support response with facts verified against source code
---

# Draft Response

Generate a customer support response. Verify all technical claims against the passbolt source code before including them. Output as an HTML file following the team's formatting standards.

## Arguments

`$ARGUMENTS` is the customer question, issue context, or ticket summary.

Examples:
- `/draft-response customer asks how to configure LDAP sync with multiple directories`
- `/draft-response user reports 500 error on SSO login after upgrade to 4.x`
- `/draft-response how to export passwords as CSV`

## Steps

1. Read the customer context in `$ARGUMENTS`.
2. Identify what technical claims you'll need to make in the response.
3. Verify each claim against the source code in `/workspaces/passbolt-pro-api`, `/workspaces/passbolt-browser-extension`, or `/workspaces/passbolt-docs`. Use the `/verify` skill mentally for each claim.
4. Draft the response following these rules:
   - Greeting: "G'day [first name]" (use the customer's first name if available, otherwise omit the name)
   - Always lowercase "passbolt"
   - No emdashes, double dashes, or arrow characters
   - Direct, matter-of-fact tone. No flattery.
   - No sign-off (email signature handles it)
   - Documentation links: plain inline URLs to passbolt.com/docs (not help.passbolt.com)
   - Use "Organisation Settings" not "Administration" for admin panel references
5. Check `/home/vscode/passbolt_responses/INDEX.md` for any previous responses on the same topic that could be referenced or updated.
6. Write the HTML file to `/home/vscode/passbolt_responses/<topic>-<YYYY-MM-DD>.html`
   - Inline styles only, system font stack, ~14px body text
   - Bold text instead of headings
   - `<br><br>` between paragraphs (not `<p>` or `<div>`)
   - No `<br>` before or after `<ul>` lists
   - Wrap in `<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size: 14px; line-height: 1.5;">`
7. Append an entry to `/home/vscode/passbolt_responses/INDEX.md`:
   `- YYYY-MM-DD | filename-without-extension | one-line summary (under 80 chars)`
   Keep the file sorted newest first (insert at the top, after the header).

## Constraints

- Never include a claim you haven't verified against source code or documentation.
- If you're uncertain about something, flag it to the user rather than including it.
- Do not add features, caveats, or information the customer didn't ask about.
- Only recommend editing `passbolt.php` for configuration changes, never `passbolt.conf`.
- For diagnostics, use `status-report` (not `healthcheck`) with full commands per install type.

## Usage

```
/draft-response customer on RHEL 9 can't get LDAP sync working over TLS
/draft-response user wants to know if they can use their production license key in staging
/draft-response how do I see who accessed a specific password
```
