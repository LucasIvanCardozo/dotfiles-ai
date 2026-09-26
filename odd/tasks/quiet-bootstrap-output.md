# Feature: quiet bootstrap output

## Goal

`bootstrap.sh` must print only intentional, human-readable lines by default
(section headers, `✓` per installed item, warnings). All third-party command
output (git clone progress, `pi install` chatter, helper-script step logs) is
captured and discarded on success, and dumped only when a step fails.

## Non-goals

- No progress spinner / `\r` in-place redraw (deferred; may be added later).
- No change to what is installed, in what order, or with which flags.
- No new dependency.

## Decisions (user-approved)

1. `bootstrap.sh` captures child-script output itself; `bake-web-design-rules.sh`
   and `generate-next-docs.sh` stay verbose when run standalone (unchanged files).
2. Quiet by default; `--verbose` / `-v` / `DOTFILES_VERBOSE=1` restores live
   streaming. A diagnostic log is written to XDG state only on failure.

## Tasks

- [x] T1 — Add arg parsing, `VERBOSE`, `LOG_DIR`, and `run_quiet()` helper.
      Evidence: `bootstrap.sh` (arg loop + helper).
- [x] T2 — Route `pi install` and `git clone` / `sparse-checkout` through
      `run_quiet`; move `ok()` to after the work succeeds (fixes a lie: `✓`
      was printed before knowing the install worked).
      Evidence: `install_pi()`, `install_agents_skill()`.
- [x] T3 — Route the `bake-web-design-rules.sh` and `generate-next-docs.sh`
      calls through `run_quiet`, keeping their non-fatal failure handling.
      Evidence: "Baking offline rules" / "Snapshotting Next.js docs" sections.
- [x] T4 — Document quiet-by-default + `--verbose` in the script header.
      Evidence: header comment block.

## Checks

- [x] Sandboxed full run, quiet mode (`HOME=/tmp/bs-sandbox3 ./bootstrap.sh`):
      output is 33 curated lines and zero third-party noise; exit 0; skill tree
      byte-identical in structure to a verbose run (23 skills, SKILL.md present
      in every one, `.git` stripped, `html-ppt-studio/scripts/verify-output`
      and `archify/test` + `package-lock.json` still dropped, baked rules
      present, `next-docs-installed.log` written).
- [x] Sandboxed full run, `--verbose`: previous behavior preserved — git clone
      banner/progress (22 lines) and `pi install` output (3 lines) stream live,
      curated lines still printed; exit 0.
- [x] Forced-failure run (bogus repo URL, sandboxed): prints
      `✗ next-dev-loop: git clone failed (exit 128)`, the captured git output
      indented, the persistent log path, and aborts with the same exit code;
      no later section runs; log written mode 600.
- [x] `bash -n` clean; `--help` works; unknown argument exits 2.
- [ ] Full run against the real `$HOME` (user-owned; see Next steps).
- [ ] `shellcheck` not installed on this machine, so no lint pass. Cheap
      follow-up if you want it: `pacman -S shellcheck && shellcheck bootstrap.sh`.

## Findings (out of scope, pre-existing)

- `generate-next-docs.sh` exits 0 when the target already exists, and
  `bake-web-design-rules.sh` exits 0 when the skill is absent; in both cases
  bootstrap still prints a `✓` success line. Not introduced by this change.
- `pi install` was verified non-interactive for the 3 configured sources in the
  sandbox. In quiet mode a trust prompt would block with its text going to the
  captured log, so confirm once on the real `$HOME` run in `--verbose`.

## Resolution

- User decision: **no RDD in this project**. Applied clone-scoped:
  `gentle-ai review mode disable --scope clone` → `off (decided by clone_local)`.
  Recorded in `AGENTS.md` so future sessions do not re-enable it.
- Commits (direct on `main`, no push):
  - `f04c85a` feat(bootstrap): quiet-by-default output with opt-in --verbose mode
  - `d0318cf` docs(agents): record quiet bootstrap output policy and RDD-off for this clone
- Real-`$HOME` run left to the user (they chose to run it themselves).
- This task file is untracked: `odd/` is new to this repo and has no convention yet.

## Next steps

- `./bootstrap.sh` against the real `$HOME`, once, to confirm on the real machine.
- Decide `odd/`'s fate: commit it as durable task docs, or gitignore it next to
  `.atl/` (agent-generated runtime state).
- Optional follow-up: TTY-only `…` progress line so long steps do not look frozen.
