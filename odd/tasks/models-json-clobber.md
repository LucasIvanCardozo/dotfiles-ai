# Feature: `models.json` clobber install with keys from the environment

## Goal

Two problems, one contract:

1. `~/.pi/agent/models.json` was the only copied config file with **no-clobber**
   semantics. A provider or model added to the bundle could not reach a machine
   that already had the file — the normal case — so updating required backing the
   file up, deleting it, re-running bootstrap, and merging the keys back. That
   procedure briefly leaves the machine with **no credentials file at all**.
2. The API key had no source outside the runtime file, so it had to be pasted in
   by hand and preserved by every code path that touched the file.

Now the bundle owns the provider list and the models, the environment owns the
keys, and the runtime file is a derived artifact that is rebuilt on every run.

## Non-goals

- No key material in the bundle: `apiKey` stays `""` (see `AGENTS.md` "API keys
  pattern").
- No union behavior for providers: a provider present only in the runtime is
  dropped. The bundle owns the provider list. Reported, never silent.
- No change to the other three clobber copies, to the theme loop, or to the
  `pi install` / skills sections.
- No support for per-provider key files or a keyring lookup: one environment
  variable per provider, nothing else.

## Design decisions

1. **The environment is the only key source.** For provider `nan` bootstrap
   reads `NAN_API_KEY`: provider name uppercased, every non-alphanumeric turned
   into `_`, plus `_API_KEY` (`my-provider.v2` → `MY_PROVIDER_V2_API_KEY`). An
   unset or empty variable means `apiKey: ""`. This is the user's chosen
   semantics: declarative, not "preserve what you find".
2. **`jq` reads `$ENV` itself.** The key never becomes an argv entry, so it
   cannot surface in `ps`, in a log line, or in the shell history of whoever ran
   bootstrap. The alternative — resolving the variable in bash and passing it to
   jq — would put the secret in the process argument list. It also avoids
   `${var^^}`, which does not exist in the bash 3.2 that ships with macOS and
   that this script already accommodates for `wait -n`.
3. **Clobber on every run.** The bundle is the document base, so a change in the
   bundle always lands. Providers that exist only in the runtime are dropped and
   reported as a `!` warning — silently deleting a provider someone added locally
   is how you lose an afternoon.
4. **Removing a key is reported.** Under declarative semantics, unsetting the
   variable deletes a credential. That is decisive and correct, but it must never
   be discovered later as a broken role: the run prints
   `! … API key(s) REMOVED because no <PROVIDER>_API_KEY is set: nan`. Only
   providers that survive the run are counted; one being dropped entirely is
   already covered by the provider warning.
5. **A malformed runtime file is replaced, not preserved.** *(Supersedes the
   first version of this branch, which left an unreadable file untouched.)* That
   guard made sense while the runtime file was the only home of the key, since
   clobbering it could silently drop every credential. Under the environment
   contract the file holds no irreplaceable state, so refusing to touch a broken
   file would freeze the machine in the broken state instead of healing it. A
   runtime file whose `.providers` is an array — the shape a bad `jq` transform
   produces — is now repaired by the next run.
6. **Atomic replacement with a tight mode.** The new document is built in a
   `mktemp` file **in the target directory** under `umask 077`, then `mv`'d over
   the target. Same filesystem, so the `mv` is atomic: the credentials file is
   never half-written and never briefly wider than `600`. Mode `600` is now
   re-applied on every run, where the old code applied it only on creation.
7. **`kept()` and the `⤵` line were removed.** With no preserved-file branch
   left, the helper was dead code and the symbol described nothing.
   `bootstrap.sh`'s `--help` and `AGENTS.md`'s quiet-output contract were updated
   so neither documents a line the script can no longer print.

## Tasks

- [x] T1 — Rewrite the `models.json` branch in `bootstrap.sh`: clobber from the
      bundle, keys from `$ENV` by provider name, warnings for dropped providers
      and removed keys.
- [x] T2 — Remove the dead `kept()` helper and its `⤵` documentation in
      `bootstrap.sh` (`--help`) and `AGENTS.md`.
- [x] T3 — Update `AGENTS.md`: the `agent/models.json` bullet, the "API keys
      pattern" contract, and a warning that an `export` in a versioned shell rc
      pushes the key.
- [x] T4 — Verify all behaviors against the block **extracted from**
      `bootstrap.sh`, under `set -euo pipefail`.
- [x] T5 — Work-unit commit.

## Checks

Every case runs the 50-line block extracted from `bootstrap.sh` by line range
(not a rewritten copy) in a throwaway `HOME`, with `set -euo pipefail` to match
the real environment, and synthetic keys.

| case | result |
| --- | --- |
| 1. `NAN_API_KEY` set, no runtime file | `apiKey` injected, mode `600` |
| 2. no variable, no runtime file | `apiKey: ""`, mode `600` |
| 3. no variable, runtime **had** a key | key removed; `!` names **only** `nan`, not the provider also being dropped |
| 4. variable set, runtime had a key | new value wins (`TESTKEY-NEW`), no key warning |
| 5. provider `my-provider.v2` | reads `MY_PROVIDER_V2_API_KEY` — the naming rule holds |
| 6. `NAN_API_KEY=""` | treated as unset: removed, reported |
| 7. runtime `.providers` is an array | **self-heals** into the correct object shape, key injected, no bogus "dropped" line |
| 8. two consecutive runs | idempotent |

- [x] `bash -n bootstrap.sh` parses.
- [x] Every case exits `0`: the trailing `[[ -n "$models_dropped" ]] && warn …`
      does not trip `set -e` when nothing was dropped (the failing test precedes
      the final `&&`, so it is exempt).
- [x] No dead references to `kept` or `⤵` remain outside `odd/`.
- [x] The variable name is derived inside `jq`, so no key ever appears in an
      argument list.

## Evidence

- Test matrix above: 8/8 cases against the extracted block.
- `AGENTS.md` documents the naming convention, the precedence (environment only),
  and the versioned-shell-rc hazard.

## Delivery

- Commit `5c4a808` `feat(bootstrap): clobber config with env-sourced keys,
  retire theme`, merged into `main` fast-forward from
  `chore/bundle-config-contract` and pushed: `origin/main` = `5c4a808`.
- **Migration note, still open on this machine:** the runtime file still holds
  its 25-character key and the shell does not export `NAN_API_KEY` yet, so the
  next `./bootstrap.sh` **removes that key** and reports it. Set the variable
  before that run.
