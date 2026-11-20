# DroneAltPriorities - ΔV: Rings of Saturn

Changes which chunk your MPI Tug drones and MLF Haul Drones work on first: the most valuable, as set on a new tab of
the OMS.

## Warning
This mod changes how the game plays. Compared to vanilla, while the switch on the mod's OMS tab is on, the player's
MPI Tug drones and MLF Haul Drones pick the chunk they work on first by the ore your geologist found in it (its value
and its mass) and, for haul drones, by how close it is to the excavator, instead of going for the heaviest, fastest
chunk; and a plant stays on its chunk until another is much better. Which chunks they may take at all is still the
game's. With the switch off the game plays as vanilla; the mod's OMS tab is there either way.

Before reporting a bug with the drones' choice of chunks to the game's developers, check that it also happens without
the mod.

## What it does and why
- **What:** each plant of nanodrones works on one target at a time, and picks again every few seconds. The game's
  rule: the Obonto USV-GOT recon drone's priority queue first; otherwise, among the chunks in the plant's reach that
  pass its filters (its row of the Geologist tab, the Tuning range, the ones no other system of the ship has taken),
  tug plants take the one with the most mass x speed², haul plants the most mass x |desired - velocity|² / distance
  (GAME.md *Nanodrones*). With the mod's switch on, the queue and which chunks are eligible stay the game's; only the
  choice among them changes.
- **The score:** each eligible chunk gets three figures, all from what the player can see:
  - *Ore value*: the base price per kg (`CurrentGame.mineralPrices`) of the best ore the geologist found in it;
  - *Ore mass*: the kg of ore the geologist found in it (the minerals the HUD can mark, not the water around them);
  - *Intake*, for haul plants only: how close the chunk is to the spot ahead of the excavator where the haul drones
    gather chunks, 1 there and 0 at the plant's reach.

  Each figure is taken as a share of the best eligible chunk's, plus `SCORE_FLOOR` (so that one missing figure doesn't
  zero a chunk's whole score), raised to its slider's weight, and the three are multiplied. A weight of 0 ignores a
  figure; with *Ore value* and *Ore mass* at the same weight, the score follows what the chunk's ore is worth. A chunk
  the geologist hasn't identified has no value or mass yet: while either counts, it comes after the identified ones,
  by intake.
- **Staying on a chunk:** the current target keeps its place unless another chunk scores more than 1 +
  `KEEP_TARGET_MARGIN` times as much, since a new pick throws away the drones already in flight. Equal scores go to
  the game's rule.
- **Only the player's tug and haul drones:** other ships' plants and the OME Maintenance drones pick as the game does.
- **Why:** the game's rule sends the drones after heavy, fast chunks they rarely stop before those leave, a new pick
  throws away the drones in flight, and the bias meant to keep a plant on its target never applies (`scanForTarget`
  clears `target` before reading it). So light, valuable chunks, Be above all, escape while the drones are busy. The
  ranking, the figures and the defaults were chosen on the repository's drone bench (`_bench/README.md`), which runs
  the game's own drone plants in a fixed mining scenario. Two other ideas lost ore there at every weight, so the mod
  has neither: chunks escaping fastest first, and chunks not yet identified first.
- **Settings:** on the OMS tab right after the Geologist tab.
  - The switch at the top: on, the drones pick as above; off, as the game does. Under it, a line on what it does.
  - *Ore value*, *Ore mass* and *Intake*: a slider each, in %, the weight of that figure. Hovering a slider shows what
    it does.
  - The sliders are the Geologist tab's own controls: pick the value to change it, then left and right (or drag the
    slider), and accept or cancel to leave. While the switch is off they are dimmed, but you can still set them.
  - *Reset to defaults*, under the sliders, puts the switch and every slider back to their defaults.
  - They are kept with your ship, next to the Geologist tab's own settings, and saved and loaded with them: one set
    for all the ship's plants. A ship that never had them starts from the defaults.
  - The switch's default is `ENABLED`, and each slider's default, range and step are its entry in `WEIGHTS`, both at
    the top of `DroneAltPriorities/Settings.gd`; `SCORE_FLOOR` and `KEEP_TARGET_MARGIN` are at the top of
    `DroneAltPriorities/Code.gd`, both inside the zip.

## For modders
- Four scripts: `Code.gd` (the drone plants' script extension: the choice), `OmsScreen.gd` (the HUD's script
  extension: adding the tab), `SettingsUI.gd` (the tab) and `Settings.gd` (the settings model the other three share),
  plus `ModMain.gd`. The texts are in `i18n/en.po`.
- Script extension of `res://weapons/drone-plant.gd` (`Code.gd`), the script of every nanodrone plant:
  `weapons/drone-plant.tscn`, which `weapons/WeaponSlot.tscn` mounts for `SYSTEM_DND_TS` and `SYSTEM_DND_HAUL`, and
  `weapons/drone-fix-plant.tscn`, an instance of it for `SYSTEM_DND_FIX` (`droneFunction` "repair"). The tag
  `group = DronePlant` in `Mod.manifest` names it.
  - Overrides `scanForTarget(delta)`, an ordinary function: it falls through to `.scanForTarget(delta)` for a plant
    that isn't tug or haul (`droneFunction`), on a ship that isn't the player's (`ship.isPlayerControlled()`), or with
    the switch off. Otherwise it does what the game's does, with the pick changed: between picks
    (`scanProcess <= scanEvery`) a target taken into the hold is dropped; at a pick, the USV-GOT's queue first
    (`_dapFromQueue()`, the game's test of a queued object), then each of `getPossibleTargets()` through the game's
    filters for the plant's function (`_dapCheck()`: in the ship's space, not in the hold, a `RigidBody2D`, not the
    autopilot's velocity target for a haul plant, inside the Tuning range, a tug's minimum speed, the target bus
    `isValidSystemTarget` with `sanbus`, the plant's row `ship.isValidMineralTarget(t, mineralConfig)` with
    `mineralTargetting`, and the game's score above `minEnergyToTarget`), each object claimed with `Tool.claim` while
    it is read.
  - `_dapCriteria()` gives a chunk's figures: ore value and ore mass from `ship.identifiedObjects[hash(chunk)][0]`
    (the kg per mineral the geologist's info box stores), counting only `CurrentGame.traceMinerals`, at
    `CurrentGame.mineralPrices`; intake from the distance between the chunk and the gathering spot,
    `excavator.global_position + haulGatherSpot.rotated(excavator.global_rotation)`, over the plant's maximum Tuning
    range, clamped, from 1 (0 for tug plants and a ship without an excavator). `_dapChoose()` scores them as above and
    breaks ties with the game's score.
  - The plants still ask the ship which chunks pass their row (`ship.isValidMineralTarget`), so a mod that changes
    that rule changes which chunks this one ranks.
- Script extension of `res://hud/Hud.gd` (`OmsScreen.gd`), the script of every ship's HUD, which builds the OMS
  (`hud/OMS.tscn`) in `instance()`, replacing its `Inventory` placeholder. The mod's `instance()` calls the parent's,
  then adds its tab with `call_deferred`: a preheated ship's HUD calls `instance()` from its `_ready` before it loads
  `mineralConfig` from the ship, and the tab shows the values stored there. The tab goes into the OMS's own `tabsPath`
  (`hud/OMS.gd`), right after `CREW_OCCUPATION_GEOLOGIST`, once per OMS, only on a HUD with mineral targeting whose
  ship has its `hud.config`, and copies that tab's `theme` and `rect_clip_content`. Its node name is its title key,
  which the game's TabContainer draws translated, as it draws the role tabs' keys. Nothing in the game refers to the
  OMS's tabs by index.
- **The tab** (`SettingsUI.gd`) is a `Tabs` node, as every OMS page is, built from the Geologist tab's own parts
  (`hud/SystemMineralList.gd`), as GeologyByMass's tab is: `hud/components/MineralSystemToggle.tscn` for the switch,
  with its label beside it (`TOGGLE_SPACING`), the `HINT` line under it, then a grid of two columns: each weight's
  name (`hud/components/MineralLabel.tscn`, without focus) and its slider (`hud/components/PriceLabel.tscn`, the
  Minimum value control), with the weight's range, step and unit in the units shown, the bar `SLIDER_WIDTH` wide and
  the weight's `label` + `_DESC` as its tooltip; last the `RESET` button, with `RESET` + `_DESC` as its tooltip. The
  grid is dimmed (`DIMMED`) while the switch is off. `menu/TabsWithGamepadControl.gd` focuses the switch when the tab
  is chosen. The values are filled in when the tab enters the tree and whenever it shows, only where they differ, so
  opening it stores nothing.
- **The settings model** (`Settings.gd`, a `Reference`) follows GeologyByMass's: one instance per ship, made from the
  ship by each script that reads it (each plant, the HUD), with no shared instance and no signal, since they all read
  the same entry: a change applies at each plant's next pick. `ENABLED` describes the switch (label, default) and
  `WEIGHTS` the sliders, in the tab's order (key, label, default, min, max, step, unit and `shown`, the factor from the
  stored weight to the one shown). `available()`: the ship's `hud.config` exists. `isEnabled()` / `setEnabled(how)`,
  `weight(key)` (a slider's description), `keys()`, `getWeight(key)` / `setWeight(key, value)`, `toShown(key, value)`
  / `fromShown(key, shown)`, and `reset()`, which erases the entry, so the ship reads as one that never had it. Reading
  never writes, and gives the defaults where nothing is stored; a weight is clamped and snapped to its step, anything
  that isn't a number gives the default, so a save edited by hand can't break anything; a setter writes only a change.
  `modId()`, `modName()` and `modVersion()` read `Mod.manifest`. Scripts reach it through the preload constant
  `DroneAltPriorities`, never `Settings`, which would hide the game's autoload.
- **Where they are kept:** in the HUD's `mineralConfig`, the dict the ship's config holds as `hud.config`
  (`HUD_CONFIG`; `Hud.gd` `_ready`), under the mod's id from `Mod.manifest`, changed in place as `Hud.gd`
  `setMinValue` changes the Minimum value. So the game saves, loads and carries them with the ship (written as JSON,
  so numbers come back as floats). The entry holds `formatVersion` (`FORMAT_VERSION`), `modVersion`, `enabled` and
  `weights` (by key). The game reads only its own keys there (`minerals`, `minValue`, `albedo`). A saved key renamed
  without a migration, or a new id, would lose the saved values.
- **With GeologyByMass**, which also extends `hud/Hud.gd` and adds an OMS tab right after the Geologist tab, each from
  its own override of `instance()` with a deferred call: mods load by path, so the chain is game ← DroneAltPriorities
  ← GeologyByMass, DroneAltPriorities's deferred call runs first, and GeologyByMass's tab ends up between the
  Geologist tab and this one. Both keep their entries in `mineralConfig`, each under its own id. Their members are
  distinct.
- Members of the drone plants' extension (`Code.gd`): `DroneAltPriorities` (preload), `SCORE_FLOOR`,
  `KEEP_TARGET_MARGIN`, `_droneAltPrioritiesSettings`, `_droneAltPriorities()`, `_dapFromQueue()`, `_dapCheck()`,
  `_dapCriteria()` and `_dapChoose()`.
- Members of the HUD's extension (`OmsScreen.gd`): `DroneAltPriorities` and `_DRONE_ALT_PRIORITIES_UI` (preloads),
  `_DRONE_ALT_PRIORITIES_TAB`, `_DRONE_ALT_PRIORITIES_AFTER`, `_droneAltPrioritiesSettings`, `_droneAltPriorities()`
  and `_addDroneAltPrioritiesTab()`. It has no `_ready` of its own.
- Tested outside the game in a headless Godot 3.6 with the game's `drone-plant.gd`, `Hud.gd`, `OMS.gd`,
  `TabsWithGamepadControl.gd`, `PriceLabel.gd`, `RepeatingHSlider.gd`, `MineralLabel.gd` and
  `MineralSystemToggle.gd`, drone plants in a stub ship and an OMS built as its scene nests the tabs (the `drones`
  suite of the repository's test harness), alone and with GeologyByMass in both load orders; on the drone bench,
  which runs the game's own drone plants, PDWs, excavator, chunks and roids; and in the game.

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
