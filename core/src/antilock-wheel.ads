--  Wheel kinematics from the tooth edges of one wheel: speed from the
--  edge period, the acceleration between two speeds, and the slip against
--  the vehicle reference. Each saturating result states its exact value
--  and its saturated case.
with Antilock.Units; use Antilock.Units;

package Antilock.Wheel with Pure, SPARK_Mode is

   subtype Wide is Long_Long_Integer;

   --  One wheel's reading at a control step: the period between the last
   --  two tooth edges, zero before the second edge, and the time since the
   --  last edge.
   type Sample is record
      Period_us : Microseconds := 0;
      Age_us    : Microseconds := 0;
   end record;

   --  The exact speed of a wheel whose teeth pass one per Period_us.
   function Exact_Speed
     (Period_us : Microseconds; Teeth : Tooth_Count; Circumference_mm : Circumference) return Wide
   is (Wide (Circumference_mm) * 1_000_000 / (Wide (Teeth) * Wide (Period_us)))
     with Pre => Period_us > 0;

   --  The speed of a wheel whose teeth pass one per Period_us, zero when no
   --  period is known, saturated at Speed'Last.
   function Speed_Of
     (Period_us : Microseconds; Teeth : Tooth_Count; Circumference_mm : Circumference) return Speed
     with Post =>
       (if Period_us = 0 then Speed_Of'Result = 0
        elsif Exact_Speed (Period_us, Teeth, Circumference_mm) > Wide (Speed'Last)
        then Speed_Of'Result = Speed'Last
        else Speed_Of'Result = Speed (Exact_Speed (Period_us, Teeth, Circumference_mm)));

   --  The speed estimate of a sample: the speed of the last period, bounded
   --  above by the speed at which the next edge would already have passed,
   --  so a wheel that stops emitting edges reads slower as its last edge
   --  ages.
   function Estimate (S : Sample; Teeth : Tooth_Count; Circumference_mm : Circumference) return Speed
     with Post =>
       (if S.Period_us = 0 then Estimate'Result = 0
        elsif S.Age_us > S.Period_us
        then Estimate'Result = Speed'Min (Speed_Of (S.Period_us, Teeth, Circumference_mm),
                                          Speed_Of (S.Age_us, Teeth, Circumference_mm))
        else Estimate'Result = Speed_Of (S.Period_us, Teeth, Circumference_mm));

   --  The exact acceleration between two speeds Dt apart.
   function Exact_Acceleration (Previous, Current : Speed; Dt : Microseconds) return Wide
   is ((Wide (Current) - Wide (Previous)) * 1_000_000 / Wide (Dt))
     with Pre => Dt > 0;

   --  The acceleration between two speeds Dt apart, saturated at the type
   --  bounds.
   function Acceleration_Of (Previous, Current : Speed; Dt : Microseconds) return Acceleration
     with Pre  => Dt > 0,
          Post =>
            (if Exact_Acceleration (Previous, Current, Dt) > Wide (Acceleration'Last)
             then Acceleration_Of'Result = Acceleration'Last
             elsif Exact_Acceleration (Previous, Current, Dt) < Wide (Acceleration'First)
             then Acceleration_Of'Result = Acceleration'First
             else Acceleration_Of'Result = Acceleration (Exact_Acceleration (Previous, Current, Dt)));

   --  The exact slip of a wheel slower than the reference, in permille.
   function Exact_Slip (Wheel_Speed, Reference : Speed) return Wide
   is ((Wide (Reference) - Wide (Wheel_Speed)) * 1_000 / Wide (Reference))
     with Pre => Wheel_Speed < Reference;

   --  The slip of a wheel against the reference speed, in permille of the
   --  reference, zero when the wheel keeps up with it.
   function Slip_Of (Wheel_Speed, Reference : Speed) return Permille
     with Post =>
       (if Wheel_Speed >= Reference then Slip_Of'Result = 0
        else Wide (Slip_Of'Result) = Exact_Slip (Wheel_Speed, Reference));

end Antilock.Wheel;
