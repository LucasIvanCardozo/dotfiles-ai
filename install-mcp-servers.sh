#!/usr/bin/env bash
# Install the MCP servers this bundle declares into the active Gentle Shell
# home.
#
# The runtime file is written by Pi's own `mcp add` command (reached through
# `gentle-shell mcp add`), never by hand: the entry keeps the exact schema Pi
# validates and the file keeps the formatting Pi writes.
#
# Usage:
#   ./install-mcp-servers.sh              # install or reconcile the servers
#   ./install-mcp-servers.sh --verbose    # stream the underlying command output
#
# Environment:
#   DOTFILES_VERBOSE=1  same as --verbose.
#
# Declaration — one pipe-separated record per server:
#
#   name|transport|target|exposure|description
#
#   name        server name; its tools reach the model as mcp__<name>__<tool>
#   transport   "stdio" (a local command) or "url" (a remote HTTP server)
#   target      stdio: the command line (quoted parts allowed, $HOME expands);
#               url:    the server URL
#   exposure    direct | deferred | codemode | hidden (empty = Pi's default)
#   description one sentence about what the server offers (may not contain "|")
#
# Rules:
#   * Only the servers declared here are touched. A server added by hand is
#     never removed and never rewritten.
#   * A declared server is reconciled: an entry that differs from the
#     declaration is replaced — the bundle is the source of truth for the
#     servers it declares — and the change is reported.
#   * A stdio server whose binary is missing on this machine is skipped with a
#     warning: that binary is a per-machine prerequisite (see AGENTS.md).
#   * Failures are non-fatal for the rest of the bundle: MCP is optional.
set -uo pipefail

usage() {
  sed -n '2,35p' "$0" | sed 's/^#\{1,\} \{0,1\}//'
}

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'install-mcp-servers.sh: unknown argument: %s\n' "$arg" >&2; exit 2 ;;
  esac
done
[[ "${DOTFILES_VERBOSE:-0}" == "1" ]] && VERBOSE=1

# The MCP servers this bundle installs. One record per line, pipe-separated,
# so no field may contain "|". Add a new server here — nothing else to touch.
MCP_SERVERS=(
  # Pen (pen.dev) design canvas. The desktop app and this MCP binary are
  # per-machine (the app ships them); the registration is what the bundle
  # owns. `direct` exposure declares its tools to the model like built-in
  # tools — the pen-dev skill calls them that way.
  'pencil|stdio|"$HOME/.local/opt/pen/mcp/mcp-server-linux-x64" --app desktop --agent gentle-shell|direct|Pen (pen.dev) design canvas: inspect and edit .pen documents in the running Pen desktop app'
)

ok()   { echo "  ✓ $*"; }
warn() { echo "  ! $*" >&2; }

if ! command -v gentle-shell >/dev/null 2>&1; then
  warn "gentle-shell not found on PATH — MCP servers not installed"
  warn "  install it with: npm i -g gentle-pi   (or the bundled installer)"
  exit 0
fi

# The agent dir the runtime actually uses. `gentle-shell home` prints
# "<mode> <path>"; the path is what owns mcp.json.
home_line="$(gentle-shell home 2>/dev/null | tail -n 1)"
agent_dir="${home_line##* }"
[[ -n "$agent_dir" && "$agent_dir" != "$home_line" ]] || agent_dir="$HOME/.gentle-shell/agent"
mcp_file="$agent_dir/mcp.json"

failed=0
tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-mcp.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

for record in "${MCP_SERVERS[@]}"; do
  [[ "$record" =~ ^[[:space:]]*$ ]] && continue
  IFS='|' read -r name transport target exposure description <<< "$record"

  if [[ -z "$name" || -z "$transport" || -z "$target" ]]; then
    warn "malformed record (name|transport|target|exposure|description): $record"
    failed=1
    continue
  fi

  # stdio: the command line becomes the server's argv, so it is word-split
  # here (quoted parts and $HOME expand).
  cmd=()
  if [[ "$transport" == "stdio" ]]; then
    eval "cmd=($target)"
    exe="${cmd[0]:-}"
    if [[ -z "$exe" ]]; then
      warn "$name — malformed command; skipped"
      failed=1
      continue
    fi
    # A missing binary is a per-machine prerequisite, not a broken bundle:
    # report it and leave the server unregistered.
    if [[ "$exe" == */* ]]; then
      [[ -x "$exe" ]] || { warn "$name — skipped: $exe not found (per-machine prerequisite)"; continue; }
    else
      command -v "$exe" >/dev/null 2>&1 || { warn "$name — skipped: $exe not on PATH (per-machine prerequisite)"; continue; }
    fi
  fi

  args=()
  [[ -n "$exposure" ]] && args+=(--exposure "$exposure")
  [[ -n "$description" ]] && args+=(--description "$description")
  if [[ "$transport" == "url" ]]; then
    args+=(--url "$target")
  else
    args+=(--)
    args+=("${cmd[@]}")
  fi

  before="$tmpdir/before.json"
  [[ -f "$mcp_file" ]] && cp "$mcp_file" "$before"

  if (( VERBOSE )); then
    if ! gentle-shell mcp add "$name" "${args[@]}"; then
      warn "$name — could not be added to $mcp_file"
      failed=1
      continue
    fi
  else
    out="$tmpdir/out.txt"
    if ! gentle-shell mcp add "$name" "${args[@]}" >"$out" 2>&1; then
      warn "$name — could not be added to $mcp_file"
      sed 's/^/      /' "$out" >&2
      failed=1
      continue
    fi
  fi

  # The command rewrites the file even when nothing changed, so compare the
  # bytes to report what really happened.
  if [[ -f "$before" ]] && cmp -s "$before" "$mcp_file"; then
    ok "$name (already configured)"
  elif [[ -f "$before" ]] && grep -q "\"$name\"" "$before"; then
    ok "$name (updated)"
  else
    ok "$name (installed)"
  fi
done

exit "$failed"
