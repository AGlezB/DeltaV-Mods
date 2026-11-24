# LidarContactCallout - Changes

## 1.0.1
- A contact first found nearer than `CALLOUT_MIN_RANGE` to the ship, by its exact distance, is no longer called out:
  a ship the arm lets go of (its Pilot tab row went while it was held, and the LIDAR finds it again when let go) or
  something out of the hold. A row found that close isn't said while it stays, even once beyond that range; an object
  with no row, for the rest of the dive. One whose row goes and is found again farther out is New, and one said from
  farther out still gets its Updated callout when marked close.
- New constant `CALLOUT_MIN_RANGE`, which may be edited inside the zip; new function `_calloutTooClose()` and constant
  `_CALLOUT_UNITS_PER_METRE`, which `_calloutValues()` uses too.
