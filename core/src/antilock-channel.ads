--  The anti-lock cycle of one wheel. Passive leaves the pedal connected
--  to the caliper. Hold closes the inlet when the wheel decelerates past
--  the threshold, and keeps it closed while the wheel re-accelerates.
--  Release opens the outlet in bounded pulses while the wheel slips past
--  the release threshold without re-accelerating and the release budget
--  lasts. Build pulses the inlet open again once the slip falls to the
--  recover threshold, a long pulse first and short ones after, until the
--  wheel decelerates past the threshold again.
with Antilock.Units; use Antilock.Units;
with Antilock.Parameters;

package Antilock.Channel with Pure, SPARK_Mode is

   type Phase is (Passive, Hold, Release, Build);

   --  The commands to the two valves of one wheel. Both False is the
   --  de-energized state: inlet open, outlet closed, the pedal connected to
   --  the caliper.
   type Valve_Command is record
      Inlet_Closed : Boolean := False;
      Outlet_Open  : Boolean := False;
   end record;

   Passive_Command : constant Valve_Command := (Inlet_Closed => False, Outlet_Open => False);

   --  What the controller tells a channel at each step: whether control is
   --  permitted at all, the vehicle reference, and the thresholds of the
   --  selected map.
   type Context is record
      Enabled    : Boolean := False;
      Reference  : Speed := 0;
      Thresholds : Parameters.Thresholds;
   end record;

   type State is record
      Current        : Phase := Passive;
      Time_In_Phase  : Microseconds := 0;
      Pulse_Elapsed  : Microseconds := 0;
      Wheel_Speed    : Speed := 0;
      Accel          : Acceleration := 0;
      Slip           : Permille := 0;
      Release_Budget : Microseconds := 0;
      Window_Elapsed : Microseconds := 0;
      Build_Open     : Boolean := False;
      Build_Pulse    : Microseconds := 0;
      Pump_Run_On    : Microseconds := 0;
      Command        : Valve_Command := Passive_Command;
      Pump_Request   : Boolean := False;
   end record;

   --  The valve command a phase implies.
   function Command_Of (S : State) return Valve_Command is
     (Inlet_Closed => S.Current in Hold | Release or else (S.Current = Build and then not S.Build_Open),
      Outlet_Open  => S.Current = Release);

   procedure Init (S : out State; P : Parameters.Set)
     with Post => S.Current = Passive and then S.Command = Passive_Command
                  and then not S.Pump_Request and then S.Release_Budget = P.Release_Budget_us;

   --  One control step of one wheel at the new wheel speed.
   procedure Step (S : in out State; New_Speed : Speed; C : Context; P : Parameters.Set)
     with Pre  => Parameters.Valid (P),
          Post =>
            --  The command follows the phase, and a passive phase energizes nothing.
            S.Command = Command_Of (S)
            and then (if S.Current = Passive then S.Command = Passive_Command)
            --  A disabled channel is passive.
            and then (if not C.Enabled then S.Current = Passive)
            --  A release pulse is bounded in time.
            and then (if S.Current = Release then S.Time_In_Phase < P.Release_Pulse_us)
            --  A release step draws one loop period from the budget, so the
            --  outlet never opens on an exhausted budget.
            and then (if S.Current = Release
                      then S'Old.Release_Budget >= P.Loop_Period_us
                           and then (S.Release_Budget = S'Old.Release_Budget - P.Loop_Period_us
                                     or else S.Window_Elapsed = 0))
            --  Release starts only on a wheel slipping past the release threshold.
            and then (if S.Current = Release and then S'Old.Current /= Release
                      then S.Slip >= C.Thresholds.Slip_Release)
            --  The pump is requested whenever the outlet is open.
            and then (if S.Current = Release then S.Pump_Request);

end Antilock.Channel;
