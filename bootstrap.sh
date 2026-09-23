#!/usr/bin/env bash
# bootstrap.sh — restore AI dev skills on a fresh machine.
#
# Edit the two arrays below to add/remove skills. Re-run the script
# anytime to update everything to upstream HEAD.
#
#   PI_SKILLS       full-repo skills installed via `pi install`
#   AGENTS_SKILLS   subfolder skills installed to ~/.agents/skills/<id>
#                   (use a | between repo URL and the subpath inside the repo,
#                    and another | + branch to pin the git ref)
#
# Companion: ./generate-next-docs.sh  — snapshot Next.js docs into a global skill
# Companion: ./bake-web-design-rules.sh — bundle web-design-guidelines rules offline
#
# Usage:  chmod +x bootstrap.sh   # first time only
#         ./bootstrap.sh

set -euo pipefail

PI_SKILLS=(
  "https://github.com/cathrynlavery/diagram-design"
  "npm:@lucascardozo/pi-edit-guard"   # own Pi ext: indentation-drift recovery on edit
  "npm:@vndv/pi-codegraph"             # CodeGraph native ext (needs `@colbymchenry/codegraph` CLI installed separately)
)

# Next.js docs snapshot — generates the nextjs-docs-v<version> skill at the end.
# Override per-run with: NEXT_DOCS_VERSION=15.5 ./bootstrap.sh
NEXT_DOCS_VERSION="${NEXT_DOCS_VERSION:-16.3}"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Log lives outside the repo: bootstrap.sh is a dotfiles drop, runtime state
# belongs in the user's XDG state dir, not inside the tracked tree.
NEXT_DOCS_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-ai/next-docs-installed.log"

AGENTS_SKILLS=(
  # Next.js official skills (sparse-checkout from vercel/next.js canary branch)
  "https://github.com/vercel/next.js|skills/next-dev-loop|canary"
  "https://github.com/vercel/next.js|skills/next-cache-components-adoption|canary"
  "https://github.com/vercel/next.js|skills/next-cache-components-optimizer|canary"
  # vercel-labs/agent-skills (sparse-checkout from main branch)
  "https://github.com/vercel-labs/agent-skills|skills/vercel-optimize|main"
  "https://github.com/vercel-labs/agent-skills|skills/react-best-practices|main"
  "https://github.com/vercel-labs/agent-skills|skills/web-design-guidelines|main"
  "https://github.com/vercel-labs/agent-skills|skills/composition-patterns|main"
  "https://github.com/vercel-labs/agent-skills|skills/react-view-transitions|main"
  # Engineering / design discipline skills (main branch)
  "https://github.com/mattpocock/skills|skills/engineering/improve-codebase-architecture|main"
  "https://github.com/mattpocock/skills|skills/engineering/codebase-design|main"
  "https://github.com/anthropics/skills|skills/frontend-design|main"
  # Typst authoring (docs mirrored locally, no network at use time)
  "https://github.com/apcamargo/typst-skills|typst-author|main"
  "https://github.com/apcamargo/typst-skills|touying-author|main"
  # Media generation via mmx CLI (text/image/video/speech/music/vision/search)
  "https://github.com/MiniMax-AI/skills|skills/minimax-multimodal-toolkit|main"
  # Prisma ORM skills (Prisma 7.x — official prisma/skills repo)
  # Targets self-hosted Postgres (Neon/Supabase/RDS/local) via prisma-database-setup.
  # prisma-postgres and prisma-postgres-setup are intentionally NOT included:
  # they target the Prisma Postgres managed product only.
  "https://github.com/prisma/skills|prisma-client-api|main"
  "https://github.com/prisma/skills|prisma-cli|main"
  "https://github.com/prisma/skills|prisma-database-setup|main"
  # wshobson/agents marketplace (~94 plugins, ~183 skills).
  # Big catalog: add new ones here as you adopt them, sparse-checkout the
  # exact subpath under plugins/<category>/skills/<id>/.
  "https://github.com/wshobson/agents|plugins/javascript-typescript/skills/typescript-advanced-types|main"
  # HTML PPT Studio (lewislulu, MIT, 8k+ stars). Subpath is space-separated
  # because assets/templates live at repo root. Trailing |id sets a custom
  # id; drops scripts/verify-output (5MB of CI screenshots) post-install.
  "https://github.com/lewislulu/html-ppt-skill|SKILL.md assets templates references scripts LICENSE README.md README.zh-CN.md|main|html-ppt-studio"
  # Archify (tt-a1i, MIT): architecture/workflow/sequence/dataflow/lifecycle
  # diagrams as standalone HTML. Subpath is the skill's directory inside
  # the upstream monorepo (NOT the repo root). Drops test/ + the npm
  # lockfile post-install (dev-only, not needed at skill runtime).
  "https://github.com/tt-a1i/archify|archify|v2.10.0"
  # firecrawl/anydoc (MIT) — Office docs / PDFs (docx/pptx/xlsx/odt/pdf/csv/rtf/epub)
  # → GFM Markdown via `npx -y @firecrawl/anydoc`. OCR hosted opcional con
  # FIRECRAWL_API_KEY. Requiere Node 20+. Re-pinear a un tag estable cuando exista.
  "https://github.com/firecrawl/anydoc|skills/convert-documents-to-markdown|main"
  # "<repo-url>|<subpath-inside-repo>|<ref>"
  # example: clone just one subfolder of a monorepo into ~/.agents/skills/<id>
  # "https://github.com/MiniMax-AI/skills|skills/android-native-dev|main"
)

install_pi() {
  local url="$1"
  echo "→ pi install: $url"
  pi install "$url"
}

install_agents_skill() {
  local repo="$1" subpath="$2" ref="$3"
  local id="${4:-$(basename "$subpath")}"
  local target="$HOME/.agents/skills/$id"

  echo "→ agents-dir: $id  ($ref)"
  local tmp; tmp="$(mktemp -d)"
  git clone --depth 1 --filter=blob:none --sparse --branch "$ref" "$repo" "$tmp/repo" >/dev/null
  # subpath may be a single directory or a space-separated list of paths
  # (e.g. "SKILL.md assets templates"); sparse-checkout applies them all.
  git -C "$tmp/repo" sparse-checkout set --no-cone $subpath >/dev/null
  mkdir -p "$(dirname "$target")"
  rm -rf "$target"
  # If $subpath resolves to a directory inside the repo, flatten it into $target
  # (so `skills/<id>/` entries land at $target/SKILL.md, not $target/skills/<id>/).
  # Otherwise treat $subpath as a multi-path list (case: html-ppt-studio's
  # `SKILL.md assets templates ...`) — sparse-checkout left them at repo root,
  # so copy the whole root. Always strip the sparse clone's .git metadata.
  if [[ -d "$tmp/repo/$subpath" ]]; then
    cp -r "$tmp/repo/$subpath/." "$target/"
  else
    cp -r "$tmp/repo/." "$target/"
  fi
  rm -rf "$target/.git"
  rm -rf "$tmp"
}

for url in "${PI_SKILLS[@]}"; do
  [[ "$url" =~ ^# ]] && continue
  install_pi "$url"
done

for entry in "${AGENTS_SKILLS[@]}"; do
  [[ "$entry" =~ ^# ]] && continue
  IFS='|' read -r repo subpath ref id _ <<< "$entry"
  install_agents_skill "$repo" "$subpath" "$ref" "$id"
done

# Drop CI verification screenshots from heavy skills (not needed at runtime)
rm -rf "$HOME/.agents/skills/html-ppt-studio/scripts/verify-output" 2>/dev/null || true
# Drop dev-only artifacts from archify (tests + npm lockfile are not runtime)
rm -rf "$HOME/.agents/skills/archify/test" 2>/dev/null || true
rm -f  "$HOME/.agents/skills/archify/package-lock.json" 2>/dev/null || true

# Install user theme (Pi visual config). Copy from bundle so it's versionable.
if [[ -f "$DOTFILES_DIR/themes/violet-rose.json" ]]; then
  mkdir -p "$HOME/.pi/agent/themes"
  cp "$DOTFILES_DIR/themes/violet-rose.json" "$HOME/.pi/agent/themes/violet-rose.json"
  echo "  ✓ theme: violet-rose installed → ~/.pi/agent/themes/"
else
  echo "  ! themes/violet-rose.json missing from bundle — skip theme install" >&2
fi

# Install pi-web-access (formerly pi-web-search) config. Copy from bundle so it's
# versionable. Destination is the loader path the ext actually reads
# (getWebSearchConfigDir() in utils.ts falls back to ~/.pi/agent/web-search.json
# when XDG_CONFIG_HOME is unset). Keep this file free of secrets — anything
# committed here ships in the repo.
if [[ -f "$DOTFILES_DIR/agent/web-search.json" ]]; then
  mkdir -p "$HOME/.pi/agent"
  cp "$DOTFILES_DIR/agent/web-search.json" "$HOME/.pi/agent/web-search.json"
  echo "  ✓ web-search config installed → ~/.pi/agent/"
else
  echo "  ! agent/web-search.json missing from bundle — skip web-search config install" >&2
fi

# Install pi-edit-guard global config (auto-format on edit). Copy from bundle
# so it's versionable. Project-level overrides are NOT touched here.
if [[ -f "$DOTFILES_DIR/agent/edit-guard.json" ]]; then
  mkdir -p "$HOME/.pi/agent"
  cp "$DOTFILES_DIR/agent/edit-guard.json" "$HOME/.pi/agent/edit-guard.json"
  echo "  ✓ edit-guard config installed → ~/.pi/agent/"
else
  echo "  ! agent/edit-guard.json missing from bundle — skip edit-guard config install" >&2
fi

# Install gentle-pi provider profiles (model + thinking config for review/agent
# roles). Copy from bundle so it's versionable. Clobber semantics: any runtime
# `active` change is overwritten on next bootstrap — the bundle is the source
# of truth for the default profile. The file carries no secrets.
if [[ -f "$DOTFILES_DIR/gentle-ai/profiles.json" ]]; then
  mkdir -p "$HOME/.pi/gentle-ai"
  cp "$DOTFILES_DIR/gentle-ai/profiles.json" "$HOME/.pi/gentle-ai/profiles.json"
  echo "  ✓ gentle-ai profiles installed → ~/.pi/gentle-ai/"
else
  echo "  ! gentle-ai/profiles.json missing from bundle — skip gentle-ai profiles install" >&2
fi

# Install custom model providers config. Copy from bundle so it's versionable.
# API keys NEVER live in the bundle — see AGENTS.md "API keys pattern". The
# bundle ships with apiKey="" placeholders; you fill them in at runtime.
#
# No-clobber rule: if a runtime copy already exists, leave it alone so the
# user's real keys survive any re-run of bootstrap.sh. To pull a refresh of
# the bundle model list, back up the runtime file first and remove it.
if [[ -f "$DOTFILES_DIR/agent/models.json" ]]; then
  mkdir -p "$HOME/.pi/agent"
  if [[ -f "$HOME/.pi/agent/models.json" ]]; then
    echo "  ⤵  models config already at ~/.pi/agent/models.json — leaving it alone (preserves API keys)"
  else
    cp "$DOTFILES_DIR/agent/models.json" "$HOME/.pi/agent/models.json"
    chmod 600 "$HOME/.pi/agent/models.json"
    echo "  ✓ models config installed (placeholder apiKey=\"\") → ~/.pi/agent/ — fill in provider keys before use"
  fi
else
  echo "  ! agent/models.json missing from bundle — skip models config install" >&2
fi

# Install local-first skills bundled with the repo (idempotent copy).
for skill_dir in "$DOTFILES_DIR"/skills/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_id="$(basename "$skill_dir")"
  if [[ ! -f "$skill_dir/SKILL.md" ]]; then
    echo "  ! $skill_id: missing SKILL.md, skip" >&2
    continue
  fi
  mkdir -p "$HOME/.agents/skills/$skill_id"
  cp -r "$skill_dir." "$HOME/.agents/skills/$skill_id/"
  echo "  ✓ skill (local): $skill_id → ~/.agents/skills/"
done

# Bake the web-design-guidelines rulebook into the skill so reviews work offline.
# Failure here is non-fatal: the un-baked skill still works via its remote fetcher.
"$DOTFILES_DIR/bake-web-design-rules.sh" \
  || echo "  ! web-design-guidelines rules not baked; skill will fall back to remote fetch" >&2

# Snapshot Next.js docs into a global skill. Failure here is non-fatal:
# the rest of the bundle is already installed and usable without it.
if "$DOTFILES_DIR/generate-next-docs.sh" "$NEXT_DOCS_VERSION"; then
  mkdir -p "$(dirname "$NEXT_DOCS_LOG")"
  printf '%s  v%s  OK\n' "$(date -u +%FT%TZ)" "$NEXT_DOCS_VERSION" >> "$NEXT_DOCS_LOG"
else
  echo "  ! nextjs-docs (v${NEXT_DOCS_VERSION}) not generated — run $DOTFILES_DIR/generate-next-docs.sh $NEXT_DOCS_VERSION manually" >&2
fi

echo "✓ done. open Pi and run /reload."
