# Roadmap

Mission: an anti-lock brake controller in SPARK and Ada that any vehicle configures from a
vehicle file and runs on a flight controller board, proved where proof buys assurance
that tests cannot: no release without a slipping wheel, no release past its budget, no
coil energized when the controller has no business touching the brakes.

A phase is complete when its units prove with no assume, the scenario gate holds, and the
gates on `main` are green.

## Phases

- Phase 0, complete 2026-10-19. Foundation. Core crate proved, the plant model and the
  scenario gate, the vehicle generator, the gates, CI, the design ledger, the safety
  case and the hardware notes.
- Phase 1, open. Target crate for the CLRacing F4S: the Cortex-M4 runtime, timer input
  capture for four wheel sensors, the coil, pump and relay outputs, ADC for the pressure
  sensors, the map ladder and the supply, the MPU-6000 longitudinal axis over SPI, UART
  telemetry, trace logging to the board flash, and `flash.do` over DFU.
- Phase 2, open. Bench and hardware in the loop. A hydraulic unit on a rig with a master
  cylinder, pressure sensors and calipers, to measure the valve and pump response the
  plant model assumes; the plant model driving the board over UART; the coil driver
  board; the supervisor microcontroller that holds the valve relay on a heartbeat.
- Phase 3, open. Vehicle commissioning. Rear-axle-only mode first, which contains any
  failure to the rear axle, then the fronts; a gravel-lot protocol with the map switch
  off position in reach; every stop logged.
- Phase 4, open. Brake force distribution. Rear-axle pressure hold on rear over-slip, so
  the proportioning valve can go, and a servo on a bias adjuster from one output.
- Phase 5, open. Telemetry. Wheel speeds, pressures, phases and faults as CAN frames for
  a dash, and a trace tool that plots the CSV traces of the checker and the board alike.
- Phase 6, open. Calibration. Maps per surface from logged stops, and a map editor that
  writes the vehicle file.
- Phase 7, candidate. Brake traction at crawl speed. On a stability unit with a changeover
  valve and an intake valve per circuit beside the per-wheel valves (twelve in the MK60,
  `docs/hardware.md`), the pump builds pressure on one spinning driven wheel with the
  pedal untouched, and the differential hands that wheel's brake torque to the wheel with
  grip: an electronic differential lock for a locked part-time four-wheel-drive train.
  Needs four more coil outputs, a circuit-level valve state beside the per-wheel channel,
  a speed ceiling, a spin threshold against the slowest wheel, pump and brake duty
  budgets, pedal priority, and a master cylinder the pump can draw through, which the
  Phase 2 rig measures.
  Launch is the same function with the reference taken from the accelerometer, since
  every wheel can spin at once. Engine torque stays with the engine controller, which
  takes the wheel speeds from the Phase 5 frames. Opening this phase amends D2.
- Phase 8, candidate. Yaw control on loose surfaces. A target yaw rate from a steering
  angle sensor and the vehicle speed, the measured rate from the board's gyro, and a
  single-wheel build against the error, with thresholds wide enough for the driver's own
  slides and an off position on the switch. A wrong build at speed in a corner is a worse
  failure than a wrong release, so the claims bound the build in time, pressure, speed
  window and yaw error before any vehicle test. Needs the circuit state of Phase 7, a
  steering angle sensor and a rigid mount for the board. Opening this phase amends D2.

## Open questions

- Whether the F4S pads have enough outputs for a four-channel unit with a pump and a
  relay without giving up the SWD pins (`docs/boards/clracing-f4s.md`).
- Whether the loop period should follow the wheel edges at low speed instead of the
  fixed 5 ms, where a 48-tooth ring on a large tire gives an edge every 9 ms at 20 km/h.
- How the controller should behave in a locked part-time four-wheel-drive train beyond
  the reference ramp of D8; no published motorsport calibration covers it.
- Whether a handbrake switch input should set the rear channels passive, so a deliberate
  rear lock with the pedal applied does not spend the release budget on a caliper the
  handbrake holds.
- Whether `teeth` should be per axle, since a ring inside a live axle tube is far smaller
  than one on a front hub and the sensor's pitch guideline caps the count by diameter.
