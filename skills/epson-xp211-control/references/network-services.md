# Network services — Epson XP-211 WiFi

The printer is **only on WiFi**. This file documents the network surface so you can debug connectivity without guessing.

## Identity

| Field | Value |
| --- | --- |
| IP (IPv4) | `192.168.1.41` |
| Hostname (mDNS) | `EPSONDCDFC5.local` |
| MAC (from avahi) | not tracked |
| Network | `192.168.1.0/24` (your LAN) |

The IP may change if the printer's DHCP lease expires. If `EPSONDCDFC5.local` no longer resolves, run:

```bash
avahi-browse -art | grep -A2 -i epson | grep hostname
```

This re-discovers the current hostname and IP. If the printer has been reassigned a new IP, update `references` and `/etc/sane.d/epson2.conf`:

```bash
# After discovery:
sudo sed -i "s/^net .*/net $(avahi-browse -art | grep -A2 -i epson | grep hostname | awk -F= '{print $2}' | tr -d ' ]')/" /etc/sane.d/epson2.conf
```

(Manual replacement is safer — this is a hint, not a copy-paste.)

## Advertised services (via avahi / mDNS)

Run `avahi-browse -art` and look for entries containing `EPSON`:

| Service type | What it is | Used for |
| --- | --- | --- |
| `_pdl-datastream._tcp` | PDL (Page Description Language) Printer | CUPS printing |
| `_printer._tcp` (UNIX) | LPD/lpr legacy queue | Optional fallback |
| `_scanner._tcp` | Scanner advertisement | SANE autodiscovery |
| `_http._tcp` (Web Site) | Embedded web admin | `http://192.168.1.41/` |

## Open ports on the printer (typical)

| Port | Protocol | Purpose |
| --- | --- | --- |
| 80/tcp | HTTP | Embedded web panel + IPP-Get + SANE-over-HTTP fallback |
| 631/tcp | IPP | Internet Printing Protocol (CUPS uses this) |
| 9100/tcp | RAW/JetDirect | Direct socket printing (legacy) |
| 5353/udp | mDNS | Service announcement (avahi) |
| 1865/tcp | Epson ESC/P-R | Network discovery on some models (XP-211 may not expose) |

Quick reachability check without `nc`:
```bash
timeout 3 bash -c '</dev/tcp/192.168.1.41/631' && echo "IPP OK" || echo "IPP FAIL"
timeout 3 bash -c '</dev/tcp/192.168.1.41/9100' && echo "RAW OK" || echo "RAW FAIL"
timeout 3 bash -c '</dev/tcp/192.168.1.41/5353' && echo "mDNS OK" || echo "mDNS FAIL"
```

## Firewalls

CachyOS defaults (`iptables`/`nftables` typically permissive for LAN) usually allow all of the above. If the printer suddenly becomes unreachable after a system update, check:

```bash
sudo iptables -L -n -v | head -30
sudo nft list ruleset 2>/dev/null | head -30
```

For inter-zone WiFi client isolation, the **router** is the most common culprit. The fix is in the router admin, not on the PC.

## CUPS printer URI

The CUPS queue uses `dnssd`-based discovery (works without static IP):

```
dnssd://EPSON%20XP-211%20214%20216%20Series._pdl-datastream._tcp.local/
```

If you ever need a static IP URI instead (e.g. for environments where mDNS is broken), use:

```
ipp://192.168.1.41:631/ipp/print
socket://192.168.1.41:9100
```

To change:
```bash
sudo lpadmin -p EPSON_XP-211_214_216_Series -v ipp://192.168.1.41:631/ipp/print
```

## SANE scanner URI

SANE uses `epson2:net:192.168.1.41`. Configured statically in `/etc/sane.d/epson2.conf`:

```
net autodiscovery
net 192.168.1.41
```

`net autodiscovery` lets SANE find the scanner via mDNS even if the IP changes (some setups). The explicit `net 192.168.1.41` line is a fallback.
