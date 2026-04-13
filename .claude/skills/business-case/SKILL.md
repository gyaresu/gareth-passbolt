---
name: business-case
description: Interview the user to draft a passbolt business case as Markdown ready for Google Docs import
model: sonnet
---

# Business Case

Draft an internal passbolt business case by interviewing the user one section at a time. Output as Markdown formatted for Google Docs import (File → Import → Markdown). Adapt scope to the size of the proposal: a small case may stop after Section 4; a large one runs the full sequence.

## Arguments

`$ARGUMENTS` is a one-line topic for the business case (becomes the working title and filename slug).

Examples:
- `/business-case agentic RAG for support tickets`
- `/business-case migrate audit log shipper from rsyslog to vector`
- `/business-case offer SSO trial extensions to enterprise prospects`

## Output

Write to `/home/vscode/passbolt_responses/business-cases/<slug>-<YYYY-MM-DD>.md`. Create the `business-cases/` directory if it does not exist. After writing, run `open <file>` so the user can review and import to Google Docs.

## Interview flow

Walk through the phases below in order. At the start of each phase, tell the user which phase you are entering and what you need from them. Draft the section as you go, show it to the user, and only move on once they accept it. Do **not** dump every question at once.

Skip any phase the user marks as not applicable. The minimum viable business case is Phases 1, 2, 3, 7, and 8.

### Phase 1 — Frame

Ask for and confirm:
- **Title** (default: title-cased version of `$ARGUMENTS`).
- **Subtitle** (e.g. "Business Case", "Business Case & High Level Approach", "Problem Definition and Proposed Solution").
- **Author name** (no default; ask each time, this is a shared support repo).
- **Classification** (default `INTERNAL`; alternatives: `CONFIDENTIAL`, `PUBLIC`).
- **Status** (default `WIP`; alternatives: `DRAFT`, `FOR REVIEW`, `FINAL`).
- **One-line abstract**: "This document describes the business case for ___. It is aimed at ___."

Render the front-matter as a Markdown frame (title H1, then a short metadata block, then a Change History table with one row).

### Phase 2 — Problem definition

Run four questions, each as its own exchange. Push back if the answer is vague: business cases at passbolt are data-driven. Always ask for numbers when applicable (ticket volume, FTE cost, growth rate, dollar impact, customer count, deal size, etc.).

- **Q1. What problem are we trying to solve?** Probe for: current volume, projected growth, FTE cost of the status quo, the named scaling cliff. If the user hands you a fuzzy problem, ask "what does this cost us today, in numbers?"
- **Q2. Who is impacted?** Probe for at least three stakeholder layers (e.g. internal team / paying customers / product team). Name specific people or teams when the user mentions them.
- **Q3. Why is it important and/or urgent?** It is acceptable for this to be "covered in Q1" if Q1 already established urgency. Don't pad.
- **Q4. What has been discussed as a solution?** Capture both the proposed solution AND the alternatives that were considered and rejected, with the reason for rejection. This sets up the comparison table later.

### Phase 3 — Proposed solution (one-pager summary)

Ask the user whether the case warrants a one-pager summary section. Skip it for narrow internal cases; include it whenever the audience extends beyond the immediate team.

If included, draft these sub-sections:
- **What is [the thing]?** One paragraph in plain language.
- **Why choose [this approach]?** 3-5 bullets, each with a bolded lead-in.
- **Why not [alternative]?** A comparison table with columns: Requirement | [Our choice] | [Alternative] | Best for us. Use ✅ / ⚠️ / ❌ markers.
- **How it works (high level).** Numbered list, 3-5 steps.
- **Benefits for passbolt.** 3-5 bullets with bolded lead-ins.
- **Why open-source / local / [other strategic choice]?** Only when the strategic choice is non-obvious and worth defending. Skip otherwise.

### Phase 4 — High-level approach

Skip for small cases. For technical proposals, draft:
- **Executive summary** (one paragraph naming the platform, the pipeline shape, and the privacy/compliance posture).
- **Process stages.** For each stage, write a `mermaid` flowchart, a "What happens" bullet list, and a "Business value" bullet list. Output mermaid as fenced ` ```mermaid ` blocks; the user will render them via the Google Docs Mermaid add-on or replace with images.
- **Technical architecture (simplified).** A single `mermaid` `graph TB` with `subgraph` groupings for data sources, processing, storage, delivery, users.
- **Key design decisions.** Numbered list, each with a one-line decision and 2-3 supporting bullets.

### Phase 5 — Working packages

Ask the user how the work breaks into phases. Use this convention strictly:
- Phase 1 — Foundation (MVP) — **MUST** — Effort S/M/L
- Phase 2 — Intelligence / Expansion — **SHOULD** — Effort S/M/L
- Phase 3 — Optimisation — **COULD** — Effort S/M/L

Each phase gets a paragraph describing what ships and what the user-visible outcome is at the end of the phase. Optionally include a ticket breakdown table with columns: # | Description | Ticket | Status (default `To spec`).

### Phase 6 — User stories (optional)

Skip unless the case introduces specific user-facing behaviour that needs acceptance criteria. When included:

- Status legend at the top of the section:
  - ● Not ready / Under construction
  - ● Discussion or validation needed
  - ● User story validated and final
- Stories follow the format:
  ```
  [MUST/SHOULD/COULD] As a [role] I can [capability] ●

  Given that I am a [role]
  When I [action]
  Then I [outcome]

  Acceptance criteria
  - ...
  ```

### Phase 7 — Risk and privacy analysis

Always include for any proposal touching customer data, infrastructure, or external services. Cover at minimum:
- Data minimisation / sanitisation approach (what gets stripped, what gets kept, irreversibility).
- Access control and audit (who can query, where logs live, retention).
- GDPR / compliance alignment (Article 30, DPIAs, erasure rights).

Three numbered guard-rails works well as a structure.

### Phase 8 — Measurable success criteria

Always include. Render as a table with columns: Milestone | Metric | Target | Evidence source. Push the user for at least one metric per phase from Section 5, plus a top-level ROI metric (FTE reclaimed, tickets prevented, deal velocity, etc.).

## Writing conventions

- "passbolt" is lowercase in prose. The only capitalised forms are product names ("Passbolt Pro Edition", "Passbolt CE", "Passbolt Cloud").
- British / Australian English spellings: sanitisation, categorisation, optimisation, prioritisation, organisation, behaviour, analyse.
- No em dashes, no double dashes, no arrow characters. Use commas, parentheses, or rewrite.
- Direct, matter-of-fact tone. No flattery, no "the good news is", no "important point".
- Lead with numbers, not adjectives. "519 tickets handled Jan-Jul, projecting 890 annually" beats "we handle a lot of tickets".
- Name people and teams when the user mentions them ("When Louis and Gareth joined in Q2, Antony spent significant time training them ...") rather than generic "engineers".
- Bullet lists use bolded lead-ins followed by a colon and the explanation: `- **Contextual understanding:** unlike traditional keyword search, ...`.
- Comparison tables use ✅ / ⚠️ / ❌ markers, not "Yes/No/Maybe".
- "Business value:" call-outs at the end of technical subsections.
- Today's date format in the change history table: `Mon DD, YYYY` (e.g. `Apr 13, 2026`).

## Markdown for Google Docs

The output file is imported into Google Docs via File → Import → Markdown. Constraints that follow from that:
- Use H1 (`#`) for the document title only. Use H2 (`##`) for top-level sections (Introduction, Problem definition, Proposed solution, etc.) and H3 (`###`) for sub-sections (Q1, Q2, ...). Google Docs maps these to its built-in heading styles, which drives the table of contents.
- Tables use standard pipe syntax. Keep them narrow enough to fit a portrait page.
- Mermaid diagrams as fenced ` ```mermaid ` blocks. Google Docs imports them as code; the user renders them separately.
- Do not include a manual table of contents. Google Docs generates one from headings after import.
- Avoid HTML tags. Google Docs ignores most of them on import.

## Constraints

- Never invent numbers. If the user has not given you a metric, ask. If they don't have one, write `[TBD: <what's needed>]` rather than guessing.
- Do not fabricate quotes, customer names, or incident references.
- Do not write the doc end-to-end before checking in. Show each phase as you draft it and accept revisions before continuing.
- Do not commit the file or push anywhere. Output is for the user to review and paste into Google Docs.
- Skip Phases 4, 5, 6 freely for small proposals. Never skip Phases 1, 2, 3, 7, 8.

## Usage

```
/business-case agentic RAG for support tickets
/business-case standardise audit log shipping across on-prem deployments
/business-case offer paid migration assistance for self-hosted to cloud
```
