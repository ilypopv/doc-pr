#!/usr/bin/env bash
# Idempotent installer for the /doc-pr Claude Code skill.
# Symlinks the command adapter + output template into ~/.claude so the
# skill stays in sync with this repo checkout (re-run anytime to update).
set -euo pipefail

# Resolve the real directory of this script, following symlinks.
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
REPO_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
COMMANDS_DIR="$CLAUDE_DIR/commands"
TEMPLATES_DIR="$CLAUDE_DIR/doc-pr/templates"

echo "==> Checking prerequisites"

missing=0
for bin in gh jq claude; do
  if command -v "$bin" >/dev/null 2>&1; then
    echo "    [ok] $bin found ($(command -v "$bin"))"
  else
    echo "    [MISSING] $bin not found on PATH"
    missing=1
  fi
done

if [ "$missing" -eq 1 ]; then
  echo ""
  echo "One or more prerequisites are missing. Install them before using /doc-pr:"
  echo "  - gh:     https://cli.github.com"
  echo "  - jq:     https://jqlang.org/download"
  echo "  - claude: https://code.claude.com"
  exit 1
fi

echo "==> Installing /doc-pr into $CLAUDE_DIR"

mkdir -p "$COMMANDS_DIR" "$TEMPLATES_DIR"

ln -sf "$REPO_DIR/adapters/claude-code/doc-pr.md" "$COMMANDS_DIR/doc-pr.md"
ln -sf "$REPO_DIR/templates/doc-pr-template.md" "$TEMPLATES_DIR/doc-pr-template.md"

echo "    linked $COMMANDS_DIR/doc-pr.md -> $REPO_DIR/adapters/claude-code/doc-pr.md"
echo "    linked $TEMPLATES_DIR/doc-pr-template.md -> $REPO_DIR/templates/doc-pr-template.md"

echo ""
echo "✔ /doc-pr installed. Try it from inside any GitHub repo checkout:"
echo "    claude"
echo "    /doc-pr <pr_number> <output_path.md> [low|medium|high]"
echo ""
echo "Prefer not to clone at all? Once this repo is pushed to GitHub, install it as a"
echo "Claude Code plugin instead — see README.md for the /plugin marketplace add command."

if ! gh auth status >/dev/null 2>&1; then
  echo ""
  echo "Note: gh is not authenticated yet. Run 'gh auth login' before using /doc-pr."
fi
