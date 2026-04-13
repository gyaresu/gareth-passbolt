---
name: draft-response
description: Draft a customer support response with facts verified against source code
model: sonnet
---

# Draft Response

Generate a customer support response. Verify all technical claims against the passbolt source code before including them. Output as an HTML file following the team's formatting standards.

## Arguments

`$ARGUMENTS` is the customer question, issue context, or ticket summary. Optional flags can be appended:
- `--channel email|forum|slack|internal-note` (default: `email`)
- `--audience technical|non-technical` (default: technical depth, adjusts explanation depth not tone)

Examples:
- `/draft-response customer asks how to configure LDAP sync with multiple directories`
- `/draft-response user reports 500 error on SSO login after upgrade to 4.x --audience non-technical`
- `/draft-response how to export passwords as CSV --channel forum`
- `/draft-response heads up on duplicate user fix from yesterday --channel slack`

## Steps

1. Read the customer context in `$ARGUMENTS`. Parse any `--channel` and `--audience` flags.
2. **Look up history first.** Run the `lookup-history` skill with the customer name (if known) and topic keywords. Use the returned brief to:
   - Acknowledge any open thread from the same customer
   - Reuse verified findings from `findings/` instead of re-investigating
   - Skip the rest of this skill if a recent response already answers the question (just point the user to it)
3. Identify what technical claims you'll need to make in the response.
4. Verify each claim against the source code in `/workspaces/passbolt-pro-api`, `/workspaces/passbolt-browser-extension`, or `/workspaces/passbolt-docs`. Use the `verify` skill for any non-trivial claim.
5. Draft the response following these tone rules (apply to ALL channels):
   - Greeting: "G'day [first name]" for email/forum; no greeting for slack/internal-note (use the customer's first name if available, otherwise omit the name)
   - Always lowercase "passbolt"
   - No emdashes, double dashes, or arrow characters
   - Direct, matter-of-fact tone. No flattery.
   - No sign-off (email signature handles it)
   - Documentation links: plain inline URLs to passbolt.com/docs (not help.passbolt.com)
   - Use "Organisation Settings" not "Administration" for admin panel references
   - Audience adjustment: if `--audience non-technical`, expand acronyms on first use, prefer plain language over jargon, give one example instead of three. Tone stays the same.
6. Format and write the file based on `--channel`:
   - **email** or **internal-note** (default): HTML file at `/home/vscode/passbolt_responses/<topic>-<YYYY-MM-DD>.html`
     - Inline styles only, system font stack, ~14px body text
     - Bold text instead of headings
     - `<br><br>` between paragraphs (not `<p>` or `<div>`)
     - No `<br>` before or after `<ul>` lists
     - Wrap in `<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size: 14px; line-height: 1.5;">`
   - **forum** (community.passbolt.com Discourse): markdown file at `/home/vscode/passbolt_responses/<topic>-<YYYY-MM-DD>.md`
     - Standard Discourse markdown (`**bold**`, `-` list items, fenced ```code blocks)
     - No HTML wrapper; no `<br>` tags
     - Plain URLs (Discourse auto-linkifies)
   - **slack**: short markdown file at `/home/vscode/passbolt_responses/<topic>-<YYYY-MM-DD>.md`
     - No greeting, no sign-off
     - Single backtick `code` for inline, triple backtick for blocks
     - Lead with the answer; keep under ~10 lines if possible
7. Append an entry to `/home/vscode/passbolt_responses/INDEX.md`:
   `- YYYY-MM-DD | filename-without-extension | one-line summary (under 80 chars)`
   Keep the file sorted newest first (insert at the top, after the header).
8. **Review before handing off.** Run the `review-response` skill against the file you just wrote. If it returns FIXES NEEDED, apply the fixes and re-run review until PASS (or surface remaining items to the user with reasoning).

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
/draft-response forum question about offline mode for shared devices --channel forum
/draft-response let the team know we shipped the duplicate-user fix --channel slack
/draft-response explain account recovery to a first-time admin --audience non-technical
```
