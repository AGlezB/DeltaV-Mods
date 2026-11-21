# CrewPerfectSort - ΔV: Rings of Saturn

Sorts the crew lists at Enceladus Prime: the Hire screen by salary, then occupation; Your Crew by occupation, then
salary.

## What it does and why
- **What:**
  - **Hire** screen: by **salary** (cheapest first), then by **occupation** (plain string order, so Astrogator,
    Geologist, Mechanic, Pilot).
  - **Your Crew** screen: by **occupation**, then by **salary** (lowest first).

  Entries that are equal in both are ordered by name, so the order never shuffles. On the Hire screen the keyboard
  and gamepad focus starts on the first entry of the sorted list.
- **Why:** the cheapest people for hire come first, and your crew is grouped by job, each job's cheapest first.

## For modders
- Script extensions of `res://enceladus/HireableCrew.gd` (the Hire screen, `HireableCrewSorted.gd`) and of
  `res://enceladus/CurrentCrewManagement.gd` (the Your Crew screen, `CurrentCrewManagementSorted.gd`),
  installed with `installScriptExtension` in `ModMain.gd`. The tag `group = HireableCrew` in `Mod.manifest` names the
  first.
- Each overrides `fillCrew`, calls the parent's first, then reorders the entries the game has just added (`_before`
  compares two), so the list is already in order when it is shown. The Hire screen focuses its `firstItem`, the entry
  the game put first, so the extension sets it to the new first entry and focuses it.
- CrewCheapHireNotifier extends `HireableCrew.gd` too: by path the chain is game ← CrewCheapHireNotifier ←
  CrewPerfectSort, and this mod only reorders the entries, so their marks stay.
- A game update that changes those two scripts can break the screens: if the Hire or Your Crew screen misbehaves,
  remove the mod.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Do not install it together with `CrewSortByJobAndSalary`, which sorts the same lists.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).

## Disclaimer
ΔV: Rings of Saturn is made and owned by Kodera Software. The game's name, and everything from the game this mod uses
or shows, belong to Kodera Software.

The author of this mod has no tie of any kind to the game or to Kodera Software. Kodera Software didn't make,
check or approve this mod, and doesn't support it.

This mod is provided as is, for free, and without warranty of any kind, express or implied: use it at your own risk.
The GNU GPLv3 it is licensed under says so in full, in its sections 15 and 16.
