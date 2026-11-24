# GeologyByMass - ΔV: Rings of Saturn

Judges the ore your geologist identifies by the mass of each mineral in it instead of its value, as set on a new tab
of the OMS.

## Warning
This mod changes how the game plays. Compared to vanilla, while the switch on the mod's OMS tab is on, a chunk your
geologist has identified passes every row of the Geologist tab (the HUD's, the arm's, the drones', the NT Mining
Companion's) when it holds enough mass of a mineral switched on in the mod's tab, whatever the chunk is worth: the
rows' own mineral switches and *Minimum value* no longer count. So the masses decide which chunks keep a full info box,
and which ones the arm and the drones go for. With the switch off the game plays as vanilla; the mod's OMS tab is there
either way.

Before reporting a bug with the info boxes, the arm's or the drones' choice of chunks, or the Geologist tab to the
game's developers, check that it also happens without the mod.

## What it does and why
- **What:** the Geologist tab has a row for each piece of equipment that picks chunks by their ore: the HUD, each
  AR-1500 arm, each plant of MPI Tug drones or MLF Haul Drones, and the NT Mining Companion (the cargo containers' rows
  pick the processed ore they carry instead, which the mod leaves alone). Each row has its own mineral switches and
  *Minimum value*. In the game, a chunk your geologist has identified passes a row when it is worth at least the row's
  *Minimum value* and holds a mineral switched on in it. The HUD's row decides which info boxes stay full (the game
  shrinks the others, hiding their kg list and price). The arm's row decides which chunks the arm takes, and each drone
  plant's row which chunks its drones work on. With the mod's switch on, a chunk passes every row when it holds, of one
  of the minerals switched on in the mod's tab, at least the least mass set for that mineral; its value, and the row's
  own mineral switches and *Minimum value*, no longer count. The masses are the ones the info box shows, as your
  geologist estimates them.
- **One set of switches and masses for every row:** the mod's tab has a switch and a least mass for each mineral, and
  they serve every row alike. So H2O (water), which the HUD's row can't switch on, counts for the info boxes too once
  it is switched on in the mod's tab: a chunk with enough water keeps a full box, as the arm and the drones go for it.
  The switches start as the game's own do for a new row: every mineral on but H2O.
- **What a mass is worth:** after each mineral's least mass, the tab shows what that mass of it is worth at the day's
  price, to compare a mass with the *Minimum value* it replaces.
- **The geologist aboard:** the masses are the geologist's estimates, so the line at the bottom of the tab says who
  makes them. With no geologist in the dive crew it warns that the masses will have no effect: without one, no chunk
  gets an info box, so none is ever identified. Otherwise it names the best one's Education, as their crew entry shows
  it, and how far off their estimates can be at that level, as a rough guide to set the masses lower or higher.
- **The overridden controls disabled:** while the switch is on, the Geologist tab disables and dims the mineral
  switches and the *Minimum value* of the rows the mod judges, since they no longer count, as the game dims a switch a
  row can't use. They stay in place, with their values; switched off, they work again, as they were.
- **When it applies:** every time the game asks. Each info box checks again by itself about once a second, the arm
  each time it picks a target, and each drone plant at each of its scans, so a change shows within a second, as a
  change in the Geologist tab does. A chunk not yet identified is left to the game, which judges it by the row's
  *Minimum Albedo*.
- **Why:** a chunk's value mixes every mineral in it and moves with the market. When you are after a particular
  mineral, its mass is what tells you whether a chunk is worth the trip, for you and for your arm and drones alike.
- **Settings:** on the OMS tab right after the Geologist tab.
  - The switch at the top: on, the mod's switches and masses decide; off, the Geologist tab's rows do, as without the
    mod.
  - Then one row per mineral of the Geologist tab's columns, H2O too: its switch, its name, a slider with its least
    mass in kg, and what that mass is worth.
  - At the bottom, the line on the geologist aboard, brought up to date, with the worths, each time the tab shows.
  - The sliders are the Geologist tab's own controls: pick the value to change it, then left and right (or drag the
    slider), and accept or cancel to leave. While the switch is off the rows are dimmed, but you can still set them.
  - Pointing at a switch or a slider, or selecting it, shows what it does. With a gamepad, the D-pad goes down from
    the switch at the top into the mineral switches, up and down either column (the switches, or the sliders' values),
    left and right between a row's switch and its slider's value, and never leaves the tab.
  - They are kept with your ship, next to the Geologist tab's own settings, and saved and loaded with them. A ship
    that never had them starts from the defaults, as it does for the *Minimum value*. A ship's masses from before the
    least masses keep their thresholds: a mineral's base plus its extra mass becomes its least mass, up to the slider's
    most.
  - The switch's default is `ENABLED`, and each mineral slider's default, range, step and unit are `MIN_MASS`, both at
    the top of `GeologyByMass/Settings.gd`, inside the zip.

## For modders
- Five scripts: `Code.gd` (the rule, a script extension of the ship), `OmsScreen.gd` (adding the tab, a script
  extension of the HUD), `GeologistTab.gd` (disabling the overridden controls, a script extension of the Geologist
  tab), `SettingsUI.gd` (the tab) and `Settings.gd` (the settings model they share).
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
  DroneAltPriorities). The mod's override, for the player's ship (`playerControlled`) with the switch on and a row
  that has `minerals` and `minValue`: an identified chunk passes when it holds, of some mineral switched on in the
  mod's tab, at least that mineral's least mass. `Settings.gd` `massRule()` reads the saved entry once per call, and
  gives null with the switch off, else the least mass of each mineral switched on, by mineral: the drone plants ask
  about every chunk in reach at each scan, and every read of the ship's config takes its lock. The row's own
  `minerals` and `minValue` aren't read. The masses come from the ship's `identifiedObjects[hash(object)][0]`, the kg
  per mineral the box stores (`MineralMark.gd` `scanParent`, then `identifyMinerals` / `identifyValue` ->
  `ship-ctrl.gd` `addIdentifiedObject`). Anything else (the switch off, another ship, a row without mineral targeting,
  a chunk not in `identifiedObjects`) falls through to the game's: by the value against `minValue` and the LIDAR
  return against `albedo`.
- **The tab:** the HUD builds the OMS (`hud/OMS.tscn`) in `instance()`, replacing its `Inventory` placeholder. The
  mod's `instance()` (`OmsScreen.gd`) calls the parent's, then adds its tab with `call_deferred`: a preheated ship's
  HUD calls `instance()` from its `_ready` before it loads `mineralConfig` from the ship, and the tab shows the values
  stored there. Only a HUD with `mineralTargetting` gets it, since the settings go next to that HUD's row. The tab goes
  into the OMS's own `tabsPath` (`hud/OMS.gd`), right after `CREW_OCCUPATION_GEOLOGIST`, once per OMS, and copies that
  tab's `theme` and `rect_clip_content`. Its node name is its title key, which the game's
  TabContainer draws translated, as it draws the role tabs' keys. Nothing in the game refers to the OMS's tabs by
  index. The tab is a `Tabs` node, as every OMS page is, built from the Geologist tab's own parts
  (`hud/SystemMineralList.gd`): `hud/components/MineralSystemToggle.tscn` for the switch at the top and each mineral's,
  `hud/components/MineralLabel.tscn` for the names (coloured from `CurrentGame.specificMineralColors`, without focus)
  and `hud/components/PriceLabel.tscn`, the *Minimum value* control, for the sliders, with the mod's format
  (`MASS_FORMAT` and the unit), range, step and bar width (`SLIDER_WIDTH` in `SettingsUI.gd`), and its tooltip on both
  the bar (`GAME_SLIDER_BAR`) and the value (`GAME_SLIDER_VALUE`, the button the D-pad lands on). The released game
  draws no Godot tooltips: the control's own tooltip node (`menu/sfx/PlaySoundsOnTheseButtons.tscn`, `GAME_TOOLTIP`)
  shows them on hover and on focus, and each mineral switch gets one of its own. A grid of four columns, one row per
  mineral: the switch, the name, the least mass slider and what that mass is worth at the day's price
  (`CurrentGame.getMineralMarketPricePerKg`, as the info box prices a chunk, shown as `VALUE_FORMAT`), which follows
  its slider. Under it, the line on the geologist aboard (`_geologistLine()`): among the dive crew
  (`CurrentGame.isCrewMemberActive`, as `getCrewStats` counts it), the geologist (`GAME_GEOLOGIST`) with the highest
  talent; with none, `NO_GEOLOGIST`; else `GEOLOGIST` with their Education level (`CurrentGame.translateLevel` of their
  talent among `talentLevels`, as their crew entry shows it) and the most error the boxes' masses have at that level,
  as `PERCENT_FORMAT`: the info box's error is within ±(1 - `CREW_STATS_GEOLOGIST_PREDICTION`) (`MineralMark.gd`
  `_ready`), and the game's own `deriveStats`, run on `makeEmptyStats()` with the level's lowest talent, gives it, so
  no formula is copied. Morale, which also moves the error (`getCrewStats`), is left out: the line is a hint, at the
  level the player sees. `menu/TabsWithGamepadControl.gd` focuses the switch at the top when the tab is chosen. The
  D-pad's way from there (`_linkFocus()`, set as `hud/SystemMineralList.gd` `adjustFocus` sets the Geologist tab's):
  down to the first mineral's switch; up and down a column, the switches or the sliders' values, in the rows' order,
  the first row's leading back up to the switch at the top; left and right between a row's switch and its slider's
  value (`focus_neighbour_*`). At the ends and the outer sides a control is its own neighbour, so the focus never
  leaves the tab, and once A turns a value into its bar, left and right are the bar's. The values are filled in when
  the tab enters the tree and whenever it shows, only where they differ, so opening it stores nothing; the worths and
  the geologist's line follow the day's prices and the crew each time.
- **The overridden controls disabled** (`GeologistTab.gd`): the list builds a row per system in `updateSystems`: a
  mineral switch per mineral (`hud/components/MineralSystemToggle.tscn`, whose `toggled` reaches the list's `toggle`
  with the row's system bound) and a Minimum value control at the end (`hud/components/PriceLabel.tscn`), which it
  disables for a system with `onlyMinerals` and without `oreValueFilter` (the cargo containers' docks, whose switches
  pick the processed ore they take); disabled, the control hides its slider and its value (`PriceLabel.gd`
  `_setDisabled`). Every row it leaves enabled is judged by the ship's rule (the HUD, the arm, the tug and haul plants,
  the NT Mining Companion), so with the switch on, for the player's ship, the extension disables those rows' mineral
  switches (`disabled`) and their Minimum value's button (`_GEOLOGY_BY_MASS_VALUE`, which would open its bar,
  `RepeatingHSlider.gd` `_on_Label_pressed`) and bar (`_GEOLOGY_BY_MASS_BAR`, `editable` off, so the mouse can't drag
  it), and dims each with the list's own `modulateDisabled`, as the game dims a switch a row can't use; `PriceLabel.gd`'s
  own `disabled` would hide them. Off, it puts each back as the game set it, recorded on the control, in node meta
  (`_GEOLOGY_BY_MASS_GAME`), the first time. The controls keep their focus, as the game's disabled switches do, so the
  D-pad still crosses them. It finds the controls by their connections to the list (`_geologyByMassControls()`): the
  Minimum values by `valueChanged` to `value`, which tells them from the Minimum Albedo controls (the same script,
  connected to `albedo`), the switches by `toggled` to `toggle`, each with its row's system, and leaves out the rows
  `updateSystems` has queued for freeing. It applies at the end of `updateSystems`, and from `_process` on a change:
  the game processes the list only while it shows (`_visibilityChanged`), and the mod's switch is on another tab, so
  the change shows when the Geologist tab does. It stores nothing.
- **The settings model** (`Settings.gd`, a `Reference`): made from the ship, since the values belong to it, by each
  script that reads them, on first use: the ship's rule (`Code.gd`), the HUD's tab (`OmsScreen.gd`) and the Geologist
  tab (`GeologistTab.gd`). They read and write the same entry, so a change on the tab applies at once, with no
  signal. `ENABLED`, `MINERAL_SWITCH` and `MIN_MASS` describe the switch at the top, the mineral switches and the
  sliders (label, which is the tooltip of a mineral's switch and slider; for the switch at the top, its default; for the
  sliders, default, min, max, step and unit; one description for every mineral). `minerals()` lists the minerals with
  a row: every mineral of `CurrentGame.mineralPrices`, in the order of the Geologist tab's columns, H2O too.
  `isEnabled()` / `setEnabled(how)`, `isMineralOn(mineral)` / `setMineralOn(mineral, how)`, whose default
  (`mineralDefault(mineral)`) is the game's own for a new row (`CurrentGame.traceMinerals`, as `Hud.gd`,
  `DockingArm.gd` and `drone-plant.gd` `_ready` start theirs), `getMinMass(mineral)` / `setMinMass(mineral, kg)`, and
  `massRule()`, the same reads for the rule with the entry read once (above): reading never writes, and gives the
  defaults where nothing is stored; a mass is clamped and snapped to the step, a switch that isn't a bool and a mass
  that isn't a number give the default, so a save edited by hand can't break anything; a setter writes only a change.
  `available()`: the ship's HUD has made its `mineralConfig` (a HUD with mineral targeting). `modId()`, `modName()`
  and `modVersion()` read `Mod.manifest`. Scripts reach it through the preload constant `GeologyByMass`, never
  `Settings`, which would hide the game's autoload.
- **Where they are kept:** in the HUD's `mineralConfig`, the dict the ship's config holds as `hud.config`
  (`HUD_CONFIG`; `Hud.gd` `_ready`), under the mod's id from `Mod.manifest`, changed in place as `Hud.gd`
  `setMinValue` changes the *Minimum value*. So the game saves, loads and carries them with the ship
  (`CurrentGame.state.ship.config`, written as JSON, so numbers come back as floats). The entry holds `formatVersion`
  (`FORMAT_VERSION`), `modVersion`, `enabled`, `minMass` (kg by mineral) and `mineralOn` (on or off by mineral), every
  mineral's written at each change. Format 1 kept each mineral's least mass in `minMass` too; format 2 kept a base for
  every mineral in `baseMass` and each mineral's extra mass on top of it in `extraMass`: an entry with `extraMass`
  reads each least mass as the base plus the extra, clamped to the slider's range, which keeps every threshold up to
  the slider's most. Neither had `mineralOn`, which reads as the defaults. The next change rewrites the entry in the
  current format. The game reads only its own keys there (`minerals`, `minValue`, `albedo`). A saved key renamed
  without a migration, or a new id, would lose the saved values.
- Overrides, ordinary functions that fall through to the parent with `.name()`: `isValidMineralTarget(object, config)`
  in `Code.gd`, `instance()` in `OmsScreen.gd`, `updateSystems(systems)` in `GeologistTab.gd`, which also has a
  `_process` (Godot runs it at every level, so it doesn't call the parent's). None has a `_ready` of its own.
- Members of `Code.gd`: `GeologyByMass` (preload), `_geologyByMassSettings` and `_geologyByMass()`. Of
  `OmsScreen.gd`: `GeologyByMass` and `_GEOLOGY_BY_MASS_UI` (preloads), `_GEOLOGY_BY_MASS_TAB`,
  `_GEOLOGY_BY_MASS_AFTER`, `_geologyByMassSettings`, `_geologyByMass()` and `_addGeologyByMassTab()`. Of
  `GeologistTab.gd`: `GeologyByMass` (preload), `_GEOLOGY_BY_MASS_VALUE`, `_GEOLOGY_BY_MASS_BAR`,
  `_GEOLOGY_BY_MASS_GAME`, `_geologyByMassSettings`, `_geologyByMassOverridden`, `_geologyByMass()`,
  `_geologyByMassOverride()` and `_geologyByMassControls()`.
- Stacks with DiveSkipTransit, which extends `ship-ctrl.gd` too (other functions), and with DroneAltPriorities, which
  extends `Hud.gd` too (another tab) and whose drone plants ask the ship's rule.
- Tested only outside the game, in a headless Godot 3.6 (the `geology` suite of the repository's test harness): the
  rule on ships of the game's `ship-ctrl.gd`, out of the tree, with the HUD's row and an arm's or drone plant's row,
  compared with the game's own script where the game decides; the tab with the game's `Hud.gd`, `OMS.gd`,
  `TabsWithGamepadControl.gd`, `PriceLabel.gd`, `RepeatingHSlider.gd`, `MineralLabel.gd`, `MineralSystemToggle.gd` and
  `PlaySoundsOnTheseButtons.gd`, an OMS built as its scene nests the tabs, and stubs of the ship and of `CurrentGame`,
  with the D-pad's way through the tab and the line on the geologist for every Education level; the Geologist tab with
  the game's `SystemMineralList.gd` in that OMS, with rows for the HUD, an arm and a cargo container's dock. The real
  check is playing the game.

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
