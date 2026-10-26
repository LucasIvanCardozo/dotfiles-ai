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
#         ./bootstrap.sh -y         # overwrite every differing config copy
#                                   # without asking (unattended runs)
#
# Overwrite prompts: the copied configs that can hold runtime edits
# (gentle-ai/profiles.json) ask before replacing a differing runtime copy — Enter/y/yes replaces, anything else keeps. With no
# terminal (cron, CI, piped stdin) the runtime copy is kept, never
# overwritten silently and never hung on; -y / --yes (or DOTFILES_ASSUME_YES=1)
# answers every prompt with yes and restores the unconditional clobber.
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

# Parse the only three flags this script understands. Everything else is an
# error rather than a silently ignored argument.
VERBOSE=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=1 ;;
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help) cat <<'USAGE'
Usage: ./bootstrap.sh [--verbose] [-y]

  (no flag)   print only curated lines: section headers, one ✓ per
              installed item, ? for the overwrite question, ! for warnings
  -v, --verbose  stream every command's output live (debugging)
  -y, --yes   answer every overwrite prompt with yes: differing config
              copies (gentle-ai/profiles.json) are replaced without
              asking. For unattended runs.

  DOTFILES_VERBOSE=1 does the same as --verbose.
  DOTFILES_ASSUME_YES=1 does the same as -y.
  DOTFILES_JOBS=<n>  concurrent skill installs (default 6, 1 = sequential).
  NEXT_DOCS_VERSION=<v> pins the Next.js docs snapshot version.
USAGE
              exit 0 ;;
    *) echo "bootstrap.sh: unknown argument: $arg" >&2; exit 2 ;;
  esac
done
[[ "${DOTFILES_VERBOSE:-0}" == "1" ]] && VERBOSE=1
# Same env-var equivalence as DOTFILES_VERBOSE: the unattended escape for the
# overwrite prompts below.
[[ "${DOTFILES_ASSUME_YES:-0}" == "1" ]] && ASSUME_YES=1
readonly VERBOSE ASSUME_YES

# Output helpers. step() emits a section header; ok() an indented success;
# warn() an indented warning to stderr for non-fatal skips.
step() { echo "→ $*"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ! $*" >&2; }

# ask_overwrite CANDIDATE TARGET LABEL — decide whether TARGET (the installed
# runtime copy) may be replaced by CANDIDATE (the bundle copy). Returns
# 0 = replace, 1 = keep. Both
# clobber sites go through this helper so the overwrite semantics cannot
# drift apart. Nothing is printed when there is nothing to decide.
ask_overwrite() {
  local candidate="$1" target="$2" label="$3"
  local answer
  # Nothing on disk yet: nothing to lose, so replace without asking.
  if [[ ! -f "$target" ]]; then
    return 0
  fi
  # Byte-identical: nothing to decide — keep the prompt out of the common
  # no-op run so it does not become noise.
  if cmp -s "$candidate" "$target"; then
    return 0
  fi
  # Unattended escape: -y / DOTFILES_ASSUME_YES=1 answers every prompt with
  # yes, restoring the old unconditional clobber for scripted runs.
  if (( ASSUME_YES )); then
    return 0
  fi
  # No terminal, no consent. A non-interactive run (cron, CI, </dev/null,
  # piped stdin) must never hang on read and must never clobber silently, so
  # the runtime copy is kept and the reason is reported. This is the
  # deliberate asymmetry that makes the [Y/n] default safe: consent is never
  # inferred from a missing terminal. Use -y to opt into overwriting.
  if [[ ! -t 0 ]]; then
    warn "$label — runtime copy kept: stdin is not a terminal (use -y to overwrite)"
    return 1
  fi
  # Prompt on stderr so a piped stdout stays clean. Default is yes ([Y/n]):
  # Enter or y replaces, anything else keeps. EOF is NOT consent — `read`
  # returning non-zero (Ctrl-D, closed descriptor) keeps the runtime copy
  # even though it also yields an empty answer, which is why the read's
  # status is tested before the answer's content.
  printf '  ? %s: runtime copy differs from the bundle — overwrite it? [Y/n] ' "$label" >&2
  answer=""
  if read -r answer; then
    case "$answer" in
      # `yes` is accepted too — the [Y/n] label invites it, and refusing it
      # would keep a copy the human just asked to replace.
      ""|[yY]|[yY][eE][sS]) return 0 ;;
      *) warn "$label — runtime copy kept; the bundle copy was NOT installed"
         return 1 ;;
    esac
  else
    warn "$label — runtime copy kept; the bundle copy was NOT installed"
    return 1
  fi
}

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
  "npm:@estebanforge/pi-codegraph-enhanced"  # CodeGraph native ext, fork of @vndv/pi-codegraph with startup auto-index (needs `@colbymchenry/codegraph` CLI on PATH)
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
  # Media generation via mmx CLI (text/image/video/speech/music/vision/search).
  # The skill lives at the repo root under skill/ (not skills/<id>/), so the
  # 4th field pins the installed id to mmx-cli — the skill's own frontmatter
  # name — instead of the subpath basename.
  "https://github.com/MiniMax-AI/cli|skill|main|mmx-cli"
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
  # Motion (motiondivision/ai-kit): animation skill for Motion (prev Framer
  # Motion) and CSS animation — best practices, docs/examples search, springs,
  # MotionScore audits.
  "https://github.com/motiondivision/ai-kit|plugins/motion/skills/motion|main"
  # firecrawl/anydoc (MIT) — Office docs / PDFs (docx/pptx/xlsx/odt/pdf/csv/rtf/epub)
  # → GFM Markdown via `npx -y @firecrawl/anydoc`. OCR hosted opcional con
  # FIRECRAWL_API_KEY. Requiere Node 20+. Re-pinear a un tag estable cuando exista.
  "https://github.com/firecrawl/anydoc|skills/convert-documents-to-markdown|main"
  # "<repo-url>|<subpath-inside-repo>|<ref>[|<id>]"
  # example: clone just one subfolder of a monorepo into ~/.agents/skills/<id>
  # "https://github.com/owner/repo|skills/<id>|main"
  # the optional 4th field overrides the installed id (default: subpath basename)
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

# === CLI tools ===
step "CLI tools"

# agent-browser: hard runtime prerequisite of the bundled next-dev-loop skill
# (>= 0.31.1), which drives a real Chrome next to /_next/mcp. Installed at
# @latest on purpose — the skill ships from vercel/next.js canary and keeps
# raising that floor, so a pinned CLI would go stale and the skill refuses to
# fall back to a weaker probe. Sequential, like `pi install`: npm -g mutates
# shared global state. No browser download happens here: agent-browser
# auto-detects an existing Chrome/Brave/Chromium/Playwright install, and the
# cold `agent-browser install` is a one-time per-machine step (see AGENTS.md).
if command -v npm >/dev/null 2>&1; then
  run_quiet "npm install -g agent-browser@latest" npm install -g agent-browser@latest
  ab_version="$(agent-browser --version 2>/dev/null | head -1 || true)"
  ok "agent-browser ${ab_version#agent-browser } (latest)"
else
  warn "npm not found on PATH — agent-browser not installed (next-dev-loop needs it)"
fi

# === Config files ===
step "Config files"

# gentle-pi provider profiles (model + thinking config for review/agent roles).
# Copy from bundle so it's versionable, but a differing runtime copy carries
# hand edits (most often the `active` profile) that a keystroke of habit must
# not lose: ask before replacing (see ask_overwrite). The file carries no
# secrets. On keep, the helper's `!` line is the only output — the `ok` line
# would falsely report an install that did not happen.
if [[ -f "$DOTFILES_DIR/gentle-ai/profiles.json" ]]; then
  mkdir -p "$HOME/.pi/gentle-ai"
  if ask_overwrite "$DOTFILES_DIR/gentle-ai/profiles.json" \
     "$HOME/.pi/gentle-ai/profiles.json" "gentle-ai/profiles.json"; then
    cp "$DOTFILES_DIR/gentle-ai/profiles.json" "$HOME/.pi/gentle-ai/profiles.json"
    ok "gentle-ai/profiles.json → ~/.pi/gentle-ai/"
  fi
else
  warn "gentle-ai/profiles.json missing from bundle — skip gentle-pi profiles install"
fi

# NOTE: model providers (~/.pi/agent/models.json) and themes are NOT managed
# by this bundle — they are machine-local state. A fresh machine must set up
# its own providers (and their API keys) directly in ~/.pi/agent/models.json.

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