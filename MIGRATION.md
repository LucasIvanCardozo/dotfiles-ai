# Migration: Pi → Gentle Shell (clean install)

The target state: **Pi is gone**, Gentle Shell is the only agent runtime, and
this repo's bundle is installed on top of it. Everything from the old Pi
installation is discarded — chat history included — because the memory that
matters already lives in Engram.

The order matters:

```
1. remove Pi and its state
2. install Gentle Shell (the way its repository recommends)
3. provision the home
4. run this repo's bootstrap
5. sign in and re-register the MCP servers
6. remove the project-level .pi/ directories
7. verify
```

Do not reorder 1 and 2: the bundled installer is self-contained and does not
need Pi, and a clean install has nothing left to import.

---

## Read this before step 1: Engram

The memory store does **not** live under `~/.pi`:

| Path | What it is | Kept? |
|---|---|---|
| `~/.engram/engram.db` | the memory store (25 MB + WAL) | **keep** |
| `~/.local/bin/engram` | your Engram 3.6.0 binary | **keep** |
| `~/.agents/skills/` | the agent skills | **keep** |
| `~/.gentle-ai/`, `~/.local/bin/gentle-ai` | the Gentle AI CLI and its state | **keep** |

Step 1 never touches those. But there is one version detail to know:

- your Engram is **3.6.0**; the Engram core bundled with Gentle Shell is
  older (**3.5.2** in the current layout);
- when the store was migrated by a newer Engram than Shell's bundled core,
  Shell refuses to start a server on it and reports *"Engram memory disabled:
  `~/.engram` was migrated by a newer Engram than Shell's bundled core"*;
- the fix is to run your own server and let Shell reuse it:

  ```sh
  engram serve &
  ```

  Shell verifies the running server's `/compatibility` endpoint before using
  it (Engram ≥ 3.4.0 answers it, so 3.6.0 is fine). The bundled alternative is
  `gentle-shell memory migrate --confirm-quiescent`, which requires that no
  Engram client is running.

**Do not delete `~/.local/bin/engram`.** `purge-pi-opencode-gentle.sh` deletes
it — that is a bug in that script, not part of this migration.

---

## Step 1 — Remove Pi and its state

```sh
# 1. the global Pi package
pnpm remove -g @earendil-works/pi-coding-agent

# 2. (optional) keep the Google account credentials so you do not sign in
#    again in step 5. Skip this line to sign in from scratch.
mkdir -p ~/.gentle-shell-migration
[ -f ~/.pi/agent/antigravity-accounts.json ] && \
  install -m 600 ~/.pi/agent/antigravity-accounts.json \
    ~/.gentle-shell-migration/antigravity-accounts.json

# 3. Pi's home: settings, installed packages, extensions, sessions, the old
#    config home. This is the whole install.
rm -rf ~/.pi

# 4. anything else Pi left behind
rm -rf ~/.local/share/pi            # only if it exists
rm -rf ~/.config/pi-hashline-edit-pro

# 5. drop the stale command from the shell's hash
hash -r
```

*Expected:* `command -v pi` prints nothing, and `ls ~/.pi` fails.

> Sessions (the chat history) go with `~/.pi`. The memory does not — that is
> Engram's store in `~/.engram`.

## Step 2 — Install Gentle Shell

Its repository recommends the release installer: it downloads a verified
bundle, checks the checksum and opens a browser wizard that installs the
self-contained product (its own Node, npm, pnpm and Pi under
`~/.gentle-shell/`, without touching your own toolchain).

```sh
cd /tmp

# 1. the release bundle and its checksum file
curl -fLO https://github.com/Gentleman-Programming/gentle-shell/releases/latest/download/gentle-shell-installer-linux.tar.gz
curl -fLO https://github.com/Gentleman-Programming/gentle-shell/releases/latest/download/gentle-shell-installers-SHA256SUMS.txt

# 2. verify before running
sha256sum -c --ignore-missing gentle-shell-installers-SHA256SUMS.txt

# 3. unpack and install (opens the wizard in your browser)
tar -xzf gentle-shell-installer-linux.tar.gz
sh gentle-shell-installer/install-gentle-shell.sh
```

*Expected:* `gentle-shell-installer-linux.tar.gz: OK`, then the wizard at
`http://127.0.0.1:<port>`. Finish it there; it installs the bundled product
and puts `~/.gentle-shell/bin/gentle-shell` on your PATH.

## Step 3 — Provision the home

```sh
# the launcher is on PATH now; open a new shell if this one is stale
export PATH="$HOME/.gentle-shell/bin:$PATH"

# what is running and which home it uses
gentle-shell --version

# provision the home: runs `gentle-ai install --agent pi --scope global`
# against the isolated home, which installs gentle-pi, gentle-engram,
# pi-web-access and pi-btw
gentle-shell setup
```

*Expected:* `home isolated ~/.gentle-shell/agent`, and the Gentle AI install
result at the end.

> `setup` is mandatory before installing packages: the launcher skips its
> automatic provisioning for Pi subcommands (it has to leave `argv[0]` alone so
> Pi can dispatch `install`).

## Step 4 — Install this project's bundle

```sh
cd ~/Documentos/Workspace/dotfiles-ai
./bootstrap.sh
```

What it installs, all inside the new home:

| What | Where |
|---|---|
| `pi-antigravity` (your provider), `diagram-design`, `pi-codegraph-enhanced` | `~/.gentle-shell/agent/npm/` |
| the 21 upstream agent skills + the 5 local ones | `~/.agents/skills/` |
| the `agent-browser` CLI | your global npm |
| `gentle-ai/profiles.json` (Full-Code / Chill-Code / Boludear) | the Gentle Shell config home |
| the baked web-design rules, the Next.js docs snapshot | `~/.agents/skills/` |

*Expected:* one `✓` per item, then `✓ Done. Open gentle-shell to use it.`

## Step 5 — Sign in and re-register the MCP servers

A clean install has no credentials and no MCP configuration: both lived in
`~/.pi/agent/`.

### Sign in

Either sign in from scratch:

```sh
gentle-shell
# inside the session: /login  → pick the Antigravity provider and sign in
```

or reuse the account saved in step 1:

```sh
install -m 600 ~/.gentle-shell-migration/antigravity-accounts.json \
  ~/.gentle-shell/agent/antigravity-accounts.json
```

### MCP servers

Pi reads `<agent home>/mcp.json`; there is no `pi mcp add` command, so write
the file:

```sh
cat > ~/.gentle-shell/agent/mcp.json <<'JSON'
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "--package=@upstash/context7-mcp@2.2.5", "--", "context7-mcp"]
    },
    "pencil": {
      "command": "/home/lucas/.local/opt/pen/mcp/mcp-server-linux-x64",
      "args": ["--app", "desktop"],
      "description": "Pen (pen.dev) design canvas: inspect and edit .pen documents in the running Pen desktop app."
    }
  }
}
JSON
```

*Expected:* the next session lists both servers; `gentle-shell` → the MCP
panel shows them connected.

## Step 6 — Remove the project-level `.pi/` directories

A project `.pi/` is Pi's **project** configuration (per-project agent/model
overrides, MCP servers, skills, extensions, persona). Pi reads it from the
working directory, so it still works under Gentle Shell — removing it is a
deliberate cleanup, not a repair.

```sh
# see them first
find ~/Documentos -maxdepth 6 -type d -name ".pi" -not -path "*/node_modules/*"
```

Delete the ones git does not track:

```sh
find ~/Documentos -maxdepth 6 -type d -name ".pi" -not -path "*/node_modules/*" -print0 |
while IFS= read -r -d $'\0' d; do
  repo="${d%/.pi}"
  if git -C "$repo" ls-files --error-unmatch .pi >/dev/null 2>&1; then
    printf 'tracked — remove it in that repository: %s\n' "$d"
  else
    rm -rf "$d"
    printf 'removed: %s\n' "$d"
  fi
done
```

The tracked ones need a commit in their own repository — one command each:

```sh
cd ~/Documentos/Workspace/NextJs/JulsGYM           && git rm -r .pi && git commit -m "chore: drop pi project config"
cd ~/Documentos/Workspace/Astro/rol-data           && git rm -r .pi && git commit -m "chore: drop pi project config"
cd ~/Documentos/Workspace/dotfile                  && git rm -r .pi && git commit -m "chore: drop pi project config"
cd ~/Documentos/Workspace/Facultad/TP-especial-SO  && git rm -r .pi && git commit -m "chore: drop pi project config"
cd "$HOME/Documentos/Facultad/Fundamento de Lenguajes Formales" && git rm -r .pi && git commit -m "chore: drop pi project config"
```

> Read each one before removing it: `dotfile` and `TP-especial-SO` hold your
> MiniMax M2.7 per-agent overrides, `JulsGYM` a project MCP server and
> `rol-data` a project extension. If you want to keep one, do not run its
> command.

## Step 7 — Verify

```sh
# the runtime and its home
gentle-shell --version

# the home has the packages and the config home has the profiles
ls ~/.gentle-shell/agent/settings.json
ls ~/.gentle-shell/config/gentle-ai/profiles.json 2>/dev/null || ls ~/.gentle-shell/gentle-ai/profiles.json

# Pi is really gone
command -v pi || echo "pi: gone"
ls ~/.pi 2>/dev/null || echo "~/.pi: gone"

# the memory store survived
ls -la ~/.engram/engram.db

# the review switch is still clone-local off
gentle-ai review mode status
```

Then start a session and check it end to end:

```sh
cd ~/Documentos/Workspace/dotfiles-ai
gentle-shell
```

Inside the session: the skills load (`/skill-registry:refresh` lists them), the
memory tools answer, the web tools answer, and the agent model routing matches
the profile you had.

---

## Rollback

Steps 1 and 6 are the only destructive ones, and they are the point of a clean
install. If the new install misbehaves, Pi is one command away again:

```sh
pnpm add -g @earendil-works/pi-coding-agent
```

The Engram store, the skills and the Gentle AI state were never touched.

## Troubleshooting

- **`gentle-shell: No pi runtime could be found`** — a bundled install ships
  its own Pi; if you installed the standalone one, Pi must be on PATH.
- **`gentle-shell install` does nothing** — the home was never provisioned:
  run `gentle-shell setup`.
- **The agent uses the wrong model** — `gentle-ai/profiles.json` did not land
  in the config home; re-run step 4.
- **Memory tools missing** — check the Engram note at the top of this file;
  the store is fine, the server is the issue.
- **`purge-pi-opencode-gentle.sh` deletes `~/.agents` and
  `~/.local/bin/engram`** — it would remove every agent skill and the ability
  to serve a newer-schema Engram store. Remove those paths from the script
  before running it.
