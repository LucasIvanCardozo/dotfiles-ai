# Feature: retire the violet-rose theme

## Goal

`themes/violet-rose.json` is the only file in `themes/`, the runtime Pi theme is
`dark`, and the user no longer uses it. Remove the shipped theme from the bundle
and replace `bootstrap.sh`'s hardcoded violet-rose block with a generic
`themes/*.json` loop, so that dropping a JSON there still works and an empty
`themes/` is silent instead of a permanent warning.

## Non-goals

- No change to the copy semantics of the other four config files (the three
  clobber copies and the `models.json` no-clobber branch).
- No change to the `pi install` or skills sections of `bootstrap.sh`.
- No removal of the theme capability: `AGENTS.md` "Adding a new Pi extension or
  theme" must stay true after this change.
- No edit to Pi's `settings.json` — the active theme is already `dark`, so
  there is nothing to unset.
- No deletion of the git history: `themes/violet-rose.json` stays recoverable
  from the previous commits.

## Design decisions

1. **Generic loop, not a deleted block.** Deleting the file alone leaves the
   hardcoded `warn "themes/violet-rose.json missing from bundle"` firing on
   every run. `AGENTS.md` makes quiet output a contract, so a permanent false
   warning is a defect, not a cosmetic issue. A loop over `themes/*.json` keeps
   the documented "drop a JSON and re-run" mechanism accurate and prints
   nothing when the bundle ships no theme.
2. **Empty `themes/` is a valid state, not a warning.** Git does not track
   empty directories, so the directory itself disappears with the file. The
   `[[ -d ]]` guard skips the section entirely, and
   `[[ -f "$theme_file" ]] || continue` absorbs an unexpanded glob.

## Tasks

- [x] T1 — Replace the hardcoded violet-rose block in `bootstrap.sh` with the
      generic `themes/*.json` loop.
- [x] T2 — Delete `themes/violet-rose.json` from the bundle.
- [x] T3 — Update `AGENTS.md`: bootstrap description, the theme bullet, the
      post-run `/reload` note.
- [x] T4 — Delete the installed copy at
      `~/.pi/agent/themes/violet-rose.json`.
- [x] T5 — Verify: no `violet` reference left outside `odd/`, `bash -n` parses,
      and the loop still copies a theme when one is present.
- [x] T6 — Work-unit commit.

## Checks

- [x] `grep -ri violet` over the repo (excluding `.git/` and `odd/`) finds no
      match. The surviving `themes/*.json` mentions are the generic mechanism's
      own documentation, which is the intended end state, not residue.
- [x] `bash -n bootstrap.sh` parses.
- [x] Isolated-`HOME` run of the extracted block with **no** `themes/`
      directory: stdout and stderr both empty, no warning. The previous block
      would have emitted `! themes/violet-rose.json missing from bundle` on
      every single run.
- [x] Isolated-`HOME` run of the extracted block with `themes/probe.json`:
      one `✓ probe.json → ~/.pi/agent/themes/` line and the file copied to
      `~/.pi/agent/themes/probe.json`.
- [x] Both isolated runs executed the block *extracted from* `bootstrap.sh` by
      line range, not a rewritten copy of it.

## Evidence

- Baseline `bootstrap.sh` sha256: `64e25c2e3106f78802c1c595a85b5545acfb000205ccd8139686d38cca1625a3`
- Baseline `AGENTS.md` sha256: `9220f6aa0d82646321c5d13ba831bd0ab63a1823029b2def9a748017da36827c`
- Baseline `themes/violet-rose.json` sha256: `b4620792e24e3ca2b93609c5bad300d7e4928286501189c5f61930c488455a3a`
- Runtime copy baseline: the same sha256 as the bundle copy, so the installed
  file was the shipped file byte-for-byte — deleting it removes nothing that was
  not already committed.
- Removed from the worktree with `git rm` (staged). The blob stays reachable at
  `git show 77a5edd:themes/violet-rose.json`, so the deletion needs no backup.
- The `themes/` directory disappeared with its only file (git does not track
  empty directories), which is exactly the empty state the new loop treats as a
  silent no-op.

## Delivery

- Commit `5c4a808` `feat(bootstrap): clobber config with env-sourced keys,
  retire theme`, merged into `main` fast-forward from
  `chore/bundle-config-contract` and pushed: `origin/main` = `5c4a808`.
