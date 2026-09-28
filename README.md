# doc-pr

A portable `/doc-pr` skill for Claude Code (and GitHub Copilot CLI) that turns a
GitHub Pull Request into a comprehensive Markdown summary — title, description,
review discussion, decisions, and file impact — without pulling full diffs into the
model's context unless you ask for maximum depth.

## What it does

Given a PR number and an output path, `/doc-pr` fetches structured PR data —
metadata, reviews, comments, commits, linked issues, and per-file additions/deletions
— via `gh pr view --json ...`. Depending on PR size and the requested detail level, it
also pulls the full diff (`gh pr diff --patch`) to ground its explanations in actual
code; otherwise it reasons from file paths, commit messages, and discussion instead, so
context never blows up. The agent then writes a Markdown document following a fixed
schema, designed to stand alone as a knowledge-base entry rather than just a
changelog:

- YAML front matter (structured metadata for downstream tooling — e.g. loading a pile
  of these into a graph DB)
- Header & metadata table (author, status, dates, labels, assignees)
- Context & motivation
- What changed & why, grouped by component
- Key decisions & trade-offs — with rejected alternatives and *why*, not just "what"
- Review timeline — including bot/CI/quality-gate findings and how they were resolved
- Bugs fixed / gotchas
- A "how to" recipe distilled from the PR, for redoing something similar later
- Impact & file summary

Every run is strictly grounded in the data `gh` actually returns — no invented
reviewers, commits, or code details, and no personal narrative or commentary about the
person who wrote the PR.

## Detail level: low / medium / high

Every run can be tuned to one of three detail levels — **`low`**, **`medium`**
(default), or **`high`**. The level controls only how much analysis and evidence each
section contains; the section list is always identical. `high` also lifts the usual
PR-size guideline for fetching the full diff (up to a 4000-changed-line safety
ceiling, above which even `high` explicitly says it skipped the diff rather than
guessing). See `templates/doc-pr-template.md` for the exact scaling rules per section.

## Requirements

- [`gh`](https://cli.github.com) (GitHub CLI), authenticated via `gh auth login`
- [`jq`](https://jqlang.org/download)
- [Claude Code](https://code.claude.com) and/or [GitHub Copilot CLI](https://github.com/github/copilot-cli)

## Install (Claude Code)

### Option A: git clone + install.sh (primary)

```sh
git clone https://github.com/ilypopv/doc-pr.git
cd doc-pr
./install.sh
```

`install.sh` is idempotent — re-run it anytime to pick up local changes. It symlinks:

- `adapters/claude-code/doc-pr.md` → `~/.claude/commands/doc-pr.md`
- `templates/doc-pr-template.md` → `~/.claude/doc-pr/templates/doc-pr-template.md`

Because these are symlinks back into your checkout, editing the template or command
in this repo takes effect immediately — no reinstall needed. `git pull` to update.

### Option B: Claude Code plugin (no clone)

Once this repo is pushed to GitHub as `ilypopv/doc-pr`, you can install it as a plugin
instead, with no local checkout at all:

```
/plugin marketplace add ilypopv/doc-pr
/plugin install doc-pr@doc-pr-marketplace
```

This is a newer Claude Code mechanism than Option A and its manifest schema may still
evolve — if it ever breaks, fall back to Option A, which will keep working regardless.

## Usage (Claude Code)

From inside any local checkout of a GitHub repo, run Claude Code and invoke:

```
/doc-pr 123 docs/changelog/pr-123.md
/doc-pr 123 docs/changelog/pr-123.md high
```

- `123` — the PR number in the current repo (as resolved by `gh`)
- `docs/changelog/pr-123.md` — where the generated Markdown summary is written
- `high` (optional) — detail level: `low`, `medium`, or `high`; defaults to `medium`
  if omitted

## Install & usage (GitHub Copilot CLI)

`gh auth login` is a machine-wide credential for the `gh` binary — any tool that
shells out to `gh`, including Copilot CLI, picks it up automatically. No separate
GitHub auth is needed for this skill specifically. (Copilot CLI does have its own
one-time `/login` for its own general use, but that's unrelated to this skill's `gh`
calls.)

Install the skill directly from GitHub — no clone required, since the Copilot adapter
is fully self-contained:

```sh
copilot skill add --project https://raw.githubusercontent.com/ilypopv/doc-pr/main/adapters/copilot-cli/SKILL.md
```

(If you're working from a local checkout instead, e.g. before this repo is pushed to
GitHub, use `copilot skill add --project ./adapters/copilot-cli/SKILL.md`.)

Then, inside Copilot CLI, just ask in plain language:

```
document PR 762 to docs/changelog/pr-762.md
document PR 762 to docs/changelog/pr-762.md in detail
briefly document PR 762 to docs/changelog/pr-762.md
```

Copilot skills have no structured argument support, so detail level is picked up from
your phrasing: words like "in detail", "thoroughly", or "comprehensive" select `high`;
"briefly", "short", or "quick" select `low`; anything else defaults to `medium`. The
agent's final confirmation states which level it resolved and why.

Unlike the Claude Code adapter, this one is self-contained (the schema is inlined
rather than referencing `templates/doc-pr-template.md`) and doesn't rely on any
Claude-specific pre-fetch or argument-substitution syntax — it just instructs the
agent to run `gh` itself.

## Repository structure

```text
doc-pr/
├── README.md
├── install.sh
├── .claude-plugin/
│   ├── plugin.json           # Claude Code plugin manifest (Option B install)
│   └── marketplace.json      # Marketplace catalog for Option B install
├── templates/
│   └── doc-pr-template.md    # Output schema, detail-level scaling & formatting rules
└── adapters/
    ├── claude-code/
    │   └── doc-pr.md          # Claude Code command definition (installed skill)
    └── copilot-cli/
        └── SKILL.md           # Self-contained Copilot CLI skill
```

## Portability

The core logic lives in plain Markdown files (command adapters and the output
template) plus a POSIX shell installer. To support another AI coding assistant, add a
new adapter under `adapters/<tool>/` that runs `gh pr view --json ...` (and, for
small-to-medium PRs or `high` detail, `gh pr diff --patch`) and follows the same schema
as `templates/doc-pr-template.md`, including a `detail_level` control — as a structured
argument if the tool supports one, otherwise extracted from the user's own phrasing (as
in the Copilot adapter).
