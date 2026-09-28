---
name: doc-pr
description: Generate a Markdown knowledge-base summary of a GitHub PR (metadata, context, decisions, review discussion, file impact) and write it to a file. Use when the user asks to document, summarize, or write up a GitHub pull request by number.
---

# doc-pr

Turn a GitHub Pull Request into a self-contained Markdown knowledge-base entry, using
the `gh` CLI (must already be authenticated via `gh auth login` — this is a machine-
wide credential, independent of your own login).

## Inputs

The user's message will contain a PR number and an output file path (e.g. "document PR
762 to docs/changelog/pr-762.md"). Extract both from their message. If either is
missing or ambiguous, ask before proceeding.

## Detail Level

Copilot skills have no structured argument support, so the detail level (`low`,
`medium`, or `high`) is extracted from the user's own phrasing:

- **high** triggers: "in detail", "in depth", "thoroughly", "comprehensive", "deep
  dive", "detailed", "exhaustive".
- **low** triggers: "briefly", "brief", "short", "quick", "tl;dr", "concise".
- Default to **medium** when no such phrase is present, or the phrasing is ambiguous.
  Do not ask the user to clarify detail level alone — only ask if the PR number or
  output path are missing/ambiguous, per the rule above.

The resolved level controls only how much analysis and evidence each section contains
— it never adds, removes, or renames a section, and it never changes what's true. See
the per-section guidance under "Output Schema" below for exactly how it scales.

## Steps

1. Fetch PR data yourself, from the current repo's checkout, via:

   ```
   gh pr view <pr_number> --json number,title,body,author,createdAt,mergedAt,state,labels,assignees,reviews,comments,url,files,additions,deletions,changedFiles,commits,closingIssuesReferences
   ```

2. Look at the returned `changedFiles`/`additions`/`deletions`:
   - If the PR is small-to-medium (roughly ≤15 files or ≤800 changed lines — a
     guideline, not a hard gate), also fetch the full patch via
     `gh pr diff <pr_number> --patch` and use it to ground the "why" behind each
     change in the actual code, not just the PR body.
   - If the resolved detail level is `high`, fetch the full patch regardless of that
     guideline — unless total changed lines exceed a hard **4000-line safety
     ceiling**, in which case skip it and say so explicitly in Impact & File Summary,
     citing the actual count and the ceiling (e.g. "even at high detail, this PR's
     diff (6,240 lines) exceeds the 4000-line safety ceiling and was not fetched in
     full").
   - Otherwise, if the PR is larger than the guideline, skip the full diff — reason
     from file paths, commit messages, the PR body, and review comments instead, and
     say so explicitly in the output rather than guessing at code you haven't seen.

3. Using **only** data you actually fetched (never fabricate reviewer names, dates,
   file paths, commit messages, or code details), write a single Markdown document to
   the given output path following the schema below exactly, at the resolved detail
   level.

Do not print the document in chat — write it directly to the output path, then confirm
in one short sentence that it was written, including the resolved path and the
resolved detail level with what triggered it (e.g. "Wrote docs/changelog/pr-762.md
(detail level: high, based on 'in detail')").

## Output Schema

This document should stand alone as a knowledge-base entry: someone should be able to
read it later without the original PR open and understand not just *what* changed but
*why*, and how to do something similar themselves. If a section has nothing to report,
say so briefly rather than omitting it. When you infer something rather than quoting it
directly, say so explicitly (e.g. "Inferred from..."). Never add personal narrative,
career reflection, or "talking points" framing that isn't derivable from the fetched PR
data — this document describes the PR, not the author.

````markdown
---
pr_number: <number>
repo: <owner/repo, parsed from the url field>
title: <title>
author: <author login>
status: <OPEN / MERGED / CLOSED>
created_at: <createdAt, ISO date>
merged_at: <mergedAt, ISO date, or null>
detail_level: <low / medium / high>
labels: [<label names>]
assignees: [<assignee logins>]
reviewers:
  - login: <reviewer login>
    decision: <APPROVED / CHANGES_REQUESTED / COMMENTED>
linked_issues: [<issue numbers or urls from closingIssuesReferences>]
components: [<top-level touched paths, deduplicated>]
files_changed: <changedFiles>
additions: <additions>
deletions: <deletions>
---

# PR #<number>: <title>

| Field | Value |
|---|---|
| Author | <author login> |
| Status | <OPEN / MERGED / CLOSED> |
| Created | <createdAt, human-readable> |
| Merged | <mergedAt or "—"> |
| Labels | <comma-separated labels or "None"> |
| Assignees | <comma-separated assignees or "None"> |

## Context & Motivation

<2-5 sentences on the state before this change and why it was needed — drawn from the
PR body, labels, and linked issues. Flag anything inferred rather than stated.
Scale with detail level: low → 1-2 sentences, the single most important motivating
fact. high → 3-6 sentences, explicitly contrasting the concrete "before" state against
the "after," drawn from file layout/labels/linked issues.>

## What Changed & Why

<Bullet list grouped by component/area (top-level directory or subsystem inferred from
changed file paths). Each bullet states the *purpose* of the change, citing a commit
message or review comment when one explains the rationale — not just a filename list.
If the PR adds or reorganizes a module tree, include a short directory-tree diagram
built from the file paths.
Scale with detail level: low → one bullet per top-level component, no sub-bullets.
high → nested bullets per notable file/function when the diff was fetched, still
grouped the same way.>

## Key Decisions & Trade-offs

<Decisions that were made, debated, or reworked during the PR — especially ones that
changed shape after review feedback. For each: what was decided, what alternative was
rejected, and why (citing the commit message, PR body, or review comment that explains
it). If nothing was substantively debated, say so briefly.
Scale with detail level: low → list only decisions that visibly changed shape after
review feedback, one line each, no elaboration; skip undebated decisions entirely
rather than saying "nothing debated." medium → cover every decision the data supports,
as above. high → for each decision, state the concrete failure mode the rejected
alternative would have caused (not "cleaner code" — a specific consequence, e.g. "would
have broken imports in CI, not just locally"); show the revision progression if a
decision changed more than once (v1 → pushback → v2, citing the commits); say
explicitly "no rejected alternative documented" rather than inventing one when the data
doesn't support it.>

## Review Timeline

<Chronological list of reviewer actions: who reviewed, when, what they asked for, and
how/whether it was resolved. Attribute points to reviewers by login. Skip purely
mechanical comments (e.g. "LGTM", bot noise) unless they represent a final
approval/rejection or a substantive automated finding (e.g. a quality-gate or CI
result). Automated/bot findings (e.g. a static-analysis or coverage-gate comment) and
how they were resolved belong here too, when present in `reviews`/`comments`/`commits`
— never invent a tool name or finding that isn't actually in the data.
Scale with detail level: low → one line per reviewer, final decision only. medium →
chronological account as above. high → full reconstruction: every review round, every
substantive automated finding, grouped by category if numerous, with explicit
before/after resolution citing the follow-up commit.>

## Bugs Fixed / Gotchas

<Specific correctness fixes or pitfalls surfaced during the PR — e.g. a resource leak
or an off-by-one fixed mid-review — drawn from commit messages or comments. Omit this
section's content (but keep the heading, noting "None called out") if the data doesn't
support it. Don't speculate about bugs that aren't documented in the data.
Scale with detail level: low → one line per documented fix, no elaboration. high → root
cause + why it was non-obvious + how it was caught (review/CI/testing), grounded
strictly in commit/diff/comment text, flagging any inferred root cause explicitly.>

## How To: <short recipe name describing the reusable pattern, e.g. "Add a new BFF endpoint">

<Concise, numbered steps distilled from this PR for doing something similar again —
referencing the actual files/functions/patterns involved. This is the section someone
would search for later when trying to replicate this work; be concrete rather than
generic.
Scale with detail level: low → 3-5 high-level numbered steps. high → numbered steps
with inline pitfall callouts sourced from Bugs Fixed/Gotchas, plus a verification step
if the PR's own commits show one (e.g. added tests).>

## Impact & File Summary

<Table or bullet list of changed files with additions/deletions counts, derived from
the `files` array. If there are more than ~20 files, summarize by directory instead of
listing every file, and note the total files/additions/deletions changed. If the full
diff wasn't inspected (due to PR size, or because it exceeded the 4000-line safety
ceiling even at high detail), say so here explicitly.
Scale with detail level: low → aggregate counts plus the top-3 changed directories
only. high → always a full per-file (or per-directory-grouped) table plus explicit
diff-inspection status.>
````

## Formatting Rules

- Output valid Markdown only — no commentary before or after the document, no code
  fences wrapping the whole thing (the schema above is fenced only for this
  instruction; your actual output starts directly with the `---` front matter).
- Front matter must be valid YAML and use only data present in the fetched JSON —
  don't invent reviewers, issues, or components.
- Keep prose sections concise and skimmable; prefer bullets over paragraphs, except
  where a short narrative genuinely reads better (e.g. Context & Motivation).
- Never fabricate reviewer names, dates, file paths, commit messages, or code details
  that aren't present in the input data.
- If the PR body is empty, note that in Context & Motivation and rely on commits,
  labels, and the file/diff summary to describe intent.
- If you did not fetch the full diff (large PR, or over the high-detail safety
  ceiling), say so explicitly wherever that affects confidence — don't present
  diff-derived detail you don't actually have.
- Never include personal narrative, retrospective career framing, or "talking points"
  content — every sentence must trace back to fetched PR data.
