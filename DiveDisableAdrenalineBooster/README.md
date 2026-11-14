# DiveDisableAdrenalineBooster - ΔV: Rings of Saturn

Version 1.0.0. The Adrenaline Booster of your ship starts every dive switched off.

## What it does and why
- **What:** when a dive starts, the booster is off on the player's ship. In the `Mechanic` tab of the
  management screen (`J` by default) its switch shows as off, and it can be switched on there at any time.
  What you choose during the dive is kept, also when the ship is replaced by a teleport.
- **Why:** every ship component starts enabled, including the booster, and the booster is a slow-down effect
  that some players do not want unless they ask for it.
- Only the ship the player controls is changed. Other ships and the booster's own behaviour are left alone.

## For modders
- Script extension of `res://ships/CabinLight.gd` (`installScriptExtension` in `ModMain.gd`), which is the
  Adrenaline Booster (`systemName == "SYSTEM_ADRENALINE_BOOSTER"`). The tag `group = CabinLight` in
  `Mod.manifest` names that game script.
- Overrides `_ready` only, which does not call the parent's: the mod loader runs the base first, so `ship` is
  set when the override runs.
- The Mechanic tab toggles the system's `enabled` property (`hud/SystemList.gd`), and `CabinLight.gd` stops
  adding adrenaline while it is false. The mod sets that property.
- The game creates the player's ship from its saved configuration at the start of every dive
  (`Game.gd`, `_respawn_ship`) and sets `playerControlled` before it enters the scene, hence
  `ship.isPlayerControlled()`. A replacement ship after a teleport gets `enabled` copied from the old one
  once it is set up (also `_respawn_ship`), which is what keeps the player's choice.
- No constants and no members, so nothing to clash with other mods on the same script.
- Tested only outside the game, in a headless Godot 3.5.3 with the game's `CabinLight.gd` and stubs. It has not
  been checked in a real game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put `DiveDisableAdrenalineBooster-1.0.0.zip` in it. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).
