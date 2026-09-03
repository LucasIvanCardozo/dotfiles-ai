# Querying Events from the CLI

How to answer questions like *"qué tengo el martes"* or *"qué parciales se vienen"* by querying the KDE calendar from the terminal.

## Read-only tools

| Tool | Use it for |
| --- | --- |
| `konsolekalendar --view` | All calendar events (KOrganizer resources) |
| `kalarm --list` | Pending alarms with their next trigger time |
| `akonadictl status` | Verify Akonadi is running (prerequisite) |

`konsolekalendar` reads from Akonadi. If Akonadi is stopped, `--view` returns nothing — see `references/akonadi-setup-kde.md`.

## Date math (Bash)

`kalarm` and `konsolekalendar` do NOT parse relative dates. Compute them first with GNU `date`.

```bash
# Today
date +%F                           # 2025-11-15

# Tomorrow / yesterday
date -d 'tomorrow' +%F
date -d 'yesterday' +%F

# Named weekday ("next Tuesday" = the upcoming Tuesday)
date -d 'next Tuesday' +%F
date -d 'last Friday' +%F

# This week (Monday → Sunday)
MON=$(date -d 'last Monday' +%F)
SUN=$(date -d 'next Sunday' +%F)

# Next N days, computed from today
START=$(date +%F)
END=$(date -d '+6 days' +%F)

# Specific date in the future
date -d '2025-12-15' +%F          # identity, but useful in pipelines
```

`date -d` understands English relative phrases; do not feed Spanish ("próximo martes" will fail).

## Flags cheatsheet for `konsolekalendar --view`

| Flag | Meaning | Example |
| --- | --- | --- |
| `--date YYYY-MM-DD` | Start day (default today) | `--date 2025-11-15` |
| `--time HH:MM` | Start of view window (default 07:00) | `--time 00:00` for full day |
| `--end-date YYYY-MM-DD` | End day of range | `--end-date 2025-11-21` |
| `--end-time HH:MM` | End of view window (default 17:00) | `--end-time 23:59` for full day |
| `--show-next N` | Next N days from today | `--show-next 7` |
| `--calendar ID` | Specific Akonadi resource | `--calendar 8` |
| `--all` | Include all calendars, not just default | |

`--view` is the operation mode. For full-day queries, always pass `--time 00:00 --end-time 23:59` — without them, the default 07:00–17:00 window can miss evening classes.

## Common query patterns

### "¿Qué tengo el martes?"

```bash
DATE=$(date -d 'next Tuesday' +%F)
konsolekalendar --view --date "$DATE" --time 00:00 --end-time 23:59
```

### "¿Qué curso esta semana?"

```bash
MON=$(date -d 'last Monday' +%F)
SUN=$(date -d 'next Sunday' +%F)
konsolekalendar --view --date "$MON" --end-date "$SUN" --time 00:00 --end-time 23:59
```

### "¿Qué se viene?" (próximos 7 días)

```bash
konsolekalendar --show-next 7
```

### "¿Qué alarmas tengo pendientes?"

```bash
kalarm --list
```

Output format per line: `<resource> <uid> <next-trigger> <message>`. Useful for sanity check after a bulk load.

## Parsing the output for the user

`konsolekalendar --view` prints one block per day. Parse in two passes:

1. Split on lines starting with `Date:` → list of days.
2. Within each day, extract `HH:MM - HH:MM` and `Summary:` → list of events.

Then translate to natural Spanish. Example:

```
Date: 2025-11-11
  18:00 - 20:00  Summary: Algoritmos

Date: 2025-11-12
  (no events)

Date: 2025-11-13
  14:00 - 16:00  Summary: Parcial Algoritmos
  18:00 - 20:00  Summary: Clase Redes
```

Becomes:

> **Martes 11/11** — Algoritmos, 18 a 20 hs.
> **Miércoles 12/11** — sin eventos.
> **Jueves 13/11** — Parcial Algoritmos (14 a 16) y Clase Redes (18 a 20).

Rules for the agent:
- Group consecutive days, never dump raw output unless the user asks.
- If multiple events same day, list in time order.
- Empty day → say "no tenés nada", do not invent.
- All-day events appear with `--time float --end-time float`; handle separately if needed.

## When `konsolekalendar` returns empty but the user expects events

Common causes:

1. **Akonadi not running**: `akonadictl status` → fix per `references/akonadi-setup-kde.md`.
2. **Event loaded with `kalarm` only (no `--korganizer`)**: it lives in KAlarm's calendar, not in KOrganizer's resource. Use `kalarm --list` to confirm.
3. **Wrong calendar resource**: pass `--calendar <id>` after `konsolekalendar --list-calendars`.
4. **View window too narrow**: forgot `--time 00:00 --end-time 23:59` and the event is outside 07–17.

## Verify end-to-end

```bash
# 1. Akonadi up
akonadictl status

# 2. Probe: write + read back
kalarm -t "$(date -d '+1 minute' '+%Y-%m-%d %H:%M')" --reminder 30S "PROBE"
sleep 3
konsolekalendar --view --date "$(date +%F)" --time 00:00 --end-time 23:59
kalarm --list
```

If all three return the probe, the query path works.
