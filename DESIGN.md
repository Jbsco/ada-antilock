# Design decision ledger

Decisions are dated and numbered. A reversal gets a new entry, never an edit.

## D1. The GPL-3.0-or-later license (2026-10-19)

The library shares its license with [adaflight](https://github.com/Jbsco/adaflight), the
flight controller port in SPARK whose repository conventions this one follows, so that
filters, drivers and board support can move between the two in either direction. A
library with no inherited code could take a permissive license; we chose the copyleft so
that a brake controller derived from this one stays open.

## D2. Scope and non-goals (2026-10-19)

The core computes valve commands for a hydraulic unit with two on/off solenoid valves per
wheel (inlet open and outlet closed when de-energized) and a return pump, from four wheel
speed samples, the longitudinal accelerometer, the pedal pressure and switch, the map
switch and the supply voltage. It runs a bounded slip cycle per wheel and a fault monitor,
and it decides the valve relay, the pump and the warning lamp.

Non-goals, enforced:

- No stability control, traction control or engine torque requests.
- No proportional (linear) valves and no three-position valves; a unit of that kind needs
  a different actuator model.
- No brake-by-wire: the de-energized unit is the hydraulic path from the pedal to the
  calipers, and the controller only modulates below the pedal's pressure.
- No vehicle in the library: a vehicle's parameters arrive through its vehicle file (D6),
  and its name never appears here (D15).
- No board drivers in the core: the target crate reads the sensors and drives the coils.

## D3. Repository layout (2026-10-19)

- `core/` is the SPARK library crate `antilock_core`: hardware independent, proved, no
  platform code.
- `tests/` is the host crate `antilock_tests`: a longitudinal vehicle model and the
  scenario checker, Ada with floating point, outside SPARK.
- `tools/` holds the repository tooling: the vehicle generator and the markdown and
  changed-units checks.
- `params/` holds the example vehicle file. A vehicle keeps its own file in its own
  repository and names it in `.env.override`.
- `docs/` holds the safety case, the hardware notes, the parameter reference and the
  board notes.
- Target crates will sit under `targets/<board>/` as they land.

Each crate is an Alire crate with its own manifest.

## D4. Where SPARK applies (2026-10-19)

Every unit in `core/` is SPARK and proves at level 2 with no `pragma Assume` and no
justified suppression. The proof covers absence of run-time errors (Silver) and the
functional contracts of `docs/safety-case.md`: the valve command follows the phase, a
disabled channel is passive, a release pulse is bounded, release draws on a budget,
release starts only on a slipping wheel, the pump runs with an open outlet, and the
controller energizes nothing without the pedal, below the speed floor, with the map off,
outside the supply range, with a sensor down or after a fault. `prove.do` prints the
assume count on every run. The plant model and the checker are tested, not proved.

## D5. Integer units (2026-10-19)

Speeds are millimetres per second, accelerations millimetres per second squared, slip
permille, pressures kilopascals, durations microseconds, each a range type in
`Antilock.Units`. Intermediate products use 64-bit integers. We chose integers over
floating point because linear integer arithmetic proves at level 2 where floating point
needs bounded subtypes and lemmas, and because 1 mm/s resolves finer than any wheel
sensor. A result that saturates (a speed past 120 m/s, an acceleration past 20 g, a
duration past 2 000 s) states the exact value and the saturated case in its
postcondition, so the bound is proved rather than hidden.

## D6. Vehicle parameters as a generated package (2026-10-19)

`tools/gen-vehicle.py` reads a vehicle YAML file and writes `Antilock.Vehicle`, a package
with one constant of `Antilock.Parameters.Set`. The generator takes every field's range
and default from the Ada specification, so a range exists once; it refuses a value out of
range, an unknown key, and a set that breaks the conditions of
`Antilock.Parameters.Valid`, and the generated package asserts `Valid` again at
elaboration. The core proves for every parameter set that `Valid` admits, so a vehicle
file never changes what is proved. `.env` names the board and the vehicle file for a
build; `.env.override`, untracked, replaces them on one machine.

## D7. The control cycle (2026-10-19)

Each wheel runs the cycle of `Antilock.Channel`: passive, hold when the wheel decelerates
past the map's threshold or slips past the release threshold, release in pulses of
`Release_Pulse_us` while the slip stays past the release threshold without the wheel
re-accelerating and the budget lasts, hold again while the wheel re-accelerates, build
once its slip falls to the recover threshold, as one inlet pulse and then short ones with
pauses, until the wheel decelerates past the threshold again. A hold without recovery or
release lasts at most `Hold_Max_us` and a build at most `Build_Max_us`. Holding through
the recovery matters on ice, where a released wheel takes a second to spin back up: a
release pulse there spends budget without lowering a pressure that is already below the
road's torque, and a build before the recovery locks the wheel again.
The thresholds come from one of eleven maps, selected by a twelve-position switch whose
position 12 is off, the dial convention of the Bosch Motorsport ABS M5, so a driver of
either system meets the same dial.

## D8. The reference speed (2026-10-19)

The vehicle reference is the fastest wheel, held up by a ramp when every wheel falls
faster than the vehicle does: the previous reference less the accelerometer's measured
deceleration, capped at the parameter `Max_Vehicle_Decel`, plus a margin, over one loop
period. A locked four-wheel-drive train can bring all four wheels down together; the ramp
keeps the slip visible for the length of the budget. The ramp follows the measurement
rather than the parameter because on ice the vehicle sheds 0.5 m/s2 while the wheels
stop in a tenth of a second: a ramp at the dry-road parameter would run the reference
down to the speed floor within two seconds and end control with the wheels locked. The
accelerometer is therefore part of the controller, and a board without one reports
`Sensors_OK` false.

## D9. The three-channel layout (2026-10-19)

A hydraulic unit with one rear channel (`Rear_Axle_Combined`) takes the axle's speed
sample as the rear left wheel. The rear left channel drives both rear outputs and the
rear right channel is never stepped. The sensor can then sit at the pinion or the
driveshaft, and the rear logic is select-low by construction.

## D10. Faults, the relay and the supply range (2026-10-19)

A fault latches until `Init`: a wheel without edges while the vehicle moves off the pedal
for longer than the grace period, a sensor the board reports failed, or pedal pressure
without the pedal switch. A fault drops the valve relay, which de-energizes every coil
whatever the commands say, and lights the lamp. The supply range only inhibits control
while it lasts, since the voltage sags during cranking and recovers. A wheel without
edges is counted only off the pedal, because a wheel the driver holds locked stops
emitting edges too.

## D11. The pump policy (2026-10-19)

The pump runs while any channel releases, and for `Pump_Run_On_us` after a release, and
only while the controller is enabled. A release without the pump fills the low-pressure
accumulator and the pedal sinks; a pump without a release does nothing but wear.

## D12. The release budget (2026-10-19)

Each channel may release for `Release_Budget_us` within each fixed window of
`Release_Window_us`, and the budget refills at the window's end. Over any sliding
interval of one window's length the release time is therefore at most twice the budget.
The bound caps what a wrong release can take from the driver: a channel that releases on
a bad signal returns the pedal's pressure after the budget, and the window gives it back.

## D13. The host plant model (2026-10-19)

`tests/` integrates a longitudinal vehicle: four wheels on the Burckhardt tire curve
(dry asphalt, wet asphalt, snow, ice), caliper pressure as a first-order lag toward the
master cylinder with the inlet open and toward zero with the outlet open, tooth-edge
sensors from the wheel angle, and the longitudinal acceleration of the body. The
scenario checker brakes from 80 km/h on each surface and on a split surface, with the
map on and off, and holds the stopping distance ratio, the longest wheel lock, the valve
behaviour below the speed floor and with the map off, and the fault state against
limits. The limits are a regression gate for the cycle and the monitor, not a prediction
for a vehicle: the model has no load transfer, no lateral dynamics and no valve delay.

## D14. The first target (2026-10-19)

The first board is the CLRacing F4S, an STM32F405RGT6 flight controller with an MPU-6000
on SPI, whose pads the pin plan in `docs/boards/clracing-f4s.md` reassigns to four
wheel speed inputs, ten outputs for the coils, the pump and the relay, two pressure
inputs, the map ladder and the pedal switch. The target crate is roadmap Phase 1. The
plan is taken from the CLRACINGF4 target map and has to be confirmed against a resource
dump of the board before the first bench run.

## D15. Sanitization (2026-10-19)

The library names no downstream vehicle anywhere, and names its sibling projects only in
the README and this ledger. `style.do` checks both on every run, together with local
paths.

## D16. Ada language level (2026-10-19)

The sources use the Ada 2012 forms of aggregates and assignment, as adaflight does, so
code moves between the two without edits.
