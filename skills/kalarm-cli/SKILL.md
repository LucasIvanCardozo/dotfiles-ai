---
name: kalarm-cli
description: "Trigger: kalarm, korganizer, konsolekalendar, akonadi, agendar, recordatorio, parcial, final, clase, cursada, horario, qué tengo, qué curso, agenda, próximo, lista eventos, calendar cli linux kde. Manage KDE calendar events, alarms, and reminders from the CLI on CachyOS/Arch."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Use this skill when the user wants to **schedule, list, modify, or delete calendar events and reminders on KDE Plasma** (CachyOS/Arch) using the terminal, or when an LLM is asked to script recurring academic/personal schedules.

Activate on requests like:
- "agendame un parcial el jueves a las 14"
- "recordame esto 1 hora antes"
- "cargá todo el cuatrimestre"
- "agregá clase semanal los martes 18hs"
- **"qué tengo el martes" / "qué curso el viernes" / "qué parciales se vienen"** (read-only query mode)
- troubleshooting `kalarm`, `akonadictl`, `korganizer`

Do not activate for: Google/Outlook cloud calendars, mobile sync (this stack is local-only), or non-KDE distros without KAlarm.

## Hard Rules

- **Default tool is `kalarm`** — it natively supports reminders via `--reminder N` (e.g. `15M`, `1H`, `24H`, `3D`).
- **Always pass `--korganizer`** unless the user explicitly says "solo en KAlarm". This makes the event visible in the GUI calendar.
- **Default reminder**: 1 hour before (`--reminder 1H`). Ask before changing.
- **Run behavior**: show the command first; only execute after user confirms with "dale"/"sí"/"ejecutá". Read-only commands (`kalarm --list`, `konsolekalendar --view`, `akonadictl status`) may run without confirmation.
- **Date math is the agent's job**: produce `YYYY-MM-DD HH:MM` in local TZ; for relative dates use `date -d 'next Tuesday' +%F`. Day-only events default to 09:00.
- **Query mode** (`qué tengo el martes`): read-only. Use `konsolekalendar --view` for events, `kalarm --list` for alarms. Parse plain-text output and answer in natural Spanish — never invent data, never dump raw output unless asked.
- **Never edit system files** (`/etc/`, Akonadi DB, `~/.config/akonadi/*` schemas) without explicit OK.
- **Recurrence for weekly classes**: `--repeat -1 --interval 7D` (infinite) or with `--until YYYY-MM-DD` for end-of-term.
- **Akonadi is required** for KOrganizer/KAlarm GUI; verify with `akonadictl status` before assuming integration works.

## Decision Gates

| Situation | Tool | Reason |
| --- | --- | --- |
| Add event with reminder(s) | `kalarm -t ... --reminder N --korganizer` | One-shot, supports reminders natively |
| Add event without reminder, pure calendar entry | `konsolekalendar --add ... --korganizer` | Lighter, no alarm overhead |
| Bulk-load recurring weekly class | `kalarm` per occurrence OR shell loop | Avoid `--repeat` misuse; recurrence is fragile for academic terms |
| Modify/delete an existing alarm | KOrganizer GUI or `kalarm --edit-id <id>` | CLI edit is awkward; GUI is safer |
| User wants to see all alarms | `kalarm --list` or open KOrganizer | Read-only, no confirmation needed |
| User asks "qué tengo el día X" / "qué curso el martes" | `konsolekalendar --view --date X --time 00:00 --end-time 23:59` | Parse and answer in Spanish |
| User asks "qué se viene" / próximos N días | `konsolekalendar --show-next N` | Compact list, no date math needed |
| User asks "qué tengo esta semana" | `konsolekalendar --view --date MON --end-date SUN` | Agent computes Monday/Sunday from today |
| Diagnose missing event from KOrganizer | `references/akonadi-setup-kde.md` | Usually Akonadi not running |

## Execution Steps

1. **Confirm scope**: ask what to schedule (date+time, text, reminder windows) when unclear. Prefer one short sentence over multiple choice.
2. **Format datetime**: produce `YYYY-MM-DD HH:MM` in local TZ. If only a date, append `09:00`.
3. **Build the command** using the template:
   ```bash
   kalarm -t "YYYY-MM-DD HH:MM" --reminder 1H --korganizer "EVENT TEXT"
   ```
   Multiple reminders: append more `--reminder N` (e.g., `--reminder 24H --reminder 1H`).
4. **Show the command** in a fenced block with a one-line explanation. Wait for user OK before executing.
5. **Execute** on confirmation. Report exit code and one-line result.
6. **Verify integration** only if user asks or if KOrganizer visibility is in question (`akonadictl status`).
7. **For bulk academic loads**: propose a CSV or shell loop and let the user approve the whole batch at once, not event-by-event.
8. **Query mode** (read-only, no confirmation needed):
   - Compute the target date(s) with `date -d 'next Tuesday' +%F` (or `MON/SUN` for week range).
   - Run the matching `konsolekalendar --view` or `--show-next N`.
   - Parse output into short natural Spanish. Group by day if multi-day. Distinguish events from alarms.
   - Empty result + user expects events → suspect Akonadi: suggest `akonadictl status` and `references/akonadi-setup-kde.md`.

## Output Contract

Return after each action:
- Commands shown vs commands executed (separated).
- Confirmation prompt used (if any).
- Files touched (usually none — Akonadi DB writes are implicit).
- Any unresolved ambiguity (e.g., missing end date for recurrence).
- Residual risks (e.g., Akonadi not running → event only in KAlarm).

## References

- `references/kalarm-vs-konsolekalendar.md` — when to use which CLI tool (write vs read).
- `references/querying-events.md` — how to query events for a day/week/range and answer "qué tengo el martes".
- `references/akonadi-setup-kde.md` — Akonadi install/start/troubleshoot on CachyOS/Arch.
- Official docs: `https://docs.kde.org/trunk_kf6/en/kalarm/kalarm/cmdline-operation.html`
