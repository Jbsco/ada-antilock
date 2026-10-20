# Hardware

What the controller needs around it: wheel sensors and encoder wheels, a hydraulic unit
whose coils the board can reach, the drivers between the board's pins and the coils, the
pressure and pedal inputs, the map switch, the supply, and the lines. The figures that
come from a vendor document are cited at the end.

## Wheel speed sensing

- **Encoder wheel.** A ferromagnetic ring of about 48 teeth, tooth height 3 mm, tooth to
  gap 50 %, one per wheel, with the sensor at a gap of 0.8 ± 0.1 mm [1]. The tooth count
  is a parameter (`teeth`), so any count in 12 to 200 works once the ring is made. A
  48-tooth ring on a 2.5 m tire gives 19 edges per metre: about 110 edges per second at
  20 km/h and 320 at 60 km/h, so a 5 ms loop sees a new edge every one or two steps at
  the low end. Below walking pace there is nothing to control, which is why the speed
  floor exists.
- **Ring placement.** On a live rear axle, a ring pressed on each shaft inboard of the
  bearing retainer with a sensor boss welded to the housing end, the pattern of the
  per-wheel rear sensing of later pickups, or a ring bolted behind the rotor hat with the
  sensor on the backing plate. On a free-running front hub the ring goes on the hub
  behind the rotor with a bracket off the spindle; the hub turns with the wheel whether
  or not the hub is locked. A three-channel unit (`rear_axle_combined`) takes one ring on
  the pinion flange or the driveshaft instead.
- **Sensors.** The core reads a period and an age per wheel, so any sensor whose edges a
  timer can capture serves. Two families fit:
  - Three-wire Hall gear-tooth sensors with a logic-level output. The ZF GS100502 is in
    production: M12 x 1 threaded body, 4.5 to 24 V supply, sinking output, up to 15 kHz,
    -40 to 125 °C, IP67 [3]. The boss becomes a tapped hole and the gap a jam nut. The
    Honeywell 1GT101DC of the same kind is discontinued [4]. A sinking output pulls up to
    the board's 3.3 V, since the capture pins of the F4S are not 5 V tolerant.
  - Two-wire differential Hall sensors of the Bosch DF11 family, as the Bosch Motorsport
    ABS M5 requires [1]. They signal by current (two levels on the supply pair) and need a
    sense resistor and a comparator in front of a timer pin. Worth choosing only when the
    rings and mounts have to serve a Bosch unit later.
- **Mounting.** Sensors are direction sensitive: the fixing screw sits in the rotation
  plane of the ring, and the mount is as rigid as possible [1].

## Hydraulic unit

The core assumes a unit with two on/off valves per wheel, inlet normally open and outlet
normally closed, low-pressure accumulators, and a return pump that sends released fluid
back to the master cylinder side. Four channels, or three with one rear channel. What
decides a donor is whether the board can reach its coils:

- **Coils in the removable module.** From Bosch 5.3 onward and in the ATE MK20, MK25 and
  MK60 family, the solenoid coils sit in the electronic module and slide over the valve
  domes, so the module comes off without opening the hydraulic circuit [5] [6]. Driving
  such a block yourself means stripping the module's circuit board and keeping the coil
  carrier, with the coil pins wired out. The MK60 of a four-cylinder E90 is a cheap
  practice donor: internal pressure sensor, standard Hall sensors, parts reported at $35
  to $40 shipped [7]. The MK60 block holds 12 solenoid valves: 4 inlet (normally open),
  4 outlet (normally closed), 2 changeover (normally open) and 2 intake (normally closed),
  with 2 accumulators and the return pump. In anti-lock regulation the pump returns fluid
  to the master cylinder circuits. In traction and stability intervention it builds the
  brake pressure, drawing through the central valves of a DSC master cylinder [13]. The
  core drives the eight per-wheel valves and leaves the other four de-energized. A
  conventional master cylinder has no central valves, so the build rate through one is a
  bench measurement before the traction candidate of the roadmap opens.
- **Coils in the block.** Late-80s to mid-90s units with a remote control unit keep the
  coils in the block and bring them to a connector: the Bosch 2E of Saab, BMW, Mercedes
  and Porsche of the era, the Teves Mk IV of Ford and others, and the Japanese actuators
  of the same years. Saab's 2E procedure reads a coil at 0.7 to 1.7 Ω across the
  connector pins [8]; a Mk IV owner expected 6 to 8 Ω on a six-valve block [9]; trade
  references give 4 to 15 Ω [10] [11]. The 2E has one three-position valve per channel,
  driven by current level (zero builds, half holds, full releases) [12], which the core's
  two-valve model does not cover (D2).
- **The pump.** Released fluid lands in the accumulators, 5 cm³ each on the Bosch M5
  [2], and the pump returns it; a release without the pump fills them and the pedal sinks
  (D11). Pump currents run to tens of amps: the M5 draws 230 W for its pump and 170 W for
  its valves at 12 V [2], so the unit's feed is a 35 A class circuit with its own fuse.
- **Fittings.** The Bosch units take M12 x 1 at the master cylinder inlets and M10 x 1 at
  the caliper outlets, DIN bubble flares, on rigid steel lines of 3.2 mm bore or more,
  with no clamp within 20 cm of the unit because it vibrates [1]. DOT 4 or DOT 5.1 fluid
  [2]. Calipers as stiff as possible, and seals inspected more often under ABS cycling
  [1].

## Drivers and the relay

- **Coil drivers.** One low-side switch per coil, an amp or two each, with a freewheel
  clamp and current sense: automotive smart low-side switches or logic-level MOSFETs with
  diodes. The core commands on and off at the loop period; pulse timing is in the
  parameters, so no PWM is needed.
- **Pump driver.** A relay or a high-side MOSFET with a soft start, with the motor current
  monitored.
- **Valve relay.** One relay feeds every coil. The board drives it, and a supervisor (a
  second flight controller, roadmap Phase 2) holds it only while the controller's
  heartbeat and plausibility checks pass. With the relay open, every valve rests in its
  de-energized position and the pedal reaches the calipers whatever the software does.

## Pressure, pedal, switch and supply

- **Pressure.** Two ratiometric 0.5 to 4.5 V sensors, one per circuit, between the master
  cylinder and the unit. Bosch mounts its sensors with the measuring hole up and as far
  from the unit as the lines allow, to bleed them and to spare them its vibration [1]. The
  core takes the larger of the two as the pedal pressure.
- **Pedal switch.** The brake light switch, as an independent second signal: the pedal
  counts as applied only with both the switch and a pressure past the threshold (D10).
- **Map switch.** A twelve-position rotary switch on a resistor ladder into one analog
  input, position 12 off; the dial convention of the M5 [1].
- **Supply.** 9 to 16.5 V by default; outside that range the controller inhibits without
  latching, since cranking sags the supply.
- **Accelerometer.** The board's own, mounted so one axis is longitudinal; the reference
  ramp follows it (D8).

## Sources

1. Bosch Motorsport, ABS M5 Kit manual, version 1.3 (encoder wheel and sensor gap, sensor
   mounting, lines, calipers, master cylinders, map switch):
   https://www.bosch-motorsport.com/content/downloads/Raceparts/Resources/pdf/Operation%20Manual_70618763_ABS_M5_Kit.pdf
2. Bosch Motorsport, ABS M5 Kit data sheet (fluids, power, accumulators, fittings):
   https://www.bosch-motorsport.de/content/downloads/Raceparts/Resources/pdf/Data%20Sheet_70612107_ABS_M5_Kit.pdf
3. ZF GS100502 gear-tooth sensor listing:
   https://my.element14.com/zf/gs100502/hall-effect-gear-tooth-sensor/dp/1971737
4. Honeywell 1GT101DC listing, no longer manufactured:
   https://sg.element14.com/honeywell/1gt101dc/hall-effect-gear-tooth-sensor/dp/1225630
5. US patent 6352317, solenoid coil structure in a removable control module:
   https://patents.google.com/patent/US6352317
6. ATE MK60 ABS control unit page: https://ate-brakes.com/products/hydraulic-parts/mk60-abs-control-unit
7. LotusTalk, MK60, MK60E1 and MK60E5 swap thread:
   https://www.lotustalk.com/threads/continental-bmw-mk60-mk60e1-mk60e5-abs-swap-thread.551646/
8. Saab WIS, ABS 2E solenoid coil check:
   https://saabwisonline.com/900/1995/5-brakes/abs-2e/fault-diagnosis-diagnostic-trouble-codes/b2460
9. Bimmerforums, Teves Mk IV diagnostics thread:
   https://forums.bimmerforums.com/forum/archive/index.php/t-223550.html
10. ASE A5 study guide, HCU and solenoid diagnosis:
    https://open-exam-prep.com/study-guides/ase-a5/electronic-brake-control-systems/abs-hcu-solenoid-diagnosis
11. Underhood Service, HCU and modulator diagnostics:
    https://www.underhoodservice.com/abs-esc-hydraulic-control-unit-modulator-diagnostics/
12. Saab WIS, ABS 2E solenoid valves:
    https://saabwisonline.com/900/1994/5-brakes/abs-2e/technical-description/solenoid-valves
13. BMW ST040 training, Teves DSC III MK60 (twelve valves, two accumulators, the return
    pump, the central-valve master cylinder):
    https://ia801005.us.archive.org/11/items/BMWTechnicalTrainingDocuments/ST040%202001%20System%20Diagnosis/6%20DSC%202010-30-00.pdf
