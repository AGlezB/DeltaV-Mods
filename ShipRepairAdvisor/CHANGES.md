# ShipRepairAdvisor - Changes

## 1.0.2
- Park repairs only the pieces on the hardpoints, the thrusters and the LIDAR, whose condition sets what they trade in
  for at the Equipment screen. It leaves every other system as it is: the other slots (the reactor, the turbine, the
  MPU, …) trade in at full price whatever their condition, and the systems on no slot (the HUD, the cabin light, …)
  are never traded in, so repairing them only spent the cash the ship is readied to hold. Its confirmation's question
  says so, and its note names only those pieces when no button brings them to `_SRA_PARK_TARGET`.
- `Code.gd`: new function `_sraSlotMembers`; `_sraParkInfo` keeps the screen's slots in `pieceSlots`.
- README: Park's summary, *Why*, third step and notes, and *For modders*.

## 1.0.1
- Licensed under the MIT License instead of the GNU GPLv3: the LICENSE in the zip and the README's *About* and
  *Disclaimer* say so.
