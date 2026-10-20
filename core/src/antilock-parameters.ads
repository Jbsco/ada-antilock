--  The vehicle and tuning parameters a build supplies, generated from the
--  vehicle file by tools/gen-vehicle.py. Every field carries its range, and
--  Valid states the conditions between fields.
with Antilock.Units; use Antilock.Units;

package Antilock.Parameters with Pure, SPARK_Mode is

   --  The thresholds of one control map. The deceleration threshold opens
   --  the hold phase, the release slip opens the release phase, the recover
   --  slip and the re-acceleration threshold end it.
   type Thresholds is record
      Decel_Threshold   : Acceleration range 1_000 .. 200_000 := 12_000;
      Slip_Release      : Permille range 50 .. 900 := 200;
      Slip_Recover      : Permille range 10 .. 500 := 80;
      Reaccel_Threshold : Acceleration range 500 .. 100_000 := 4_000;
   end record;

   type Map_Table is array (Active_Map) of Thresholds;

   type Set is record
      Teeth                    : Tooth_Count := 48;
      Circumference_mm         : Circumference := 2_000;
      Loop_Period_us           : Microseconds range 1_000 .. 20_000 := 5_000;
      Speed_Floor              : Speed range 500 .. 10_000 := 1_500;
      Max_Vehicle_Decel        : Acceleration range 2_000 .. 20_000 := 12_000;
      Decel_Margin             : Acceleration range 0 .. 5_000 := 200;
      Release_Pulse_us         : Microseconds range 1_000 .. 50_000 := 8_000;
      Hold_Max_us              : Microseconds range 10_000 .. 1_000_000 := 150_000;
      Build_Pulse_First_us     : Microseconds range 1_000 .. 100_000 := 10_000;
      Build_Pulse_us           : Microseconds range 1_000 .. 50_000 := 5_000;
      Build_Pause_us           : Microseconds range 1_000 .. 100_000 := 20_000;
      Build_Max_us             : Microseconds range 10_000 .. 5_000_000 := 500_000;
      Release_Budget_us        : Microseconds range 10_000 .. 1_000_000 := 300_000;
      Release_Window_us        : Microseconds range 100_000 .. 10_000_000 := 1_000_000;
      Pulse_Timeout_us         : Microseconds range 10_000 .. 2_000_000 := 500_000;
      Dropout_Grace_us         : Microseconds range 10_000 .. 5_000_000 := 1_000_000;
      Pump_Run_On_us           : Microseconds range 0 .. 5_000_000 := 1_000_000;
      Pedal_Pressure_Threshold : Pressure range 0 .. 10_000 := 300;
      Supply_Min_mV            : Millivolts range 6_000 .. 20_000 := 9_000;
      Supply_Max_mV            : Millivolts range 10_000 .. 40_000 := 16_500;
      Rear_Axle_Combined       : Boolean := False;
      Maps                     : Map_Table := (others => (others => <>));
   end record;

   --  The conditions between fields. The generator refuses a vehicle file
   --  that breaks one, and the controller requires them.
   function Valid (P : Set) return Boolean is
     (P.Loop_Period_us <= P.Release_Pulse_us
      and then P.Release_Pulse_us <= P.Release_Budget_us
      and then P.Release_Budget_us <= P.Release_Window_us
      and then P.Loop_Period_us <= P.Build_Pulse_us
      and then P.Loop_Period_us <= P.Build_Pause_us
      and then P.Supply_Min_mV < P.Supply_Max_mV
      and then (for all M in Active_Map => P.Maps (M).Slip_Recover < P.Maps (M).Slip_Release));

end Antilock.Parameters;
