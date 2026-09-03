#!/usr/bin/env bash
# One-shot setup: calendario académico CLI con khal + wrappers.
# Plasma 6 / KDE Gear 26.08+ (CachyOS/Arch).
#
# Idempotente: corre las veces que quieras sin romper nada.
#
# Hace:
#   1. Crea ~/.calendars/personal/ (vdir)
#   2. Escribe ~/.config/khal/config (compatible con khal 0.14+)
#   3. Crea 3 wrappers en ~/.local/bin/: que-teno, proximo-parcial, cuanto-falta
#   4. Verifica que khal responde sin warnings
#
# Uso: bash assets/setup-calendario.sh

set -euo pipefail

CAL_DIR="$HOME/.calendars/personal"
KHAL_CONF="$HOME/.config/khal/config"
BIN_DIR="$HOME/.local/bin"

echo "▶ Paso 1/4: directorio de calendario (formato vdir)"
mkdir -p "$CAL_DIR"
echo "  ✓ $CAL_DIR listo"

echo "▶ Paso 2/4: configurando khal"
mkdir -p "$HOME/.config/khal"
cat > "$KHAL_CONF" <<'KCONF'
[calendars]
[[personal]]
path = ~/.calendars/personal/
type = calendar

[default]
default_calendar = personal
show_all_days = False
print_new = event

[locale]
timeformat = %H:%M
dateformat = %Y-%m-%d
longdateformat = %Y-%m-%d
datetimeformat = %Y-%m-%d %H:%M
longdatetimeformat = %Y-%m-%d %H:%M
KCONF
echo "  ✓ $KHAL_CONF escrito"

echo "▶ Paso 3/4: wrappers en $BIN_DIR"
mkdir -p "$BIN_DIR"

# que-teno: agenda del día (vista calendario)
cat > "$BIN_DIR/que-teno" <<'WRAP'
#!/usr/bin/env bash
# Uso: que-teno [fecha]
# Acepta: hoy, mañana, today, tomorrow, "next monday", "2026-09-15"
fecha="${1:-hoy}"
case "$fecha" in
    hoy|today)        f="$(date +%F)" ;;
    mañana|manana|tomorrow) f="$(date -d 'tomorrow' +%F)" ;;
    *)                f="$(date -d "$fecha" +%F 2>/dev/null || date +%F)" ;;
esac
khal calendar "$f" "$f"
WRAP
chmod +x "$BIN_DIR/que-teno"

# proximo-parcial: próximo evento taggeado + delta de días
cat > "$BIN_DIR/proximo-parcial" <<'WRAP'
#!/usr/bin/env bash
# Uso: proximo-parcial [tag]
# Default: parcial
TAG="${1:-parcial}"
HOY="$(date +%F)"
LIM="$(date -d '+60 days' +%F)"
python3.14 - "$TAG" "$HOY" "$LIM" <<'PY'
import sys, subprocess
from datetime import datetime
tag, hoy_s, lim_s = sys.argv[1].lower(), sys.argv[2], sys.argv[3]
hoy = datetime.strptime(hoy_s, "%Y-%m-%d")
lim = datetime.strptime(lim_s, "%Y-%m-%d")
out = subprocess.check_output(
    ["khal", "list", hoy_s, lim_s, "--once", "--format", "{start-date}|{title}"],
    text=True
)
matches = []
for line in out.splitlines():
    if "," in line or "|" not in line:
        continue
    fecha_s, titulo = line.split("|", 1)
    if tag not in titulo.lower():
        continue
    try:
        d = datetime.strptime(fecha_s.strip(), "%Y-%m-%d")
    except ValueError:
        continue
    if hoy <= d <= lim:
        matches.append((d, titulo.strip()))
matches.sort()
if not matches:
    print(f"Sin eventos con tag '{tag}' entre {hoy_s} y {lim_s}.")
    sys.exit(0)
d, titulo = matches[0]
delta = (d - hoy).days
cuando = "hoy" if delta == 0 else ("mañana" if delta == 1 else f"en {delta} días")
print(f"▶ {titulo}: {d.strftime('%Y-%m-%d')} ({cuando})")
PY
WRAP
chmod +x "$BIN_DIR/proximo-parcial"

# cuanto-falta: cuánto falta para un evento por texto
cat > "$BIN_DIR/cuanto-falta" <<'WRAP'
#!/usr/bin/env bash
# Uso: cuanto-falta <texto del evento>
if [ $# -lt 1 ]; then
    echo "Uso: cuanto-falta <texto a buscar>" >&2
    exit 1
fi
QUERY="$*"
python3.14 - "$QUERY" <<'PY'
import sys, subprocess
from datetime import datetime
query = sys.argv[1].lower()
hoy = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
out = subprocess.check_output(
    ["khal", "search", query, "--format", "{start-date}|{title}"],
    text=True
)
matches = []
for line in out.splitlines():
    if "," in line or "|" not in line:
        continue
    fecha_s, titulo = line.split("|", 1)
    try:
        d = datetime.strptime(fecha_s.strip(), "%Y-%m-%d")
    except ValueError:
        continue
    if d >= hoy:
        matches.append((d, titulo.strip()))
matches.sort()
if not matches:
    print(f"Sin eventos que matcheen '{query}'.")
    sys.exit(0)
for d, titulo in matches[:5]:
    delta = (d - hoy).days
    cuando = "hoy" if delta == 0 else ("mañana" if delta == 1 else f"en {delta} días")
    print(f"▶ {titulo}: {d.strftime('%Y-%m-%d')} ({cuando})")
PY
WRAP
chmod +x "$BIN_DIR/cuanto-falta"

echo "  ✓ que-teno, proximo-parcial, cuanto-falta"

echo "▶ Paso 4/4: verificación"
echo "--- khal printcalendars ---"
khal printcalendars 2>&1
echo "--- khal list próximos 30 días ---"
HOY="$(date +%F)"; LIM="$(date -d '+30 days' +%F)"
khal list "$HOY" "$LIM" --once 2>&1 | head -10

echo
echo "✓ Listo."
echo
echo "Comandos:"
echo "  que-teno [fecha]       → calendario del día (acepta hoy/mañana/YYYY-MM-DD)"
echo "  proximo-parcial [tag]  → próximo evento con ese tag"
echo "  cuanto-falta <texto>   → cuántos días faltan"
echo
echo "Agregar eventos:"
echo "  khal new 2026-09-15 14:00 2h 'Parcial X' -g parcial -m 1H"
echo "  khal new 'monday 18:00' 2h 'Clase Y' -g clase -r weekly -u 2026-12-15"
echo "  khal new 2026-10-20 09:00 1h 'TP 3' -g tp"
