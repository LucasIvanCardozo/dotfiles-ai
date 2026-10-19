---
name: epson-xp211-control
description: "Trigger: epson, xp-211, xp211, xp-214, xp-216, impresora, printer, escáner, scanner, escanear, escaneo, imprimir, impresión, impresión, escaneame, print, scan, scanimage, lp, lpstat, tinta, niveles de tinta, ink levels, nozzle check, head cleaning, alineación cabezal, hp (hermano printer, hermana printer), imprimir x cosa, escanear documento. Control CLI de la Epson XP-211 214 216 conectada por WiFi en CachyOS/Arch: imprimir con driver nativo epson-inkjet-printer-201304w y escanear con SANE backend epson2 vía red (192.168.1.41 / EPSONDCDFC5.local). NO cubre mantenimiento desde PC (la GUI epson-printer-utility del AUR no detecta por red — usar app móvil Epson Smart Panel)."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Use when the user wants to **print, scan, or query the state of an Epson XP-211 / XP-214 / XP-216 connected via WiFi** from the terminal on CachyOS/Arch Linux.

Activate on: "imprimí el PDF", "mandá a la epson", "escaneame esto", "pasá la página al PC", "qué imprime quedó encolado", "cómo está la impresora", "cuánta tinta tiene", "limpieza de cabezales", "nozzle check", "qué nivel de tinta".

Do **not** activate for:
- Other printer brands (HP, Canon, Brother, Samsung).
- USB-only Epson workflows (this skill assumes WiFi).
- Router / firewall / mDNS configuration (out of scope — see `references/network-services.md` only for diagnostic context).
- Generic `lp`/`scanimage` help unrelated to this specific printer.

## Hard Rules

- **Network is the only transport.** Impresora en `192.168.1.41` (hostname mDNS `EPSONDCDFC5.local`). No asumir USB, no preguntar por `/dev/usb/lp0`.
- **CUPS queue name is `EPSON_XP-211_214_216_Series`.** Always use this exact name with `lp`, `lpstat`, `cancel`. Never invent names.
- **PPD is the native `epson-inkjet-printer-201304w` driver** (`/etc/cups/ppd/EPSON_XP-211_214_216_Series.ppd`). The old "Generic PDF Printer" PPD is deprecated — reinstall the queue if it ever reappears.
- **Scanner backend is `epson2:net:192.168.1.41`.** Configured in `/etc/sane.d/epson2.conf` with `net 192.168.1.41`. Do not switch to `epson` or `epsonds` without a reason — `epson2` is the modern, network-capable backend.
- **The `epson-printer-utility` GUI does NOT detect network printers** in the AUR package (ecbd 1.3.1 ships without `ekpnet` module). For ink levels / nozzle check / head cleaning from the PC, redirect the user to the **Epson Smart Panel** mobile app or the printer's physical panel. Do NOT spend more than one diagnosis step on this.
- **`ecbd.service` is only useful for USB.** Leave it enabled (idempotent, no harm), but do not try to "fix" its lack of network discovery.
- **Show before execute** for any non-trivial command (printing with options, scanning with custom resolution/format). Read-only commands (`lpstat`, `scanimage -L`, `systemctl is-active ecbd`) need no confirmation.
- **Verify connectivity first** when something fails: `scanimage -L` should list `epson2:net:192.168.1.41`, `lpstat -p` should show the queue active. If either fails, jump to `references/troubleshooting.md`.
- **Default scan format is PNG**, default resolution is 300 DPI for documents / 150 DPI for photos, default mode is color. Override only if the user says so.
- **Default print mode is color**, default media is A4 / `PlainPaper`. Override only if the user says so.

## Decision Gates

| Situation | Tool / command | Reason |
| --- | --- | --- |
| Print an existing file | `lp -d EPSON_XP-211_214_216_Series [opts] <file>` | Native PPD understands PostScript/PDF/text |
| Print N copies | `lp -n N -d ... <file>` | CUPS native |
| Print in B/N | `lp -o print-color-mode=monochrome -d ...` | Use CUPS option, not PPD filter |
| Print in draft / high quality | `lp -o PrintQuality=Draft\|High\|Standard` | PPD-specific option |
| Print duplex (manual) | `lp -o sides=two-sided-long-edge` | XP-211 has no auto-duplex; this flag still affects layout |
| List available media types | `lpoptions -p EPSON_XP-211_214_216_Series` | All current PPD options |
| Change default media | `lpoptions -p EPSON_XP-211_214_216_Series -o MediaType=PhotoPaper` | Persistent default |
| List pending print jobs | `assets/cola` or `lpstat -o` | Wrapper preferred for stable output |
| Cancel a job | `cancel EPSON_XP-211_214_216_Series-<id>` | CUPS native |
| Quick state check | `assets/estado` | Combined CUPS + SANE + daemon |
| Scan to PNG file | `assets/escanear --resolution 300 --format png -o /tmp/scan.png` | Wrapper preferred |
| Scan to PDF | `scanimage -d epson2:net:192.168.1.41 --format png -p > /tmp/p1.png` then `img2pdf /tmp/p1.png -o out.pdf`; or use `simple-scan` GUI | XP-211 is single-page flatbed, no native multipage |
| Scan at high resolution | `assets/escanear --resolution 600 ...` | Max usable is 600 DPI; beyond is interpolated |
| Scan in B/N | `assets/escanear --mode Lineart ...` | Saves space, faster |
| Diagnose full environment | `references/diagnose-environment.sh` | One-shot probe |
| Ink levels from PC | **Not supported** — redirect to Epson Smart Panel app | AUR limitation |
| Head cleaning from PC | **Not supported** — redirect to printer panel or Smart Panel | AUR limitation |
| Nozzle check from PC | **Not supported** — redirect to printer panel or Smart Panel | AUR limitation |

## Execution Steps

### 1. Diagnose (first interaction in a session, or when something fails)

```bash
references/diagnose-environment.sh
```

Confirms:
- `lpstat -p EPSON_XP-211_214_216_Series` shows queue active
- `scanimage -L` lists `epson2:net:192.168.1.41`
- `systemctl is-active ecbd` returns `active`
- `getent hosts EPSONDCDFC5.local` resolves to `192.168.1.41`

### 2. Confirm scope

Print: file path, copies, color/B&N, media, quality.
Scan: output path, format, resolution, color/grayscale, mode.
State: nothing — just run the command.

### 3. Build command

Examples:

```bash
# Print a PDF in color, default quality, 1 copy
lp -d EPSON_XP-211_214_216_Series doc.pdf

# Print 2 copies in draft B&N
lp -d EPSON_XP-211_214_216_Series -n 2 -o print-color-mode=monochrome -o PrintQuality=Draft doc.pdf

# Scan to PNG 300 DPI color
scanimage -d epson2:net:192.168.1.41 --format png --resolution 300 > /tmp/scan.png

# Scan to PDF (single page)
scanimage -d epson2:net:192.168.1.41 --format png --resolution 300 > /tmp/page.png && \
  img2pdf /tmp/page.png -o /tmp/scan.pdf
```

### 4. Show + wait for OK + execute

For anything non-trivial, paste the command in a fenced block with one line of intent. Wait for "dale" / "sí" / "ejecutá".

### 5. Report

Per the Output Contract below.

## Output Contract

Return after each action:

- **Print job**: ID, state (`pending` / `completed`), bytes, timestamp; if completed, optional `lpstat -W completed -o` to confirm.
- **Scan job**: file path, size, dimensions (via `file` or `identify`), confirmation that scan completed without backend error.
- **State query**: queue name, state, driver PPD, scanner backend, daemon state, IP/hostname.
- **Cancellation**: pre-cancel job list, post-cancel job list (should be empty).
- **Failure**: which check failed (CUPS / SANE / daemon / mDNS) and one troubleshooting pointer.
- **Out-of-scope request** (ink levels, head cleaning from PC): one sentence redirecting to Epson Smart Panel app or printer panel — do not propose workarounds.

## References

- `references/diagnose-environment.sh` — one-shot environment probe (CUPS, SANE, ecbd, mDNS)
- `references/printer-options.md` — full PPD option reference for `epson-inkjet-printer-201304w`
- `references/sane-options.md` — `scanimage` options for `epson2:net:192.168.1.41`
- `references/troubleshooting.md` — common failures and fixes
- `references/network-services.md` — mDNS/avahi, ports, firewall context
- `assets/imprimir` — wrapper around `lp` with safe defaults
- `assets/escanear` — wrapper around `scanimage` with safe defaults
- `assets/estado` — combined printer+scanner+daemon state
- `assets/cola` — print queue inspection (lpq-like)
