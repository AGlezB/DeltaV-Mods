# CrewPerfectSort - Changes

## NEXT
- Adds this CHANGES.md.
- The README no longer states the version (it is in `Mod.manifest` and here), and its Install step says to remove
  any other version of the mod from the `mods` folder.

## 1.1.1
- Adds a `Mod.manifest` (ManifestV2.2).
- The README ends with a note: made with the help of Claude, licensed under the GNU GPLv3.

## 1.1.0
- Rewritten as script extensions of the game's Hire and Your crew screens (`enceladus/HireableCrew.gd`,
  `enceladus/CurrentCrewManagement.gd`). The lists are sorted inside the game's own `fillCrew()`, right after the
  game fills them, instead of after a timer: they appear already in order, and nothing jumps.
- On the Hire screen, keyboard and gamepad focus starts on the top sorted entry by itself, without the extra signal
  hooks 1.0.1 needed.
- Entries equal in both sort keys are ordered by name, so they no longer swap places when the list refreshes.
- Because it extends two game scripts, a game update to them can break those screens; if one misbehaves, remove the
  mod.

## 1.0.1
- Fix: the Hire screen started keyboard and gamepad focus on the entry the game had put first, which after sorting
  is in the middle of the list, so pressing A on a gamepad could hire the wrong candidate. Focus now moves to the
  top of the sorted list, also when a candidate is hired or leaves.
