#!/usr/bin/env bash
# One-shot setup: calendario académico CLI con khal + 4 binaries.
# Plasma 6 / KDE Gear 26.08+ (CachyOS/Arch).
#
# Idempotente: corre las veces que quieras sin romper nada.
#
# Hace:
#   1. Crea ~/.calendars/personal/ (vdir)
#   2. Escribe ~/.config/khal/config (compatible con khal 0.14+)
#   3. Crea 4 binaries en ~/.local/bin/: parciales, finales, clases, tps
#   4. Elimina wrappers deprecados (que-teno, proximo-parcial, cuanto-falta)
#   5. Verifica que khal responde sin warnings
#
# Uso: bash assets/setup-calendario.sh

set -euo pipefail

CAL_DIR="$HOME/.calendars/personal"
KHAL_CONF="$HOME/.config/khal/config"
BIN_DIR="$HOME/.local/bin"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "▶ Paso 1/5: directorio de calendario (formato vdir)"
mkdir -p "$CAL_DIR"
echo "  ✓ $CAL_DIR listo"

echo "▶ Paso 2/5: configurando khal"
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

echo "▶ Paso 3/5: eliminando wrappers deprecados (v1)"
for old in que-teno proximo-parcial cuanto-falta; do
    if [ -f "$BIN_DIR/$old" ]; then
        rm -f "$BIN_DIR/$old"
        echo "  ✓ $BIN_DIR/$old eliminado"
    fi
done

echo "▶ Paso 4/5: instalando 4 binaries en $BIN_DIR"
mkdir -p "$BIN_DIR"
for w in parciales finales clases tps; do
    if [ -f "$SKILL_DIR/wrappers/$w" ]; then
        cp "$SKILL_DIR/wrappers/$w" "$BIN_DIR/$w"
        chmod +x "$BIN_DIR/$w"
        echo "  ✓ $w"
    else
        echo "  ✗ $w (falta en assets/wrappers/)"
    fi
done

echo "▶ Paso 5/5: verificación"
echo "--- khal printcalendars ---"
khal printcalendars 2>&1
echo "--- khal list próximos 30 días ---"
HOY="$(date +%F)"; LIM="$(date -d '+30 days' +%F)"
khal list "$HOY" "$LIM" --once 2>&1 | head -10

echo
echo "✓ Listo. Para probar:"
echo "  parciales"
echo "  clases"
echo "  finales"
echo "  tps"
echo
echo "Agregar eventos con tag:"
echo "  khal new 2026-09-15 14:00 2h 'Parcial X' -g parcial -m 1H"
echo "  khal new 'monday 18:00' 2h 'Clase Y' -g clase -r weekly -u 2026-12-15"
echo "  khal new 2026-10-20 09:00 1h 'TP 3' -g tp"
