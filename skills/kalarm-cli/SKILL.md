---
name: kalarm-cli
description: "Trigger: kalarm, korganizer, konsolekalendar, akonadi, agendar, recordatorio, parcial, parciales, final, finales, clase, clases, tp, tps, cursada, horario, agenda, próximo, lista eventos, calendar cli linux kde. Manage KDE calendar events and reminders from the CLI on Plasma 6 / KDE Gear 26.08+ (CachyOS/Arch). Replaces the removed konsolekalendar with khal-based queries and argument-less tag binaries."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "3.0"
---

## Activation Contract

Use when the user wants to **schedule, list, modify, or delete calendar events and reminders on KDE Plasma** (CachyOS/Arch) via terminal, or scripts recurring academic/personal schedules.

Activate on: "agendame un parcial", "qué parciales se vienen", "qué clases tengo", "cuándo es el próximo final", "cargá el cuatrimestre", troubleshooting `kalarm` / `khal` / `akonadi`.

Do not activate for: Google/Outlook cloud calendars, mobile sync, non-KDE distros.

## Hard Rules

- **Plasma 6 reality check first.** Run `references/diagnose-environment.sh` once per session. Assume `konsolekalendar` does NOT exist and `kalarm --time` may be broken (KDE Gear 26.08+).
- **Default query tool is `khal`**, not `konsolekalendar`. Install: `sudo pacman -S khal vdirsyncer`. If Python shebang breaks, apply the wrapper fix in `references/troubleshooting.md`.
- **`kalarm` is preferred for events with native alarms**, but `--korganizer` segfaults without `--time` in 3.13.1 — pass `--time` always or use khal.
- **Date math is the agent's job**: produce absolute `YYYY-MM-DD HH:MM`. khal 0.14+ does NOT parse "today +7 days" or "next monday"; convert with `date -d '...' +%F`.
- **Daily queries use 4 argument-less binaries**: `parciales`, `finales`, `clases`, `tps`. Each lists future events matching the tag, sorted chronologically with weekday + day delta. No arguments, no flags.
- **Show before execute.** Fenced block + one-line explanation; wait for "dale"/"sí"/"ejecutá". Read-only (`khal list`, the 4 binaries, `akonadictl status`) needs no confirmation.
- **Default reminder**: `--reminder 1H` or `-m 1H`. Ask before changing.
- **Never edit system files** (`/etc/`, Akonadi DB, `~/.config/akonadi/*`) without explicit OK.
- **Akonadi required for KOrganizer/KAlarm GUI**, not for khal CLI workflows.

## Decision Gates

| Situation | Tool | Reason |
| --- | --- | --- |
| Add event with native KDE alarm | `khal new ... -m 1H` (preferred) | Writes `VALARM`, reliable. `kalarm` is buggy. |
| Add event with GUI visibility (KOrganizer) | KOrganizer GUI; CLI fallback broken | `--korganizer` segfaults in 3.13.1 without `--time` |
| Bulk-load cuatrimestre | `assets/setup-calendario.sh` + loop `khal new` per occurrence | Idempotent + per-event khal |
| List all future parciales | `parciales` (no args) | argument-less, weekday + delta format |
| List all future finales | `finales` (no args) | same shape, tag `final` |
| List all future clases | `clases` (no args) | tag `clase` |
| List all future TPs | `tps` (no args) | tag `tp` |
| Edit/delete existing event | `khal edit <query>` (interactive) or KOrganizer GUI | CLI edit awkward |
| Diagnose missing event | `references/troubleshooting.md` | pyenv/Python, mirror desync, akonadi service name |

## Execution Steps

1. **Diagnose** (first interaction): `references/diagnose-environment.sh`.
2. **One-shot setup** if `~/.calendars/personal/` missing: `assets/setup-calendario.sh`. Idempotent.
3. **Confirm scope**: date+time, text, reminder window, tag (`parcial`/`final`/`clase`/`tp`).
4. **Compute absolute dates** with `date -d '...' +%F`. Day-only events default to 09:00.
5. **Build command**:
   ```bash
   khal new 2026-09-15 14:00 2h "Parcial Algoritmos" -g parcial -m 1H
   # Recurring class:
   khal new "$(date -d 'monday' +%F) 18:00" 2h "Clase Redes" -g clase -r weekly -u 2026-12-15
   ```
6. **Show + wait for OK** + execute. Report exit code.
7. **Daily query**: just run the binary, no arguments. `parciales`, `finales`, `clases`, `tps`.

## Output Contract

Return after each action:
- Commands shown vs executed (separated).
- Confirmation prompt used (if any).
- Files touched (usually none — Akonadi writes are implicit).
- Unresolved ambiguity (missing end date, recurring vs one-shot).
- Residual risks (kalarm CLI bugs, no native notifications without KAlarm).

## References

- `references/plasma6-changes.md` — Plasma 5 → 6 calendar CLI changes
- `references/troubleshooting.md` — pyenv/Python, mirror cache, `akonadi_control.service`, khal date quirks
- `references/khal-queries.md` — khal 0.14+ command cheatsheet
- `references/akonadi-setup-kde.md` — Akonadi install/start/reset
- `references/diagnose-environment.sh` — environment probe
- `assets/setup-calendario.sh` — one-shot setup; idempotent
- `assets/wrappers/parciales` — list all future parciales
- `assets/wrappers/finales` — list all future finales
- `assets/wrappers/clases` — list all future clases
- `assets/wrappers/tps` — list all future TPs
