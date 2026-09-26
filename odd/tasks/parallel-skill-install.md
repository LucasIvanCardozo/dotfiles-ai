# Feature: parallel agent-skill install

## Goal

The `AGENTS_SKILLS` loop (21 entries, 12 distinct repos) is 79% of a cold
bootstrap run: 67.6s of 85.2s, at a near-constant 2.5-3.2s per clone. The cost
is latency-bound (DNS + TLS + ref negotiation + a blob fetch per sparse
subpath), not bandwidth-bound, so it parallelizes almost linearly.

Measured on this machine (8 real skills from the list, content verified
identical with `diff -r --exclude=.git`):

| Mode | Wall clock | Speedup |
| --- | --- | --- |
| Sequential (today) | 25.5s | 1x |
| Pool of 6 | 5.0s | 5.1x |
| Unthrottled | 3.6s | 7.0x |

No HTTP 429 / rate-limit responses at either level. Projected whole script:
85s → ~25s.

## Non-goals

- `PI_SKILLS` (`pi install`) stays sequential on purpose: each invocation does a
  read-modify-write of the shared `packages` array in
  `~/.pi/agent/settings.json` plus a shared `node_modules`. Concurrent runs can
  drop entries. This is the Amdahl floor (~9.7s).
- No `next-docs` concurrency, no per-repo clone dedup (21 clones → 12), no
  SHA-based skip. Measured and deferred; see the conversation.
- No live progress line during the parallel phase.

## Design decisions

1. **Deterministic output.** Each job writes `<id>.log` + `<id>.status` in a temp
   job dir; the parent replays the curated `✓ id (ref)` lines in declaration
   order after the barrier. Output is byte-identical to the sequential run, with
   no interleaving. Deliberate trade-off: the phase prints nothing while it
   runs (it is ~8-10s).
2. **`--verbose` stays foreground and streaming.** Interleaved noise from 6
   concurrent clones is useless for debugging. `SKILL_JOBS=1` also uses the
   ordered replay path.
3. **`GIT_TERMINAL_PROMPT=0` + `</dev/null` on every job.** A background job
   inherits stdin, so a credential prompt (seen earlier: `fatal: could not read
   Username for 'https://github.com'` on an unreachable repo) would either hang
   or steal terminal input. Fail fast instead.
4. **`DOTFILES_JOBS`, default 6.** 12 distinct repos; 6 is the measured sweet
   spot. Unbounded concurrency was not tested against GitHub's secondary rate
   limits.
5. **`wait -n` needs bash >= 4.3.** Older bash (macOS 3.2) is detected and
   forced to `SKILL_JOBS=1`, which degenerates to one-at-a-time through the same
   ordered path.
6. **Failure semantics change.** A pool cannot abort at the first error. All jobs
   finish, every failing skill is reported with its own log, and the script then
   exits 1 without running later sections.

## Tasks

- [x] T1 — Split `install_agents_skill` into a silent `install_agents_skill_worker
      (repo, subpath, ref, target)`.
- [x] T2 — Resolve all entries into parallel arrays, then run either the verbose
      foreground loop or the throttled pool with ordered replay.
- [x] T3 — Keep `unset` the post-install cleanups and `bake-web-design-rules.sh`
      behind the barrier (they already are: separate sections after the loop).
- [x] T4 — Document `DOTFILES_JOBS` in `--help`, the header, and `AGENTS.md`.

## Checks

Real runs, two clean sandboxes, full script:

| Run | Wall clock | Exit |
| --- | --- | --- |
| `DOTFILES_JOBS=1` | 92s | 0 |
| `DOTFILES_JOBS=6` | **26s** | 0 |

- [x] **Equivalence (the acceptance test)**: jobs=1 vs jobs=6 -> curated output
      identical (39 lines, same order, `diff` clean), file set identical (1090
      files), `sha256sum` of every file identical. Install stamps
      (`.bootstrap-origin`, `.baked-rules-stamp`) excluded: they embed a timestamp
      by design.
- [x] Quiet run: zero third-party output; shape and order unchanged from the
      sequential run.
- [x] `--verbose`: foreground streaming preserved (83 lines; `pi install` chatter
      still live). Deliberate change: skill clones no longer print the
      `Cloning into` banner even in verbose, since `--quiet` is now unconditional
      in the worker. Diagnostics survive it — a failing clone still prints
      `fatal: ...`.
- [x] Forced failure (5 bogus entries, pool=3): 19 skills installed, **all 5**
      failures reported with the `fatal:` line and a per-skill persistent log,
      no later section ran, exit 1. Logs show
      `terminal prompts disabled`, proving `GIT_TERMINAL_PROMPT=0`.
- [x] `DOTFILES_JOBS=0` -> warns and falls back to 6 (validation regex).
- [x] `bash -n` clean; `--help` documents `DOTFILES_JOBS`.
- [ ] Real `$HOME` run (user-owned).

## Behaviour change to remember

Failure semantics: the pool cannot abort at the first error. Every job finishes,
all failures are reported, and only then does the script exit 1. Previously the
first failure aborted immediately, leaving later skills untouched.
