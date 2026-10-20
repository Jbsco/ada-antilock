--  Runs braking scenarios through the controller on the plant model and
--  checks stopping distances, wheel lock times and valve behaviour against
--  limits. Every run writes its trace to out/<name>.csv.
with Ada.Directories;
with Ada.Numerics;
with Ada.Text_IO;
with Antilock.Units; use Antilock.Units;
with Antilock.Channel;
with Antilock.Controller; use Antilock.Controller;
with Antilock.Parameters;
with Antilock.Vehicle;
with Plant;

procedure Scenario_Check is
   use Ada.Text_IO;

   P : constant Antilock.Parameters.Set := Antilock.Vehicle.Params;

   Initial_Speed  : constant Float := 22.2;
   Brake_Start    : constant Float := 0.5;
   Pedal_Ramp     : constant Float := 0.15;
   Master_Max     : constant Float := 8_000.0;
   Switch_On      : constant Float := 50.0;
   Plant_Dt       : constant Float := 0.000_5;
   Stop_Speed     : constant Float := 1.0;
   Lock_Fraction  : constant Float := 0.2;
   Lock_Min_Speed : constant Float := 2.0;
   Supply         : constant Millivolts := 13_800;

   type Result is record
      Distance         : Float := 0.0;
      Max_Lock         : Float := 0.0;
      Release_Steps    : Natural := 0;
      Floor_Violations : Natural := 0;
      Fault            : Fault_Kind := None;
   end record;

   function Image (F : Float; Decimals : Natural) return String is
      Scale : Float := 1.0;
   begin
      for I in 1 .. Decimals loop
         Scale := Scale * 10.0;
      end loop;
      declare
         Whole : constant Integer := Integer (Float'Floor (F * Scale));
         Text  : constant String := Integer'Image (Whole);
         Digits_Text : constant String := Text (Text'First + 1 .. Text'Last);
      begin
         if Decimals = 0 then
            return Digits_Text;
         elsif Digits_Text'Length <= Decimals then
            return "0." & (1 .. Decimals - Digits_Text'Length => '0') & Digits_Text;
         else
            return Digits_Text (Digits_Text'First .. Digits_Text'Last - Decimals) & "." &
                   Digits_Text (Digits_Text'Last - Decimals + 1 .. Digits_Text'Last);
         end if;
      end;
   end Image;

   function Run (Name : String; Roads : Plant.Surfaces; Map : Map_Index) return Result is
      Steps_Per_Loop : constant Positive := Positive (Float (P.Loop_Period_us) / (Plant_Dt * 1.0E6));
      V              : Plant.Vehicle;
      S              : State;
      O              : Outputs;
      I              : Inputs;
      R              : Result;
      Master         : Float := 0.0;
      Start_Position : Float := -1.0;
      Lock_Start     : array (Wheel_Position) of Float := (others => -1.0);
      Trace          : File_Type;
      Step_Count     : Natural := 0;
   begin
      V.Radius := Float (P.Circumference_mm) / 1_000.0 / (2.0 * Ada.Numerics.Pi);
      V.Teeth := Float (P.Teeth);
      Plant.Init (V, Initial_Speed, Roads);
      Init (S, P);
      Create (Trace, Out_File, "out/" & Name & ".csv");
      Put_Line (Trace, "t,v,ref,fl,fr,rl,rr,p_fl,p_fr,p_rl,p_rr,master,fl_phase,fr_phase,rl_phase,rr_phase," &
                       "fl_slip,fr_slip,rl_slip,rr_slip,fl_acc,fr_acc,rl_acc,rr_acc");
      while V.Speed > Stop_Speed and then V.Time < 20.0 loop
         if V.Time >= Brake_Start then
            Master := Float'Min (Master_Max, Master_Max * (V.Time - Brake_Start) / Pedal_Ramp);
            if Start_Position < 0.0 then
               Start_Position := V.Position;
            end if;
         end if;
         if Step_Count mod Steps_Per_Loop = 0 then
            for W in Wheel_Position loop
               I.Wheels (W) := Plant.Sample_Of (V, W);
            end loop;
            I.Longitudinal_Accel := Plant.Longitudinal_Accel (V);
            I.Pedal_Pressure := Pressure (Float'Min (Master, Float (Pressure'Last)));
            I.Pedal_Switch := Master > Switch_On;
            I.Map := Map;
            I.Supply_mV := Supply;
            I.Sensors_OK := True;
            Step (S, I, P, O);
            if S.Reference < P.Speed_Floor and then not All_Passive (O) then
               R.Floor_Violations := R.Floor_Violations + 1;
            end if;
            for W in Wheel_Position loop
               if O.Valves (W).Outlet_Open then
                  R.Release_Steps := R.Release_Steps + 1;
               end if;
            end loop;
            Put (Trace, Image (V.Time, 4) & "," & Image (V.Speed, 3) & "," & Image (Float (S.Reference) / 1_000.0, 3));
            for W in Wheel_Position loop
               Put (Trace, "," & Image (Plant.Wheel_Speed (V, W), 3));
            end loop;
            for W in Wheel_Position loop
               Put (Trace, "," & Image (V.Wheels (W).Pressure, 0));
            end loop;
            Put (Trace, "," & Image (Master, 0));
            for W in Wheel_Position loop
               Put (Trace, "," & Antilock.Channel.Phase'Image (S.Channels (W).Current));
            end loop;
            for W in Wheel_Position loop
               Put (Trace, "," & Permille'Image (S.Channels (W).Slip));
            end loop;
            for W in Wheel_Position loop
               Put (Trace, "," & Acceleration'Image (S.Channels (W).Accel));
            end loop;
            New_Line (Trace);
         end if;
         Plant.Integrate (V, Master, O.Valves, Plant_Dt);
         for W in Wheel_Position loop
            if V.Speed > Lock_Min_Speed and then Plant.Wheel_Speed (V, W) < Lock_Fraction * V.Speed then
               if Lock_Start (W) < 0.0 then
                  Lock_Start (W) := V.Time;
               end if;
               R.Max_Lock := Float'Max (R.Max_Lock, V.Time - Lock_Start (W));
            else
               Lock_Start (W) := -1.0;
            end if;
         end loop;
         Step_Count := Step_Count + 1;
      end loop;
      Close (Trace);
      R.Distance := V.Position - Float'Max (Start_Position, 0.0);
      R.Fault := S.Fault;
      return R;
   end Run;

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Text : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Put_Line ("  FAIL: " & Text);
      end if;
   end Check;

   procedure Surface_Pair (Name : String; Roads : Plant.Surfaces; Distance_Ratio : Float; Lock_Limit : Float) is
      With_Abs : constant Result := Run (Name & "-abs", Roads, 6);
      Without  : constant Result := Run (Name & "-off", Roads, Off_Position);
   begin
      Put_Line (Name & ": abs " & Image (With_Abs.Distance, 1) & " m, lock " & Image (With_Abs.Max_Lock, 2) &
                " s, " & Natural'Image (With_Abs.Release_Steps) & " release steps; off " &
                Image (Without.Distance, 1) & " m, lock " & Image (Without.Max_Lock, 2) & " s");
      Check (With_Abs.Fault = None, Name & ": fault " & Fault_Kind'Image (With_Abs.Fault) & " with ABS");
      Check (Without.Fault = None, Name & ": fault " & Fault_Kind'Image (Without.Fault) & " without ABS");
      Check (With_Abs.Floor_Violations = 0, Name & ": valve energized below the speed floor");
      Check (Without.Release_Steps = 0, Name & ": outlet opened with the map off");
      Check (With_Abs.Max_Lock <= Lock_Limit,
             Name & ": a wheel locked for " & Image (With_Abs.Max_Lock, 2) & " s with ABS");
      Check (With_Abs.Distance <= Distance_Ratio * Without.Distance,
             Name & ": ABS stopping distance exceeds " & Image (Distance_Ratio, 2) & " times the locked distance");
   end Surface_Pair;

begin
   Ada.Directories.Create_Path ("out");
   Surface_Pair ("dry", (others => Plant.Dry_Asphalt), 1.15, 0.3);
   Surface_Pair ("wet", (others => Plant.Wet_Asphalt), 1.15, 0.3);
   Surface_Pair ("snow", (others => Plant.Snow), 1.30, 0.6);
   Surface_Pair ("ice", (others => Plant.Ice), 1.30, 1.0);
   Surface_Pair ("split", (Front_Left => Plant.Wet_Asphalt, Rear_Left => Plant.Wet_Asphalt,
                           Front_Right => Plant.Dry_Asphalt, Rear_Right => Plant.Dry_Asphalt), 1.15, 0.3);
   if Failures = 0 then
      Put_Line ("scenario check: all scenarios within limits");
   else
      Put_Line ("scenario check: FAILED (" & Natural'Image (Failures) & " checks)");
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "scenario check failed");
      raise Program_Error;
   end if;
end Scenario_Check;
