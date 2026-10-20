with Antilock.Wheel;

package body Antilock.Channel with SPARK_Mode is

   -----------
   -- Enter --
   -----------

   procedure Enter (S : in out State; To : Phase) is
   begin
      S.Current := To;
      S.Time_In_Phase := 0;
      S.Pulse_Elapsed := 0;
   end Enter;

   -----------------
   -- Enter_Build --
   -----------------

   procedure Enter_Build (S : in out State; P : Parameters.Set) is
   begin
      Enter (S, Build);
      S.Build_Open := True;
      S.Build_Pulse := P.Build_Pulse_First_us;
   end Enter_Build;

   -------------------
   -- Advance_Build --
   -------------------

   procedure Advance_Build (S : in out State; P : Parameters.Set) is
   begin
      if S.Build_Open then
         if S.Pulse_Elapsed >= S.Build_Pulse then
            S.Build_Open := False;
            S.Pulse_Elapsed := 0;
         end if;
      elsif S.Pulse_Elapsed >= P.Build_Pause_us then
         S.Build_Open := True;
         S.Build_Pulse := P.Build_Pulse_us;
         S.Pulse_Elapsed := 0;
      end if;
   end Advance_Build;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; P : Parameters.Set) is
   begin
      S := (Release_Budget => P.Release_Budget_us, others => <>);
   end Init;

   ----------
   -- Step --
   ----------

   procedure Step (S : in out State; New_Speed : Speed; C : Context; P : Parameters.Set) is
      Dt : constant Microseconds := P.Loop_Period_us;
   begin
      S.Accel := Wheel.Acceleration_Of (S.Wheel_Speed, New_Speed, Dt);
      S.Wheel_Speed := New_Speed;
      S.Slip := Wheel.Slip_Of (New_Speed, C.Reference);

      S.Time_In_Phase := Saturating_Add (S.Time_In_Phase, Dt);
      S.Pulse_Elapsed := Saturating_Add (S.Pulse_Elapsed, Dt);
      S.Window_Elapsed := Saturating_Add (S.Window_Elapsed, Dt);
      if S.Pump_Run_On > Dt then
         S.Pump_Run_On := S.Pump_Run_On - Dt;
      else
         S.Pump_Run_On := 0;
      end if;

      if not C.Enabled then
         if S.Current /= Passive then
            Enter (S, Passive);
         end if;
      else
         case S.Current is
            when Passive =>
               if S.Accel <= -C.Thresholds.Decel_Threshold
                 or else S.Slip >= C.Thresholds.Slip_Release
               then
                  Enter (S, Hold);
               end if;
            when Hold =>
               if S.Slip <= C.Thresholds.Slip_Recover then
                  Enter_Build (S, P);
               elsif S.Accel >= C.Thresholds.Reaccel_Threshold then
                  --  The wheel is recovering under the held pressure.
                  null;
               elsif S.Slip >= C.Thresholds.Slip_Release and then S.Release_Budget >= Dt then
                  Enter (S, Release);
               elsif S.Time_In_Phase >= P.Hold_Max_us and then S.Slip < C.Thresholds.Slip_Release then
                  Enter_Build (S, P);
               end if;
            when Release =>
               if S.Time_In_Phase >= P.Release_Pulse_us
                 or else S.Accel >= C.Thresholds.Reaccel_Threshold
                 or else S.Slip < C.Thresholds.Slip_Release
                 or else S.Release_Budget < Dt
               then
                  Enter (S, Hold);
               end if;
            when Build =>
               if S.Accel <= -C.Thresholds.Decel_Threshold
                 or else S.Slip >= C.Thresholds.Slip_Release
               then
                  Enter (S, Hold);
               elsif S.Time_In_Phase >= P.Build_Max_us then
                  Enter (S, Passive);
               else
                  Advance_Build (S, P);
               end if;
         end case;
      end if;

      if S.Current = Release then
         S.Release_Budget := S.Release_Budget - Dt;
         S.Pump_Run_On := P.Pump_Run_On_us;
      end if;
      if S.Window_Elapsed >= P.Release_Window_us then
         S.Window_Elapsed := 0;
         S.Release_Budget := P.Release_Budget_us;
      end if;

      S.Pump_Request := S.Current = Release or else S.Pump_Run_On > 0;
      S.Command := Command_Of (S);
   end Step;

end Antilock.Channel;
