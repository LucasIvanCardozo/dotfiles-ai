#!/usr/bin/env bash
# generate-next-docs.sh — snapshot Next.js bundled docs into a global skill.
#
# Reads dist/docs/ from the official npm package and lands it at
# ~/.agents/skills/nextjs-docs-v<sanitized-version>/ as a deterministic, self-contained
# skill. Replaces per-project AGENTS.md reliance with a global one.
#
# Docs/ is mirrored, NOT auto-loaded into agent context. SKILL.md carries the
# TOC; the agent uses `read`/`ls` to navigate docs/ on demand — same pattern
# diagram-design uses with its assets/.
#
# Usage:
#   ./generate-next-docs.sh                 # latest version from npm
#   ./generate-next-docs.sh 16.3.0          # specific version
#
# Idempotent: skips if the skill folder already exists for that version.
# Requires: npm OR curl + tar.

set -euo pipefail

VERSION="${1:-latest}"
# Skill id must match Pi's slug rule (lowercase a-z, 0-9, hyphens only),
# so dots in the semver version become dashes in the slug.
SKILL_ID="nextjs-docs-v${VERSION//./-}"
TARGET="$HOME/.agents/skills/${SKILL_ID}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if [[ -d "$TARGET" ]]; then
  echo "→ already exists: $TARGET (delete it to regenerate)"
  exit 0
fi

# Resolve "latest" → concrete version from npm registry
if [[ "$VERSION" == "latest" ]]; then
  echo "→ resolving latest Next.js version…"
  if command -v npm >/dev/null 2>&1; then
    VERSION=$(npm view next version 2>/dev/null || true)
  fi
  if [[ -z "${VERSION:-}" ]] && command -v curl >/dev/null 2>&1; then
    VERSION=$(curl -sfL https://registry.npmjs.org/next/latest \
              | grep -oE '"version":"[^"]+"' | head -1 | cut -d'"' -f4)
  fi
  if [[ -z "${VERSION:-}" ]]; then
    echo "✗ could not resolve latest (no npm and no curl?)"; exit 1
  fi
  echo "  latest: $VERSION"
  SKILL_ID="nextjs-docs-v${VERSION//./-}"
  TARGET="$HOME/.agents/skills/${SKILL_ID}"
  [[ -d "$TARGET" ]] && { echo "→ already exists: $TARGET"; exit 0; }
fi

cd "$WORKDIR"

# Download the package tarball (lighter than full install)
if command -v npm >/dev/null 2>&1; then
  echo "→ downloading next@${VERSION} via npm pack…"
  # npm pack resolves semver (e.g. 16.3 → 16.3.4) and prints the actual
  # tarball filename on stdout. Capture it instead of guessing from $VERSION.
  TARBALL=$(npm pack "next@${VERSION}" 2>/dev/null | tail -1)
  [[ -n "$TARBALL" && -f "$TARBALL" ]] || { echo "✗ tarball not found"; exit 1; }
else
  echo "→ downloading from registry (npm not installed)…"
  curl -sfL "https://registry.npmjs.org/next/-/next-${VERSION}.tgz" -o pkg.tgz
  TARBALL="pkg.tgz"
fi

[[ -f "$TARBALL" ]] || { echo "✗ tarball not found"; exit 1; }

# Pull just dist/docs/ out of the tarball
echo "→ extracting dist/docs/…"
mkdir extracted
tar -xzf "$TARBALL" -C extracted
[[ -d extracted/package/dist/docs ]] || { echo "✗ dist/docs missing in tarball"; exit 1; }

# Assemble the skill
echo "→ writing $TARGET…"
mkdir -p "$TARGET/docs"
cp -r extracted/package/dist/docs/. "$TARGET/docs/"

# Small SKILL.md (TOC only; not the docs themselves)
cat > "$TARGET/SKILL.md" <<EOF
---
name: ${SKILL_ID}
description: Next.js v${VERSION} bundled documentation. Snapshot of npm \`next@${VERSION}/dist/docs/\` as the canonical API and per-error reference. Use when you need the exact current behavior of an App Router API (Server Components, Server Actions, Route Handlers), Cache Components / PPR semantics (\`use cache\`, \`cacheLife\`, \`cacheComponents\`), \`next.config.js\` options, or the per-error pages in \`docs/app/messages/\` (written for AI agents in Next 16+). Prefer this for "what does X do / why am I hitting error Y" look-ups; for workflow help load \`next-cache-components-adoption\`, \`next-cache-components-optimizer\`, or \`next-dev-loop\` instead. Navigate \`docs/\` by topic; do not load the whole tree at once.
---

# Next.js docs (v${VERSION})

Deterministic snapshot of the official Next.js documentation bundled with npm \`next@${VERSION}\`.

## When to use
    
When writing or reviewing Next.js code, prefer reading the matching file here over recalling patterns. The agent invokes this skill on Next.js work to pull per-page truth directly from \`docs/\`. For workflow-specific help (adopting Cache Components, instant-navigation e2e, dev-server verification) the dedicated \`next-cache-components-adoption\`, \`next-cache-components-optimizer\`, and \`next-dev-loop\` skills are better starting points.

## How to navigate

Do not load the entire \`docs/\` at once. Identify the topic, then read the matching file with \`read\`:

- \`docs/app/getting-started/\` — install, routing, data fetching, deployment
- \`docs/app/guides/\` — deep guides (caching, migrations, instant-navigation, partial-prefetching)
- \`docs/app/api-reference/cli/\` — \`create-next-app\`, \`next build\`, \`next dev\`, …
- \`docs/app/api-reference/components/\` — Image, Link, Script, Font
- \`docs/app/api-reference/config/\` — next.config.js options
- \`docs/app/api-reference/directives/\` — \`use client\`, \`use server\`, \`use cache\`
- \`docs/app/api-reference/file-conventions/\` — \`page.tsx\`, \`layout.tsx\`, \`route.ts\`, …
- \`docs/app/api-reference/functions/\` — \`cookies\`, \`headers\`, \`generateMetadata\`, …
- \`docs/app/messages/\` — per-error pages written for AI agents (Next 16+)

Refresh by deleting the skill directory and re-running this script.

## Source

Generated by \`generate-next-docs.sh\`. Audit stamp: \`.bootstrap-origin\` (source = npm:next@${VERSION}).
EOF

# Audit stamp
printf 'source=npm:next@%s\ninstalled_at=%s\n' \
  "$VERSION" "$(date -u +%FT%TZ)" > "$TARGET/.bootstrap-origin"

# Informational size report
SIZE=$(du -sh "$TARGET" 2>/dev/null | cut -f1)
echo "✓ done. $TARGET  (size on disk: $SIZE)"
echo "  refresh: ./generate-next-docs.sh  # delete the folder first to regenerate"
