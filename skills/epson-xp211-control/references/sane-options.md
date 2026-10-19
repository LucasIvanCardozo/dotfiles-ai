# SANE options — `epson2:net:192.168.1.41`

Backend: `epson2` (sane-backends 1.4.0).
Connection: `epson2:net:192.168.1.41` (configured in `/etc/sane.d/epson2.conf`).

## Probe supported options for this device

```bash
scanimage -d epson2:net:192.168.1.41 -A
```

## Common scanimage flags

| Flag | Meaning | Notes |
| --- | --- | --- |
| `-d <device>` | device URI | Always `epson2:net:192.168.1.41` here |
| `--format png\|tiff\|pnm\|jpeg` | output format | PNG for lossless, JPEG for photos, TIFF for archival |
| `--resolution N` | DPI | 150 (draft/photo), 300 (document), 600 (high-detail scan) |
| `-p` | progress to stderr | Useful to see scan progress |
| `-l N -t N -x N -y N` | geometry in mm | `-l` left, `-t` top, `-x` width, `-y` height |
| `--source Flatbed` | scan source | XP-211 only has flatbed (no ADF) |
| `--mode Color\|Gray\|Lineart` | color mode | `Lineart` = 1-bit B&N, `Gray` = 8-bit grayscale |

## Output examples

PNG, A4, 300 DPI, color:
```bash
scanimage -d epson2:net:192.168.1.41 --format png --resolution 300 > scan.png
```

JPEG, A4, 150 DPI, color (smaller file):
```bash
scanimage -d epson2:net:192.168.1.41 --format jpeg --resolution 150 > scan.jpg
```

A5 region only, 600 DPI, grayscale:
```bash
scanimage -d epson2:net:192.168.1.41 \
  --format png --resolution 600 --mode Gray \
  -l 0 -t 0 -x 148 -y 210 > scan_a5.png
```

1-bit B&N for OCR-friendly text scan:
```bash
scanimage -d epson2:net:192.168.1.41 --format png --resolution 300 --mode Lineart > ocr.png
```

## To PDF (single page)

The XP-211 is single-page flatbed. For multipage, use `simple-scan` GUI or loop scans manually:

```bash
scanimage -d epson2:net:192.168.1.41 --format png --resolution 300 > /tmp/p1.png
img2pdf /tmp/p1.png -o /tmp/out.pdf
```

`img2pdf` is preferred over `convert` because it does not re-compress the bitmap (lossless).

## Preview (low-res fast scan)

```bash
scanimage -d epson2:net:192.168.1.41 --format jpeg --resolution 75 > preview.jpg
```
