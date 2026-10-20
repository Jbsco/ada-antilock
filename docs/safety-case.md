# Safety case

The controller sits between the pedal and the calipers of a hydraulic unit whose
de-energized state is the plain hydraulic path. Every hazard below ends in the same
place: the coils off, the pedal connected. This page lists the claims the core proves, the
evidence for each, the argument that connects them, the assumptions the argument rests
on, and the hazards the proof does not reach.

## Claims proved in the core

Every claim is a postcondition in `core/src`, proved by GNATprove at level 2 with no
`pragma Assume` and no justified suppression. `prove.do` re-proves them on every run.

| Claim | Contract | Argument |
|---|---|---|
| A valve command follows its channel's phase, and a passive phase energizes nothing | `Antilock.Channel.Step`, `S.Command = Command_Of (S)` | The command is computed from the phase at the end of every step, by the one expression function the contract names |
| A disabled channel is passive | `Antilock.Channel.Step`, `(if not C.Enabled then S.Current = Passive)` | A step without `Enabled` enters the passive phase before computing its command |
| A release pulse is bounded in time | `Antilock.Channel.Step`, `(if S.Current = Release then S.Time_In_Phase < P.Release_Pulse_us)` | The phase timer advances before the transition check, and the check leaves the release phase at the pulse length |
| The outlet never opens on an exhausted budget, and every release step spends one loop period of it | `Antilock.Channel.Step`, the budget clause | Release is entered and kept only with at least one period of budget left, and the period is subtracted after the transition |
| Release starts only on a wheel slipping past the map's release threshold | `Antilock.Channel.Step`, the slip clause | The only entry to the release phase is from hold, under the slip condition, on the slip computed in the same step |
| The pump is requested whenever an outlet is open | `Antilock.Channel.Step`, `(if S.Current = Release then S.Pump_Request)` | The request is the release phase or the run-on timer |
| A fault latches, drops the relay and lights the lamp | `Antilock.Controller.Step`, the fault clauses | The fault field is written only while it is `None`, and the relay and lamp are computed from it |
| Without the relay nothing is energized and the pump is off | `Antilock.Controller.Step`, `(if not O.Valve_Relay then All_Passive (O) and then not O.Pump)` | Every valve output and the pump are gated by the relay |
| No intervention without the pedal, below the speed floor, with the map off, outside the supply range, or with a sensor down | `Antilock.Controller.Step`, the enable clause | The enable condition contains all five terms, and a channel stepped without it is passive |
| The pump runs whenever an outlet is open | `Antilock.Controller.Step`, `(for all W => (if O.Valves (W).Outlet_Open then O.Pump))` | An open outlet implies the relay, an enabled release phase, and that channel's pump request |
| An open outlet belongs to a channel in its release phase within the pulse bound | `Antilock.Controller.Step`, the last clause | Every output is the command of its source channel, and the channel's own contract bounds the phase |
| Every arithmetic result is in range, with each saturation stated as a case of its postcondition | `Antilock.Wheel`, `Antilock.Reference`, `Antilock.Units.Saturating_Add` | Silver proof of the core; the exact value and the saturated case are both in the contract (D5) |

## Assumptions

The argument holds under these conditions, which the target crate and the installation
have to provide:

- The hydraulic unit has two on/off valves per wheel, inlet normally open and outlet
  normally closed, and a return pump; a de-energized unit passes the pedal pressure to
  every caliper and lets it back out.
- The valve relay feeds every coil, and the board drops it on any fault the core reports
  and on the loss of the core's heartbeat (the supervisor of roadmap Phase 2).
- The board calls `Step` once per `Loop_Period_us`, with samples whose period and age are
  measured in microseconds by a timer capture, and reports `Sensors_OK` false when the
  accelerometer or any sensor supply fails.
- The accelerometer measures the vehicle's longitudinal deceleration; the reference ramp
  follows it (D8).
- The pedal switch and the pressure sensor are independent, so one failure cannot both
  report a pedal and a pressure.
- The vehicle file passed `tools/gen-vehicle.py`, so the parameter set is `Valid`.

## Hazards and their mitigations

| Hazard | Mitigation | Where |
|---|---|---|
| Unintended release: an outlet opens on a wheel that is not slipping | The slip clause of the channel contract; the release threshold of the selected map | Proved |
| Runaway release: an outlet stays open and the caliper empties | The pulse bound and the budget; at most twice the budget of release in any window (D12) | Proved |
| Release after a fault or a sensor loss | The fault latch and the relay; the enable clause | Proved |
| Intervention at standstill or without the pedal | The speed floor and the pedal clause of the enable condition | Proved |
| A locked part-time four-wheel-drive train brings every wheel down together | The reference ramp from the accelerometer (D8) | Proved for the ramp; the ramp's margins are a calibration |
| Software stops running with coils energized | The heartbeat supervisor drops the relay; the de-energized unit is the plain path | Roadmap Phase 2, outside the core |
| A coil driver fails on | The relay opens the common supply; a stuck outlet then closes | Hardware, outside the core |
| An outlet valve sticks open mechanically | None in software: the unit's own health, bench-tested before installation | Roadmap Phase 2 |
| The accelerometer reads too low while the vehicle decelerates hard | The reference ramp slows, slip reads high, and the budget bounds the release; a plausibility check against the wheels is open | Open, roadmap Phase 2 |
| The pedal switch fails on | No release without pressure past the threshold as well | Proved (the pedal clause) |
| The pressure sensor fails high | A pressure without the switch latches `Pedal_Mismatch` after the grace period | Proved |
| The pump does not run while releasing | The pump clause; a pump failure is a bench and monitoring matter | Proved for the command; the motor is outside the core |

## What the proof does not reach

- The board drivers, the timer capture, the ADC scaling and the coil drive are Ada or
  hardware, tested on the bench.
- The scenario gate is a regression check of the cycle on a simple plant, not a
  prediction of a vehicle's stopping distance.
- The thresholds and timings of a vehicle file are a calibration, obtained on the
  vehicle with the map switch off position in reach.
