# Troubleshooting Calendar CLI on Plasma 6 (CachyOS/Arch)

Known issues and exact fixes discovered while refactoring this skill.

## 1. pyenv shadows system Python — `kalarm`/`vdirsyncer` break

**Symptom**:
```
$ khal --version
Traceback (most recent call last):
  File "/usr/bin/khal", line 2, in <module>
    from khal.cli import main_khal
ModuleNotFoundError: No module named 'khal'
```

**Cause**: `~/.pyenv/shims` is early in `PATH`. Pyenv's `python` resolves to a venv (e.g. demucs) running Python 3.11. But Arch packages install `khal` and `vdirsyncer` modules into Python 3.14 (`/usr/lib/python3.14/site-packages/`).

**Fix (no sudo)**:

```bash
mkdir -p ~/.local/bin
echo '#!/bin/bash
exec python3.14 /usr/bin/khal "$@"' > ~/.local/bin/khal
chmod +x ~/.local/bin/khal
hash -r
khal --version   # should print "khal, version 0.14.1"
```

**Fix (sudo, more durable)**:

```bash
echo '#!/bin/bash
exec python3.14 /usr/bin/khal "$@"' | sudo tee /usr/local/bin/khal > /dev/null
sudo chmod +x /usr/local/bin/khal
hash -r
khal --version
```

`/usr/local/bin` is at PATH position 11 (before `/usr/bin` at 12), so the wrapper wins without touching shell config.

## 2. `pacman -S` returns 404 on specific packages

**Symptom**: 3 packages fail to download with `404 Not Found` even though `pacman -Si` shows a version. Same 404 on every mirror.

**Cause**: mirror desync — DB knows a version that isn't on any pool yet. The files exist in `/var/cache/pacman/pkg/` from a previous sync, but the `.sig` files are newer than the `.pkg.tar.zst`, so pacman thinks the cache is stale.

**Diagnosis**:

```bash
ls -la /var/cache/pacman/pkg/ | grep <pkg>
# Note: .sig files newer than .pkg.tar.zst = desync confirmed
```

**Fix**: install directly from cache, bypassing the broken download path.

```bash
sudo pacman -U \
  /var/cache/pacman/pkg/<pkg-with-version>.pkg.tar.zst \
  /var/cache/pacman/pkg/<other>.pkg.tar.zst
```

For multiple failed packages, list them all in one `pacman -U` invocation.

## 3. `systemctl --user enable --now akonadi` → "Unit does not exist"

**Cause**: The user unit is named `akonadi_control.service`, not `akonadi.service`. Also, it's marked `static`, so `enable` is rejected.

**Fix**:

```bash
akonadictl start
# verify
akonadictl status
```

`akonadi_control` is DBus-activated — it auto-starts when a KDE client (KAlarm, KOrganizer, KMail) needs it.

## 4. `khal` config: "type 'filesystem' is unacceptable"

**Symptom**:
```
critical: in [calendars] type: the value "filesystem" is unacceptable.
```

**Cause**: khal 0.14+ removed the `filesystem` type. Use `calendar` (default — covers vdir format).

**Fix**:

```ini
[calendars]
[[personal]]
path = ~/.calendars/personal/
type = calendar   # NOT filesystem, NOT vdir
```

`path` must point to a DIRECTORY (vdir format: one `.ics` per event), not a single `.ics` file.

## 5. khal date parser doesn't accept relative phrases

**Symptom**:
```
$ khal list "today" "today +7 days"
critical: Could not parse "('today', 'today +7 days')".
```

**Cause**: khal 0.14+ parser is strict. Only absolute `YYYY-MM-DD` is accepted for ranges.

**Fix**: compute dates with GNU `date` first.

```bash
HOY=$(date +%F)
LIM=$(date -d '+7 days' +%F)
khal list "$HOY" "$LIM"
```

## 6. `khal list` output mixes day headers with events

**Symptom**: Parsing `khal list` output in scripts fails because of lines like `viernes, 2026-09-04` mixed with `10:00-11:00 TP 1 entrega`.

**Fix**: use `--format "{start-date}|{title}"` for clean one-line-per-event output, then filter by `"," in line` to drop day headers.

```bash
khal list "$HOY" "$LIM" --once --format "{start-date}|{title}"
```

## 7. `kalarm --list` returns nothing even though events exist

**Cause**: `kalarm --list` only shows events in KAlarm's own calendar. Events added with `khal` live in a separate vdir directory — KAlarm doesn't see them.

**Fix**: either
- Add Akonadi `icaldir_resource` pointing at the khal vdir (advanced; see `akonadi-setup-kde.md`)
- Accept that queries go through `khal` for khal events and `kalarm --list` for KAlarm events

For pure khal workflows, ignore `kalarm --list` entirely.

## 8. `khal` event has ⏰ but no notification fires

**Cause**: khal writes `VALARM` blocks but doesn't ship a notification daemon. The block is data, not action.

**Phase 2 fix**: write a Python notifier that scans `~/.calendars/personal/*.ics` periodically and calls `notify-send`. Run via `systemd --user timer` every minute.

```python
# ~/.local/bin/khal-notifier
import glob, time, datetime
from icalendar import Calendar
now = datetime.datetime.now()
for f in glob.glob(os.path.expanduser("~/.calendars/personal/*.ics")):
    with open(f, "rb") as fh:
        cal = Calendar.from_ical(fh.read())
    for comp in cal.walk("VEVENT"):
        for alarm in comp.walk("VALARM"):
            trigger = alarm.get("TRIGGER")
            # ... compute fire time, notify if within window
```
