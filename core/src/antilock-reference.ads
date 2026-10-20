--  The vehicle reference speed: the fastest wheel, held up by a ramp when
--  every wheel slows faster than the vehicle does, so that four wheels
--  locking together, as a locked four-wheel-drive train can, still read as
--  slip. The ramp follows the measured deceleration, so the accelerometer
--  is part of the controller.
with Antilock.Units; use Antilock.Units;
with Antilock.Parameters;

package Antilock.Reference with Pure, SPARK_Mode is

   subtype Wide is Long_Long_Integer;

   --  The measured deceleration, zero while the vehicle accelerates.
   function Braking (Measured : Acceleration) return Wide is
     (if Measured < 0 then -Wide (Measured) else 0);

   --  The deceleration the reference ramps at: the measured deceleration,
   --  capped at the vehicle's parameter, plus the margin.
   subtype Ramp_Rate is Wide range 0 .. 25_000;
   function Ramp (Measured : Acceleration; P : Parameters.Set) return Ramp_Rate is
     (Wide'Min (Braking (Measured), Wide (P.Max_Vehicle_Decel)) + Wide (P.Decel_Margin));

   --  The exact drop of the reference over one loop period.
   function Exact_Drop (Measured : Acceleration; P : Parameters.Set) return Wide is
     (Ramp (Measured, P) * Wide (P.Loop_Period_us) / 1_000_000);

   --  The largest drop the reference may take in one step, saturated at
   --  Speed'Last.
   function Max_Drop (Measured : Acceleration; P : Parameters.Set) return Speed is
     (if Exact_Drop (Measured, P) > Wide (Speed'Last) then Speed'Last
      else Speed (Exact_Drop (Measured, P)));

   --  The reference for this step: the fastest wheel, or the previous
   --  reference less the maximum drop when every wheel fell below that.
   function Update
     (Previous : Speed; Fastest_Wheel : Speed; Measured : Acceleration; P : Parameters.Set) return Speed
   is (Speed'Max (Fastest_Wheel, Previous - Speed'Min (Previous, Max_Drop (Measured, P))));

end Antilock.Reference;
