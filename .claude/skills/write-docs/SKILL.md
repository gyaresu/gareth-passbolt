---
name: write-docs
description: Write or update passbolt documentation in passbolt-docs with verified claims and correct Docusaurus conventions
model: sonnet
---

# Write Docs

Write, update, or reorder pages in the passbolt documentation repo at `/workspaces/passbolt-docs`. Ground every factual claim in source code via the `verify` skill before writing it. Follow Docusaurus 3 + MDX conventions and the project's tone rules.

## Arguments

`$ARGUMENTS` is a plain-English docs task.

Examples:
- `/write-docs new page on SCIM group filtering under admin/authentication/scim`
- `/write-docs update admin/directory-sync to cover the ldap-meta aggregation`
- `/write-docs reorder admin/authentication so SSO comes before MFA`

## Steps

1. **Classify the task.** One of: *new page*, *update existing*, *restructure* (move/rename/reorder), *multi-page addition*. Identify the target section: `admin`, `hosting`, `user`, `contribute`, or `development`.

2. **Locate target files.** Use Glob/Grep under `/workspaces/passbolt-docs/docs/` to find the precise file path(s). For updates, read the full existing page. For new pages, read at least one sibling page in the same section to match local style, frontmatter usage, and component imports.

3. **Extract factual claims.** List every claim about passbolt behavior, configuration, or API that the doc will make. Style claims (voice, tone, structure) do not need verification.

4. **Print a change plan and gate.** Output a short plan: files to create/modify/move, sidebar edits, and the list of claims to verify. STOP and ask for confirmation when any of these are true:
   - More than one page is affected.
   - A file move or rename is needed.
   - A first-level sidebar entry must be added or reordered (i.e. `sidebars/*.sidebar.js` will change).
   - Any claim is about behavior you cannot locate in source.

5. **Verify claims.** For each factual claim, invoke the `verify` skill. Require a **Confirmed** verdict with `file:line` citations before the claim appears in the doc. If `verify` returns **Denied** or **Partially correct**, reword or drop the claim. During drafting, record citations inline as `<!-- verify: passbolt-pro-api/src/Controller/X.php:123 -->` and strip them before the final write.

6. **Write or edit the MDX.** Apply the conventions below. Use Edit for targeted updates; use Write only for new files.

7. **Handle reordering / restructuring** when applicable:
   - Ordering within an auto-generated level → change `sidebar_position:` in frontmatter.
   - First-level sidebar items → edit the relevant `/workspaces/passbolt-docs/sidebars/*.sidebar.js` (e.g. `admin.sidebar.js`). Remind the user the dev server must be restarted; hot reload does not pick up sidebar changes.
   - Moves/renames → use `mv` and grep for inbound internal links under `/workspaces/passbolt-docs/docs/` to update them.

8. **Lint.** Run `cd /workspaces/passbolt-docs && npm run lint:fix:mdx` scoped to the touched files from inside the devcontainer. Node 22 in the devcontainer handles linting fine. Report lint output.

9. **Remind about preview on the host.** Preview runs on the **host**, not the devcontainer. Reasons: the devcontainer has Node 22 but `passbolt-docs/CONTRIBUTING.md` requires Node >= 24, and port 3000 is not mapped in `docker-compose.yaml`. Tell the user to run the dev server on the host in a separate terminal:

   ```
   cd ~/code/passbolt-docs && npm run start
   ```

   Edits made via Claude in the devcontainer are picked up by the host dev server automatically because `/workspaces/passbolt-docs` and `~/code/passbolt-docs` are the same bind mount. Do NOT start the dev server from the skill.

## Frontmatter

Use only these fields:
- `title:` (required) — Docusaurus renders this as H1, do not repeat it in the body.
- `description:` (required, SEO).
- `sidebar_label:` — only when nav label differs from title.
- `sidebar_position:` — integer, for ordering within auto-generated levels.
- `unlisted: true` — only when the page should be direct-link-only.
- `slug:` — only when a custom URL is needed.

Do not invent other fields.

## Writing conventions

- "passbolt" is lowercase in prose. The only capitalized forms are "Passbolt Pro Edition", "Passbolt CE", "Passbolt Cloud" as product names.
- Imperative second person: "Go to Organisation Settings, then ...".
- No em dashes, no double dashes, no arrow characters. Use commas or rewrite.
- Body uses H2 (`##`) for main sections, H3 (`###`) for subsections. H1 is the frontmatter title.
- Code blocks: match the sibling page. If it imports `CodeBlock` from `/src/components/CodeBlock/CodeBlock`, use `<CodeBlock>{\`code\`}</CodeBlock>`; otherwise use fenced triple-backtick blocks with a language tag.
- Admonitions: `:::info[Title]`, `:::tip[Good to know]`, `:::warning[Attention]`, `:::danger[IMPORTANT]`, `:::important`.
- Components available: `Figure`, `Chips`, `CodeBlock`, `Video`, `DistributionCard`, `ProviderCard`. Only use a component when the page already imports it, or when you are explicitly adding the import at the top of the file.
- Internal links: root-relative with trailing slash, e.g. `[Directory sync](/docs/admin/directory-sync/)`.
- Images: reference as `/img/...` in MDX. Files live under `/static/` mirroring the doc's folder structure. Example: a doc at `/docs/hosting/setup/configuration/firewall-rules.mdx` stores images at `/static/admin/setup/configuration/firewall-rules/`. If the image does not exist, leave `<!-- TODO: add image at /static/... -->` — do not fabricate files.
- Before duplicating any boilerplate, check the section's `_includes/` directory (e.g. `/workspaces/passbolt-docs/docs/hosting/_includes/`) for a partial you can import. If no suitable partial exists and the same content would appear on more than one page, create one: add a new `_name.mdx` file under the appropriate `_includes/` subfolder (underscore-prefixed filenames are the convention, grouped by topic like `default/`, `troubleshooting/`, `https/`), then import it from each consuming page rather than duplicating the text inline.

## Constraints

- Never write a factual claim without a verified source citation behind it.
- Never invent frontmatter fields, components, or admonition types that do not exist in the repo.
- Never fabricate image files. Placeholder with a TODO comment instead.
- Always read a sibling page before writing new content.
- Refuse to edit `/workspaces/passbolt-docs/openapi/**`. API reference is generated from OpenAPI YAML; tell the user to edit `openapi/root.yml` or its included files directly.
- Do not `git add`, commit, or push. Commits happen from the host, not the devcontainer.
- Do not start the dev server. Just remind the user to run `npm run start`.
- Stop and ask the user when any condition in Step 4 is triggered, or when a `verify` call comes back Denied.

## Usage

```
/write-docs new page covering LDAPS certificate setup under admin/authentication/ldap
/write-docs update user/settings/browser/change-passphrase to mention the new strength meter
/write-docs reorder admin/emails so the SMTP providers card page sits above troubleshooting
```
