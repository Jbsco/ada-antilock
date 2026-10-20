with Antilock.Reference;

package body Antilock.Controller with SPARK_Mode is

   --  The speed of a wheel from its sample, the rear left speed for the
   --  rear right wheel of a three-channel unit.
   function Speed_For
     (I : Inputs; P : Parameters.Set; W : Wheel_Position; Rear_Left_Speed : Speed) return Speed
   is (if P.Rear_Axle_Combined and then W = Rear_Right then Rear_Left_Speed
       else Wheel.Estimate (I.Wheels (W), P.Teeth, P.Circumference_mm));

   --  Whether a wheel that should emit edges gave none: no period yet or a
   --  stale edge, on a channel that is not holding the wheel.
   function Missing (I : Inputs; S : State; P : Parameters.Set; W : Wheel_Position) return Boolean is
     (not (P.Rear_Axle_Combined and then W = Rear_Right)
      and then (I.Wheels (W).Period_us = 0 or else I.Wheels (W).Age_us > P.Pulse_Timeout_us)
      and then S.Channels (W).Current = Channel.Passive);

   --  The command a wheel's valves receive: its source channel's command
   --  with the relay on, passive without it.
   function Valve_For (S : State; W : Wheel_Position; P : Parameters.Set; Relay : Boolean)
     return Channel.Valve_Command
   is (if Relay then S.Channels (Source_Of (W, P)).Command else Channel.Passive_Command);

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; P : Parameters.Set) is
   begin
      S := (Channels => (others => <>), others => <>);
      Channel.Init (S.Channels (Front_Left), P);
      Channel.Init (S.Channels (Front_Right), P);
      Channel.Init (S.Channels (Rear_Left), P);
      Channel.Init (S.Channels (Rear_Right), P);
   end Init;

   ----------
   -- Step --
   ----------

   procedure Step (S : in out State; I : Inputs; P : Parameters.Set; O : out Outputs) is
      Dt          : constant Microseconds := P.Loop_Period_us;
      Mismatch    : constant Boolean :=
        not I.Pedal_Switch and then I.Pedal_Pressure >= P.Pedal_Pressure_Threshold;
      Fastest     : Speed;
      Any_Missing : Boolean;
      Enabled     : Boolean;
      Ctx         : Channel.Context;
      Relay       : Boolean;
   begin
      --  Wheel speeds and the reference.
      S.Wheel_Speeds (Front_Left) := Speed_For (I, P, Front_Left, 0);
      S.Wheel_Speeds (Front_Right) := Speed_For (I, P, Front_Right, 0);
      S.Wheel_Speeds (Rear_Left) := Speed_For (I, P, Rear_Left, 0);
      S.Wheel_Speeds (Rear_Right) := Speed_For (I, P, Rear_Right, S.Wheel_Speeds (Rear_Left));
      Fastest := Speed'Max (Speed'Max (S.Wheel_Speeds (Front_Left), S.Wheel_Speeds (Front_Right)),
                            Speed'Max (S.Wheel_Speeds (Rear_Left), S.Wheel_Speeds (Rear_Right)));
      S.Reference := Reference.Update (S.Reference, Fastest, I.Longitudinal_Accel, P);

      --  Faults. A wheel without edges counts only off the pedal, since a
      --  wheel held by the driver's braking stops emitting edges too.
      if S.Fault = None then
         if not I.Sensors_OK then
            S.Fault := Sensor_Fault;
         end if;
         Any_Missing := Missing (I, S, P, Front_Left) or else Missing (I, S, P, Front_Right)
                        or else Missing (I, S, P, Rear_Left) or else Missing (I, S, P, Rear_Right);
         if Any_Missing and then not Pedal_Applied (I, P) and then S.Reference >= 2 * P.Speed_Floor then
            S.Dropout_Time := Saturating_Add (S.Dropout_Time, Dt);
            if S.Dropout_Time >= P.Dropout_Grace_us then
               S.Fault := Sensor_Dropout;
            end if;
         else
            S.Dropout_Time := 0;
         end if;
         if Mismatch then
            S.Pedal_Mismatch_Time := Saturating_Add (S.Pedal_Mismatch_Time, Dt);
            if S.Pedal_Mismatch_Time >= P.Dropout_Grace_us then
               S.Fault := Pedal_Mismatch;
            end if;
         else
            S.Pedal_Mismatch_Time := 0;
         end if;
      end if;

      --  The enable conditions and the map.
      Enabled := S.Fault = None and then I.Sensors_OK and then Pedal_Applied (I, P)
                 and then S.Reference >= P.Speed_Floor and then I.Map /= Off_Position
                 and then Supply_In_Range (I, P);
      Ctx := (Enabled    => Enabled,
              Reference  => S.Reference,
              Thresholds => P.Maps (if I.Map in Active_Map then I.Map else Active_Map'First));

      --  The channels.
      Channel.Step (S.Channels (Front_Left), S.Wheel_Speeds (Front_Left), Ctx, P);
      Channel.Step (S.Channels (Front_Right), S.Wheel_Speeds (Front_Right), Ctx, P);
      Channel.Step (S.Channels (Rear_Left), S.Wheel_Speeds (Rear_Left), Ctx, P);
      if not P.Rear_Axle_Combined then
         Channel.Step (S.Channels (Rear_Right), S.Wheel_Speeds (Rear_Right), Ctx, P);
      end if;

      --  The outputs.
      Relay := S.Fault = None;
      O := (Valves       => (Front_Left  => Valve_For (S, Front_Left, P, Relay),
                             Front_Right => Valve_For (S, Front_Right, P, Relay),
                             Rear_Left   => Valve_For (S, Rear_Left, P, Relay),
                             Rear_Right  => Valve_For (S, Rear_Right, P, Relay)),
            Pump         => Relay and then Enabled
                            and then (S.Channels (Front_Left).Pump_Request
                                      or else S.Channels (Front_Right).Pump_Request
                                      or else S.Channels (Rear_Left).Pump_Request
                                      or else (not P.Rear_Axle_Combined
                                               and then S.Channels (Rear_Right).Pump_Request)),
            Valve_Relay  => Relay,
            Warning_Lamp => S.Fault /= None or else I.Map = Off_Position);

      --  Cuts for the enable clause of the postcondition: a disabled step
      --  leaves every stepped channel passive, so every output is passive.
      pragma Assert
        (if not Enabled
         then S.Channels (Front_Left).Current = Channel.Passive
              and then S.Channels (Front_Right).Current = Channel.Passive
              and then S.Channels (Rear_Left).Current = Channel.Passive
              and then (P.Rear_Axle_Combined or else S.Channels (Rear_Right).Current = Channel.Passive));
      pragma Assert (if not Enabled then All_Passive (O) and then not O.Pump);
   end Step;

end Antilock.Controller;
