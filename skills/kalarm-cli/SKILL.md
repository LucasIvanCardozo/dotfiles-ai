---
name: kalarm-cli
description: "Trigger: kalarm, korganizer, konsolekalendar, akonadi, agendar, recordatorio, parcial, final, clase, cursada, horario, qué tengo, qué curso, agenda, próximo, lista eventos, calendar cli linux kde. Manage KDE calendar events and reminders from the CLI on Plasma 6 / KDE Gear 26.08+ (CachyOS/Arch). Replaces the removed konsolekalendar with khal-based queries."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "2.0"
---

## Activation Contract

Use when the user wants to **schedule, list, modify, or delete calendar events and reminders on KDE Plasma** (CachyOS/Arch) via terminal, or scripts recurring academic/personal schedules.

Activate on: "agendame un parcial", "recordame esto 1 hora antes", "cargá el cuatrimestre", "qué tengo mañana", "qué parciales se vienen", troubleshooting `kalarm` / `khal` / `akonadi`.

Do not activate for: Google/Outlook cloud calendars, mobile sync, non-KDE distros.

## Hard Rules

- **Plasma 6 reality check first.** Run `references/diagnose-environment.sh` once per session. Assume `konsolekalendar` does NOT exist and `kalarm --time` may be broken (KDE Gear 26.08+).
- **Default query tool is `khal`**, not `konsolekalendar`. Install: `sudo pacman -S khal vdirsyncer`. If Python shebang breaks, apply the wrapper fix in `references/troubleshooting.md`.
- **`kalarm` is preferred for events with native alarms**, but `--korganizer` segfaults without `--time` in 3.13.1 — pass `--time` always or use khal.
- **Date math is the agent's job**: produce absolute `YYYY-MM-DD HH:MM`. khal 0.14+ does NOT parse "today +7 days" or "next monday"; convert with `date -d '...' +%F`.
- **Show before execute.** Fenced block + one-line explanation; wait for "dale"/"sí"/"ejecutá". Read-only (`kalarm --list`, `khal list`, `akonadictl status`) needs no confirmation.
- **Default reminder**: `--reminder 1H` or `-m 1H`. Ask before changing.
- **Never edit system files** (`/etc/`, Akonadi DB, `~/.config/akonadi/*`) without explicit OK.
- **Akonadi required for KOrganizer/KAlarm GUI**, not for khal CLI workflows. Verify with `akonadictl status` before assuming integration.

## Decision Gates

| Situation | Tool | Reason |
| --- | --- | --- |
| Add event with native KDE alarm | `khal new ... -m 1H` (preferred) | Writes `VALARM`, reliable. `kalarm` is buggy. |
| Add event with GUI visibility (KOrganizer) | KOrganizer GUI; CLI fallback broken | `--korganizer` segfaults in 3.13.1 without `--time` |
| Bulk-load cuatrimestre | `assets/setup-calendario.sh` + loop `khal new` per occurrence | Idempotent + per-event khal |
| "Qué tengo el día X" / "qué curso el martes" | `que-teno [fecha]` → `khal calendar` | khal 0.14+ uses `calendar`, not `agenda` |
| "Próximo parcial / clase / TP" | `proximo-parcial [tag]` → `khal list --format` | Tag-based filtering + day delta |
| "Cuánto falta para X" | `cuanto-falta <texto>` → `khal search` | Fuzzy match + day delta |
| Edit/delete existing event | `khal edit <query>` (interactive) or KOrganizer GUI | CLI edit awkward; khal editor friendlier |
| Diagnose missing event | `references/troubleshooting.md` | pyenv/Python, mirror desync, akonadi service name |

## Execution Steps

1. **Diagnose** (first interaction): `references/diagnose-environment.sh`. Capture Plasma/kalarm/khal versions, pyenv status, akonadi state.
2. **One-shot setup** if `~/.calendars/personal/` missing: `assets/setup-calendario.sh`. Idempotent.
3. **Confirm scope**: date+time, text, reminder window, tag (`parcial`/`clase`/`final`/`tp`).
4. **Compute absolute dates** with `date -d '...' +%F`. Day-only events default to 09:00.
5. **Build command**:
   ```bash
   khal new 2026-09-15 14:00 2h "Parcial Algoritmos" -g parcial -m 1H
   # Recurring class (with --until for end-of-term):
   khal new "$(date -d 'monday' +%F) 18:00" 2h "Clase Redes" -g clase -r weekly -u 2026-12-15
   ```
6. **Show + wait for OK** + execute. Report exit code.
7. **Query mode** (read-only): use the wrappers; parse output, answer in natural Spanish, never invent.

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
- `references/khal-queries.md` — khal 0.14+ command cheatsheet (replaces old `querying-events.md`)
- `references/akonadi-setup-kde.md` — Akonadi install/start/reset (kept from v1, updated)
- `references/diagnose-environment.sh` — environment probe; run once per session
- `assets/setup-calendario.sh` — one-shot setup; idempotent
- `assets/wrappers/que-teno` — calendar view for a day
- `assets/wrappers/proximo-parcial` — next event with tag + day delta
- `assets/wrappers/cuanto-falta` — fuzzy match + day deltas
