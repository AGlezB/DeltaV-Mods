# GeologyByMass - ΔV: Rings of Saturn

Judges the ore your geologist identifies by the mass of each mineral in it instead of its value, as set on a new tab
of the OMS.

## Warning
This mod changes how the game plays. Compared to vanilla, while the switch on the mod's OMS tab is on, a chunk your
geologist has identified passes each row of the Geologist tab (the HUD's, the arm's, the drones') when it holds enough
mass of a mineral switched on in that row, whatever the chunk is worth: the *Minimum value* no longer counts. So the
masses decide which chunks keep a full info box, and which ones the arm and the drones go for. With the switch off the
game plays as vanilla; the mod's OMS tab is there either way.

Before reporting a bug with the info boxes, the arm's or the drones' choice of chunks, or the Geologist tab to the
game's developers, check that it also happens without the mod.

## What it does and why
- **What:** the Geologist tab has a row for each piece of equipment that picks chunks by their ore: the HUD, each
  AR-1500 arm, each plant of MPI Tug drones or MLF Haul Drones, and the NT Mining Companion (the cargo containers' rows
  pick the processed ore they carry instead, which the mod leaves alone). Each row has its own mineral switches and
  *Minimum value*. In the game, a chunk your geologist has identified passes a row when it is worth at least the row's
  *Minimum value* and holds a mineral switched on in it. The HUD's row decides which info boxes stay full (the game
  shrinks the others, hiding their kg list and price). The arm's row decides which chunks the arm takes, and each drone
  plant's row which chunks its drones work on. With the mod's switch on, a chunk passes a row when it holds, of one of
  the minerals switched on in that row, at least the base mass plus the extra mass set for that mineral; its value and
  the row's *Minimum value* no longer count. The masses are the ones the info box shows, as your geologist estimates
  them.
- **Base and extra:** the base is the least mass for every mineral, and each mineral's extra mass is added to it. So
  one slider raises or lowers every mineral's threshold together, keeping the differences between them, and a mineral
  with no extra mass needs just the base.
- **One set of masses, each row's own switches:** the masses serve every row. Each row's mineral switches still decide
  which minerals count for it, as they do in the game: a mineral switched off in a row never makes a chunk pass that
  row, however much of it there is. H2O (water) has a slider too: only the arm's and the drones' rows can switch it
  on.
- **The Minimum value hidden:** while the switch is on, the Geologist tab hides the *Minimum value* of those rows, and
  the column's title, since it no longer counts, as the game already hides it for the cargo containers' rows. Switched
  off, the title and the sliders are back, with their values.
- **When it applies:** every time the game asks. Each info box checks again by itself about once a second, the arm
  each time it picks a target, and each drone plant at each of its scans, so a change shows within a second, as a
  change in the Geologist tab does. A chunk not yet identified is left to the game, which judges it by the row's
  *Minimum Albedo*.
- **Why:** a chunk's value mixes every mineral in it and moves with the market. When you are after a particular
  mineral, its mass is what tells you whether a chunk is worth the trip, for you and for your arm and drones alike.
- **Settings:** on the OMS tab right after the Geologist tab.
  - The switch at the top: on, the masses decide; off, the game's *Minimum value* does, as without the mod.
  - The *Base* slider, with the base mass in kg.
  - Then one row per mineral of the Geologist tab's columns, H2O too: a slider with its extra mass (`+` kg), and after
    it the total (`=` kg), the least mass that mineral needs.
  - The sliders are the Geologist tab's own controls: pick the value to change it, then left and right (or drag the
    slider), and accept or cancel to leave. While the switch is off they are dimmed, but you can still set them.
  - They are kept with your ship, next to the Geologist tab's own settings, and saved and loaded with them. A ship
    that never had them starts from the defaults, as it does for the *Minimum value*. A ship's masses from before
    the base slider become its extra masses, over the default base.
  - The switch's default is `ENABLED`, the base slider's default, range, step and unit are `BASE_MASS`, and each
    mineral slider's are `EXTRA_MASS`, all at the top of `GeologyByMass/Settings.gd`, inside the zip.

## For modders
- Five scripts: `Code.gd` (the rule, a script extension of the ship), `OmsScreen.gd` (adding the tab, a script
  extension of the HUD), `GeologistTab.gd` (hiding the Minimum values, a script extension of the Geologist tab),
  `SettingsUI.gd` (the tab) and `Settings.gd` (the settings model they share).
- Script extensions (`installScriptExtension` in `ModMain.gd`, in that order) of `res://ships/ship-ctrl.gd`, the script
  of every ship (`Code.gd`), of `res://hud/Hud.gd`, the script of every ship's HUD (`hud/Hud.tscn`,
  `hud/HudBare.tscn`; `OmsScreen.gd`), and of `res://hud/SystemMineralList.gd`, the Geologist tab's list of rows
  (`GeologistTab.gd`). That list lives only in `hud/OMS.tscn`, which the HUD scene holds as an instance placeholder, so
  it loads when a HUD builds its OMS, long after the mods are installed. The tag `group = Hud` in `Mod.manifest` names
  the HUD, whose Geologist tab the mod's settings and rule belong to.
- **The rows:** the Geologist tab (`hud/SystemMineralList.gd`) shows a row for every system with `mineralTargetting`,
  each kept in that system's own config, `mineralConfig` (`minerals`, `minValue`, `albedo`): the HUD's is the ship's
  `hud.config`, a hardpoint system's `weaponSlot.<slot>.config`.
- **The rule:** every system asks the ship whether a chunk passes its row: `ships/ship-ctrl.gd`
  `isValidMineralTarget(object, config)`, with the system's own `mineralConfig`. The callers: the HUD
  (`hud/Hud.gd` `isValidMineralTarget(body)`, which each info box, `hud/MineralMark.gd`, asks now and then,
  `mineralConfigReexamine`, through `hud/AutopilotOverlay.gd`; a "no" plays the box's `diminish` animation); the
  AR-1500 arm (`ships/modules/DockingArm.gd` `isValidTarget`, with `pickupOnlyMineralTargets`); the tug and haul drone
  plants (`weapons/drone-plant.gd` `scanForTarget`, after the USV-GOT recon drone's queue, which they take without
  asking); the NT Mining Companion's AI, for its cradle's row, and a ship's AI catching a chunk with its haul drones
  (both in `ship-ctrl.gd`). Mods that keep those calls follow the rule too (the arm mods' `isValidTarget`,
  DroneAltPriorities). The mod's override, for the player's ship (`playerControlled`) with the
  switch on and a row that has `minerals` and `minValue`: an identified chunk passes when some mineral in the row's
  `minerals` has at least its least mass, the base plus its extra (`getBaseMass`, `getExtraMass`, each read once per
  call, an extra only for a mineral the chunk holds, since the drone plants ask about every chunk in reach at each
  scan). The masses come from the ship's `identifiedObjects[hash(object)][0]`, the kg per mineral the box stores
  (`MineralMark.gd` `scanParent`, then `identifyMinerals` / `identifyValue` -> `ship-ctrl.gd` `addIdentifiedObject`).
  Anything else (the switch off, another ship, a row without mineral targeting, a chunk not in `identifiedObjects`)
  falls through to the game's: by the value against `minValue` and the LIDAR return against `albedo`.
- **The tab:** the HUD builds the OMS (`hud/OMS.tscn`) in `instance()`, replacing its `Inventory` placeholder. The
  mod's `instance()` (`OmsScreen.gd`) calls the parent's, then adds its tab with `call_deferred`: a preheated ship's
  HUD calls `instance()` from its `_ready` before it loads `mineralConfig` from the ship, and the tab shows the values
  stored there. Only a HUD with `mineralTargetting` gets it, since the settings go next to that HUD's row. The tab goes
  into the OMS's own `tabsPath` (`hud/OMS.gd`), right after `CREW_OCCUPATION_GEOLOGIST`, once per OMS, and copies that
  tab's `theme` and `rect_clip_content`. Its node name is its title key, which the game's
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
- **The Minimum values hidden** (`GeologistTab.gd`): the list builds a row per system in `updateSystems`, each ending
  in a Minimum value control (`hud/components/PriceLabel.tscn`), which it disables for a system with `onlyMinerals`
  and without `oreValueFilter` (the cargo containers' docks); disabled, the control hides its slider and its value
  (`PriceLabel.gd` `_setDisabled`). Every row it leaves enabled is judged by the ship's rule (the HUD, the arm, the tug
  and haul plants, the NT Mining Companion), so with the switch on, for the player's ship, the extension disables
  every row's control, and off, it puts each back as the game set it (recorded on the control, in node meta, the
  first time). It finds the controls by their `valueChanged` connection to the list's `value`, which tells them from
  the Minimum Albedo controls (the same script, connected to `albedo`), and leaves out the rows `updateSystems` has
  queued for freeing. The column's title, the last cell of the header row (a `hud/components/MineralLabel.tscn`
  button titled `HUD_MIN_PRICE`), loses its text and its focus meanwhile, and gets the game's back (recorded in node
  meta too): the list is a `GridContainer`, which leaves out a hidden child and would shift every cell after it, so the
  title keeps its cell, and the emptied column takes no room. It is found by that key, or once emptied by its meta.
  It applies at the end of `updateSystems` (which `systemsChanged` follows with `adjustFocus`), and from `_process` on
  a change: the game processes the list only while it shows (`_visibilityChanged`), and the mod's switch is on another
  tab, so the change shows when the Geologist tab does. After a change it calls `adjustFocus`, whose `path()` passes
  over hidden labels, so the focus skips the empty cells; Godot's focus passes over the title, which takes no focus
  while empty. It stores nothing.
- **The settings model** (`Settings.gd`, a `Reference`): made from the ship, since the values belong to it, by each
  script that reads them, on first use: the ship's rule (`Code.gd`), the HUD's tab (`OmsScreen.gd`) and the Geologist
  tab (`GeologistTab.gd`). They read and write the same entry, so a change on the tab applies at once, with no
  signal. `ENABLED`, `BASE_MASS` and
  `EXTRA_MASS` describe the switch, the base slider and the mineral sliders (label, default, and for the sliders min,
  max, step and unit; one description for every mineral). The base's `label` names its row and `label` + `_DESC` is
  its tooltip; a mineral slider's `label` is its tooltip. `minerals()` lists the minerals with a slider: every mineral
  of `CurrentGame.mineralPrices`, in the order of the Geologist tab's columns, H2O too, since the arm's and the drone
  plants' rows (without `onlyMinerals`) can switch it on. `isEnabled()` / `setEnabled(how)`, `getBaseMass()` /
  `setBaseMass(kg)`, `getExtraMass(mineral)` / `setExtraMass(mineral, kg)`, and `getMinMass(mineral)`, the base plus
  the mineral's extra, which the tab shows: reading never writes, and gives the defaults where nothing is stored; a
  number is clamped and snapped to the step, anything else gives the default, so a save edited by hand can't break
  anything; a setter writes only a change. `available()`: the ship's HUD has made its `mineralConfig` (a HUD with
  mineral targeting). `modId()`, `modName()` and `modVersion()` read `Mod.manifest`. Scripts reach it through the
  preload constant `GeologyByMass`, never `Settings`, which would hide the game's autoload.
- **Where they are kept:** in the HUD's `mineralConfig`, the dict the ship's config holds as `hud.config`
  (`HUD_CONFIG`; `Hud.gd` `_ready`), under the mod's id from `Mod.manifest`, changed in place as `Hud.gd`
  `setMinValue` changes the *Minimum value*. So the game saves, loads and carries them with the ship
  (`CurrentGame.state.ship.config`, written as JSON, so numbers come back as floats). The entry holds `formatVersion`
  (`FORMAT_VERSION`), `modVersion`, `enabled`, `baseMass` (kg) and `extraMass` (kg by mineral). Format 1 had no base
  and kept each mineral's least mass in `minMass`: an entry without `extraMass` reads its `minMass` as the extra
  masses, which keeps every threshold with the default base, and the next change rewrites the entry in the current
  format. The game reads only its own keys there (`minerals`, `minValue`, `albedo`). A saved key renamed without a
  migration, or a new id, would lose the saved values.
- Overrides, ordinary functions that fall through to the parent with `.name()`: `isValidMineralTarget(object, config)`
  in `Code.gd`, `instance()` in `OmsScreen.gd`, `updateSystems(systems)` in `GeologistTab.gd`, which also has a
  `_process` (Godot runs it at every level, so it doesn't call the parent's). None has a `_ready` of its own.
- Members of `Code.gd`: `GeologyByMass` (preload), `_geologyByMassSettings` and `_geologyByMass()`. Of
  `OmsScreen.gd`: `GeologyByMass` and `_GEOLOGY_BY_MASS_UI` (preloads), `_GEOLOGY_BY_MASS_TAB`, `_GEOLOGIST_TAB`,
  `_geologyByMassSettings`, `_geologyByMass()` and `_addGeologyByMassTab()`. Of `GeologistTab.gd`: `GeologyByMass`
  (preload), `_GEOLOGY_BY_MASS_GAME_DISABLED`, `_GEOLOGY_BY_MASS_HEADER`, `_GEOLOGY_BY_MASS_GAME_HEADER`,
  `_geologyByMassSettings`, `_geologyByMassHidden`, `_geologyByMass()`, `_geologyByMassPrices()`,
  `_geologyByMassHeader()` and `_geologyByMassPriceBoxes()`.
- Stacks with DiveSkipTransit, which extends `ship-ctrl.gd` too (other functions), and with DroneAltPriorities, which
  extends `Hud.gd` too (another tab) and whose drone plants ask the ship's rule.
- Tested only outside the game, in a headless Godot 3.6 (the `geology` suite of the repository's test harness): the
  rule on ships of the game's `ship-ctrl.gd`, out of the tree, with the HUD's row and an arm's or drone plant's row,
  compared with the game's own script where the game decides; the tab with the game's `Hud.gd`, `OMS.gd`,
  `TabsWithGamepadControl.gd`, `PriceLabel.gd`, `RepeatingHSlider.gd`, `MineralLabel.gd` and
  `MineralSystemToggle.gd`, an OMS built as its scene nests the tabs, and stubs of the ship and of `CurrentGame`; the
  Geologist tab with the game's `SystemMineralList.gd` in that OMS, with rows for the HUD, an arm and a cargo
  container's dock. It has not been checked in a real game.

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
