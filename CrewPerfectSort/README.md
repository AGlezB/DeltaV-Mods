# CrewPerfectSort - ΔV: Rings of Saturn

Sorts the crew lists at Enceladus Prime:

- **Hire** screen: by **salary** (cheapest first), then by **occupation**
  (plain string order, so Astrogator, Geologist, Mechanic, Pilot).
- **Your crew** screen: by **occupation**, then by **salary** (lowest first).

Entries that are equal in both are ordered by name, so the order never shuffles.
On the Hire screen the keyboard/gamepad focus starts on the first entry of the
sorted list.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Do not install it together with `CrewSortByJobAndSalary`, which sorts the same lists.

## How it works
The game's mod loader can extend a game script. This mod extends
`res://enceladus/HireableCrew.gd` (the Hire screen) and
`res://enceladus/CurrentCrewManagement.gd` (the Your crew screen) and sorts the list
right after the game's own `fillCrew()` has filled it, so the list is already in
order when it is shown.

Because it extends game scripts, a game update that changes those two scripts can
break the screens. If the Hire or Your crew screen misbehaves, remove the mod.

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
