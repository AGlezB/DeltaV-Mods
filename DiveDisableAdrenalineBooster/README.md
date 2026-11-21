# DiveDisableAdrenalineBooster - ΔV: Rings of Saturn

The Adrenaline booster of your ship starts every dive switched off.

## Warning
This mod changes how the game plays. Compared to vanilla:
- your ship's Adrenaline booster starts every dive switched off, until you switch it on in the OMS's `Mechanic` tab;
- while it is off, the pilot and the smart camera also get little or no bullet time: a booster that is switched off
  pushes adrenaline down every frame (the game's `ships/CabinLight.gd` `_process`).

Before reporting a bug with the Adrenaline booster or bullet time to the game's developers, check that it also
happens without the mod.

## What it does and why
- **What:** when a dive starts, the booster is off on the player's ship. In the Mechanic tab of the
  Onboard Maintenance System (OMS, `J` by default) its switch shows as off, and it can be switched on there at any time.
  What you choose during the dive is kept, also when the ship is replaced by a teleport.
- **Why:** every ship component starts enabled, including the booster, and the booster is a slow-down effect
  that some players do not want unless they ask for it.
- Only the ship the player controls is changed. Other ships and the booster's own behaviour are left alone.

## For modders
- Script extension of `res://ships/CabinLight.gd` (`installScriptExtension` in `ModMain.gd`), which is the
  Adrenaline booster (`systemName == "SYSTEM_ADRENALINE_BOOSTER"`). The tag `group = CabinLight` in
  `Mod.manifest` names that game script.
- Overrides `_ready` only, which does not call the parent's: Godot runs every level's `_ready`, the base first, so
  `ship` is set when the override runs.
- The Mechanic tab toggles the system's `enabled` property (`hud/SystemList.gd`), and `CabinLight.gd` stops
  adding adrenaline while it is false. The mod sets that property.
- The game creates the player's ship from its saved configuration at the start of every dive
  (`Game.gd`, `_respawn_ship`) and sets `playerControlled` before it enters the scene, hence
  `ship.isPlayerControlled()`. A replacement ship after a teleport gets `enabled` copied from the old one
  once it is set up (also `_respawn_ship`), which is what keeps the player's choice.
- No constants and no members, so nothing to clash with other mods on the same script.
- Tested in the harness (`_tests\`, suite `dive`): a headless Godot 3.6 with the game's `CabinLight.gd` and stubs. The
  real check is playing the game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

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
