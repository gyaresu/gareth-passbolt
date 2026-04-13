---
name: lookup-history
description: Look up past customer interactions and prior investigation findings before drafting a response
model: haiku
---

# Lookup History

Search the support response archive and findings log for prior context on a customer or topic. Run before drafting a response so the new reply acknowledges past threads and reuses verified findings instead of starting cold.

## Arguments

`$ARGUMENTS` is the customer name, email, topic keywords, or a short ticket summary to search for.

Examples:
- `/lookup-history Tobias iphone PGP`
- `/lookup-history LDAP sync multiple directories`
- `/lookup-history léon offline mode`

## Steps

1. Parse `$ARGUMENTS` into search terms: customer name (if present), and topic keywords.
2. Search `/home/vscode/passbolt_responses/INDEX.md` for matching entries:
   - Use Grep with case-insensitive matching on each term
   - Match against the filename slug AND the one-line summary
3. Search `/home/vscode/passbolt_responses/findings/*.md` for matching topics:
   - Grep across the findings directory for each term
   - For matches, read the **Finding** and **Resolution** sections
4. If a customer name is present, list every prior response involving that customer (their name in greeting line of past `.html` files, or in INDEX summary).
5. Produce a brief in this format:

   ```
   ## Prior context

   **Customer thread** (if customer name given):
   - YYYY-MM-DD | <filename> | <one-line summary>

   **Related findings**:
   - findings/<file>.md — <one-line finding summary>

   **Related responses**:
   - YYYY-MM-DD | <filename> | <one-line summary>

   **Open threads to acknowledge**: (only if a recent response from the same customer is unresolved)
   - <what was last said and what was promised, if anything>
   ```

6. If nothing matches, return: `No prior context found for "<terms>".`

## Constraints

- Do NOT draft a response. Only surface context.
- Do NOT modify any files.
- Keep the brief under 30 lines. If many matches, list the 5 most recent and note `(N more, run grep for full list)`.
- Sort all lists newest first.
- If a customer name match is uncertain (e.g. a common first name), include it but flag with `(name match, verify)`.

## Usage

```
/lookup-history Tobias PGP fingerprint
/lookup-history LDAP sync duplicate users
/lookup-history MFA Duo configuration
```
