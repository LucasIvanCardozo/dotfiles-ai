#!/usr/bin/env bash
# Diagnose the calendar CLI environment on Plasma 6 / CachyOS.
# Run once per session to capture state.
set -uo pipefail

echo "=== Calendar CLI environment probe ==="
echo "Date: $(date)"
echo

echo "[OS]"
grep -E "^(NAME|PRETTY_NAME|ID)=" /etc/os-release 2>/dev/null | head -3
echo

echo "[KDE Plasma]"
plasmashell --version 2>/dev/null || echo "  plasmashell: not found"
echo

echo "[kalarm]"
which kalarm 2>/dev/null || echo "  kalarm: NOT INSTALLED"
kalarm --version 2>&1 | head -1 || true
echo "  --time bug test:"
kalarm --time "2099-01-01 00:00" --reminder 1H "PROBE" 2>&1 | head -1 | sed 's/^/    /'
echo "  --list (works):"
kalarm --list 2>&1 | head -3 | sed 's/^/    /'
echo

echo "[konsolekalendar]"
which konsolekalendar 2>/dev/null || echo "  konsolekalendar: NOT INSTALLED (expected on Plasma 6)"
echo

echo "[khal]"
which khal 2>/dev/null || echo "  khal: NOT INSTALLED"
khal --version 2>&1 | head -1 || true
echo "  Config:"
ls -la ~/.config/khal/config 2>/dev/null | sed 's/^/    /' || echo "    no config"
echo "  Calendars:"
khal printcalendars 2>&1 | head -3 | sed 's/^/    /'
echo

echo "[Python environment]"
which python python3 python3.14 2>/dev/null | sed 's/^/  /'
echo "  pyenv status:"
pyenv version 2>&1 | sed 's/^/    /'
echo "  System Python khal can import:"
python3.14 -c "import khal; print('    OK:', khal.__file__)" 2>&1 | sed 's/^/    /'
echo

echo "[Akonadi]"
akonadictl status 2>&1 | head -5 | sed 's/^/  /'
echo "  systemd unit (should be akonadi_control.service, NOT akonadi.service):"
systemctl --user list-unit-files 2>/dev/null | grep -i akonadi | sed 's/^/    /'
echo

echo "[Available khal events dir]"
ls -la ~/.calendars/personal/ 2>/dev/null | sed 's/^/  /' || echo "  no ~/.calendars/personal/ — run assets/setup-calendario.sh"
echo

echo "=== End of probe ==="
