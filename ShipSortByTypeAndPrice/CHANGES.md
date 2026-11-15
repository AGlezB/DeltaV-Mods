# ShipSortByTypeAndPrice - Changes

## NEXT
- The code moved from `ModMain.gd` to `ShipSortByTypeAndPrice/Code.gd`, which `ModMain.gd` now adds as a node. No
  change in behaviour.
- Adds this CHANGES.md.
- The README no longer states the version (it is in `Mod.manifest` and here), and its Install step says to remove
  any other version of the mod from the `mods` folder.

## 1.0.2
- Adds a `Mod.manifest` (ManifestV2.2).
- The README ends with a note: made with the help of Claude, licensed under the GNU GPLv3.

## 1.0.1
- Fix: a ship fills in its type and price a few frames after it is added to the dealer list, but the mod sorted
  only once, after a fixed wait. On a fresh start it could sort before that data was there, and the list stayed out
  of order until the next in-game hour. It now also sorts again when each entry finishes filling in (its `done`
  signal).
