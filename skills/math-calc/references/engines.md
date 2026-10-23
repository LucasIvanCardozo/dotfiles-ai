# engines, semantics and troubleshooting

## Engine matrix

| Engine | Backed by | Needed for | Missing means |
|---|---|---|---|
| `eval` (float) | python3 stdlib (`math`) | fast numeric evaluation | never missing: python3 is the requirement |
| `eval --prec N` | python3 stdlib (`decimal`) | exact decimal arithmetic | never missing |
| `stats` | python3 stdlib (`statistics`) | descriptive statistics | never missing |
| `python` | python3 subprocess | numpy / scipy / pandas escape hatch | never missing (libraries may be) |
| `exact`, `simplify`, `diff`, `int`, `solve` | sympy | symbolic / exact math | exit code 3 + install hint |
| `bc` | GNU bc | raw bc language, base conversion | exit code 3 + install hint |

`calc --check` prints the live state of each engine:

```
wrapper ~/.agents/skills/math-calc/scripts/calc
python  3.14.8  /usr/bin/python3
sympy   OK  1.14.0
bc      OK  bc 1.08.2
numpy   OK  2.5.4
```

The wrapper picks the first interpreter that can import sympy, in this order:

1. `$MATH_CALC_PYTHON` (explicit override)
2. the venv bundled with the skill: `<skill>/.venv/bin/python`
3. `~/.local/share/math-calc-venv/bin/python`
4. the interpreter running the script

So a bundled or user-created venv works without any system change. Setting
`MATH_CALC_NO_SYMPY=1` simulates a machine without sympy and is used by the
selftest to check the missing-dependency contract.

## Numeric semantics

| Situation | Mode | Result |
|---|---|---|
| `2+3*4` | `eval` | `14` (float64, printed with 12 significant digits) |
| `0.1+0.2` | `eval` | `0.3` (rounded for display; the binary float is 0.30000000000000004) |
| `0.1+0.2` | `eval --prec 20` | `0.3` (exact decimal arithmetic) |
| `1/3` | `eval` | `0.333333333333` (12 significant digits) |
| `1/3` | `eval --prec 10` | `0.3333333333` (10 significant digits) |
| `1/3` | `exact` | `1/3` (exact rational) |
| `sqrt(8)` | `exact` | `2*sqrt(2)` |
| `355/113` | `bc "scale=4; 355/113"` | `3.1415` (scale = digits **after** the point) |
| `355/113` | `eval --prec 12` | `3.14159292035` (prec = significant digits) |

`bc` and `--prec` have different scale semantics. Pick one; do not convert
between them by hand.

## Error catalogue

| stderr | Exit | Meaning | Response |
|---|---|---|---|
| `ERROR: division by zero` | 2 | the expression is undefined | report it; do not guess a value |
| `ERROR: unknown function: X` | 2 | `X` is not in the whitelist | use the documented function list, or `exact` with SymPy syntax |
| `ERROR: unknown name: X` | 2 | only `pi`, `e`, `tau` are predefined | define the value explicitly in the expression |
| `ERROR: unsupported call form` | 2 | only plain `f(x)` calls, no attribute access | use `python` mode for anything else |
| `ERROR: cannot parse expression` | 2 | SymPy could not parse it | fix the syntax; `exact` accepts SymPy syntax, not shell syntax |
| `ERROR: sympy is required ...` | 3 | sympy missing | report the `HINT:` install command |
| `ERROR: bc is required ...` | 3 | bc missing | report the `HINT:` install command |
| `ERROR: calculation exceeded 20s` | 2 | the symbolic step was too slow | split the problem, or use `eval` |

## Output format rules

- The result is on stdout, one value per line, ASCII only, decimal point.
- `solve` prints one `var = value` line per solution.
- `stats` prints `label: value` lines in this order: count, mean, median,
  stdev (sample), variance (sample), min, max.
- `exact` prints SymPy's canonical form: `2*sqrt(2)`, `49*pi/4`, `1/2`.
- There is no unit support in this version: the engine returns numbers only.

## Troubleshooting

**`calc` is not found**
Use the absolute path. `PATH` may not include the skill directory, and some
distributions ship a different program called `calc` (GNU `bc` builds one;
Arch and Debian do not install it, but other systems do).

**`sympy` missing although it was installed**
The wrapper prefers the bundled venv. Either install it system-wide and remove
the bundled venv (`rm -rf <skill>/.venv`), or point the wrapper at the system
interpreter with `MATH_CALC_PYTHON=/usr/bin/python3`.

**A result differs between `exact` and `eval`**
`exact` is symbolic, `eval` is float64. If they disagree, the expression is
ill-conditioned (catastrophic cancellation) or `eval` lost precision. Use
`--prec` with more digits, or restructure the expression.

**Symbolic mode is slow**
`simplify` is the expensive step. Use `exact` on already-simple input, or
`eval` when only a number is needed.

## Extending this skill

Unit conversion is deliberately **not** part of this skill. `qalc` was evaluated
and rejected: it prints a locale decimal separator (`,` instead of `.`), it
mis-parses unit names (`GiB` becomes giga-inch-bit) and several functions do
not evaluate in command mode. If units are ever needed, use one of these
instead, in increasing order of effort:

1. **The `python` escape hatch with `pint`** - no wrapper change at all:
   `calc python "import pint; print(pint.Quantity('5 km').to('m/s'))"`.
2. **A built-in conversion table** in the wrapper - a fixed, audited subset
   (SI prefixes, length, mass, time, speed, temperature, data) with explicit
   factors. Deterministic, no third-party dependency, but every unit has to be
   added by hand.
3. **A dedicated library** - `pint` (`python-pint`) or `chempy`, imported lazily
   the way `sympy` is today, exposing a `units` mode.

Other engines, all available as pacman packages, if a task outgrows the current
modes:

- `pari` - number theory (fast).
- `maxima` - full classic CAS.
- `sagemath` - everything, Python-based, large install.
