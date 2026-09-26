# Feature: sync runtime configs into the bundle

## Goal

The bundle is the source of truth for the installed environment, but two
runtime files drifted ahead of it and the user considers the runtime copies the
improved ones:

- `~/.pi/gentle-ai/profiles.json` — 3 profiles (`Full-Code`, `Chill-Code`,
  `Boludear`), `active: Full-Code`. The bundle still ships 5 profiles including
  `current` / `Full-Minimax-M3` / `Basic`, which reference `minimax/MiniMax-M3`,
  a provider that no longer exists in any `models.json`.
- `~/.pi/agent/models.json` — adds `thinkingLevelMap` to `glm5.3-flash`,
  `gemma4`, `qwen3.6` (bumping their `maxTokens` to 131072) and drops the
  `glm5.3` (premium) entry.

Bring the bundle back in line with what actually runs, without ever committing
the runtime API key.

## Non-goals

- No key material in the bundle: `apiKey` stays `""` (see AGENTS.md "API keys
  pattern").
- No change to `bootstrap.sh` semantics: `profiles.json` keeps clobber, the
  runtime `models.json` keeps no-clobber.
- No touching of unrelated runtime state without a bundle source
  (`~/.pi/gentle-ai/background-subagents.json`, the legacy flat
  `~/.pi/gentle-ai/models.json`, `~/.pi/agent/models-store.json`).
- No new provider, no new model id invented.

## Design decisions

1. **Verbatim mirror.** The bundle copies the runtime content byte-for-byte,
   except `apiKey` values, which become `""`. Reasoning: bootstrap re-clobbers
   `profiles.json`, so bundle == runtime is the only self-consistent state after
   a fresh bootstrap; and the runtime `models.json` is the template a new
   machine would get.
2. **Dropping `glm5.3` (premium) is accepted as intentional.** The runtime is
   the improved file the user named; nothing live references the model
   (`grep` over `~/.pi` finds it only in gentle-pi's own test fixtures).
   Flagged in the report as a one-command revert if it was accidental.
3. **`apiKey` redaction by `jq`, not by hand.** Rebuilding the JSON
   programmatically means the key cannot leak through a partial edit, and the
   runtime file is never written to.

## Tasks

- [x] T1 — Mirror the runtime `profiles.json` into `gentle-ai/profiles.json`
      (verbatim, JSON validated).
- [x] T2 — Mirror the runtime `agent/models.json` into `agent/models.json` with
      every `apiKey` blanked; runtime file untouched.
- [x] T3 — Fix `AGENTS.md` drift: the `nan` provider model count and the
      profiles description.
- [x] T4 — Verify: JSON validity, bundle has zero secrets, runtime file
      byte-identical before/after, and bootstrap copy semantics in an isolated
      HOME.
- [x] T5 — Work-unit commit on a feature branch.

## Checks

- [x] `jq empty` on both bundle files — both parse.
- [x] Bundle `models.json`: every `apiKey` is `""`; no `sk-`-shaped string.
- [x] Runtime `~/.pi/agent/models.json` (+ `profiles.json`) unchanged (`sha256sum -c` matches; they are the sync source).
- [ ] Isolated-HOME bootstrap semantics: profiles clobbered, models.json
      preserved when present.
- [x] No live config references a model removed by this sync (`nan/glm5.3` appears only in gentle-pi's own test fixtures).
- [x] Invariant: 6 models defined, 6 referenced by profiles, 0 dangling `provider/model` ids, 0 unused models.

## Evidence

- Commit: `2bf7c90` on branch `chore/sync-runtime-configs` (main untouched).
- Diffstat: `AGENTS.md` 4, `agent/models.json` 36, `gentle-ai/profiles.json` 180.

## Delivery

- Merged into `main` fast-forward (`b8d64f5..2bf7c90`) and pushed:
  `origin/main` = `2bf7c90` (published together with the 3 pre-existing
  unpushed commits, user-approved).
- Local branch `chore/sync-runtime-configs` deleted after the merge
  (`git branch -d`, which refuses unmerged branches — it succeeded).

## Increment 2 — `mimo-v2.6-flash` rollout

The runtime copies moved again after `2bf7c90`: the `nan` provider gained
`mimo-v2.6-flash`, and 7 agent/review roles were remapped onto it. Same feature,
second increment; the bundle is again behind the machine that runs it.

### Delta found (runtime vs bundle, `jq -S` diff)

- `agent/models.json`: +1 model `mimo-v2.6-flash` (1 MiB context, 32 k output,
  text+image). No model removed, no provider or `compat` change.
- `gentle-ai/profiles.json`: 7 role entries, all onto `nan/mimo-v2.6-flash`:
  1. `Full-Code.review-resilience` — from `nan/mimo-v2.5` (thinking unchanged).
  2. `Chill-Code.gentle-ai-explore` — from `nan/gemma4` (thinking unchanged).
  3. `Chill-Code.review-reliability` — from `nan/gemma4`/`max` → `high`.
  4. `Boludear.review-refuter` — from `nan/qwen3.6` (thinking unchanged).
  5. `Boludear.review-validator` — from `nan/gemma4`/`max` → `high`.
  6. `Boludear.jd-judge-b` — from `nan/gemma4` (thinking unchanged).
  7. `Boludear.review-risk` — from `nan/gemma4`/`max` → `high`.
- Non-changes confirmed: same 3 profiles, `active: Full-Code`, no added/removed
  profile, no other key touched.

### Design decisions (increment 2)

4. **Minimum diff, not a byte-for-byte re-mirror.** Increment 1's decision 1 said
   "verbatim mirror", but the bundle rows were normalized (inline
   `["text", "image"]`, alphabetical keys) and never matched the runtime bytes.
   Restating that as byte-for-byte would mean rewriting both files for no
   semantic gain, so this increment keeps the bundle's existing formatting and
   inserts only the semantic delta: a reviewer reads a 7-line-plus-1-entry diff
   instead of a whole-file rewrite. Bundle and runtime are asserted *semantically*
   equal (`jq -S` diff empty) as the acceptance bar.
5. **`profiles.json` regenerated with `jq`, preserving key order.** A `reduce`
   over the runtime profile map assigns `model`/`thinking` into the existing
   bundle object, so jq reuses the current key order and emits the delta only.
   Round-trip was proven byte-identical on the bundle before the merge was
   trusted with it.
6. **`models.json` edited by hand, not by `jq`.** jq would expand the inline
   `input` arrays and turn a 10-line insertion into a 40-line reformat, so the
   new entry is inserted textually in the neighbours' style.

### Tasks (increment 2)

- [x] T6 — Add `mimo-v2.6-flash` to `agent/models.json`; every `apiKey` stays `""`.
- [x] T7 — Mirror the 7 role remaps into `gentle-ai/profiles.json`.
- [x] T8 — Fix `AGENTS.md` drift: `nan` model count 6 → 7.
- [x] T9 — Verify: JSON validity, zero secrets in the bundle, referential
      integrity, runtime files byte-identical, bundle ≡ runtime semantically.
- [x] T10 — Work-unit commit on branch `chore/sync-mimo-v2.6-remap`.

### Checks (increment 2)

- [x] `jq empty` on both bundle files.
- [x] Bundle `models.json`: 1 `apiKey`, value `""`; no `sk-`-shaped string anywhere in the diff or the bundle.
- [x] Runtime `~/.pi/agent/models.json` + `~/.pi/gentle-ai/profiles.json` unchanged (`sha256sum -c` passes).
- [x] `jq -S` semantic diff bundle↔runtime empty for both files, after redacting `apiKey`.
- [x] Invariant: 7 models defined, every `provider/model` id referenced by the
      3 profiles resolves, 0 dangling ids.
- [x] Diff scope is exactly the 7 remapped roles + 1 model entry + 1 AGENTS.md count.

### Evidence (increment 2)

- Commit: `bd7dd76` on branch `chore/sync-mimo-v2.6-remap`, branched off
  `main` @ `2bf7c90` (`main` untouched, nothing pushed).
- Diffstat: `AGENTS.md` 2, `agent/models.json` 8, `gentle-ai/profiles.json` 20.
- Runtime baseline hashes captured before the first write:
  `e65a0576…` (`models.json`), `99232f68…` (`profiles.json`).
- `nan/mimo-v2.5` is now defined but unreferenced (7 defined / 6 used / 0
  dangling) — kept because the runtime still defines it and the bundle mirrors
  the runtime.

### Delivery (increment 2)

- Pending: push/merge are the user's decision. `main` is still `2bf7c90`.
