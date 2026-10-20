# Parameters

`Antilock.Parameters.Set` contains every vehicle and tuning value the core reads. A vehicle
file supplies them in YAML and `tools/gen-vehicle.py` writes the `Antilock.Vehicle`
package the target build compiles in (D6). The generator reads the ranges and defaults
from `core/src/antilock-parameters.ads`, so this page describes them and that file
defines them.

## The vehicle file

Keys are the field names in lower case and may sit under any heading; the generator
flattens the headings. A key left out takes the default. Values are integers, or `true`
and `false` for `rear_axle_combined`. The `maps` key contains a `default` entry and
numbered entries `1` to `11` that override single fields of one map.

    vehicle:
      teeth: 48
      circumference_mm: 2000
      rear_axle_combined: false
    maps:
      default: {decel_threshold: 12000, slip_release: 200, slip_recover: 80, reaccel_threshold: 4000}
      1: {slip_release: 120, slip_recover: 50}

Generate, or check without writing:

    python3 tools/gen-vehicle.py vehicle.yaml antilock-vehicle.ads
    python3 tools/gen-vehicle.py vehicle.yaml --check

The generator refuses a value outside its range, an unknown key, and a set that breaks
a condition of `Valid`. The generated package asserts `Valid` again at elaboration.

## Fields

Units: mm, mm/s, mm/s2 (forward positive), kPa, us, mV.

| Field | Range | Default | Meaning |
|---|---|---|---|
| `teeth` | 12 .. 200 | 48 | Encoder teeth per wheel revolution |
| `circumference_mm` | 500 .. 5 000 | 2 000 | Rolling circumference of the tire |
| `loop_period_us` | 1 000 .. 20 000 | 5 000 | Period at which the board calls `Step` |
| `speed_floor` | 500 .. 10 000 | 1 500 | No intervention below this reference speed |
| `max_vehicle_decel` | 2 000 .. 20 000 | 12 000 | Cap on the measured deceleration the reference ramp follows |
| `decel_margin` | 0 .. 5 000 | 1 000 | Added to the measured deceleration in the ramp |
| `release_pulse_us` | 1 000 .. 50 000 | 8 000 | Length of one outlet pulse |
| `hold_max_us` | 10 000 .. 1 000 000 | 150 000 | A hold without release or recovery ends in build after this |
| `build_pulse_first_us` | 1 000 .. 100 000 | 20 000 | First inlet pulse of a build |
| `build_pulse_us` | 1 000 .. 50 000 | 5 000 | Later inlet pulses of a build |
| `build_pause_us` | 1 000 .. 100 000 | 20 000 | Pause between inlet pulses of a build |
| `build_max_us` | 10 000 .. 5 000 000 | 500 000 | A build without a new hold ends passive after this |
| `release_budget_us` | 10 000 .. 1 000 000 | 300 000 | Release time allowed per window |
| `release_window_us` | 100 000 .. 10 000 000 | 1 000 000 | Length of the budget window |
| `pulse_timeout_us` | 10 000 .. 2 000 000 | 500 000 | An edge older than this counts as missing |
| `dropout_grace_us` | 10 000 .. 5 000 000 | 1 000 000 | Missing edges or a pedal mismatch latch a fault after this |
| `pump_run_on_us` | 0 .. 5 000 000 | 1 000 000 | The pump keeps running this long after a release |
| `pedal_pressure_threshold` | 0 .. 10 000 | 300 | Pressure that, with the switch, counts as the pedal applied |
| `supply_min_mv` | 6 000 .. 20 000 | 9 000 | Below this supply the controller inhibits |
| `supply_max_mv` | 10 000 .. 40 000 | 16 500 | Above this supply the controller inhibits |
| `rear_axle_combined` | boolean | false | Three-channel unit: the rear left sample and channel serve both rear wheels |

Each of the eleven maps contains:

| Field | Range | Default | Meaning |
|---|---|---|---|
| `decel_threshold` | 1 000 .. 200 000 | 12 000 | Wheel deceleration that opens the hold phase |
| `slip_release` | 50 .. 900 | 200 | Slip, in permille of the reference, that opens the release phase |
| `slip_recover` | 10 .. 500 | 80 | Slip at or below which a hold ends in build |
| `reaccel_threshold` | 500 .. 100 000 | 4 000 | Wheel acceleration that ends a release or a hold |

## Conditions between fields

`Antilock.Parameters.Valid` requires, and the generator checks:

- `loop_period_us <= release_pulse_us <= release_budget_us <= release_window_us`
- `loop_period_us <= build_pulse_us` and `loop_period_us <= build_pause_us`
- `supply_min_mv < supply_max_mv`
- `slip_recover < slip_release` in every map
