#!/bin/bash
# SPARK proof gate over the core. Counts unproved checks and pragma Assume
# occurrences on every run, so a weakened claim is visible immediately.
exec >&2
if ! command -v alr >/dev/null 2>&1; then
    echo "alr (Alire) not found - skipping SPARK proofs"
    [ -n "${3:-}" ] && touch "$3"
    exit 0
fi
cd core || exit 1
# Regenerate the crate configuration so the proof runs under the development
# profile whatever a dependent crate's build left behind.
alr -n build --stop-after=generation >/dev/null 2>&1
echo "Running SPARK proofs..."
# PROVE_JOBS caps the prover parallelism on hosts that share their memory; the default
# uses every core. PROVE_SWITCHES adds switches after the project file's. PROVE_UNITS
# names the source files to analyze, one -u each; unset, the whole core is analyzed.
UNIT_ARGS=""
for unit in ${PROVE_UNITS:-}; do UNIT_ARGS="$UNIT_ARGS -u $unit"; done
[ -n "$UNIT_ARGS" ] && echo "Units:${PROVE_UNITS// / }" | tr ' ' '\n' | sed '1!s/^/  /'
set -o pipefail
PROVE_OUT=$(alr -n exec -- gnatprove -P antilock_core.gpr -j"${PROVE_JOBS:-0}" ${PROVE_SWITCHES:-} $UNIT_ARGS --output=oneline 2>&1 | tee >(cat >&2); exit "${PIPESTATUS[0]}")
EXIT_CODE=$?
# A unit that fails to compile is dropped from the analysis without a nonzero
# exit, so any error line fails the gate.
if [ $EXIT_CODE -eq 0 ] && printf '%s\n' "$PROVE_OUT" | grep -q ': error: '; then
    EXIT_CODE=1
fi
if [ $EXIT_CODE -ne 0 ]; then
    echo "=========================================="
    echo "SPARK proofs: gnatprove FAILED (exit $EXIT_CODE)"
    echo "  (any summary on disk is from a previous run and is not evidence)"
    echo "=========================================="
    exit $EXIT_CODE
fi
SUMMARY=$(printf '%s\n' "$PROVE_OUT" | sed -n 's/^Summary logged in //p' | tail -1)
[ -z "$SUMMARY" ] && SUMMARY=obj/development/gnatprove/gnatprove.out
echo "=========================================="
if [ -f "$SUMMARY" ]; then
    TOTAL=$(awk '/^Total/ {print $2; exit}' "$SUMMARY")
    UNPROVED=$(awk '/^Total/ {print ($NF == "." ? 0 : $(NF - 1)); exit}' "$SUMMARY")
    if [ "$UNPROVED" = "0" ]; then
        echo "SPARK proofs: core 100% proved (${TOTAL:-?} checks)"
    else
        echo "SPARK proofs: $UNPROVED of ${TOTAL:-?} checks UNPROVED"
        exit 1
    fi
    ASSUMES=$(grep -h "pragma Assume" src/*.adb src/*.ads 2>/dev/null | wc -l)
    JUSTIFIED=$(grep -h "pragma Annotate (GNATprove" src/*.adb src/*.ads 2>/dev/null | wc -l)
    OFF=$(grep -l "SPARK_Mode => Off" src/*.adb 2>/dev/null | wc -l)
    echo "  ($ASSUMES pragma Assume, $JUSTIFIED justified check(s), $OFF body(ies) outside SPARK)"
else
    echo "Summary file not found: $SUMMARY"
    exit 1
fi
echo "=========================================="
[ -n "${3:-}" ] && touch "../$3"
exit 0
