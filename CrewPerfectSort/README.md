# CrewPerfectSort - ΔV: Rings of Saturn

Sorts the crew lists: at Enceladus Prime, the Hire screen by salary, then occupation, and Your Crew by occupation, then
salary; in a dive, the crew a derelict's conversation offers to send over on EVA, as Your Crew.

## What it does and why
- **What:**
  - **Hire** screen: by **salary** (cheapest first), then by **occupation** (plain string order, so Astrogator,
    Geologist, Mechanic, Pilot).
  - **Your Crew** screen: by **occupation**, then by **salary** (lowest first).
  - **EVA** choice: when a derelict's conversation offers to send one of the crew over to restart it, the crew aboard
    are listed as on Your Crew, instead of in the order they were hired.

  Entries that are equal in both are ordered by name, so the order never shuffles. On the Hire screen the keyboard
  and gamepad focus starts on the first entry of the sorted list.
- **Why:** the cheapest people for hire come first, and your crew is grouped by job, each job's cheapest first,
  wherever you pick one of them.

## For modders
- Script extensions of `res://enceladus/HireableCrew.gd` (the Hire screen, `HireableCrewSorted.gd`), of
  `res://enceladus/CurrentCrewManagement.gd` (the Your Crew screen, `CurrentCrewManagementSorted.gd`) and of
  `res://CurrentGame.gd` (the autoload, `EvaCrewSorted.gd`), installed with `installScriptExtension` in `ModMain.gd`'s
  `_init`, so the last applies to the autoload, which the engine creates afterwards. The tag `group = HireableCrew`
  in `Mod.manifest` names the first.
- The two screens override `fillCrew`, call the parent's first, then reorder the entries the game has just added
  (`_before` compares two), so the list is already in order when it is shown. The Hire screen focuses its
  `firstItem`, the entry the game put first, so the extension sets it to the new first entry and focuses it.
- The EVA choice: a derelict's conversation (`comms/conversation/subtrees/DIALOG_DERELICT_RANDOM.tscn`) has one reply
  per crew member aboard, `DIALOG_DERELICT_SWITCH_CREW|<n>` with the agenda `CREW/<n>`, which asks
  `CurrentGame.getSpecificMemberNr(n)` for the n-th of `getActiveMembers()`: `state.crew`, in the order the crew was
  hired (`comms/ConversationPlayer.gd` `getAgendaMember`). `EvaCrewSorted.gd` overrides `getSpecificMemberNr` to sort
  them first (`_cpsBefore`). Only those replies call it: `getRandomMember`, which picks who reports the derelict, keeps
  the game's order, and nothing changes in the save.
- `Shared.gd` holds the code the scripts share, static, reached through the constant `CrewPerfectSort`: the Your Crew
  order (`yourCrewBefore`), which both the Your Crew screen and the EVA choice sort by.
- Other mods can extend the same scripts: this mod only reorders the entries the game has added, so what another mod
  puts on them stays, and of `CurrentGame.gd` it overrides only `getSpecificMemberNr`.
- Tested in the harness's `crew` suite, also beside another mod that marks the Hire screen's entries: the Hire screen's
  order, and the EVA choice's from crew hired in another order, with benched and on-leave crew left out. The Your Crew
  screen is tested only in the game.
- A game update that changes those scripts can break the screens or the EVA choice: if one misbehaves, remove the
  mod.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the MIT License.

## Disclaimer
ΔV: Rings of Saturn is made and owned by Kodera Software. The game's name, and everything from the game this mod uses
or shows, belong to Kodera Software.

The author of this mod has no tie of any kind to the game or to Kodera Software. Kodera Software didn't make,
check or approve this mod, and doesn't support it.

This mod is provided as is, for free, and without warranty of any kind, express or implied: use it at your own risk.
The MIT License it is licensed under says so in full.
