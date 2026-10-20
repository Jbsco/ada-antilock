# CLRacing F4S

The first target board: an STM32F405RGT6 flight controller with an MPU-6000 on SPI1, an
8 MHz crystal, a 16 MB flash or an SD card slot for logging depending on the revision, a
MAX7456 OSD, four UARTs, a 5 V regulator and a current sensor. The target crate is
roadmap Phase 1; this page holds the pin plan it will implement.

## Provenance

The pin map is the Betaflight unified target `CLRA-CLRACINGF4`, the target the F4S
flashes. It has to be confirmed against a resource dump (`resource` in the Betaflight
command line) of one of the boards before the first bench run, because the F4S revisions
differ from the original board in the logging device and may differ in a pad.

## Pin plan

Every pad listed is a solder pad of the F4S. The controller needs four capture inputs,
ten outputs, three analog inputs, one switch input and one serial port; the board's
motor, LED, camera, beeper and UART pads cover them.

| Function | Pin | Board pad | Timer and alternate function | Note |
|---|---|---|---|---|
| Wheel speed front left | PB0 | M1 | TIM3_CH3, AF2 | Input capture. Not 5 V tolerant: pull the sensor output up to 3.3 V |
| Wheel speed front right | PB1 | M2 | TIM3_CH4, AF2 | Input capture, same |
| Wheel speed rear left | PA3 | M3 | TIM5_CH4, AF2 | Input capture on the 32-bit TIM5, same |
| Wheel speed rear right | PA2 | M4 | TIM5_CH3, AF2 | Input capture, same; unused on a three-channel unit |
| Inlet front left | PB8 | M5 / LED | GPIO | To a low-side coil driver |
| Outlet front left | PB9 | Camera control | GPIO | |
| Inlet front right | PB4 | Beeper | GPIO | |
| Outlet front right | PA0 | TX4 | GPIO | |
| Inlet rear left | PA1 | RX4 | GPIO | |
| Outlet rear left | PC6 | TX6 | GPIO | |
| Inlet rear right | PC7 | RX6 | GPIO | Free on a three-channel unit |
| Outlet rear right | PB10 | TX3 | GPIO | Free on a three-channel unit |
| Pump | PB11 | RX3 | GPIO | To the pump relay or MOSFET driver |
| Valve relay | PC0 | Inverter control | GPIO | Also held by the supervisor's heartbeat monitor |
| Pressure front circuit | PC1 | Current | ADC1_IN11 | Ratiometric 0.5 to 4.5 V sensor through the pad's divider |
| Pressure rear circuit | PC3 | RSSI | ADC1_IN13 | Same |
| Map switch | PC2 | VBAT | ADC1_IN12 | A twelve-position switch on a resistor ladder; the pad's divider sets the ladder's top |
| Pedal switch | PC5 | USB detect | GPIO | Opto or divider from the brake light circuit |
| Accelerometer | PA4, PA5, PA6, PA7, PC4 | On board | SPI1, EXTI | The MPU-6000's longitudinal axis |
| Telemetry | PA9, PA10 | TX1, RX1 | USART1 | Dash link, or a CAN transceiver in Phase 5 |
| Logging | PB3 or PB12 | On board | SPI3 or SPI2 | Flash or SD card by revision |
| Status LED | PB5 | On board | GPIO | Warning lamp mirror |
| Debug | PA13, PA14 | SWD pads | SWD | Kept for the debugger; PA14 doubles as PINIO on the board |

Supply monitoring reads the board's own supply through the VBAT divider when the map
ladder moves to another pad; the plan above spends the VBAT pad on the ladder and reads
the supply from the 5 V rail's divider instead, which the target crate settles.

## Flashing

The STM32F405 carries a USB DFU bootloader. With the boot button held at power-up, the
board enumerates as a DFU device and `flash.do` writes the image:

    dfu-util -a 0 -s 0x08000000:leave -D targets/clracing_f4s/bin/antilock.bin

## Open points

- The pad count leaves no spare output for a four-channel unit with both a pump and a
  relay without the camera control and beeper pads; a three-channel unit frees two.
- The MPU-6000's mounting orientation on the board sets which axis is longitudinal; the
  target crate reads the board alignment from the vehicle file or a board constant.
- The current sensor pad carries a shunt amplifier on some revisions; a pressure sensor
  on it needs the amplifier bypassed.
