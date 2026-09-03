# `khal` 0.14+ Command Reference for Calendar Queries

Replaces the old `konsolekalendar --view` / `--show-next` workflow.

## Quick cheatsheet

| Old (konsolekalendar) | New (khal 0.14+) |
| --- | --- |
| `konsolekalendar --view --date X` | `khal calendar X X` or `khal list X` |
| `konsolekalendar --show-next 7` | `khal list $(date +%F) $(date -d '+7 days' +%F)` |
| `konsolekalendar --list-calendars` | `khal printcalendars` |
| `konsolekalendar --view --search "foo"` | `khal search foo` |

## Date format (mandatory: absolute `YYYY-MM-DD`)

khal 0.14+ parser does NOT accept `"today +7 days"` or `"next monday"`. Always compute with GNU `date` first.

```bash
HOY=$(date +%F)                              # 2026-09-02
LIM=$(date -d '+7 days' +%F)                # 2026-09-09
LUNES=$(date -d 'next monday' +%F)          # 2026-09-07
```

## Reading the calendar

```bash
# All events of a specific day
khal list 2026-09-07

# Range
khal list "$HOY" "$LIM"

# Calendar + agenda view (grid + events)
khal calendar 2026-09-07 2026-09-07

# Default calendar (must be set in [default] default_calendar)
khal printcalendars
```

## Searching

```bash
# Free-text search across all events
khal search "Parcial"

# Filter by calendar
khal search --include-calendar personal "Parcial"

# Exclude
khal search --exclude-calendar trash "foo"
```

## Parsing output programmatically

Default `khal list` output mixes day headers with events — hard to parse. Always pass `--format` for scripts.

```bash
# Clean pipe-delimited output
khal list "$HOY" "$LIM" --once --format "{start-date}|{title}"
# Output:
# 2026-09-04|TP 1 entrega
# 2026-09-07|Parcial Física
# 2026-09-09|Clase Algoritmos

# Day headers (e.g. "viernes, 2026-09-04") still appear with --format; filter by ","
```

## Adding events

```bash
# One-shot with alarm
khal new 2026-09-15 14:00 2h "Parcial Algoritmos" -g parcial -m 1H

# Recurring class (weekly until end of term)
khal new "$(date -d 'monday' +%F) 18:00" 2h "Clase Redes" \
  -g clase -r weekly -u 2026-12-15

# Multiple alarms
khal new 2026-12-20 09:00 2h "Final" -g final -m 24H,1H

# Categories (comma-separated)
khal new 2026-10-20 09:00 1h "TP 3" -g "tp,urgente"
```

## Editing / deleting

```bash
# Interactive edit
khal edit "Parcial"

# Interactive delete
khal edit --delete "Parcial prueba"

# Bulk
khal edit --exclude-calendar personal "foo"
```

## Output placeholders (for `--format`)

- `{start-date}` — event start date (locale-formatted)
- `{start-time}` — event start time
- `{end-date}`, `{end-time}` — same for end
- `{title}` — event SUMMARY
- `{description}` — event DESCRIPTION
- `{location}` — event LOCATION
- `{categories}` — comma-separated categories
- `{status}` — TENTATIVE / CONFIRMED / CANCELLED

Run `khal printformats` to see locale defaults for date/time formats.

## Aliases recommended in `~/.zshrc`

```bash
alias kl='khal list'
alias kc='khal calendar'
alias kn='khal new'
alias ks='khal search'
```
