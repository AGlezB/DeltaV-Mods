# WeaponMaxPowerSwitch - ΔV: Rings of Saturn

A switch in the OMS Mechanic tab, and a key, fire your ship's weapons at their highest power until you switch them
back; every dive starts with the switch off.

## Warning
This mod changes how the game plays. Compared to vanilla, while its switch is on:
- your mass drivers, lasers and microwave emitters fire at the highest power their Tuning allows, whatever you set
  there, so they draw more power, wear faster (a weapon's wear grows with the square of its power:
  `weapons/massdriver.gd`, `laser.gd`, `emp.gd`) and, for a mass driver, kick harder;
- the CL-600P pulse mining laser fires at its lowest Pulse frequency, and the CL-200AP pulse mining laser at its
  highest;
- so part of the ship's Tuning, which the game lets you change only at the station, changes during a dive.

With the switch off, the weapons fire as you tuned them, as in vanilla.

Before reporting a bug with a weapon, its power or its wear to the game's developers, check that it also happens
without the mod.

## What it does and why
- **What:** the first row of the OMS Mechanic tab (the Onboard Maintenance System, `J` by default) is a switch, with
  the mod's key beside it (`KEY` in `Shared.gd`). While it is on, every mass driver, laser and microwave emitter of your
  ship, on a hardpoint or a turret, fires at the highest power its Tuning slider allows (the entries in
  `_WMPS_HIGHEST`): the top of its own slider, half again its default. A pulse laser's Pulse frequency goes to the end
  it fights best at (`_WMPS_FREQUENCY`): the CL-600P's lowest, where its pulses are fewest and strongest, all of their
  damage kinetic, enough to make a reactor leak; the CL-200AP's highest, since its pulses are only ever heat.
  Everything else keeps your Tuning: a microwave emitter's Water Resonance, whose best is the same for mining and for
  fighting; the exhaust weapons' Thrust, which adds no damage that counts at its highest; the SPC Gungnir, which has
  no Tuning; and every other piece of equipment. Switched off, every weapon fires as tuned again. Your Tuning itself
  is never changed.
- **The row:** it shows only while your ship has a weapon the switch changes, coloured as the game colours a system
  that is on or off. The switch clicks as the game's own switches do.
- **The key:** it works with the OMS closed too, and plays your ship's alarm (the one a full storage sounds) to say
  which way it switched: more times for on (`_WMPS_ALARM_ON`) than for off (`_WMPS_ALARM_OFF`). Both play at the same
  pitch, so the count still tells them apart in bullet time, which slows the alarm down. Pressed again while the alarm
  sounds, it cuts it short and plays the new count. It does nothing during a cutscene, or on a ship with no weapon the
  switch changes.
- **The red light:** while the switch is on, your ship's cabin light is red (`_WMPS_LIGHT_COLOR`), however you
  switched it: the cabin's glow, and the light it casts on the ship and around it where the game's *Lights* setting
  shows it.
- **Every dive starts with it off:** the game builds your ship anew for every dive, and for the simulator, and the
  switch belongs to that ship, not to the save.
- **Why:** the game sets a weapon's power and pulse frequency only in the Tuning screen, at the station, so one
  setting serves the whole dive: low power to spare the reactor and the weapons while mining, or high power for a
  fight. The switch gives you full power when a fight comes, and your own Tuning back when it is over.
- **What you can change inside the zip:** `_WMPS_HIGHEST`, `_WMPS_FREQUENCY` and `_WMPS_LIGHT_COLOR` at the top of
  `WeaponMaxPowerSwitch/Code.gd`, `_WMPS_ALARM_ON` and `_WMPS_ALARM_OFF` at the top of `MechanicTab.gd`, and `KEY` in
  `Shared.gd`.

## For modders
- Files: `Code.gd` (the switch and the light, a script extension of the ship), `MechanicTab.gd` (the row and the key,
  a script extension of the Mechanic tab's list), `Shared.gd` (the key, static functions in a script never instanced)
  and `i18n/en.po` (the row's texts).
- Script extensions (`installScriptExtension` in `ModMain.gd`, in that order) of `res://ships/ship-ctrl.gd`, the script
  of every ship (`Code.gd`), and of `res://hud/SystemList.gd`, the OMS Mechanic tab's list (`MechanicTab.gd`). That
  list, the only one with `toggleSystem` on, lives in `hud/OMS.tscn`, which the HUD scene holds as an instance
  placeholder, so it loads when a HUD builds its OMS, long after the mods are installed; the Eagle Prospector's HUD has
  another list of that script (`hud/Display-Prospector.tscn`), without `toggleSystem`, which the mod leaves alone.
  `ModMain.gd` also loads `i18n/en.po` and adds the key's input action (`Shared.gd` `addKey()`). The tag
  `group = Weapons` in `Mod.manifest` names the part of the game the mod changes.
- **The power:** every system reads its Tuning through the ship's `getTunedValue(system, tune, default)`, the game's
  only read of it, and mass drivers, lasers and microwave emitters read it every frame they fire (`getPowerDraw`,
  `getFrequency`), so a switch applies at once. The override (`Code.gd`), while the switch is on, returns the end set
  for the weapon's slot name (its `slotName`, the key of its Tuning, which starts with `_WMPS_SLOT_PREFIX` on a
  hardpoint: `ships/WeaponSlot.gd` `loadPlaceholder`, `ships/modules/PDT.gd` `_setSlotName`) and entry, and falls
  through to the parent with `.getTunedValue()` for everything else. The ends come from each weapon's own
  `getTuneables()`, as the Tuning screen draws its sliders: the `max` of each entry in `_WMPS_HIGHEST`, and for a laser
  named in `_WMPS_FREQUENCY` (by its `systemName`; the CL-200AP's laser is `SYSTEM_CL200P`,
  `ships/modules/act-laser.tscn`) the `min` or `max` of `_WMPS_FREQUENCY_KEY`. `_wmpsWeapons()` finds the weapons by
  walking the ship's nodes (`_wmpsScan`): a node with `getTuneables` and a hardpoint's `slotName`, but no `system`, with
  at least one entry of `_WMPS_HIGHEST` (`_wmpsEndsOf`), which leaves out the arm and the drone plants. A hardpoint and
  a turret hold their weapon as `system` and pass its Tuning on, so the weapon itself is found under them. It works
  them out once, and again when the ship's systems change (`systemsChanged`, which `fillInSystems` emits only on a
  change). Nothing is written: the ship's config stays as the player tuned it.
- **Only the player's ship, off at every dive:** `_wmpsSetOn(how)` switches on only while `isPlayerControlled()`. The
  switch is a member of the ship (`_wmpsOn`), and the game builds the player's ship anew for every dive (`Game.gd`
  `_respawn_ship`, `CurrentGame.gd` `createPlayerShip`), for the station and for the simulator, so it always starts
  off.
- **The light:** `_wmpsLight(on)` tints every cabin light of the ship (`ships/CabinLight.gd` with `systemName`
  `_WMPS_CABIN_LIGHT`, the Adrenaline booster's node, in every ship the player can fly; `_wmpsCabinLights`): its
  `modulate` and its spotlight's `color` (`lightNode`, a `Light2D`), kept first in `_wmpsLightWas` and put back when
  switched off. `CabinLight.gd` sets only the glow's alpha (`self_modulate`) and the spotlight's energy and visibility
  (`Settings.cfg.display.lights` against `lightEssentiality`), never a colour, so the tint holds. DiveDisableAdrenalineBooster
  extends `CabinLight.gd` only to switch the booster off when a dive starts, which leaves the colours alone.
- **The row** (`MechanicTab.gd`): built on the list's first `update()` once the ship is set up, cell by cell as the
  game lays out a system's row (`update`, `makeTogglerFor`, `makeLabelFor`, `makeCtrlsFor`, and `damageLabel({})` for
  the damage columns a system leaves empty), so the columns stay aligned: the switch (`toggleButton`,
  `hud/components/PowerToggleCheckBox.tscn`, with `_WMPS_TOOLTIP`), the name (`_WMPS_ROW`), the key hint (`cscd`, with
  the key's action) and the damage columns (`detailedDamage`), in the order `hotkeysFirst` sets. The game only ever adds
  rows at the end, and `_wmpsRow()` keeps the row's cells first (`move_child`), hides them while the ship has no weapon
  the switch changes (a GridContainer leaves hidden cells out), shows the switch's state, and colours the name, the
  switch and the key as the game colours a system on or off at full power (`colorOk`, `colorOff`). `update()` falls
  through to the parent with `.update()`; the game runs it every `readEvery` seconds while the tab shows, and when the
  ship's systems change. The switch (`_wmpsSwitched()`) plays the list's click (`clickSound`), as the game's own
  switches do (`toggle`). It is the game's switch, so with a gamepad it takes the focus, A presses it, and its own
  tooltip node (`menu/sfx/PlaySoundsOnTheseButtons.tscn`) shows its tooltip.
- **The key:** an input action of the mod's own (`KEY_ACTION`), bound to `KEY` by scancode as the game binds its letter
  keys (`project.godot`), added once by `addKey()`. No action or script of the game uses the key, and the game's
  controls settings remap only their own actions (`Settings.gd` `inputs`), so the game neither uses nor remaps it.
  `_input` (the game's script has none) answers it while the list's ship is set up, flown by the player, not in a
  cutscene (as `ships/WeaponSlot.gd` `_input` gates a hardpoint's key) and has a weapon the switch changes. The list
  exists from the moment the HUD builds its OMS (`hud/Hud.gd` `instance()`), so the key works with the OMS closed.
- **The key's sound** (`_wmpsAlarm(times)`): the ship's alarm (`ship-ctrl.gd` `playerAlert`, its `Noises/Alert`, each
  ship model's own sound), `_WMPS_ALARM_ON` times in a row for on and `_WMPS_ALARM_OFF` for off, each play right after
  the last (`finished`, `_wmpsAlarmFinished()`), as the game repeats its own alarm (`avFeedback`). It plays on a copy of
  the ship's player, made once beside it (`duplicate()`: its stream, volume, bus and script, `sfx/PitchAdjustedAudio.gd`,
  which slows it with bullet time), since the ship stops its own player every frame while no alarm is raised
  (`avFeedback`). A new cue restarts the copy and drops the plays the last one had left (`_wmpsAlarmLeft`). The copy
  sits beside the ship's alarm rather than in the list, whose children other mods may count on. The key doesn't click,
  and the switch doesn't play the alarm.
- Overrides: `getTunedValue(system, tune, default)` in `Code.gd` and `update()` in `MechanicTab.gd`, ordinary functions
  that fall through to the parent; `_input(event)` in `MechanicTab.gd`, which the game's script doesn't have. No
  `_ready` or `_process`.
- Members of `Code.gd`: `_WMPS_HIGHEST`, `_WMPS_FREQUENCY_KEY`, `_WMPS_FREQUENCY`, `_WMPS_SLOT_PREFIX`,
  `_WMPS_CABIN_LIGHT`, `_WMPS_LIGHT_COLOR`, `_wmpsOn`, `_wmpsEnds`, `_wmpsLightWas`, `_wmpsIsOn()`, `_wmpsSetOn(how)`,
  `_wmpsLight(on)`, `_wmpsCabinLights(node)`, `_wmpsWeapons()`, `_wmpsSystemsChanged(systems)`, `_wmpsScan(node, ends)`
  and `_wmpsEndsOf(weapon)`. Of `MechanicTab.gd`: `WeaponMaxPowerSwitch` (preload of `Shared.gd`), `_WMPS_ROW`,
  `_WMPS_TOOLTIP`, `_WMPS_ALARM_ON`, `_WMPS_ALARM_OFF`, `_wmpsCells`, `_wmpsSwitch`, `_wmpsLabel`, `_wmpsKeys`,
  `_wmpsAlarmPlayer`, `_wmpsAlarmLeft`, `_wmpsAlarm(times)`, `_wmpsAlarmFinished()`, `_wmpsReady()`, `_wmpsRow()`,
  `_wmpsBuild()`, `_wmpsKeyHint()` and `_wmpsSwitched()`. `Shared.gd`: `KEY_ACTION`, `KEY` and `addKey()`.
- Stacks with DiveSkipTransit and GeologyByMass, which extend `ship-ctrl.gd` too (other functions), and with
  DiveDisableAdrenalineBooster (above).
- Tested only outside the game, in a headless Godot 3.6 (the `power` suite of the repository's test harness): the
  switch on ships of the game's `ship-ctrl.gd`, out of the tree, with the game's `massdriver.gd`, `laser.gd` and
  `emp.gd` held by its `WeaponSlot.gd` and `PDT.gd`, and its `CabinLight.gd`; the row, the key, the alarm's cues and the
  gamepad on the game's `SystemList.gd` with its row parts, the alarm on its `PitchAdjustedAudio.gd`. Also with
  DiveSkipTransit and GeologyByMass loaded, in every order (`power`, `skip`), and with DiveDisableAdrenalineBooster
  (`power`, `dive`). The real check is playing the game.

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
