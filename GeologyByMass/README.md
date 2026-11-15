# GeologyByMass - ΔV: Rings of Saturn

Judges the ore your geologist identifies by the mass of each mineral in it instead of its value, as set on a new tab
of the OMS.

## Warning
This mod changes how the game plays. Compared to vanilla, while the switch on the mod's OMS tab is on, your
geologist's info boxes stay full for chunks holding enough mass of a mineral switched on in the Geologist tab,
whatever the chunk is worth: the *Minimum value* no longer counts. With the switch off the game plays as vanilla; the
mod's OMS tab is there either way.

Before reporting a bug with the info boxes or the Geologist tab to the game's developers, check that it also happens
without the mod.

## What it does and why
- **What:** in a dive, your geologist puts an info box on each chunk they identify. The game shrinks the box (hiding
  its kg list and price) when the chunk falls short of the Geologist tab's settings for the HUD: worth less than its
  *Minimum value*, or holding none of the minerals switched on there. With the mod's switch on, a chunk keeps its full
  box when it holds, of one of the minerals switched on in the Geologist tab, at least the base mass plus the extra
  mass set for that mineral; its value and the *Minimum value* no longer count. The masses are the ones the box
  shows, as your geologist estimates them.
- **Base and extra:** the base is the least mass for every mineral, and each mineral's extra mass is added to it. So
  one slider raises or lowers every mineral's threshold together, keeping the differences between them, and a mineral
  with no extra mass needs just the base.
- **The Geologist tab still applies:** its mineral switches decide which minerals count, as they do in the game. A
  mineral switched off there never keeps a box full, however much of it there is.
- **When it applies:** each box checks again by itself about once a second, so a change shows within a second, as a
  change in the Geologist tab does. A chunk not yet identified is left to the game.
- **Why:** a chunk's value mixes every mineral in it and moves with the market. When you are after a particular
  mineral, its mass is what tells you whether a chunk is worth the trip.
- **Settings:** on the OMS tab right after the Geologist tab.
  - The switch at the top: on, the masses decide; off, the game's *Minimum value* does, as without the mod.
  - The *Base* slider, with the base mass in kg.
  - Then one row per mineral the HUD can switch on in the Geologist tab: a slider with its extra mass (`+` kg), and
    after it the total (`=` kg), the least mass that mineral needs.
  - The sliders are the Geologist tab's own controls: pick the value to change it, then left and right (or drag the
    slider), and accept or cancel to leave. While the switch is off they are dimmed, but you can still set them.
  - They are kept with your ship, next to the Geologist tab's own settings, and saved and loaded with them. A ship
    that never had them starts from the defaults, as it does for the *Minimum value*. A ship's masses from before
    the base slider become its extra masses, over the default base.
  - The switch's default is `ENABLED`, the base slider's default, range, step and unit are `BASE_MASS`, and each
    mineral slider's are `EXTRA_MASS`, all at the top of `GeologyByMass/Settings.gd`, inside the zip.

## For modders
- Three scripts: `Code.gd` (the script extension: the rule, adding the tab), `SettingsUI.gd` (the tab) and
  `Settings.gd` (the settings model both share).
- Script extension of `res://hud/Hud.gd` (`installScriptExtension` in `ModMain.gd`), the script of every ship's HUD
  (`hud/Hud.tscn`, `hud/HudBare.tscn`). The tag `group = Hud` in `Mod.manifest` names it.
- **The rule:** each info box (`hud/MineralMark.gd`) asks, now and then (`mineralConfigReexamine`), whether its chunk
  is still a valid target: `hud/AutopilotOverlay.gd` `isValidMineralTarget` passes the question to the HUD, whose
  `isValidMineralTarget(body)` asks the ship with the HUD's `mineralConfig` (`ships/ship-ctrl.gd`
  `isValidMineralTarget(object, config)`). A "no" plays the box's `diminish` animation. Nothing else calls the HUD's
  `isValidMineralTarget`: the drones and the salvage arm call the ship's with their own settings, so the mod changes
  only the boxes. The mod's override, for the player's ship (`ship.isPlayerControlled()`) with the switch on: an
  identified chunk is valid when some mineral in `mineralConfig.minerals` (the Geologist tab's switches) has at least
  its least mass, the base plus its extra (`getMinMass`). The masses come from the ship's `identifiedObjects[hash(body)][0]`, the kg per mineral the box stores
  (`MineralMark.gd` `scanParent`, then `identifyMinerals` / `identifyValue` -> `ship-ctrl.gd` `addIdentifiedObject`).
  Anything else (the switch off, another ship's HUD, a chunk not in `identifiedObjects`) falls through to the game's.
- **The tab:** the HUD builds the OMS (`hud/OMS.tscn`) in `instance()`, replacing its `Inventory` placeholder. The
  mod's `instance()` calls the parent's, then adds its tab with `call_deferred`: a preheated ship's HUD calls
  `instance()` from its `_ready` before it loads `mineralConfig` from the ship, and the tab shows the values stored
  there. The tab goes into the OMS's own `tabsPath` (`hud/OMS.gd`), right after `CREW_OCCUPATION_GEOLOGIST`, once
  per OMS, and copies that tab's `theme` and `rect_clip_content`. Its node name is its title key, which the game's
  TabContainer draws translated, as it draws the role tabs' keys. Nothing in the game refers to the OMS's tabs by
  index. The tab is a `Tabs` node, as every OMS page is, built from the Geologist tab's own parts
  (`hud/SystemMineralList.gd`): `hud/components/MineralSystemToggle.tscn` for the switch,
  `hud/components/MineralLabel.tscn` for the names (coloured from `CurrentGame.specificMineralColors`, without focus;
  the base row's shows its key, uncoloured) and `hud/components/PriceLabel.tscn`, the *Minimum value* control, for
  the sliders, with the mod's format, range, step, tooltip and bar width (`SLIDER_WIDTH` in `SettingsUI.gd`). A grid
  of three columns: the base row first (its third cell empty), then each mineral's name, extra mass slider
  (`EXTRA_FORMAT`) and total (`TOTAL_FORMAT`), which follows both sliders. `menu/TabsWithGamepadControl.gd` focuses
  the switch when the tab is chosen. The values are filled in when the tab enters the tree and whenever it shows, only
  where they differ, so opening it stores nothing.
- **The settings model** (`Settings.gd`, a `Reference`): one instance per HUD, made by `Code.gd` on first use, since
  the values belong to the ship. `ENABLED`, `BASE_MASS` and `EXTRA_MASS` describe the switch, the base slider and
  the mineral sliders (label, default, and for the sliders min, max, step and unit; one description for every
  mineral). The base's `label` names its row and `label` + `_DESC` is its tooltip; a mineral slider's `label` is its
  tooltip. `minerals()` lists the minerals with a slider as the Geologist tab does for the HUD:
  `CurrentGame.mineralPrices`, minus those not in `CurrentGame.traceMinerals` for a system with `onlyMinerals`.
  `isEnabled()` / `setEnabled(how)`, `getBaseMass()` / `setBaseMass(kg)`, `getExtraMass(mineral)` /
  `setExtraMass(mineral, kg)`, and `getMinMass(mineral)`, the base plus the mineral's extra, which the rule uses:
  reading never writes, and gives the defaults where nothing is stored; a number is clamped and snapped to the step,
  anything else gives the default, so a save edited by hand can't break anything; a setter writes only a change. `available()`: the HUD has mineral targeting and has loaded
  `mineralConfig`. `modId()`, `modName()` and `modVersion()` read `Mod.manifest`. Scripts reach it through the
  preload constant `GeologyByMass`, never `Settings`, which would hide the game's autoload.
- **Where they are kept:** in the HUD's `mineralConfig`, the dict the ship's config holds as `hud.config`
  (`Hud.gd` `_ready`), under the mod's id from `Mod.manifest`, changed in place as `Hud.gd` `setMinValue` changes the
  *Minimum value*. So the game saves, loads and carries them with the ship (`CurrentGame.state.ship.config`, written
  as JSON, so numbers come back as floats). The entry holds `formatVersion` (`FORMAT_VERSION`), `modVersion`,
  `enabled`, `baseMass` (kg) and `extraMass` (kg by mineral). Format 1 had no base and kept each mineral's least mass
  in `minMass`: an entry without `extraMass` reads its `minMass` as the extra masses, which keeps every threshold
  with the default base, and the next change rewrites the entry in the current format. The game reads only its own
  keys there (`minerals`, `minValue`, `albedo`). A saved key renamed without a migration, or a new id, would lose the
  saved values.
- Overrides `isValidMineralTarget(body)` and `instance()`, ordinary functions that fall through to the parent with
  `.name()`. It has no `_ready` of its own.
- Members of the extension: `GeologyByMass` and `_GEOLOGY_BY_MASS_UI` (preloads), `_GEOLOGY_BY_MASS_TAB`,
  `_GEOLOGIST_TAB`, `_geologyByMassSettings`, `_geologyByMass()` and `_addGeologyByMassTab()`.
- Tested only outside the game, in a headless Godot 3.6 with the game's `Hud.gd`, `OMS.gd`,
  `TabsWithGamepadControl.gd`, `PriceLabel.gd`, `RepeatingHSlider.gd`, `MineralLabel.gd` and
  `MineralSystemToggle.gd`, an OMS built as its scene nests the tabs, and stubs of the ship and of `CurrentGame` (the
  `geology` suite of the repository's test harness). It has not been checked in a real game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).
