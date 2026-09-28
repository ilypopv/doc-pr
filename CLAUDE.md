# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`doc-pr` is a portable, prompt-only skill (no application code) that turns a GitHub
PR into a self-contained Markdown knowledge-base entry. It fetches structured PR data
via `gh pr view --json ...` (and, for small/medium PRs, or when the requested detail
level is `high`, `gh pr diff --patch`) and writes a Markdown document following a
fixed schema — never pulling full diffs into context for large PRs unless the user
explicitly asked for `high` detail (and even then, only up to a 4000-changed-line
safety ceiling).

There is no build, lint, or test tooling in this repo — it's Markdown command
definitions plus one shell installer and two small JSON plugin manifests. "Testing" a
change means running the installed `/doc-pr` command (or the Copilot skill) against a
real PR and inspecting the output file it writes, at all three detail levels.

## Repository structure & how the pieces relate

- `templates/doc-pr-template.md` — the canonical output schema (front matter fields,
  section order, detail-level scaling rules, diff-fetch threshold, formatting rules).
  This is the source of truth.
- `adapters/claude-code/doc-pr.md` — Claude Code slash-command definition. Gets
  symlinked to `~/.claude/commands/doc-pr.md` by `install.sh`. It pre-fetches PR JSON
  via a `!`gh pr view ...`` directive, resolves the optional third `detail_level`
  argument (default `medium`), then tells the agent to read the schema — trying
  `${CLAUDE_PLUGIN_ROOT}/templates/doc-pr-template.md` first (resolves under a plugin
  install), falling back to the *installed*, symlinked copy at
  `~/.claude/doc-pr/templates/doc-pr-template.md` (resolves under an `install.sh`
  install).
- `adapters/copilot-cli/SKILL.md` — Copilot CLI skill. Self-contained: the schema from
  `templates/doc-pr-template.md` is inlined directly rather than referenced, and it
  instructs the agent to run `gh` itself rather than relying on Claude-specific
  pre-fetch/argument-substitution syntax. Copilot skills have no structured-argument
  support, so `detail_level` is instead extracted from the user's natural-language
  phrasing (see the "Detail Level" section in that file for the trigger words).
- `install.sh` — idempotent installer (primary Claude Code install path). Checks for
  `gh`, `jq`, `claude` on PATH, then symlinks (not copies) the adapter and template
  into `~/.claude/`, so edits in this repo checkout take effect immediately without
  reinstalling.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — an *additional*,
  secondary Claude Code install path (`/plugin marketplace add` + `/plugin install`,
  no clone required) alongside `install.sh`, not a replacement for it. This mechanism
  is newer and its schema may still evolve — if plugin install breaks, `install.sh`
  keeps working regardless.

**Invariant 1 — the schema is duplicated three times, keep them in sync:**
`adapters/claude-code/doc-pr.md` (by reference), `adapters/copilot-cli/SKILL.md`
(inlined), and `templates/doc-pr-template.md` (canonical) all encode the *same* output
schema — including the detail-level scaling language (the "low/medium/high" guidance
per section) and the diff-size threshold (plus the `high`-detail override and
4000-line safety ceiling). When changing any of this, update all three together — they
will silently drift otherwise since nothing enforces consistency between them.

**Invariant 2 — the plugin manifest's paths must stay valid:** `.claude-plugin/plugin.json`
references `adapters/claude-code/doc-pr.md` by relative path, and — transitively, via
the `${CLAUDE_PLUGIN_ROOT}` fallback inside that file — `templates/doc-pr-template.md`.
If either file moves or is renamed, the plugin manifest (and the plugin-install path)
breaks silently; the fallback logic in `adapters/claude-code/doc-pr.md` must stay
consistent with wherever `install.sh` actually symlinks the template to.

## Adding support for a new AI coding assistant

Add `adapters/<tool>/` with a command/skill definition that:

1. Runs `gh pr view --json number,title,body,author,createdAt,mergedAt,state,labels,assignees,reviews,comments,url,files,additions,deletions,changedFiles,commits,closingIssuesReferences`.
2. For PRs ≤~15 files or ≤~800 changed lines, also runs `gh pr diff --patch` to ground
   explanations in real code; otherwise skips it and says so explicitly in the output
   — unless the resolved detail level is `high`, in which case it fetches the full
   diff regardless (up to the 4000-line safety ceiling).
3. Supports (or explicitly documents non-support of) a `detail_level` argument
   (`low`/`medium`/`high`, default `medium`) — as a structured argument if the tool
   supports one, otherwise extracted from the user's natural-language phrasing.
4. Follows the same schema as `templates/doc-pr-template.md` (front matter, section
   headings, detail-level scaling, and formatting rules) — either by referencing it (if
   the tool supports reading files from a fetch step, like the Claude Code adapter) or
   inlining it (like the Copilot adapter).
5. Never fabricates reviewer names, dates, file paths, or code details not present in
   fetched data, and never adds personal narrative or commentary about the PR's author.

If installation should be automated, extend `install.sh` rather than creating a
separate installer.
