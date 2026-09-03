# `kalarm` vs `konsolekalendar` vs `korganizer` GUI

Quick reference for choosing the right tool on KDE Plasma (CachyOS/Arch).

## At a glance

| Capability | `kalarm` (CLI) | `konsolekalendar` (CLI) | `korganizer` (GUI) |
| --- | --- | --- | --- |
| Add event | yes | yes | yes |
| Add alarm/reminder (`VALARM`) | **yes** (`--reminder`) | **no** | yes |
| Show in KOrganizer calendar | via `--korganizer` flag | yes (default) | n/a |
| Recurring events | `--repeat N --interval 1W` | no native support | yes (rich UI) |
| Edit existing event | awkward (`--edit-id`) | `--edit` | yes (best UX) |
| Delete event | `--delete-id` | `--delete` | yes |
| List events | `--list` | `--list` | yes |
| Works without Akonadi | **yes** (own calendar) | no (needs Akonadi) | no |
| Default use | alarms + reminders with one command | bulk calendar entries | interactive edit / view |

## Decision flow

```
Need a reminder before the event?
├── YES → kalarm (default)
│         └── Want it visible in KOrganizer? → add --korganizer
└── NO  → konsolekalendar --add (lighter, no alarm overhead)
```

## Install (Arch / CachyOS)

```bash
sudo pacman -S kalarm korganizer kdepim-runtime
```

`kdepim-runtime` provides Akonadi. Without it, `kalarm --korganizer` will silently fail to sync with KOrganizer.

## Common flag cheatsheet

### `kalarm` — alarms + reminders

```bash
# One-off event with one reminder
kalarm -t "2025-11-15 14:00" --reminder 1H --korganizer "Parcial Algoritmos"

# Multiple reminders
kalarm -t "2025-12-20 09:00" --reminder 24H --reminder 1H --korganizer "Final Sistemas Op"

# Weekly recurring class (infinite)
kalarm -t "2025-03-11 18:00" --repeat -1 --interval 7D --reminder 30M --korganizer "Clase Redes"

# Class with end-of-term date
kalarm -t "2025-03-11 18:00" --interval 7D --until 2025-07-15 --reminder 30M --korganizer "Clase Redes"

# List all alarms
kalarm --list

# Delete by ID (from --list)
kalarm --delete-id <id>
```

Time units accepted in `--reminder`, `--interval`, `--late-cancel`:
`S` seconds, `M` minutes, `H` hours, `D` days, `W` weeks.

### `konsolekalendar` — pure calendar entries

```bash
# Get the calendar ID first
konsolekalendar --list-calendars

# Insert event into calendar 8
konsolekalendar --add --calendar 8 \
  --date 2025-11-15 --time 14:00 --end-time 16:00 \
  --summary "Reunión TP" --description "Sala 203"
```

### `korganizer` (GUI)

Just run `korganizer`. Best for:
- Visualizing week/month
- Drag-and-drop reschedule
- Editing recurrences safely
- Seeing what Akonadi actually synced

## When to suspect Akonadi is the problem

- `kalarm --korganizer` runs but the event does not appear in KOrganizer.
- `korganizer` opens empty.
- `akonadictl status` reports a stopped agent.

See `references/akonadi-setup-kde.md` for fixes.
