#!/bin/bash
# Flashes the target image over USB DFU. Reads the board and the vehicle
# file from .env, overridden by .env.override. The board enters DFU with its
# boot button held at power-up.
exec >&2
set -a
[ -f .env ] && . ./.env
[ -f .env.override ] && . ./.env.override
set +a
BOARD="${ANTILOCK_BOARD:?ANTILOCK_BOARD unset}"
VEHICLE="${ANTILOCK_VEHICLE:?ANTILOCK_VEHICLE unset}"
IMAGE="targets/$BOARD/bin/antilock.bin"
python3 tools/gen-vehicle.py "$VEHICLE" --check || exit 1
if [ ! -f "$IMAGE" ]; then
    echo "flash: no image at $IMAGE for board $BOARD; the target crate is roadmap Phase 1"
    exit 1
fi
"${ANTILOCK_FLASH_TOOL:-dfu-util}" -a 0 -s 0x08000000:leave -D "$IMAGE"
