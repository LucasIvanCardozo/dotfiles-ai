# Akonadi Setup & Troubleshooting on CachyOS / Arch

Akonadi is the local storage and sync backend that KOrganizer, KAlarm GUI, and `konsolekalendar` rely on. `kalarm --korganizer` writes through Akonadi, so if Akonadi is not running, the event will only live in KAlarm's own calendar and KOrganizer will not show it.

## Install

```bash
sudo pacman -S kdepim-runtime
# optional but common
sudo pacman -S mariadb   # Akonadi default backend on Arch
```

`kdepim-runtime` ships the Akonadi server and the resource agents (ICAL, etc.). `mariadb` is what Akonadi uses by default; SQLite is also available but MariaDB is the common path on Arch.

## Start / enable

```bash
# Start now
akonadictl start

# Autostart on login (Plasma usually handles this already; manual if needed)
akonadictl enable-autostart

# Verify
akonadictl status
```

Healthy `akonadictl status` output ends with `Akonadi Control: running`. If any agent reports `stopped` or `error`, see fixes below.

> **Plasma 6 note**: `systemctl --user enable --now akonadi` will fail with "Unit akonadi.service does not exist". The correct unit is `akonadi_control.service` (marked `static`), and Akonadi is DBus-activated — `akonadictl start` is the only command you need.

## Reset / re-init (last resort)

```bash
akonadictl stop
mv ~/.local/share/akonadi ~/.local/share/akonadi.bak.$(date +%s)
akonadictl start
```

This wipes local data. Cloud-synced resources (Google, Nextcloud) will re-sync from the server.

## Common errors on CachyOS / Arch

### "DBus interface failed"

`kded6` or `akonadi_control` is not running.

```bash
akonadictl restart
```

### MariaDB / MySQL backend fails to start

Symptom: `akonadictl status` shows the `server` agent in error state.

```bash
# Check actual journal
journalctl --user -u akonadi --no-pager -n 80

# Most common fix: re-initialize Akonadi DB
akonadictl stop
rm -rf ~/.local/share/akonadi/db
akonadictl start
```

### Event added via `kalarm --korganizer` but does not appear

1. Confirm `akonadictl status` → running.
2. Open KOrganizer once and wait ~5 seconds for the resource to sync.
3. Check the resource is enabled: KOrganizer → Settings → Manage calendars → your calendar enabled.
4. As a test, add an event directly in KOrganizer GUI. If it persists, Akonadi is fine and the issue was transient.

### Conflicts with mariadb.service (system-wide)

Akonadi uses a **user-local** MariaDB instance, but if a system MariaDB is running it can sometimes race on socket paths. Disable the system service for Akonadi hosts only:

```bash
systemctl --user mask mariadb.service    # if Akonadi is your only DB consumer
```

For most desktop users, leaving the system MariaDB alone is fine — Akonadi uses `$XDG_RUNTIME_DIR/akonadi/` for its sockets.

## Verify everything end-to-end

```bash
# 1. Akonadi up
akonadictl status

# 2. KAlarm CLI sees Akonadi
kalarm --list | head

# 3. Add a probe event via kalarm CLI
kalarm -t "$(date -d '+1 minute' '+%Y-%m-%d %H:%M')" --reminder 30S "Akonadi probe"

# 4. Confirm visible in KOrganizer
korganizer &   # should show the probe event
```

If steps 1–4 pass, the stack is healthy and `kalarm-cli` skill commands will work as expected.

## Optional: expose `khal` vdir to KOrganizer via Akonadi icaldir_resource

If you keep events in `~/.calendars/personal/` (khal's vdir) and want them visible in KOrganizer GUI, register the Akonadi icaldir resource:

```bash
# Create the agent instance (DBus call)
qdbus6 org.freedesktop.Akonadi /ResourceManager \
  org.freedesktop.Akonadi.ResourceManager.addResourceInstance \
  akonadi_icaldir_resource \
  '["Calendar", "ICal"]'

# Configure the path via the resource's DBus interface
# (path depends on the instance ID returned above; check with
#  qdbus6 org.freedesktop.Akonadi /ResourceManager resourceInstances)
```

After setup, events added with `khal new` appear in KOrganizer. This is advanced — verify first whether KOrganizer visibility is actually needed before going through this.
