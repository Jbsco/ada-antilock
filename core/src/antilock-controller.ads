--  The four-wheel controller: wheel speeds and the vehicle reference from
--  the samples, the fault monitor, the enable conditions, one channel
--  per wheel, and the outputs to the valves, the pump, the valve relay
--  and the warning lamp.
with Antilock.Units; use Antilock.Units;
with Antilock.Parameters;
with Antilock.Channel;
with Antilock.Wheel;

package Antilock.Controller with Pure, SPARK_Mode is
   use type Channel.Phase;
   use type Channel.Valve_Command;

   type Wheel_Position is (Front_Left, Front_Right, Rear_Left, Rear_Right);

   type Samples is array (Wheel_Position) of Wheel.Sample;
   type Speeds is array (Wheel_Position) of Speed;
   type Commands is array (Wheel_Position) of Channel.Valve_Command;
   type Channel_States is array (Wheel_Position) of Channel.State;

   --  A fault latches until Init. Sensor_Dropout: a wheel gave no edges
   --  while the vehicle moved. Sensor_Fault: the board reports a failed
   --  sensor. Pedal_Mismatch: pedal pressure without the pedal switch.
   type Fault_Kind is (None, Sensor_Dropout, Sensor_Fault, Pedal_Mismatch);

   --  The readings of one step. A three-channel unit (Rear_Axle_Combined)
   --  supplies the axle's sample as Rear_Left and leaves Rear_Right unread.
   type Inputs is record
      Wheels             : Samples := (others => (others => <>));
      Longitudinal_Accel : Acceleration := 0;
      Pedal_Pressure     : Pressure := 0;
      Pedal_Switch       : Boolean := False;
      Map                : Map_Index := Off_Position;
      Supply_mV          : Millivolts := 0;
      Sensors_OK         : Boolean := False;
   end record;

   --  The commands of one step. Valve_Relay False cuts the supply of every
   --  coil whatever the valve commands say.
   type Outputs is record
      Valves       : Commands := (others => Channel.Passive_Command);
      Pump         : Boolean := False;
      Valve_Relay  : Boolean := False;
      Warning_Lamp : Boolean := True;
   end record;

   type State is record
      Channels            : Channel_States;
      Wheel_Speeds        : Speeds := (others => 0);
      Reference           : Speed := 0;
      Fault               : Fault_Kind := None;
      Dropout_Time        : Microseconds := 0;
      Pedal_Mismatch_Time : Microseconds := 0;
   end record;

   function Pedal_Applied (I : Inputs; P : Parameters.Set) return Boolean is
     (I.Pedal_Switch and then I.Pedal_Pressure >= P.Pedal_Pressure_Threshold);

   function Supply_In_Range (I : Inputs; P : Parameters.Set) return Boolean is
     (I.Supply_mV in P.Supply_Min_mV .. P.Supply_Max_mV);

   function All_Passive (O : Outputs) return Boolean is
     (for all W in Wheel_Position => O.Valves (W) = Channel.Passive_Command);

   --  The channel a wheel's valves follow: its own, or the rear left
   --  channel's for the rear right wheel of a three-channel unit.
   function Source_Of (W : Wheel_Position; P : Parameters.Set) return Wheel_Position is
     (if P.Rear_Axle_Combined and then W = Rear_Right then Rear_Left else W);

   procedure Init (S : out State; P : Parameters.Set)
     with Post => S.Fault = None and then S.Reference = 0;

   --  One control step.
   procedure Step (S : in out State; I : Inputs; P : Parameters.Set; O : out Outputs)
     with Pre  => Parameters.Valid (P),
          Post =>
            --  A fault latches, drops the relay and lights the lamp.
            (if S'Old.Fault /= None then S.Fault = S'Old.Fault)
            and then (if S.Fault /= None then not O.Valve_Relay and then O.Warning_Lamp)
            --  Without the relay nothing is energized and the pump is off.
            and then (if not O.Valve_Relay then All_Passive (O) and then not O.Pump)
            --  No intervention without the pedal, below the speed floor, with
            --  the map off, outside the supply range, or with a sensor down.
            and then (if not Pedal_Applied (I, P) or else S.Reference < P.Speed_Floor
                         or else I.Map = Off_Position or else not Supply_In_Range (I, P)
                         or else not I.Sensors_OK
                      then All_Passive (O) and then not O.Pump)
            --  The pump runs whenever an outlet is open.
            and then (for all W in Wheel_Position => (if O.Valves (W).Outlet_Open then O.Pump))
            --  An open outlet belongs to a channel in its release phase, within
            --  the pulse bound, with the slip and budget conditions of the channel.
            and then (for all W in Wheel_Position =>
                        (if O.Valves (W).Outlet_Open
                         then S.Channels (Source_Of (W, P)).Current = Channel.Release
                              and then S.Channels (Source_Of (W, P)).Time_In_Phase < P.Release_Pulse_us));

end Antilock.Controller;
