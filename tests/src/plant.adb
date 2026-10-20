with Ada.Numerics;
with Ada.Numerics.Elementary_Functions;

package body Plant is

   Gravity : constant Float := 9.81;

   type Coefficients is record
      C1 : Float;
      C2 : Float;
      C3 : Float;
   end record;

   --  Burckhardt coefficients: mu = C1 (1 - exp (-C2 slip)) - C3 slip.
   Curves : constant array (Surface) of Coefficients :=
     (Dry_Asphalt => (C1 => 1.2801, C2 => 23.99, C3 => 0.52),
      Wet_Asphalt => (C1 => 0.857, C2 => 33.822, C3 => 0.347),
      Snow        => (C1 => 0.1946, C2 => 94.129, C3 => 0.0646),
      Ice         => (C1 => 0.05, C2 => 306.39, C3 => 0.0));

   function Pitch (V : Vehicle) return Float is (2.0 * Ada.Numerics.Pi / V.Teeth);

   function Is_Front (W : Wheel_Position) return Boolean is (W in Front_Left | Front_Right);

   --------
   -- Mu --
   --------

   function Mu (Road : Surface; Slip : Float) return Float is
      C : Coefficients renames Curves (Road);
   begin
      return C.C1 * (1.0 - Ada.Numerics.Elementary_Functions.Exp (-C.C2 * Slip)) - C.C3 * Slip;
   end Mu;

   ----------
   -- Init --
   ----------

   procedure Init (V : in out Vehicle; Speed : Float; Roads : Surfaces) is
   begin
      V.Speed := Speed;
      V.Position := 0.0;
      V.Accel := 0.0;
      V.Time := 0.0;
      for W in Wheel_Position loop
         V.Wheels (W) := (Omega     => Speed / V.Radius,
                          Angle     => 0.0,
                          Pressure  => 0.0,
                          Last_Edge => 0.0,
                          Period    => Pitch (V) * V.Radius / Speed,
                          Road      => Roads (W));
      end loop;
   end Init;

   ---------------
   -- Integrate --
   ---------------

   procedure Integrate (V : in out Vehicle; Master_kPa : Float; Valves : Commands; Dt : Float) is
      Total_Force : Float := 0.0;
   begin
      for W in Wheel_Position loop
         declare
            M     : Wheel_Model renames V.Wheels (W);
            Share : constant Float := (if Is_Front (W) then V.Front_Share else 1.0 - V.Front_Share);
            Load  : constant Float := V.Mass * Gravity * Share / 2.0;
            Gain  : constant Float := (if Is_Front (W) then V.Front_Gain else V.Rear_Gain);
            Patch : constant Float := M.Omega * V.Radius;
            Slip  : Float := 0.0;
            Force : Float;
         begin
            if V.Speed > 0.1 and then Patch < V.Speed then
               Slip := (V.Speed - Patch) / V.Speed;
            end if;
            Force := Mu (M.Road, Slip) * Load;
            if Valves (W).Outlet_Open then
               M.Pressure := M.Pressure - M.Pressure * Dt / V.Tau_Release;
            elsif not Valves (W).Inlet_Closed then
               M.Pressure := M.Pressure + (Master_kPa - M.Pressure) * Dt / V.Tau_Build;
            end if;
            M.Omega := M.Omega + (Force * V.Radius - Gain * M.Pressure) / V.Inertia * Dt;
            if M.Omega < 0.0 then
               M.Omega := 0.0;
            end if;
            --  An edge inside the step is timed by the angle it crosses, not
            --  by the step boundary, as a timer capture would time it.
            declare
               Angle_Before : constant Float := M.Angle;
            begin
               M.Angle := M.Angle + M.Omega * Dt;
               if M.Angle >= Pitch (V) then
                  declare
                     Edge_Time : constant Float := V.Time + (Pitch (V) - Angle_Before) / M.Omega;
                  begin
                     M.Angle := M.Angle - Pitch (V);
                     M.Period := Edge_Time - M.Last_Edge;
                     M.Last_Edge := Edge_Time;
                  end;
               end if;
            end;
            Total_Force := Total_Force + Force;
         end;
      end loop;
      V.Accel := -Total_Force / V.Mass;
      V.Speed := V.Speed + V.Accel * Dt;
      if V.Speed < 0.0 then
         V.Speed := 0.0;
      end if;
      V.Position := V.Position + V.Speed * Dt;
      V.Time := V.Time + Dt;
   end Integrate;

   ---------------
   -- Sample_Of --
   ---------------

   function Sample_Of (V : Vehicle; W : Wheel_Position) return Antilock.Wheel.Sample is
      use Antilock.Units;
      M : Wheel_Model renames V.Wheels (W);
      function Micro (Seconds : Float) return Microseconds is
        (if Seconds <= 0.0 then 0
         elsif Seconds >= 2_000.0 then Microseconds'Last
         else Microseconds (Seconds * 1.0E6));
   begin
      return (Period_us => Micro (M.Period), Age_us => Micro (V.Time - M.Last_Edge));
   end Sample_Of;

   ------------------------
   -- Longitudinal_Accel --
   ------------------------

   function Longitudinal_Accel (V : Vehicle) return Antilock.Units.Acceleration is
      use Antilock.Units;
      Bound : constant Float := Float (Acceleration'Last);
   begin
      return Acceleration (Float'Max (-Bound, Float'Min (Bound, V.Accel * 1_000.0)));
   end Longitudinal_Accel;

   -----------------
   -- Wheel_Speed --
   -----------------

   function Wheel_Speed (V : Vehicle; W : Wheel_Position) return Float is
     (V.Wheels (W).Omega * V.Radius);

end Plant;
