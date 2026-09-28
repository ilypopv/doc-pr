---
description: Generate a Markdown summary of a GitHub PR (metadata, reviews, discussion, decisions, file impact) and write it to a file.
argument-hint: <pr_number> <output_path> [detail_level]
arguments: [pr_number, output_path, detail_level]
allowed-tools: Bash(gh pr view *) Bash(gh pr diff *) Read Write
---

## PR metadata, reviews, comments, commits & file change stats

!`gh pr view $pr_number --json number,title,body,author,createdAt,mergedAt,state,labels,assignees,reviews,comments,url,files,additions,deletions,changedFiles,commits,closingIssuesReferences`

## Your task

Resolve `$detail_level`: if it's empty or not one of `low`/`medium`/`high`
(case-insensitive), treat it as `medium`.

Read the output schema and formatting rules before doing anything else. Try, in order:

1. `${CLAUDE_PLUGIN_ROOT}/templates/doc-pr-template.md` (resolves when installed as a
   Claude Code plugin)
2. `~/.claude/doc-pr/templates/doc-pr-template.md` (resolves when installed via
   `install.sh`)

Apply its "Detail Level" section throughout every part of the output at the resolved
level — it controls only depth, never which sections appear.

Using the data fetched above, look at `changedFiles`/`additions`/`deletions`:

- If the PR is small-to-medium (roughly ≤15 files or ≤800 changed lines — a guideline,
  not a hard gate), fetch the full patch yourself via `gh pr diff $pr_number --patch`
  (you're pre-approved to run it) and use it to ground the "why" behind each change in
  the actual code, not just the PR body.
- If resolved detail level is `high`, fetch the full patch regardless of that
  guideline — unless total changed lines exceed the template's 4000-line safety
  ceiling, in which case skip it and say so explicitly, citing the actual count and the
  ceiling.
- Otherwise, if the PR is larger than the guideline, don't fetch the full diff —
  reason from file paths, commit messages, the PR body, and review comments instead,
  and say so explicitly in the output (e.g. "full diff not inspected due to PR size")
  rather than guessing at code you haven't seen.

Then produce the output the template describes for PR #$pr_number at the resolved
detail level, including `detail_level: <resolved value>` in the front matter, using
**only** data you actually fetched — never fabricate reviewer names, dates, file paths,
or code details.

Once you have composed the final Markdown document, use the Write tool to save it to:
$output_path

Do not print the document in the chat — write it directly to that path, then confirm
in one short sentence that it was written, including the resolved output path and
detail level.
