# TurretLockableFacing - ΔV: Rings of Saturn

A switch in the OMS Mechanic tab, and a key, lock your ship's turrets facing where their hardpoints point, turned by an
angle you set, so that they fire where you aim the ship, and only while you hold the trigger.

## Warning
This mod changes how the game plays. Compared to vanilla, while the facing lock is on (every dive starts with it off):
- your ship's turrets (the NDPT-4205 and the ONMWG-650) no longer pick targets or aim at them: each one faces where a
  fixed weapon on its hardpoint would point, turned by the angle set in its row;
- they fire only while you hold the trigger, at its power: the ONMWG-650 no longer fires by itself.

Before reporting a bug with turrets to the game's developers, check that it also happens without the mod.

## What it does and why
- **What:** while your ship has a turret, the Onboard Maintenance System's Mechanic tab (OMS, `J` by default) ends with
  a LOCK FACING row: a switch, the key that does the same (`KEY`), and an ANGLE slider where the other rows have their
  jury-rig sliders, from -`FACING_ANGLE_MAX` to +`FACING_ANGLE_MAX` degrees in steps of `FACING_ANGLE_STEP`. The switch
  clicks as the game's switches do; the key is silent, as the game's keys for hardpoints are.
- **Locked:** each turret turns to its hardpoint's direction, where a fixed weapon on that hardpoint would point,
  and stays there as the ship turns. The side versions of a turret (`-L`, `-R`, for the left and right hardpoints),
  which rest turned outward, turn back to it too. The turret fires while you hold the trigger, with the
  power the trigger gives, and never by itself. Unlocked, it picks targets and fires as the game has it.
- **The angle** turns each locked turret further, mirrored across the ship: a positive angle turns the turrets on the
  left to the right and those on the right to the left, so their lines of fire meet ahead (`||` becomes `/\`); a
  negative angle spreads them (`\/`). A turret on the ship's centre line turns right for a positive angle. Turrets
  that face a side (the OCP-209's side bay) mirror across the line through the ship's middle from side to side: for a
  positive angle the front one turns back and the back one forward, so they meet out to that side.
- **Kept:** the lock is off at the start of every dive (and in the simulator), and isn't saved. Each ship keeps its
  angle with its own settings, saved with the game, for the turrets it was set with: put another turret on one of its
  hardpoints and the angle reads `FACING_ANGLE_DEFAULT` until the old turrets are back.
- **What not:** only the turrets, the mounts that turn all the way round. The AEMD-14 mass driver and the CL-200AP
  pulse mining laser turn only a little, and are left as the game has them, as are every fixed weapon and every other
  ship's turrets.
- **Why:** a turret is nearly impossible to aim at a specific target: it picks its own. Locked, it fires where you
  point the ship, as a fixed weapon does. The angle moves where the turrets' shots meet, since straight ahead isn't
  always best.
- The key (`KEY`) and the angle's default, range and step (`FACING_ANGLE_DEFAULT`, `FACING_ANGLE_MAX`,
  `FACING_ANGLE_STEP`) are constants at the top of `TurretLockableFacing/Shared.gd`, which you may edit inside the zip.
  The row's texts are in `TurretLockableFacing/i18n/en.po`.

## For modders
- Two script extensions (`installScriptExtension` in `ModMain.gd`): `Code.gd` of `res://ships/modules/PDT.gd`, the
  gimballed mounts (every turret, and the AEMD-14 and CL-200AP), and `MechanicTab.gd` of `res://hud/SystemList.gd`,
  the OMS's lists of systems. The tag `group = PDT` in `Mod.manifest` names the first. Code both use is in `Shared.gd`
  (static, never instanced), reached through the preload constant `TurretLockableFacing`.
- **A turret** is a mount with no gimbal limit (`gimbalLimit < 0`): the NDPT-4205 (`ships/modules/PDT-minigun.tscn`)
  and the ONMWG-650 (`PDT-microwave.tscn`). The AEMD-14 and CL-200AP (`act-massdriver.tscn`, `act-laser.tscn`) set
  `gimbalLimit`, so the mod leaves them alone: they join no group and `getTarget` falls through.
- **The lock** is a metadata of the player's ship node (`LOCK_META`). The game builds that node anew for every dive and
  for the simulator, so every dive starts unlocked and nothing is saved. `Shared.gd` `setLocked` tells every turret of
  the ship at once (the group `MOUNTS_GROUP`, filtered by ship): an idle turret has its physics frames off.
- **A locked turret** finds no target (`getTarget` returns null), so the game's `PDT.gd` `_physics_process` takes its
  path without one: it fires the weapon with `firepower` (what the ship's `w` command sets through `fire`, the trigger)
  when `fireWithNoLock` is on, and turns the turret back to its rest when `returnToDefault` is on. While locked, the
  mod sets `fireWithNoLock` on and `returnToDefault` off, keeps the physics frames on, and turns the pivot itself in its
  own `_physics_process` (Godot runs the child's first): towards a point straight ahead of the hardpoint, as the game
  aims at a target (`angle_to_point` plus `aimOffset`), at `rotationPerSecond`, drawing `powerDraw` and turning only
  with more than `_TLF_POWER_NEEDED` of it, and no longer once within `_TLF_ALIGNED`. The game stops the actuation sound
  in every frame it doesn't turn the turret itself, so this turn is silent. Unlocked, the scene's `fireWithNoLock` and
  `returnToDefault` come back, a weapon that fires only at a target stops (`system.fire(0)`), and the physics frames
  stay as the game's `_on_DefendArea_body_entered` and `_exited` would leave them. A ship the player doesn't fly is
  never locked.
- **The hardpoint's direction** is the parent's `global_rotation` (`ships/WeaponSlot.gd`). That is the turret's rest
  except for the side versions, the `-L` and `-R` nodes of `weapons/WeaponSlot.tscn`, which the scene turns outward on
  their hardpoint.
- **The mirror** runs through the ship's centre along the hardpoint's direction squared to the ship's nearest axis: the
  nose line for turrets facing forward, or nearly (the K225's bays, turned 30° outward, whose forward position would
  otherwise put them on the wrong side), and the line across the ship for turrets facing a side (the OCP-209's side
  bay, whose front hardpoint the game calls `mainLeft` and its back one `mainRight`). The side is as seen looking along
  that direction; within `_TLF_CENTRE` of the line counts as on it. Hardpoints never move, so the side is found once.
- **The angle** is kept in the ship's tuning (`ship-ctrl.gd` `getConfig("tuning")`, the game's per-ship store of its
  systems' settings, saved with the game and carried with the ship), as one entry under the mod's id from
  `Mod.manifest`: `formatVersion` (`FORMAT_VERSION`), `modVersion`, `angle`, and `weapons`, each turret's `slotName`
  sorted (the game's key for a weapon's tuning, `weaponSlot.<slot>.type_<mount>_<weapon>`), so another turret on a
  hardpoint makes another list. The player's ship works on the save's own config (`CurrentGame.gd` `createPlayerShip`),
  so a change in flight is saved as the game's own are. Reading never writes: a value that isn't a number, or another
  list of turrets, gives `FACING_ANGLE_DEFAULT`, and the rest is snapped to `FACING_ANGLE_STEP` and kept in range.
  Removing the mod leaves the entry in the ship's tuning, where the game ignores it.
- **The row** belongs only to the list with `toggleSystem` on: the Mechanic tab's (`hud/OMS.tscn`). `update` calls the
  parent's, which adds the rows of new systems at the end, then moves the row back there. It is built cell for cell as
  the game builds a system's row (`update`, `makeTogglerFor`, `makeLabelFor`, `makeCtrlsFor`), so the columns stay
  aligned: the list's `toggleButton` (`hud/components/PowerToggleCheckBox.tscn`), the name, the key hint (`cscd`), and
  one `damageLabelResource` (`hud/components/DamageLabel.tscn`) as the angle, its jury-rig slider given the angle's
  range, then blank cells. A `GridContainer` leaves hidden cells out, so the row takes no place on a ship without a
  turret. It is coloured with the list's `colorOk` and `colorOff`, and the switch plays the list's `clickSound`, as the
  game's `toggle` does. The angle's cell keeps the game's mouse and gamepad handling (`RepeatingHSlider.gd`), and its
  name is the angle, signed, in whole degrees or with its decimals (`TURRETLOCKABLEFACING_ANGLE`); `DamageLabel.gd`
  gives the name and the slider the tooltip `<name>_TOOLTIP`.
- **The key** is an input action of the mod's own (`KEY_ACTION`), bound to `KEY` by scancode as the game binds its
  letter keys (`project.godot`), added once by `ModMain.gd` (`Shared.gd` `addKey`). No action or script of the game
  uses the key, and the game's controls settings remap only their own actions (`Settings.gd` `loadKeymapFromConfig`).
  `MechanicTab.gd` `_input` (the game's script has none) switches the lock as `ships/WeaponSlot.gd` `_input` switches a
  hardpoint: on the player's ship, outside cutscenes, and only while it has a turret.
- **The texts.** `i18n/en.po` holds the row's name, its tooltip, the angle's text and its tooltip. `ModMain.gd` loads
  it with `load()` and `TranslationServer.add_translation`, as the game loads its own `.po` files. English is Godot's
  fallback language, so every language shows it until it gets its own file.
- **Stacking.** CombatSimulator's `Turret.gd` extends `PDT.gd` too (`fire`, `perhapsFire`); by path the chain is game ←
  CombatSimulator ← TurretLockableFacing. It disarms a turret by zeroing `firepower`, which a locked turret fires with,
  so a disarmed turret stays disarmed. WeaponMaxPowerSwitch's `MechanicTab.gd` extends `SystemList.gd` too; by path
  the chain is game ← TurretLockableFacing ← WeaponMaxPowerSwitch. It keeps its row first and this mod keeps its row
  last, each moving only its own cells, and their keys differ. `getTarget` falls through to the parent with
  `.getTarget()`, and `update` with
  `.update()`; `_ready` and `_physics_process` never call the parent's (Godot runs them at every level).
- Members. `Code.gd`: the constants `_TLF_ALIGNED`, `_TLF_POWER_NEEDED` and `_TLF_CENTRE`; the variables
  `_tlfHardpoint`, `_tlfFireWithNoLock`, `_tlfReturnToDefault`, `_tlfApplied`, `_tlfSide` and `_tlfAngle`; the
  functions `_tlfRefresh()`, `_tlfTurret()`, `_tlfLocked()`, `_tlfTurn()` and `_tlfSideOf()`; overrides `_ready`,
  `getTarget` and `_physics_process`. `MechanicTab.gd`: the constants `_TLF_ROW`, `_TLF_TOOLTIP` and `_TLF_ANGLE`; the
  variables `_tlfCells`, `_tlfSwitch`, `_tlfLabel`, `_tlfKeys` and `_tlfAngleCell`; the functions `_tlfRow()`,
  `_tlfBuild()`, `_tlfAngleSlider()`, `_tlfAngleSync()`, `_tlfAngleChanged()`, `_tlfAngleName()`, `_tlfKeyHint()` and
  `_tlfSwitched()`; overrides `update`, and adds `_input`. `Shared.gd`: `LOCK_META`, `MOUNTS_GROUP`, `KEY_ACTION`,
  `KEY`, the `FACING_ANGLE_*` constants, `FORMAT_VERSION`, `addKey()`, `mounts()`, `isLocked()`, `setLocked()`,
  `weapons()`, `angle()`, `setAngle()`, `modId()` and `modVersion()`.
- Tested outside the game, in a headless Godot 3.6 with the game's `PDT.gd`, `SystemList.gd`, `DamageLabel.gd` and
  the Mechanic tab's switch and damage cell, on stub ships, hardpoints and weapons (the `turret` suite of the
  repository's test harness, also with CombatSimulator, as is its `combat` suite, and with WeaponMaxPowerSwitch, as
  is its `power` suite). The real check is playing the game.

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
