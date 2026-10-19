# Troubleshooting — Epson XP-211 WiFi workflow

Run `references/diagnose-environment.sh` first. It separates failures into CUPS, PPD, SANE, ecbd, mDNS.

## "Scanner not detected" / `scanimage -L` is empty

1. **Verify mDNS resolves**:
   ```bash
   getent hosts EPSONDCDFC5.local
   # Should return 192.168.1.41
   ```
   If empty:
   - Is the printer powered on and WiFi LED solid?
   - `ping 192.168.1.41` from this PC — does it respond?
   - `avahi-browse -art | grep -i epson` — does it list the device?

2. **Verify `epson2` backend has the IP in its config**:
   ```bash
   grep -v '^#' /etc/sane.d/epson2.conf | grep -E 'net|autodiscovery'
   # Should show:
   #   net autodiscovery
   #   net 192.168.1.41
   ```
   If missing, add:
   ```bash
   echo "net 192.168.1.41" | sudo tee -a /etc/sane.d/epson2.conf
   ```

3. **Usb issue? SANE expects epson2 net, not epson**:
   - The legacy backend `epson` does NOT support network.
   - Only `epson2` and `epsonds` support network.

## "Printer queue not found" / `lpstat -p` empty

1. **Check if the queue was deleted**:
   ```bash
   lpstat -p
   ```
   If empty, re-add it:
   ```bash
   sudo lpadmin -p EPSON_XP-211_214_216_Series -E \
     -v "dnssd://EPSON%20XP-211%20214%20216%20Series._pdl-datastream._tcp.local/" \
     -P /usr/share/cups/model/epson-inkjet-printer-201304w/EPSON_XP_211_214_216.ppd \
     -D "Epson XP-211 214 216 (driver nativo 201304w)" \
     -L "Oficina"
   sudo cupsenable EPSON_XP-211_214_216_Series
   sudo cupsaccept EPSON_XP-211_214_216_Series
   ```

2. **Wrong PPD selected** (queue exists but uses Generic PDF):
   ```bash
   lpoptions -p EPSON_XP-211_214_216_Series | grep -o 'printer-make-and-model=.*'
   ```
   If it does NOT say `epson-inkjet-printer 1.0.1-1`, reinstall the queue as above.

## Print job stuck in queue

```bash
lpstat -o
# See the stuck job, e.g. EPSON_XP-211_214_216_Series-12
cancel EPSON_XP-211_214_216_Series-12
```

If `cancel` doesn't work, restart the CUPS scheduler:
```bash
sudo systemctl restart cups
```

## Scan fails with I/O error

This is typically a transient network drop:
```bash
# Retry
scanimage -d epson2:net:192.168.1.41 --format png --resolution 150 > retry.png
```

If persistent:
- Check WiFi signal on the printer
- Power-cycle the printer (off, wait 10s, on)
- Verify `ping 192.168.1.41` is stable (no packet loss)

## avahi / mDNS broken

If `EPSONDCDFC5.local` does not resolve but `192.168.1.41` does:
```bash
systemctl status avahi-daemon
sudo systemctl --now enable avahi-daemon
```

If both fail:
- The PC's firewall may block UDP 5353 (mDNS). CachyOS default is open.
- The router may be blocking multicast between WiFi clients — try `ping 192.168.1.41` to verify direct reachability.

## "epson-printer-utility" doesn't see the printer

**This is expected.** The AUR package `epson-printer-utility` installs `ecbd` 1.3.1 which only discovers USB printers (no `ekpnet` module).

Workarounds:
- **Epson Smart Panel** (Android/iOS): shows ink levels, performs head cleaning, scans to mobile. Free, official.
- **Printer's physical panel**: Setup → Maintenance → Nozzle Check / Head Cleaning / Ink Levels.
- **Web panel** (limited): `http://192.168.1.41/` — only shows the model name on XP-211.
- **Build from official `.deb`**: low ROI, not recommended.

Do NOT spend time debugging ecbd's lack of network discovery — it is a known AUR limitation.

## Color prints come out wrong / inverted

Check default:
```bash
lpoptions -p EPSON_XP-211_214_216_Series | grep -o 'print-color-mode=.*'
```

Should be `color`. If stuck on `monochrome`:
```bash
lpoptions -p EPSON_XP-211_214_216_Series -o print-color-mode=color
```

## Head cleaning needed (ink streaks on print)

You cannot trigger this from PC over WiFi with the current setup. Three options:
1. Printer panel: Ink button → confirm head cleaning
2. Epson Smart Panel mobile app
3. (Last resort) Connect USB and use `epson-printer-utility` GUI
