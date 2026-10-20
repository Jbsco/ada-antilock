#!/bin/bash
# Scenario gate: the controller stops the plant model within the limits on
# every surface, with the example vehicle generated into the tests crate.
exec >&2
if ! command -v alr >/dev/null 2>&1; then
    echo "test: alr not found - skipping scenario check"
    [ -n "${3:-}" ] && touch "$3"
    exit 0
fi
mkdir -p tests/generated tests/out
python3 tools/gen-vehicle.py params/vehicle.example.yaml tests/generated/antilock-vehicle.ads || exit 1
cd tests || exit 1
alr -n build >/dev/null 2>&1 || { alr -n build; exit 1; }
./bin/scenario_check || exit 1
[ -n "${3:-}" ] && touch "../$3"
exit 0
