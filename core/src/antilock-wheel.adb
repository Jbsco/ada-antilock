package body Antilock.Wheel with SPARK_Mode is

   --------------
   -- Speed_Of --
   --------------

   function Speed_Of
     (Period_us : Microseconds; Teeth : Tooth_Count; Circumference_mm : Circumference) return Speed
   is
   begin
      if Period_us = 0 then
         return 0;
      end if;
      declare
         Exact : constant Wide := Exact_Speed (Period_us, Teeth, Circumference_mm);
      begin
         if Exact > Wide (Speed'Last) then
            return Speed'Last;
         else
            return Speed (Exact);
         end if;
      end;
   end Speed_Of;

   --------------
   -- Estimate --
   --------------

   function Estimate (S : Sample; Teeth : Tooth_Count; Circumference_mm : Circumference) return Speed is
      Last : constant Speed := Speed_Of (S.Period_us, Teeth, Circumference_mm);
   begin
      if S.Period_us = 0 then
         return 0;
      elsif S.Age_us > S.Period_us then
         return Speed'Min (Last, Speed_Of (S.Age_us, Teeth, Circumference_mm));
      else
         return Last;
      end if;
   end Estimate;

   ---------------------
   -- Acceleration_Of --
   ---------------------

   function Acceleration_Of (Previous, Current : Speed; Dt : Microseconds) return Acceleration is
      Exact : constant Wide := Exact_Acceleration (Previous, Current, Dt);
   begin
      if Exact > Wide (Acceleration'Last) then
         return Acceleration'Last;
      elsif Exact < Wide (Acceleration'First) then
         return Acceleration'First;
      else
         return Acceleration (Exact);
      end if;
   end Acceleration_Of;

   -------------
   -- Slip_Of --
   -------------

   function Slip_Of (Wheel_Speed, Reference : Speed) return Permille is
   begin
      if Wheel_Speed >= Reference then
         return 0;
      end if;
      declare
         Deficit : constant Wide := (Wide (Reference) - Wide (Wheel_Speed)) * 1_000;
      begin
         --  The deficit is at most the reference, so the quotient is at most one thousand.
         pragma Assert (Deficit <= Wide (Reference) * 1_000);
         return Permille (Deficit / Wide (Reference));
      end;
   end Slip_Of;

end Antilock.Wheel;
