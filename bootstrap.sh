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
#         ./bootstrap.sh            # quiet: only curated lines
#         ./bootstrap.sh --verbose  # stream every command's output live
#
# DOTFILES_JOBS=<n> caps how many agent skills install concurrently
# (default 6, 1 = one at a time). The clone loop is latency-bound, so a small
# pool is most of the wall-clock win; 12 distinct repos back the 21 entries.
#
# Output policy: by default only intentional lines are printed (section
# headers, one ✓ per installed item, warnings). Everything a third-party
# command prints (git clone progress, `pi install` chatter, helper-script
# step logs) is captured by run_quiet() and discarded on success. On failure
# the captured output is dumped, a persistent log is written under
# $XDG_STATE_HOME/dotfiles-ai/, and the script aborts. Use --verbose to
# bypass capture entirely when debugging.

set -euo pipefail

# Parse the only two flags this script understands. Everything else is an
# error rather than a silently ignored argument.
VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=1 ;;
    -h|--help) cat <<'USAGE'
Usage: ./bootstrap.sh [--verbose]

  (no flag)   print only curated lines: section headers, one ✓ per
              installed item, ! for warnings
  -v, --verbose  stream every command's output live (debugging)

  DOTFILES_VERBOSE=1 does the same as --verbose.
  DOTFILES_JOBS=<n>  concurrent skill installs (default 6, 1 = sequential).
  NEXT_DOCS_VERSION=<v> pins the Next.js docs snapshot version.
  API keys: bootstrap reads one environment variable per provider — the
  provider name uppercased with non-alphanumerics turned into _ plus
  "_API_KEY" (provider `nan` -> NAN_API_KEY). No variable means apiKey="".
  Keys are read by jq from its own environment, never from an argument.
USAGE
              exit 0 ;;
    *) echo "bootstrap.sh: unknown argument: $arg" >&2; exit 2 ;;
  esac
done
[[ "${DOTFILES_VERBOSE:-0}" == "1" ]] && VERBOSE=1
readonly VERBOSE

# Output helpers. step() emits a section header; ok() an indented success;
# warn() an indented warning to stderr for non-fatal skips.
step() { echo "→ $*"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ! $*" >&2; }

# Failure logs live outside the repo, next to the Next.js docs log below.
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-ai"

# run_quiet LABEL CMD... — run CMD with stdout+stderr captured.
# Success: nothing is printed. Failure: print the label, the captured output
# indented, and the path of the persistent log, then propagate the exit code
# (which aborts under `set -e`, or is caught by the caller's `if`).
run_quiet() {
  local label="$1"; shift
  if (( VERBOSE )); then
    "$@"
    return
  fi
  local out rc=0
  out="$(mktemp "${TMPDIR:-/tmp}/dotfiles-ai.XXXXXX")"
  "$@" >"$out" 2>&1 || rc=$?
  if (( rc == 0 )); then
    rm -f "$out"
    return 0
  fi
  local log; log="$LOG_DIR/bootstrap-$(date -u +%Y%m%dT%H%M%SZ).log"
  mkdir -p "$LOG_DIR"
  mv "$out" "$log" 2>/dev/null || true
  _dump_failure "$label" "$rc" "$log"
  return "$rc"
}

# _dump_failure LABEL EXITCODE LOGFILE — the single place that decides how a
# failed step looks. Shared by run_quiet and by the parallel skills loop.
# `tr` because git writes progress with carriage returns, which would otherwise
# collapse the dump into one unreadable line.
_dump_failure() {
  local label="$1" rc="$2" log="$3"
  {
    printf '  ✗ %s failed (exit %s)\n' "$label" "$rc"
    if [[ -f "$log" ]]; then tr '\r' '\n' < "$log" | sed 's/^/      /'; fi
    printf '    full log: %s\n' "$log"
  } >&2
}

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
NEXT_DOCS_LOG="$LOG_DIR/next-docs-installed.log"

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

# Pre-count entries for the section banners. AGENTS_SKILLS entries are
# "<repo>|<subpath>|<ref>[|<id>]" — count the array directly; pure-`#` lines
# inside the array definition are bash comments and not elements.
PI_COUNT=${#PI_SKILLS[@]}
AGENTS_COUNT=${#AGENTS_SKILLS[@]}
local_count=0
for _ in "$DOTFILES_DIR"/skills/*/; do
  [[ -d "$_" ]] || continue
  local_count=$((local_count + 1))
done

install_pi() {
  local url="$1"
  # Derive a short name from the URL or npm spec for cleaner output. Works
  # for both https://host/path/<name> and npm:@scope/<name> forms.
  local name="${url##*/}"
  run_quiet "pi install $name" pi install "$url"
  ok "$name"
}

install_agents_skill_worker() {
  local repo="$1" subpath="$2" ref="$3" target="$4"
  local tmp; tmp="$(mktemp -d)"
  # GIT_TERMINAL_PROMPT=0: jobs run with stdin detached, so a credential prompt
  # (unreachable repo, private repo, bad ref) would hang or steal terminal input
  # instead of failing. Fail fast. --quiet always: in the parallel path the
  # caller already captures this function's output, and in the verbose path the
  # clone banner is noise the user did not ask for.
  GIT_TERMINAL_PROMPT=0 git clone --quiet --depth 1 --filter=blob:none \
    --sparse --branch "$ref" "$repo" "$tmp/repo" || { rm -rf "$tmp"; return 1; }
  # subpath may be a single directory or a space-separated list of paths
  # (e.g. "SKILL.md assets templates"); sparse-checkout applies them all.
  git -C "$tmp/repo" sparse-checkout set --no-cone $subpath \
    || { rm -rf "$tmp"; return 1; }
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

# === Pi extensions ===
step "Pi extensions (${PI_COUNT})"
for url in "${PI_SKILLS[@]}"; do
  [[ "$url" =~ ^# ]] && continue
  install_pi "$url"
done

# === Agent skills ===
#
# The clone loop is latency-bound: each entry costs ~2.5-3.2s of DNS + TLS +
# ref negotiation + one blob fetch, and it was 79% of a cold run. It runs in a
# bounded pool instead, at ~5x wall-clock. Every skill writes to its own target
# directory, so the jobs share no state — only PI_SKILLS (`pi install`) does,
# through settings.json, and that is why it stays sequential.
#
# Output stays deterministic: jobs write to their own log, and the curated ✓
# lines are replayed in declaration order after the barrier. No interleaving,
# no completion-order dependence.
SKILL_JOBS="${DOTFILES_JOBS:-6}"
if [[ ! "$SKILL_JOBS" =~ ^[1-9][0-9]*$ ]]; then
  warn "DOTFILES_JOBS='$SKILL_JOBS' is not a positive integer — using 6"
  SKILL_JOBS=6
fi
# The throttle uses `wait -n` (bash >= 4.3). On older bash (macOS ships 3.2)
# fall back to one job at a time; the same code path then runs sequentially.
if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3) )); then
  warn "bash ${BASH_VERSION%%(*} has no 'wait -n' — installing skills sequentially"
  SKILL_JOBS=1
fi

step "Agent skills (${AGENTS_COUNT})"

# Resolve every entry up front so both paths share one list and one ordering.
SKILL_REPOS=(); SKILL_SUBPATHS=(); SKILL_REFS=(); SKILL_IDS=(); SKILL_LABELS=()
for entry in "${AGENTS_SKILLS[@]}"; do
  [[ "$entry" =~ ^# ]] && continue
  IFS='|' read -r repo subpath ref id _ <<< "$entry"
  id="${id:-$(basename "$subpath")}"
  SKILL_REPOS+=("$repo"); SKILL_SUBPATHS+=("$subpath"); SKILL_REFS+=("$ref")
  SKILL_IDS+=("$id"); SKILL_LABELS+=("$id  ($ref)")
done

if (( VERBOSE )); then
  # Debug path: foreground, one at a time, output streaming live.
  for skill_i in "${!SKILL_IDS[@]}"; do
    install_agents_skill_worker "${SKILL_REPOS[skill_i]}" "${SKILL_SUBPATHS[skill_i]}" \
      "${SKILL_REFS[skill_i]}" "$HOME/.agents/skills/${SKILL_IDS[skill_i]}"
    ok "${SKILL_LABELS[skill_i]}"
  done
else
  SKILL_JOBDIR="$(mktemp -d)"
  for skill_i in "${!SKILL_IDS[@]}"; do
    skill_id="${SKILL_IDS[skill_i]}"
    # </dev/null: never let a job read the terminal. The status file is the only
    # authoritative result — `wait` alone cannot say which job failed.
    ( skill_rc=0
      install_agents_skill_worker "${SKILL_REPOS[skill_i]}" "${SKILL_SUBPATHS[skill_i]}" \
        "${SKILL_REFS[skill_i]}" "$HOME/.agents/skills/$skill_id" || skill_rc=$?
      echo "$skill_rc" > "$SKILL_JOBDIR/$skill_id.status"
    ) >"$SKILL_JOBDIR/$skill_id.log" 2>&1 </dev/null &
    # Throttle: wait for one job to finish once the pool is full.
    while (( $(jobs -rp | wc -l) >= SKILL_JOBS )); do wait -n || true; done
  done
  wait || true

  # Barrier: all jobs are done, so the post-install cleanups and the bake step
  # below see a complete tree. Replay results in declaration order.
  skill_failed=0
  for skill_i in "${!SKILL_IDS[@]}"; do
    skill_id="${SKILL_IDS[skill_i]}"; skill_rc=1
    skill_status="$SKILL_JOBDIR/$skill_id.status"
    [[ -f "$skill_status" ]] && skill_rc="$(<"$skill_status")"
    if (( skill_rc == 0 )); then
      ok "${SKILL_LABELS[skill_i]}"
    else
      mkdir -p "$LOG_DIR"
      skill_log="$LOG_DIR/bootstrap-$(date -u +%Y%m%dT%H%M%SZ)-$skill_id.log"
      cp "$SKILL_JOBDIR/$skill_id.log" "$skill_log" 2>/dev/null || skill_log="$SKILL_JOBDIR/$skill_id.log"
      _dump_failure "${SKILL_LABELS[skill_i]}" "$skill_rc" "$skill_log"
      skill_failed=1
    fi
  done
  rm -rf "$SKILL_JOBDIR"

  # A pool cannot abort at the first error: every job already ran. Report them
  # all, then stop before the later sections touch a half-installed tree.
  if (( skill_failed )); then
    warn "${AGENTS_COUNT} agent skills requested, some failed — fix and re-run"
    exit 1
  fi
fi

# Drop CI verification screenshots from heavy skills (not needed at runtime)
rm -rf "$HOME/.agents/skills/html-ppt-studio/scripts/verify-output" 2>/dev/null || true
# Drop dev-only artifacts from archify (tests + npm lockfile are not runtime)
rm -rf "$HOME/.agents/skills/archify/test" 2>/dev/null || true
rm -f  "$HOME/.agents/skills/archify/package-lock.json" 2>/dev/null || true

# === Config files ===
step "Config files"

# Themes: Pi visual config. Copy every themes/*.json from the bundle so each
# one is versionable. The loop is the mechanism, not a shipped artifact: the
# bundle currently ships no theme, and an empty themes/ must be a silent no-op
# rather than a permanent "missing from bundle" warning on every run.
if [[ -d "$DOTFILES_DIR/themes" ]]; then
  for theme_file in "$DOTFILES_DIR"/themes/*.json; do
    # No nullglob here: an unmatched glob stays literal, so test before copying.
    [[ -f "$theme_file" ]] || continue
    theme_id="$(basename "$theme_file")"
    mkdir -p "$HOME/.pi/agent/themes"
    cp "$theme_file" "$HOME/.pi/agent/themes/$theme_id"
    ok "$theme_id → ~/.pi/agent/themes/"
  done
fi

# pi-web-access (formerly pi-web-search) config. Copy from bundle so it's
# versionable. Destination is the loader path the ext actually reads
# (getWebSearchConfigDir() in utils.ts falls back to ~/.pi/agent/web-search.json
# when XDG_CONFIG_HOME is unset). Keep this file free of secrets — anything
# committed here ships in the repo.
if [[ -f "$DOTFILES_DIR/agent/web-search.json" ]]; then
  mkdir -p "$HOME/.pi/agent"
  cp "$DOTFILES_DIR/agent/web-search.json" "$HOME/.pi/agent/web-search.json"
  ok "web-search.json → ~/.pi/agent/"
else
  warn "agent/web-search.json missing from bundle — skip web-search config install"
fi

# pi-edit-guard global config (auto-format on edit). Copy from bundle so it's
# versionable. Project-level overrides are NOT touched here.
if [[ -f "$DOTFILES_DIR/agent/edit-guard.json" ]]; then
  mkdir -p "$HOME/.pi/agent"
  cp "$DOTFILES_DIR/agent/edit-guard.json" "$HOME/.pi/agent/edit-guard.json"
  ok "edit-guard.json → ~/.pi/agent/"
else
  warn "agent/edit-guard.json missing from bundle — skip edit-guard config install"
fi

# gentle-pi provider profiles (model + thinking config for review/agent roles).
# Copy from bundle so it's versionable. Clobber semantics: any runtime `active`
# change is overwritten on next bootstrap — the bundle is the source of truth
# for the default profile. The file carries no secrets.
if [[ -f "$DOTFILES_DIR/gentle-ai/profiles.json" ]]; then
  mkdir -p "$HOME/.pi/gentle-ai"
  cp "$DOTFILES_DIR/gentle-ai/profiles.json" "$HOME/.pi/gentle-ai/profiles.json"
  ok "gentle-ai/profiles.json → ~/.pi/gentle-ai/"
else
  warn "gentle-ai/profiles.json missing from bundle — skip gentle-ai profiles install"
fi

# Custom model providers config. The bundle is the source of truth for the
# provider list, the models and their metadata, and the API keys come from the
# environment: provider `nan` reads NAN_API_KEY (provider name uppercased, every
# non-alphanumeric turned into _). No variable -> apiKey="". See AGENTS.md
# "API keys pattern".
#
# CLOBBERED on every run, so a provider or model added to the bundle reaches the
# machine at the next bootstrap. The runtime file holds no irreplaceable state
# (keys live in the environment, not in the file), so a malformed runtime copy
# is simply replaced instead of being preserved or repaired.
if [[ -f "$DOTFILES_DIR/agent/models.json" ]]; then
  mkdir -p "$HOME/.pi/agent"
  runtime_models="$HOME/.pi/agent/models.json"
  # umask 077 + same-directory temp + mv: the replacement is atomic and never
  # exposes a half-written credentials file or a momentarily widened mode.
  models_tmp="$(umask 077; mktemp "$HOME/.pi/agent/.models.json.XXXXXX")"
  models_dropped=""; models_lost=""
  if [[ -f "$runtime_models" ]]; then
    # Work out what this run removes BEFORE removing it, so the removal can be
    # reported instead of discovered later as a broken role.
    models_dropped="$(jq -r --slurpfile b "$DOTFILES_DIR/agent/models.json" \
      'if (.providers | type) == "object"
       then ((.providers | keys) - ($b[0].providers | keys) | join(", "))
       else "" end' "$runtime_models" 2>/dev/null || true)"
  fi
  # jq reads $ENV itself: the key never reaches an argv, so it cannot show up in
  # `ps`, and no bash-4-only uppercasing is needed (macOS ships bash 3.2).
  jq '.providers |= with_entries(
        . as $e
        | .value.apiKey = ($ENV[($e.key | ascii_upcase | gsub("[^A-Z0-9]"; "_")) + "_API_KEY"] // "")
      )' "$DOTFILES_DIR/agent/models.json" > "$models_tmp"
  if [[ -f "$runtime_models" ]]; then
    # Only providers that survive this run count as a lost key: one that is being
    # dropped entirely is already reported by the provider warning above.
    models_lost="$(jq -r --slurpfile new "$models_tmp" \
      '[.providers | to_entries[] | . as $e
        | select($e.value.apiKey != ""
                 and ($new[0].providers | has($e.key))
                 and (($new[0].providers[$e.key].apiKey // "") == ""))
        | $e.key] | join(", ")' \
      "$runtime_models" 2>/dev/null || true)"
  fi
  chmod 600 "$models_tmp"
  mv "$models_tmp" "$runtime_models"
  ok "models.json → ~/.pi/agent/ ($(jq '.providers | length' "$runtime_models") provider(s); $(jq '[.providers[] | select(.apiKey != "")] | length' "$runtime_models") key(s) from the environment)"
  [[ -n "$models_dropped" ]] && warn "models.json — provider(s) absent from the bundle were dropped: $models_dropped"
  [[ -n "$models_lost" ]] && warn "models.json — API key(s) REMOVED because no <PROVIDER>_API_KEY is set: $models_lost"
else
  warn "agent/models.json missing from bundle — skip models config install"
fi

# === Local skills ===
step "Local skills (${local_count})"
for skill_dir in "$DOTFILES_DIR"/skills/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_id="$(basename "$skill_dir")"
  if [[ ! -f "$skill_dir/SKILL.md" ]]; then
    warn "$skill_id: missing SKILL.md, skip"
    continue
  fi
  mkdir -p "$HOME/.agents/skills/$skill_id"
  cp -r "$skill_dir." "$HOME/.agents/skills/$skill_id/"
  ok "$skill_id → ~/.agents/skills/"
done

# === Baking offline rules ===
step "Baking offline rules"
# Bake the web-design-guidelines rulebook into the skill so reviews work offline.
# Failure here is non-fatal: the un-baked skill still works via its remote fetcher.
if run_quiet "bake-web-design-rules.sh" "$DOTFILES_DIR/bake-web-design-rules.sh"; then
  ok "web-design-guidelines rules baked"
else
  warn "web-design-guidelines rules not baked; skill will fall back to remote fetch"
fi

# === Snapshotting Next.js docs ===
step "Snapshotting Next.js docs (v${NEXT_DOCS_VERSION})"
# Snapshot Next.js docs into a global skill. Failure here is non-fatal:
# the rest of the bundle is already installed and usable without it.
if run_quiet "generate-next-docs.sh v${NEXT_DOCS_VERSION}" \
   "$DOTFILES_DIR/generate-next-docs.sh" "$NEXT_DOCS_VERSION"; then
  mkdir -p "$(dirname "$NEXT_DOCS_LOG")"
  printf '%s  v%s  OK\n' "$(date -u +%FT%TZ)" "$NEXT_DOCS_VERSION" >> "$NEXT_DOCS_LOG"
  ok "nextjs-docs (v${NEXT_DOCS_VERSION}) installed"
else
  warn "nextjs-docs (v${NEXT_DOCS_VERSION}) not generated — run $DOTFILES_DIR/generate-next-docs.sh $NEXT_DOCS_VERSION manually"
fi

echo "✓ Done. Open Pi and run /reload."