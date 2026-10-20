# ada-antilock

[![SPARK Proofs](https://github.com/Jbsco/ada-antilock/actions/workflows/prove.yml/badge.svg)](https://github.com/Jbsco/ada-antilock/actions/workflows/prove.yml)
[![Scenario Checks](https://github.com/Jbsco/ada-antilock/actions/workflows/test.yml/badge.svg)](https://github.com/Jbsco/ada-antilock/actions/workflows/test.yml)
[![Style](https://github.com/Jbsco/ada-antilock/actions/workflows/style.yml/badge.svg)](https://github.com/Jbsco/ada-antilock/actions/workflows/style.yml)

An anti-lock brake controller in SPARK and Ada, built as a library: a vehicle configures
it from a vehicle file and runs it on an STM32F4 flight controller board, driving the
valves and the pump of a hydraulic unit with two on/off valves per wheel. The core is
proved: no outlet opens on a wheel that is not slipping past its threshold, no release
pulse outlasts its bound or its budget, nothing is energized without the pedal, below the
speed floor, with the map off, outside the supply range, with a sensor down or after a
fault, and the pump runs whenever an outlet is open. The de-energized unit is the plain
hydraulic path from the pedal to the calipers, and the controller only ever modulates
below the pedal's pressure.

The repository follows the conventions of [adaflight](https://github.com/Jbsco/adaflight):
Alire crates, a proved core beside a host test crate, one-line gates, and a design ledger.

## Contents

- [Status](#status)
- [Repository layout](#repository-layout)
- [Configuration](#configuration)
- [Development](#development)
- [Safety model](#safety-model)
- [Verification policy](#verification-policy)
- [License](#license)

## Status

The core contains:

<details>
<summary><b>Kinematics</b> (2)</summary>

- integer kinematic units, wheel speed from tooth-edge periods with an aging bound, acceleration
  and slip
- vehicle reference speed with its ramp from the accelerometer

</details>

<details>
<summary><b>Control</b> (2)</summary>

- per-wheel cycle: passive, hold, release in bounded pulses on a budget, build in pulses, with
  thresholds of eleven maps and an off position
- four-wheel controller with fault monitor, enable conditions, valve relay, pump and warning lamp,
  with a three-channel option for one rear sensor

</details>

<details>
<summary><b>Configuration</b> (1)</summary>

- parameter set every vehicle file fills, with ranges and conditions between fields

</details>

The state of `main`:

- Core proves at level 2: every check proved, no `pragma Assume`, no justified suppression
  (`gnatprove` 16.1.0).
- Scenario gate holds on the plant model: braking from 80 km/h with the map on against the map
  off, on dry asphalt 29.9 m against 33.8 m locked, wet asphalt 36.5 m against 42.1 m, snow
  140.2 m against 192.6 m, a split surface 32.8 m against 37.5 m, with no wheel locked longer
  than 0.3 s on those four and 0.49 s on snow; on ice neither run stops within the 20 s window
  and no wheel locks with the map on.
- No target builds yet. `docs/boards/clracing-f4s.md` contains the pin plan of the first board
  and `flash.do` the DFU recipe; `ROADMAP.md` has the phases.

## Repository layout

| Path | Contents |
|---|---|
| `core/` | SPARK library crate `antilock_core`: the proved, hardware-independent core |
| `tests/` | Host crate `antilock_tests`: the plant model and the scenario checker |
| `tools/` | The vehicle generator, the markdown rendering check, the changed-units selection |
| `params/` | The example vehicle file |
| `docs/` | The safety case, the hardware notes, the parameter reference, the board notes |
| `style.do`, `test.do`, `prove.do`, `verify.do`, `flash.do` | The gates and the flash recipe, runnable with `bash` or `redo` |
| `DESIGN.md` | Numbered design decisions with their reasons |
| `ROADMAP.md` | Phases and open questions |

## Configuration

A vehicle keeps its parameters in a YAML file in its own repository and names it in
`.env.override`, which replaces the tracked defaults of `.env`:

    ANTILOCK_BOARD=clracing_f4s
    ANTILOCK_VEHICLE=../my-vehicle/antilock-vehicle.yaml

`tools/gen-vehicle.py` turns the file into the `Antilock.Vehicle` package a target build
compiles in, checking every value against the range the core declares and the conditions
between fields; `docs/parameters.md` lists them. The library never contains a vehicle:
its name, its tire, its unit and its tuning live in that file.

    python3 tools/gen-vehicle.py params/vehicle.example.yaml --check

## Development

[Alire](https://alire.ada.dev) provides the compiler and the prover; PyYAML provides the
generator's parser.

    cd core && alr build                      # build the core
    bash test.do                              # generate the example vehicle, run the scenarios
    bash prove.do                             # SPARK proof of the core
    bash verify.do                            # every gate, cheapest first
    bash flash.do                             # flash the board named in .env over DFU

A change is finished when `verify.do` is green. The scenario traces land in `tests/out`
as CSV, one per run, with the vehicle and wheel speeds, the reference, the pressures,
the phases, the slip and the wheel accelerations per controller step.

## Safety model

`docs/safety-case.md` lists the claims the core proves, the assumptions the board and the
installation have to meet, and the hazards with their mitigations. `docs/hardware.md`
describes the sensors, the hydraulic units the board can drive, the coil drivers, the
valve relay and the supervisor. The non-goals of `DESIGN.md` D2 are enforced: no
stability or traction control, no proportional or three-position valves, no brake by
wire, no vehicle and no drivers in the core. Brake traction at crawl speed and yaw
control are candidates in `ROADMAP.md`, Phases 7 and 8, outside the core until D2 is
amended.

## Verification policy

- Every unit in `core/` is SPARK and proves free of run-time errors and of the
  functional contracts the safety case names, with no `pragma Assume` and no justified
  suppression. `prove.do` prints both counts on every run.
- Every push and pull request proves the whole core, runs the scenarios and the style
  gate. `tools/changed-units.py` selects the units a change touched for a local run.
- The scenario gate holds the stopping distance ratio, the longest wheel lock, the valve
  behaviour below the speed floor and with the map off, and the fault state against
  limits, with the example vehicle. The limits are a regression gate for the cycle, not
  a prediction for a vehicle (`DESIGN.md` D13).
- `style.do` fails on a compile warning, on markdown the local viewer would not render, on
  a local path, on a downstream vehicle's name anywhere, and on a sibling project's name
  outside this file and the design ledger.

## License

GPL-3.0-or-later. See `LICENSE`.
