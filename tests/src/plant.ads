--  A longitudinal vehicle for the host checks: four wheels on a Burckhardt
--  tire curve, calipers behind two-valve channels with first-order pressure
--  dynamics, tooth-edge sensors, and the longitudinal accelerometer.
with Antilock.Units;
with Antilock.Wheel;
with Antilock.Controller;

package Plant is

   use Antilock.Controller;

   type Surface is (Dry_Asphalt, Wet_Asphalt, Snow, Ice);
   type Surfaces is array (Wheel_Position) of Surface;

   type Wheel_Model is record
      Omega     : Float := 0.0;
      Angle     : Float := 0.0;
      Pressure  : Float := 0.0;
      Last_Edge : Float := 0.0;
      Period    : Float := 0.0;
      Road      : Surface := Dry_Asphalt;
   end record;

   type Wheel_Models is array (Wheel_Position) of Wheel_Model;

   --  SI units: kg, m, kg m2, N m per kPa, s. The brake gains are those of
   --  a two-piston front caliper and a single-piston rear caliper on
   --  280 mm rotors with a pad friction of 0.4.
   type Vehicle is record
      Mass        : Float := 1_800.0;
      Radius      : Float := 0.393;
      Inertia     : Float := 2.0;
      Front_Gain  : Float := 0.25;
      Rear_Gain   : Float := 0.125;
      Front_Share : Float := 0.55;
      Tau_Build   : Float := 0.08;
      Tau_Release : Float := 0.05;
      Teeth       : Float := 48.0;
      Speed       : Float := 0.0;
      Position    : Float := 0.0;
      Accel       : Float := 0.0;
      Time        : Float := 0.0;
      Wheels      : Wheel_Models;
   end record;

   --  The tire friction coefficient of a surface at a longitudinal slip.
   function Mu (Road : Surface; Slip : Float) return Float;

   --  The vehicle rolling at Speed with every wheel turning freely and the
   --  sensors warm.
   procedure Init (V : in out Vehicle; Speed : Float; Roads : Surfaces);

   --  One integration step under the master cylinder pressure and the
   --  valve commands.
   procedure Integrate (V : in out Vehicle; Master_kPa : Float; Valves : Commands; Dt : Float);

   function Sample_Of (V : Vehicle; W : Wheel_Position) return Antilock.Wheel.Sample;

   function Longitudinal_Accel (V : Vehicle) return Antilock.Units.Acceleration;

   --  The speed of a wheel's contact patch, m/s.
   function Wheel_Speed (V : Vehicle; W : Wheel_Position) return Float;

end Plant;
