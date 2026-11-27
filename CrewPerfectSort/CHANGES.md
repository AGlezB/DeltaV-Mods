# CrewPerfectSort - Changes

## 1.3.2
- The README no longer names other mods: where the mod meets another one, it says what it does there in general
  terms.
- The README no longer warns against the older mod this one replaced.

## 1.3.1
- Licensed under the MIT License instead of the GNU GPLv3: the LICENSE in the zip and the README's *About* and
  *Disclaimer* say so.

## 1.3.0
- A derelict's conversation, offering to send a crew member over on EVA, lists the crew aboard as Your Crew does (by
  job, then salary lowest first, then name) instead of in the order they were hired: a new script extension of
  `res://CurrentGame.gd`, `EvaCrewSorted.gd`, overrides `getSpecificMemberNr` (new member `_cpsBefore`).
- New `Shared.gd`, the code the scripts share: the Your Crew order, `yourCrewBefore`, moved there from
  `CurrentCrewManagementSorted.gd` `_before`, which now calls it.
- The README and the description in `Mod.manifest` name the EVA choice; the README's *For modders* tells how it was
  tested.

## 1.2.4
- The README is laid out as the others: *What it does and why*, *For modders*, with the game's names of the screens
  (Your Crew).
- Comments and the description in `Mod.manifest` write Your Crew as the game does.

## 1.2.3
- The README's *Disclaimer* no longer names the author.

## 1.2.2
- The README has a new *Disclaimer*: the game belongs to Kodera Software, the author has no tie to it or to the
  company, and the mod is provided as is, for free, without warranty.

## 1.2.1
- The mod's id is now `AGlezB.CrewPerfectSort`, and its author is capitalized the same way (both were lowercase).

## 1.2.0
- The Your crew screen sorts each occupation by salary lowest first (was highest first); the README says so.
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
