#!/usr/bin/env bash
# bake-web-design-rules.sh — bake web-design-guidelines rules into the skill
# so reviews work fully offline (no runtime fetch).
#
# web-design-guidelines ships as a thin wrapper that fetches its rulebook
# from GitHub on every review. This script bakes the rulebook into the
# skill once at install time and rewrites SKILL.md to point at the local copy.
#
# Idempotent: skips if rules are already baked (references/web-interface-guidelines.md).
# No-op if the skill isn't installed yet.

set -euo pipefail

SOURCE_URL="https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md"
TARGET_DIR="$HOME/.agents/skills/web-design-guidelines"
RULES_FILE="$TARGET_DIR/references/web-interface-guidelines.md"
SKILL_FILE="$TARGET_DIR/SKILL.md"

# No-op if the skill is not installed yet
[[ -d "$TARGET_DIR" ]] || { echo "  ↳ web-design-guidelines not installed, skipping"; exit 0; }

# Idempotent
[[ -f "$RULES_FILE" ]] && { echo "  ↳ rules already baked at $RULES_FILE"; exit 0; }

# Fetch the upstream rulebook
echo "  ↳ baking web-design-guidelines rules (one-time fetch from upstream)…"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! curl -sfL "$SOURCE_URL" -o "$TMP"; then
  echo "  ! could not fetch rules (network). Skill will fall back to remote fetch at runtime." >&2
  exit 0
fi

# Persist the rulebook
mkdir -p "$TARGET_DIR/references"
cp "$TMP" "$RULES_FILE"

# Overwrite SKILL.md so it points to the local copy instead of fetching each run
cat > "$SKILL_FILE" <<'EOF'
---
name: web-design-guidelines
description: Review UI code for compliance with the Web Interface Guidelines (100+ rules). Use when asked to "review my UI", "check accessibility", "audit design", "review UX", or "check my site against best practices".
license: MIT
---

# Web Interface Guidelines (bundled)

Review files for compliance with the Web Interface Guidelines.

## How it works

The rulebook is bundled at `references/web-interface-guidelines.md`. Read it on demand — no network access required at runtime.

## Usage

When the user provides a file or pattern argument:

1. Read `references/web-interface-guidelines.md` for the full rulebook and output format.
2. Apply the rules to the requested files.
3. Output findings in the format specified in the rulebook.

If no files are specified, ask the user which files to review.

## Source

Bundled from `vercel-labs/web-interface-guidelines` upstream at install time. To refresh, delete `references/web-interface-guidelines.md` and re-run `bake-web-design-rules.sh`.
EOF

# Audit stamp
date -u +%FT%TZ > "$TARGET_DIR/.baked-rules-stamp"

echo "  ✓ rules baked (skill is now offline-ready)"
