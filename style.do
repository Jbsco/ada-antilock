#!/bin/bash
# Style and hygiene gate: Ada style warnings from a fresh compile, markdown
# that renders in the local viewer, and no local paths, vehicle names or
# private material.
exec >&2
FAIL=0

echo "== 1/3  Ada style"
if command -v alr >/dev/null 2>&1; then
    mkdir -p tests/generated
    python3 tools/gen-vehicle.py params/vehicle.example.yaml tests/generated/antilock-vehicle.ads >/dev/null || FAIL=1
    for crate in core tests; do
        (cd "$crate" && alr -n clean >/dev/null 2>&1)
        OUT=$(cd "$crate" && alr -n build 2>&1)
        N=$(printf '%s\n' "$OUT" | grep -c '(style)\|warning:')
        if [ "$N" != "0" ]; then
            echo "  $crate: $N style warning(s):"
            printf '%s\n' "$OUT" | grep '(style)\|warning:' | sed 's/^/    /'
            FAIL=1
        else
            echo "  $crate: clean"
        fi
    done
else
    echo "  alr not found - skipped"
fi

echo "== 2/3  Markdown renders in the local viewer"
MD=$(git ls-files '*.md')
if [ -n "$MD" ] && command -v markdown >/dev/null 2>&1; then
    if python3 tools/mdlint.py $MD; then
        echo "  clean"
    else
        FAIL=1
    fi
else
    echo "  markdown renderer not found - skipped"
fi

echo "== 3/3  Content sanitization"
PATHS=$(git ls-files -z | xargs -0 grep -nE '~/|/home/[a-z]+/' 2>/dev/null \
        | grep -v '^style.do:' | grep -v '^.github/workflows/' || true)
if [ -n "$PATHS" ]; then
    echo "  local path reference(s):"
    echo "$PATHS" | sed 's/^/    /'
    FAIL=1
fi
# The library carries no downstream vehicle: a vehicle's name belongs in its own
# repository and its vehicle file.
VEHICLES=$(git ls-files -z | xargs -0 grep -nliE 'wd21|pathfinder|nissan|hardbody' 2>/dev/null \
           | grep -v '^style.do$' || true)
if [ -n "$VEHICLES" ]; then
    echo "  downstream vehicle named in the library:"
    echo "$VEHICLES" | sed 's/^/    /'
    FAIL=1
fi
# The sibling project is named in the README and the design ledger only, and the
# flight firmware whose board maps the board notes cite in those notes as well.
SIBLINGS=$(git ls-files -z | xargs -0 grep -nliE 'adaflight' 2>/dev/null \
           | grep -v '^style.do$' | grep -v '^README.md$' | grep -v '^DESIGN.md$' || true)
FIRMWARE=$(git ls-files -z | xargs -0 grep -nliE 'betaflight' 2>/dev/null \
           | grep -v '^style.do$' | grep -v '^README.md$' | grep -v '^DESIGN.md$' | grep -v '^docs/boards/' || true)
if [ -n "$SIBLINGS$FIRMWARE" ]; then
    echo "  sibling project or flight firmware named outside the README, the design ledger and the board notes:"
    echo "$SIBLINGS$FIRMWARE" | sed 's/^/    /'
    FAIL=1
fi
[ -z "$PATHS$VEHICLES$SIBLINGS$FIRMWARE" ] && echo "  clean"

echo "=========================================="
if [ "$FAIL" != "0" ]; then
    echo "style: FAILED"
    exit 1
fi
echo "style: all checks clean"
echo "=========================================="
[ -n "${3:-}" ] && touch "$3"
exit 0
