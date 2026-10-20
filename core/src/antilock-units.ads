--  Integer units of the controller: speeds in millimetres per second,
--  accelerations in millimetres per second squared, slip in permille,
--  pressures in kilopascals, durations in microseconds.
package Antilock.Units with Pure, SPARK_Mode is

   type Speed is range 0 .. 120_000;
   --  mm/s. 120 m/s is 432 km/h.

   type Acceleration is range -200_000 .. 200_000;
   --  mm/s2, forward positive. 200 m/s2 is about 20 g.

   type Permille is range 0 .. 1_000;

   type Pressure is range 0 .. 30_000;
   --  kPa. 30 000 kPa is 300 bar.

   type Microseconds is range 0 .. 2_000_000_000;
   --  A duration of at most 2 000 s.

   type Millivolts is range 0 .. 60_000;

   type Tooth_Count is range 12 .. 200;

   type Circumference is range 500 .. 5_000;
   --  mm, the rolling circumference of the tire.

   type Map_Index is range 1 .. 12;
   subtype Active_Map is Map_Index range 1 .. 11;
   Off_Position : constant Map_Index := 12;

   --  A duration sum that saturates at the type's bound.
   function Saturating_Add (A, B : Microseconds) return Microseconds is
     (if A > Microseconds'Last - B then Microseconds'Last else A + B);

end Antilock.Units;
