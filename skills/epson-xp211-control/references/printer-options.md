# PPD options — `epson-inkjet-printer-201304w`

Source PPD: `/etc/cups/ppd/EPSON_XP-211_214_216_Series.ppd`
Source model: `Epson XP-211 214 216 Series - epson-inkjet-printer 1.0.1-1 (Seiko Epson Corporation)`

## How to set options

Per-job (one-off):
```bash
lp -d EPSON_XP-211_214_216_Series -o <Option>=<Value> <file>
```

Persistent default (survives across jobs):
```bash
lpoptions -p EPSON_XP-211_214_216_Series -o <Option>=<Value>
```

Inspect current options:
```bash
lpoptions -p EPSON_XP-211_214_216_Series
```

Reset to factory:
```bash
lpoptions -p EPSON_XP-211_214_216_Series -o <Option>=<DefaultValue>
```

## Common options

| Option | Values | Default | Use case |
| --- | --- | --- | --- |
| `print-color-mode` | `color`, `monochrome` | `color` | Force B&N to save color ink |
| `PrintQuality` | `Draft`, `Standard`, `High` | `Standard` | Draft is faster + saves ink; High for photos |
| `MediaType` | `PlainPaper`, `PhotoPaper`, `PremiumPhoto`, `Envelope`, etc. | `PlainPaper` | Match the paper in the tray |
| `PageSize` | `A4`, `Letter`, `Legal`, `B5`, `A5`, `A6`, `B4` | `A4` | Match the paper |
| `InputSlot` | `Rear`, `Front` | depends | Tray selection |
| `sides` | `one-sided`, `two-sided-long-edge`, `two-sided-short-edge` | `one-sided` | XP-211 has no auto-duplex — long-edge flips along A4 long side |

## Print quality cheat sheet

| Goal | Combo |
| --- | --- |
| Fastest draft B&N (save ink) | `print-color-mode=monochrome PrintQuality=Draft MediaType=PlainPaper` |
| Standard color document | (defaults) |
| Photo print on photo paper | `PrintQuality=High MediaType=PremiumPhoto` |
| Draft for review | `PrintQuality=Draft` |
| Envelope | `MediaType=Envelope PageSize=Envelope` |

## PPD inspection

List all available options and their current/default values:
```bash
grep -E '^\*OpenUI\|^\*Default' /etc/cups/ppd/EPSON_XP-211_214_216_Series.ppd | head -50
```

This is useful when an option name in `lp` doesn't seem to take effect — the PPD is the source of truth for valid keys.
