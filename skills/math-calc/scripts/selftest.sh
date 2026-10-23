#!/usr/bin/env bash
# Selftest for the `calc` wrapper (skill: math-calc).
#
#   bash scripts/selftest.sh
#
# Every case checks a public observable effect: stdout, stderr and exit code.
# Cases whose engine is not installed are reported as SKIP, never as PASS.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CALC="$DIR/calc"
ERR="$(mktemp)"
trap 'rm -f "$ERR"' EXIT

PASS=0
FAIL=0
SKIP=0
FAILED=()

red()   { printf '\033[31m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
yellow(){ printf '\033[33m%s\033[0m' "$1"; }

ok()   { PASS=$((PASS + 1)); printf '  %s %s\n' "$(green ok)" "$1"; }
bad()  {
  FAIL=$((FAIL + 1)); FAILED+=("$1")
  printf '  %s %s\n' "$(red FAIL)" "$1"
  printf '       expected: %s\n' "$2"
  printf '       actual:   %s\n' "$3"
}
skip() { SKIP=$((SKIP + 1)); printf '  %s %s (%s)\n' "$(yellow skip)" "$1" "$2"; }

# --- engine detection -------------------------------------------------------
have_sympy() { "$CALC" --check 2>/dev/null | grep -qE '^sympy +OK'; }
have_bc()    { "$CALC" --check 2>/dev/null | grep -qE '^bc +OK'; }

# --- assertions -------------------------------------------------------------
# expect_out <name> <expected-stdout> <args...>
expect_out() {
  local name="$1" expected="$2"; shift 2
  local out rc
  out="$("$CALC" "$@" 2>"$ERR")"; rc=$?
  if [ "$rc" -ne 0 ]; then
    bad "$name" "exit 0 / stdout: $expected" "exit $rc / stderr: $(cat "$ERR")"
    return
  fi
  if [ "$out" != "$expected" ]; then
    bad "$name" "$expected" "$out"
    return
  fi
  ok "$name"
}

# expect_contains <name> <stdout-substring> <args...>
expect_contains() {
  local name="$1" needle="$2"; shift 2
  local out rc
  out="$("$CALC" "$@" 2>"$ERR")"; rc=$?
  if [ "$rc" -ne 0 ]; then
    bad "$name" "exit 0 / stdout contains: $needle" "exit $rc / stderr: $(cat "$ERR")"
    return
  fi
  case "$out" in
    *"$needle"*) ok "$name" ;;
    *) bad "$name" "stdout contains: $needle" "$out" ;;
  esac
}

# expect_err <name> <expected-exit> <expected-stderr-substring> <args...>
expect_err() {
  local name="$1" want_rc="$2" want_msg="$3"; shift 3
  local out rc
  out="$("$CALC" "$@" 2>"$ERR")"; rc=$?
  if [ "$rc" -ne "$want_rc" ]; then
    bad "$name" "exit $want_rc (stderr contains: $want_msg)" "exit $rc / stderr: $(cat "$ERR")"
    return
  fi
  if ! grep -qF "$want_msg" "$ERR"; then
    bad "$name" "stderr contains: $want_msg" "stderr: $(cat "$ERR")"
    return
  fi
  ok "$name"
}

# expect_err_env <name> <expected-exit> <expected-stderr-substring> <VAR=value> <args...>
expect_err_env() {
  local name="$1" want_rc="$2" want_msg="$3" envassign="$4"; shift 4
  local out rc
  out="$(env "$envassign" "$CALC" "$@" 2>"$ERR")"; rc=$?
  if [ "$rc" -ne "$want_rc" ]; then
    bad "$name" "exit $want_rc (stderr contains: $want_msg)" "exit $rc / stderr: $(cat "$ERR")"
    return
  fi
  if ! grep -qF "$want_msg" "$ERR"; then
    bad "$name" "stderr contains: $want_msg" "stderr: $(cat "$ERR")"
    return
  fi
  ok "$name"
}

echo "selftest: $CALC"

# --- check ------------------------------------------------------------------
expect_contains "check reports wrapper path" "wrapper"  --check
expect_contains "check reports python"        "python" --check
expect_contains "check reports sympy"         "sympy"  --check

# --- eval (float) -----------------------------------------------------------
expect_out "eval precedence"        "14"             eval "2+3*4"
expect_out "eval parentheses"       "20"             eval "(2+3)*4"
expect_out "eval division"          "2.5"            eval "10/4"
expect_out "eval power"             "1024"           eval "2**10"
expect_out "eval sqrt"              "4"              eval "sqrt(16)"
expect_out "eval float noise"       "0.3"            eval "0.1+0.2"
expect_out "eval repeating"         "0.333333333333" eval "1/3"
expect_out "eval modulo"            "1"              eval "7 % 3"
expect_out "eval factorial"         "120"            eval "factorial(5)"
expect_out "eval gcd"               "6"              eval "gcd(12,18)"
expect_out "eval log(e)"            "1"              eval "log(e)"
expect_out "eval pi"                "3.14159265359"  eval "pi"
expect_out "eval hypot"             "5"              eval "hypot(3,4)"
expect_out "eval unary minus"       "-3"             eval "-5+2"

# --- eval (decimal precision) ----------------------------------------------
expect_out "eval prec exact decimal"   "0.3"          eval --prec 20 "0.1+0.2"
expect_out "eval prec repeating"       "0.3333333333" eval --prec 10 "1/3"
expect_out "eval prec rounding"        "0.66667"      eval --prec 5 "2/3"

# --- eval errors ------------------------------------------------------------
expect_err "eval division by zero" 2 "division by zero" eval "1/0"
expect_err "eval unknown function" 2 "unknown function" eval "nosuchfn(1)"
expect_err "eval unknown name"     2 "unknown name"    eval "foo"
expect_err "eval rejects imports"  2 "unsupported"     eval "__import__('os').system('ls')"

# --- sympy-backed modes -----------------------------------------------------
if have_sympy; then
  expect_out "exact surd"            "2*sqrt(2)" exact "sqrt(8)"
  expect_out "exact rational"        "1/2"       exact "1/3 + 1/6"
  expect_out "exact fraction"        "1/2"       exact "2/4"
  expect_out "exact pi with decimal" "49*pi/4"   exact "pi*3.5**2"
  expect_out "exact integer"         "8"         exact "2+2*3"
  expect_out "diff power"            "3*x**2 + 2" diff "x**3 + 2*x" x
  expect_out "diff sin"              "cos(x)"    diff "sin(x)" x
  expect_out "integral definite"     "9"         int "x**2" x 0 3
  expect_out "integral indefinite"   "x**3/3"    int "x**2" x
  expect_out "solve quadratic"       "x = 2
x = 3"                                     solve "x**2 - 5*x + 6 = 0" x
  expect_out "matrix determinant"    "-2"        exact "det(Matrix([[1,2],[3,4]]))"
else
  skip "sympy cases (exact/diff/int/solve/matrix)" "sympy not installed"
fi

# --- stats (stdlib) ---------------------------------------------------------
expect_out "stats summary" "count: 4
mean: 2.5
median: 2.5
stdev: 1.2909944487358056
variance: 1.6666666666666667
min: 1
max: 4" stats "1,2,3,4"

# --- missing dependency contract -------------------------------------------
expect_err_env "exact without sympy exits 3" 3 "sympy" "MATH_CALC_NO_SYMPY=1" exact "1+1"

# --- bc passthrough ---------------------------------------------------------
if have_bc; then
  expect_out "bc scale division" "3.1415" bc "scale=4; 355/113"
else
  skip "bc passthrough" "bc not installed"
fi

# --- python escape hatch ----------------------------------------------------
expect_out "python escape hatch" "6" python "print(2*3)"

# --- summary ----------------------------------------------------------------
echo
echo "passed: $PASS   failed: $FAIL   skipped: $SKIP"
if [ "$FAIL" -ne 0 ]; then
  printf 'failed cases:\n'
  for c in "${FAILED[@]}"; do printf '  - %s\n' "$c"; done
  exit 1
fi
exit 0
