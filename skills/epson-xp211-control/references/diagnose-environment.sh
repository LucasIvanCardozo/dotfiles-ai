#!/usr/bin/env bash
# diagnose-environment.sh — probe the Epson XP-211 environment
# Exits 0 if everything is fine, non-zero on first failure.

set -uo pipefail

QUEUE="EPSON_XP-211_214_216_Series"
IP="192.168.1.41"
HOST="EPSONDCDFC5.local"

ok=()
fail=()

echo "=== Epson XP-211 environment probe ==="
echo

# 1. CUPS queue
echo "[1/5] CUPS queue '$QUEUE'"
if state=$(lpstat -p "$QUEUE" 2>&1); then
  echo "  OK: $state"
  ok+=("cups-queue")
else
  echo "  FAIL: $state"
  fail+=("cups-queue")
fi

# 2. PPD model (use lpoptions, which works without root)
echo "[2/5] PPD driver"
if model=$(lpoptions -p "$QUEUE" 2>/dev/null | grep -o "printer-make-and-model='[^']*'" | sed "s/printer-make-and-model='//;s/'$//"); then
  if [[ -n "$model" ]]; then
    if [[ "$model" == *epson-inkjet-printer* ]]; then
      echo "  OK: $model"
      ok+=("ppd")
    else
      echo "  FAIL: wrong driver — $model"
      echo "        Expected: epson-inkjet-printer-201304w"
      fail+=("ppd")
    fi
  else
    echo "  FAIL: lpoptions returned empty model"
    fail+=("ppd")
  fi
else
  echo "  FAIL: lpoptions failed for $QUEUE"
  fail+=("ppd")
fi

# 3. SANE scanner
echo "[3/5] SANE scanner backend"
if sane_out=$(scanimage -L 2>&1 | grep -F "epson2:net:${IP}"); then
  echo "  OK: $sane_out"
  ok+=("sane")
else
  echo "  FAIL: scanimage -L did not list epson2:net:${IP}"
  fail+=("sane")
fi

# 4. ecbd daemon
echo "[4/5] ecbd.service"
ecbd_state=$(systemctl is-active ecbd 2>&1)
if [[ "$ecbd_state" == "active" ]]; then
  echo "  OK: $ecbd_state"
  ok+=("ecbd")
else
  echo "  WARN: $ecbd_state (only needed for USB, not for WiFi workflow)"
fi

# 5. mDNS resolution
echo "[5/5] mDNS resolution ($HOST)"
if resolved=$(getent hosts "$HOST" 2>&1); then
  echo "  OK: $resolved"
  ok+=("mdns")
else
  echo "  FAIL: $HOST does not resolve"
  fail+=("mdns")
fi

echo
echo "=== Summary ==="
echo "  OK:   ${ok[*]:-none}"
echo "  FAIL: ${fail[*]:-none}"

if [[ ${#fail[@]} -gt 0 ]]; then
  exit 1
fi
exit 0
