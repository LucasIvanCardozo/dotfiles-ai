---
name: math-calc
description: Compute arithmetic, algebra, calculus, statistics and matrix math with a deterministic CLI instead of guessing. Use whenever a number must be calculated, verified, rounded, compared or reproduced - percentages, growth rates, unit-free numeric results, derivatives, integrals, equation solving, matrix determinants, descriptive statistics - or when a figure the user expects to be exact has to be produced or checked.
compatibility: "Linux/macOS with python3. Optional: sympy (exact/symbolic math) and bc (arbitrary precision arithmetic)."
---

# math-calc

A single deterministic CLI for every calculation. It exists so that numeric
results in an answer are **computed, not recalled**.

## The rule (non-negotiable)

1. **Never compute arithmetic, algebra, statistics or numeric conversions by
   intuition.** If a number appears in your answer, it must come verbatim from
   the stdout of a `calc` call.
2. **One command = one verifiable step.** Do not chain several operations into
   a single expression unless each intermediate value is visible in the output.
3. **Report stdout literally.** Round only when the user asks for it, and say
   that you rounded.
4. **`ERROR:` on stderr means stop and report.** Never silently "fix" the
   expression and retry, and never fill in a plausible result yourself.
5. **Exit code 3 means a dependency is missing.** Report the missing engine and
   the install command from `HINT:`. Do not emulate the engine yourself.
6. **Cross-check before it matters.** For results that drive a decision or a
   formula, confirm with two engines (`exact` vs `eval`) and compare.
7. **Do not use `calc` for non-mathematics**: dates, versions, prices, names,
   file contents. Those are lookups, not calculations.

## The command

Always call it by absolute path, never by bare name:

```bash
~/.agents/skills/math-calc/scripts/calc <mode> <args...>
```

(The skill lives in `~/.agents/skills/math-calc/`, the standard Agent Skills
location, so it is discovered globally by Pi and by any other host that
implements the standard. The path above is the installed location. A bare
`calc` in `PATH` may be a different program - GNU `bc` ships a program called
`calc` on some distributions.)

## Modes

| Mode | Use it for | Example |
|---|---|---|
| `--check` | which engines are available on this machine | `calc --check` |
| `eval <expr>` | fast numeric evaluation | `calc eval "2+3*4"` → `14` |
| `eval --prec N <expr>` | exact decimal arithmetic, N significant digits | `calc eval --prec 20 "0.1+0.2"` → `0.3` |
| `exact <expr>` | exact symbolic result (rationals, radicals, simplification) | `calc exact "sqrt(8)"` → `2*sqrt(2)` |
| `simplify <expr>` | same as `exact`, when the input is already an expression | `calc simplify "x**2+2*x+1"` |
| `diff <expr> <var>` | derivative | `calc diff "x**3 + 2*x" x` → `3*x**2 + 2` |
| `int <expr> <var> [lo] [hi]` | integral, definite when bounds are given | `calc int "x**2" x 0 3` → `9` |
| `solve <equation> [var]` | solve an equation | `calc solve "x**2 - 5*x + 6 = 0" x` → `x = 2` / `x = 3` |
| `stats <list>` | descriptive statistics | `calc stats "1,2,3,4"` |
| `bc <expr>` | raw `bc` language (base conversion, `scale`, `ibase`/`obase`) | `calc bc "scale=4; 355/113"` |
| `python <code>` | escape hatch for numpy / scipy / pandas | `calc python "import numpy as np; print(round(np.linalg.det([[1,2],[3,4]]), 10))"` |

`exact` accepts SymPy syntax, including `Matrix(...)`:
`calc exact "det(Matrix([[1,2],[3,4]]))"` → `-2`.

## Output contract

- **stdout**: the result only. ASCII, decimal point, one value per line. No
  banners, no colours, no units, no prose.
- **stderr**: `ERROR: <message>` and, when useful, `HINT: <install command>`.
- **exit code**: `0` ok, `2` expression or domain error, `3` missing
  dependency, `4` internal error.

Never treat exit code 0 as "the answer is right" - it only means the
expression was evaluated.

## Recipes

**Plain arithmetic**

```bash
calc eval "1250 * 0.19"          # 237.5
calc eval --prec 20 "0.1+0.2"    # 0.3
```

**Exact value first, decimal when the user wants a number**

```bash
calc exact "pi*3.5**2"   # 49*pi/4
calc eval  "pi*3.5**2"   # 38.4845100065
```

**Growth, percentages, discounting** - express it as one explicit expression
and let the engine do it:

```bash
calc eval "(1+0.08)**5"                # compound growth
calc eval "1000 * (1 - 0.21)"           # discount
calc eval "floor(12.25*pi/0.04)"        # how many whole units fit
```

**Symbolic work**

```bash
calc diff "x**3 + 2*x" x
calc int  "x**2" x 0 3
calc solve "x**2 - 5*x + 6 = 0" x
```

**Cross-check a result that matters**

```bash
calc exact "1/3 + 1/6"   # 1/2      (exact)
calc eval  "1/3 + 1/6"   # 0.5      (numeric - must agree)
```

**Statistics over a sample**

```bash
calc stats "12,15,15,18,22"    # count, mean, median, stdev, variance, min, max
```

## Bootstrap: the machine may not have the engines

Run this first on an unfamiliar machine, or after an `ERROR:` that mentions a
missing engine:

```bash
calc --check
```

It prints one line per engine. `MISSING` means the mode that needs it will
exit with code 3.

Install what is missing (ask the user before installing anything):

```bash
# Arch / CachyOS
sudo pacman -S bc python-sympy

# Debian / Ubuntu
sudo apt install bc python3-sympy

# any distro, no root: a private venv the wrapper picks up automatically
uv venv ~/.local/share/math-calc-venv
uv pip install --python ~/.local/share/math-calc-venv/bin/python sympy
```

`bc` is optional (only the `bc` mode needs it). `sympy` is optional (only the
`exact`, `simplify`, `diff`, `int` and `solve` modes need it).

If an engine is missing and the user does not want to install it, say so
explicitly and offer the mode that still works: `eval` and `stats` need
nothing beyond `python3`.

## Limits

- `eval` is float64 by default (12 significant digits shown). Use `--prec` for
  exact decimals, `exact` for symbolic results.
- `eval` supports arithmetic, whitelisted functions and the constants `pi`,
  `e`, `tau`. It has no variables and no lists.
- `bc`'s `scale` counts digits **after** the decimal point, not significant
  digits. `--prec` counts **significant digits**. Do not mix the two.
- Unit conversion is not part of this version.
- `python` runs arbitrary code. Use it only for libraries `calc` does not
  cover, and keep it short. numpy results carry float noise
  (`-2.0000000000000004`): round them explicitly inside the snippet.

## Reference

`references/engines.md` - engine matrix, numeric semantics, error catalogue and
troubleshooting.
