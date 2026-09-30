# Feature: opt-in overwrite prompt for the copied config files

## Goal

Two linked changes, both about the runtime copy of a bundle config:

1. **Sync.** The running `~/.pi/gentle-ai/profiles.json` is ahead of the bundle
   in one place — `Boludear.orchestrator.model` is `nan/mimo-v2.6-flash` on the
   machine and `nan/qwen3.6` in the bundle. Mirror the runtime file into the
   bundle so a fresh bootstrap reproduces what actually runs.
2. **Prompt.** `bootstrap.sh` currently overwrites `gentle-ai/profiles.json` and
   `~/agent/models.json` unconditionally. Add one interactive confirmation before
   replacing either file, so a runtime edit (most often the `active` profile) is
   never lost to a keystroke of habit.

## Non-goals

- No prompt for `web-search.json`, `edit-guard.json`, or the theme loop: those
  carry no runtime-mutable state worth a confirmation.
- No diff viewer, no per-key merge, no backup file, no "merge runtime into
  bundle" path. The decision is binary: bundle copy or runtime copy.
- No change to the API-key contract: the rendered `models.json` still takes every
  `apiKey` from `$ENV` (see `AGENTS.md` "API keys pattern"). The prompt decides
  *whether* the rendered file lands, never *what* it contains.
- No new flag beyond `-y` / `--yes` (`DOTFILES_ASSUME_YES=1` for the same).
- No prompt when the target is absent (nothing to lose) or byte-identical to the
  candidate (nothing to decide): the prompt must not become noise on the common
  no-op run.

## Design decisions

1. **One helper, `ask_overwrite CANDIDATE TARGET LABEL`.** It compares the
   candidate against the target and returns `0` (replace) or `1` (keep). Both
   clobber sites call it, so the semantics cannot drift apart. For
   `profiles.json` the candidate is the bundle file; for `models.json` it is the
   already-rendered temp file, which is why the helper takes a candidate path
   instead of assuming "bundle".

2. **Default is yes, but only when a human is there to say it.** Interactive
   prompt is `[Y/n]`: Enter, `y`/`Y`, or `yes` replaces; anything else keeps. The
   user chose this over `[y/N]` to preserve the familiar "run bootstrap → bundle
   lands" flow, and `yes` is accepted because the label invites it — refusing it
   would keep a copy the human just asked to replace.

3. **No TTY means keep, never hang and never clobber silently.** `[[ -t 0 ]]`
   gates the prompt. Unattended runs (cron, CI, `</dev/null`, piped stdin) keep
   the runtime copy and emit a `!` line naming the reason and the `-y` escape.
   This is the deliberate asymmetry that makes decision 2 safe: consent is never
   inferred from a missing terminal.

4. **EOF is not consent.** `read` returning non-zero (Ctrl-D, closed descriptor)
   is treated as "keep", while an empty *successful* read is Enter's yes. The
   implementation must distinguish the two — testing `-z "$answer"` alone cannot.

5. **A kept runtime copy is reported, never silent.** One `!` line:
   `… runtime copy kept; the bundle copy was NOT installed`. Skipping is
   user-visible, which is the whole point of having the prompt.

6. **`models.json`: decide before reporting, and delete the temp on keep.** The
   dropped-provider and removed-key warnings describe a mutation. If the user
   keeps the runtime file, those warnings are false and must not print — so both
   are computed inside the replace branch, after the decision. The rendered temp
   is removed on keep so no half-configured copy is left in `~/.pi/agent/`.

7. **A kept `models.json` still gets mode `600` when it is wider.** The old
   unconditional clobber was also what re-tightened the mode of a file holding
   API keys. Keep deliberately does not rewrite content, but leaving a
   hand-created `644` file full of keys readable would be a security regression
   introduced by this feature. `chmod 600` is applied only when the mode is not
   already `600`, and the tightening is reported. `stat` is probed GNU-first then
   BSD (`-c '%a'` / `-f '%Lp'`) to keep the macOS path this script already
   accommodates for `wait -n`.

8. **`-y` / `--yes` (and `DOTFILES_ASSUME_YES=1`) is the automation escape.** It
   answers every overwrite prompt with yes and prints no prompt, restoring exact
   today's behavior for scripted runs.

9. **The rendered temp is cleaned up on exit.** *(Added after review, finding
   F1.)* Because the candidate must exist in order to be compared, decision 6's
   temp is created *before* the prompt — so a run interrupted while a human
   deliberates parks a copy of the env-derived keys in `~/.pi/agent/`, a window
   that used to last microseconds. A single `trap 'rm -f "$models_tmp"' EXIT`
   covers the interrupt paths (bash runs `EXIT` traps on the fatal signals a
   killed script receives; verified for SIGINT, SIGTERM and SIGHUP), while the
   replace branch's `mv` and the keep branch's `rm -f` already cover the normal
   paths, so the trap is a no-op there. SIGKILL cannot be trapped at all, so the
   block also sweeps `~/.pi/agent/.models.json.*` before rendering its temp: a
   leftover from an untrappable death is removed by the next run instead of
   holding a copy of the keys indefinitely.

## Tasks

- [x] T1 — Mirror `~/.pi/gentle-ai/profiles.json` into
      `gentle-ai/profiles.json` (verbatim, JSON validated, no other diff line).
- [x] T2 — Add `ask_overwrite()` and the `-y` / `--yes` flag to `bootstrap.sh`,
      and wire both clobber sites (`gentle-ai/profiles.json`, `agent/models.json`)
      through it, per decisions 1–8.
- [x] T3 — Update `AGENTS.md`: the `profiles.json` and `models.json` Layout
      bullets, the "API keys pattern" clobber point, and the Commands block.
- [x] T4 — Independent verification of the behavior matrix (isolated `HOME`).
- [x] T5 — Work-unit commit on the feature branch.

## Checks

- [x] `bash -n bootstrap.sh` parses.
- [x] Sync is exactly one line: `diff` between the bundle and the runtime file
      shows only `nan/qwen3.6` → `nan/mimo-v2.6-flash` under
      `Boludear.orchestrator.model`; `jq empty` passes on the bundle.
- [x] Behavior matrix below, run against an extracted block in a throwaway
      `HOME`, not against the live machine.

| case | expected |
| --- | --- |
| target absent | copy, no prompt |
| target identical to candidate | copy (no-op), **no** prompt |
| `-y` / `DOTFILES_ASSUME_YES=1`, differing target | replace, no prompt |
| stdin not a TTY, differing target | keep + `!` naming the reason |
| interactive `y`, differing target | replace |
| interactive Enter, differing target | replace (default yes) |
| interactive `n`, differing target | keep + `!` |
| interactive EOF (Ctrl-D) | keep + `!` (never treated as consent) |
| `models.json` keep with mode `644` | content untouched, mode tightened to `600`, reported |
| `models.json` keep | no "provider dropped" / "key removed" warning printed |

- [x] `--help` documents `-y` / `--yes` (and the `?` line in the curated-output paragraph).
- [x] No prompt path can block a non-interactive run; the exit status stays `0`
      on every path, including a deliberate `n`.

## Evidence

The harness extracts the code instead of rewriting it: `sed -n '/^ask_overwrite() {/,/^}/p'`
for the helper and `awk '/^# gentle-pi provider profiles/,/^# === Local skills ===/'`
for the two config blocks, replayed in a throwaway `HOME` under
`set -euo pipefail` with `DOTFILES_DIR` pointed at the repo (`jq` required).
Interactive cases use a real pty via `printf '<answer>\n' | timeout 10 script -qec …`,
never a hand-rolled pty reader.

**Independent verification (pre-review revision): 13/13 acceptance cases PASS.**
Reported with command and observed output. Highlights: the non-tty path returns
in 18 ms with the runtime copy kept; a piped `y` is not consent; an empty-answer
EOF keeps (the discriminator a `-z "$answer"` test would have failed); the
key never appears in `jq`'s argv (sentinel probe, `grep -c` = 0 over the recorded
argv) while the rendered file still receives it at mode 600.

**Delta re-verification (after the review fixes).** Parent-run, same harness:

| case | result |
| --- | --- |
| empty HOME | installs both, no `?`, no `!` |
| identical re-run | silent, no prompt |
| differing profiles + no tty | kept + reason named, no prompt, 43 ms |
| differing profiles + `-y` / `DOTFILES_ASSUME_YES=1` | replaced |
| answers `n`/`no`/`yeah`/`x` | kept |
| answers `y`/`Y`/`yes`/`YES`/`Yes`/Enter | replaced |
| EOF with an empty answer, EOF after a partial line | kept, both |
| `models.json` keep | content byte-identical, no ✓, no dropped/removed-key warning, 0 stray temps |
| `models.json` keep at mode 644 | tightened to 600 and reported |
| `models.json` replace (`-y`) | installed, mode 600, both warnings fire, `legacy` provider gone |
| exit status | `0` on every path, including `n`; a `trap … EXIT` does not overwrite the script's status |

**F1 fix, end to end.** With a sentinel `NAN_API_KEY` and the run genuinely
parked at the prompt on a pty, a `.models.json.XXXXXX` temp **did** exist in the
fake `$HOME/.pi/agent/`, at mode 600, **containing the sentinel key** — the
exposure the finding described. After SIGTERM/SIGHUP: 0 orphans and the runtime
copy byte-identical. After SIGKILL: 1 orphan, because no trap can run — and the
next run's sweep removed it (`antes: 1 huérfano` → `después: 0`, with the run
still exiting 0 and still printing its provider warnings).

**Structural checks.** `bash -n` clean; `--help` exits 0 and documents `-y`,
`--yes`, `DOTFILES_ASSUME_YES=1`; an unknown flag is still rejected with exit 2;
`ask_overwrite` has exactly one definition and two call sites; `web-search.json`,
`edit-guard.json` and the theme loop still clobber unconditionally (the
non-goals hold); the sync is exactly the one claimed line and the bundle file is
byte-identical to the live runtime copy.

## Review findings

| id | finding | disposition |
| --- | --- | --- |
| F1 | An interrupted run left the rendered temp — holding the env-derived keys — in `~/.pi/agent/`, and they accumulated across kills. The prompt widened a microsecond window to "however long a human deliberates". | **Fixed** (decision 9), in two parts: `trap 'rm -f "$models_tmp"' EXIT` for the trappable signals, plus a pre-render sweep that self-heals the untrappable ones. Re-proven after the fix: parked at the prompt with a sentinel key, SIGTERM leaves 0 orphans and an intact runtime copy; SIGKILL leaves 1 orphan (no trap can run) that the next run removes. |
| F2 | The whole "Config files" section runs *after* the extensions, the skill pool and the CLI tools, so a run stalls at the prompt only once the network installs have already mutated the machine. | **Recorded, not fixed** — reordering the sections changes the curated output contract and is out of scope for this feature. Candidate follow-up. |
| F3 | Typing `yes` kept the copy, because decision 2 only accepted `y`/`Y`. Spec-conformant but a UX trap under a `[Y/n]` label. | **Fixed** (decision 2): `[yY][eE][sS]` is accepted; `yeah` still keeps. |
| F4 | Three doc/code drifts in `AGENTS.md`: "a malformed runtime file is simply replaced" (now confirmed), "the next bootstrap removes the key" (now on the replace path only), and `DOTFILES_ASSUME_YES=1` documented nowhere. | **Fixed.** |

## Delivery

- Branch `chore/config-overwrite-prompt`, two work-unit commits on top of `e1428e5`:
  - `b6864c1` `chore(config): sync the Boludear orchestrator model into the bundle`
    — T1 in isolation, so the one-line config sync stays reviewable on its own.
  - `7f75aed` `feat(bootstrap): ask before overwriting a differing config copy`
    — `bootstrap.sh`, `AGENTS.md` and this record, including the F1/F3/F4 fix batch.
- **Merged fast-forward into `main` and pushed:** `origin/main` = `4ab51e3`
  (merge commit-free: `main` had no commit the branch lacked, and the pushed
  range was `e1428e5..4ab51e3`). The local feature branch was deleted; no remote
  branch existed, since it was never pushed on its own.
- One follow-up fix commit landed on top, after the late delivery of the
  verifier's message: the pre-render sweep for untrappable deaths (F1's last
  quarter). The post-fix regression is 8/8 in the extracted-block harness.
- Open follow-up for the user: F2 (the prompt lands after the network installs,
  because the whole "Config files" section runs last). Fixing it means moving
  sections, which changes the curated-output order this feature deliberately
  left alone.
