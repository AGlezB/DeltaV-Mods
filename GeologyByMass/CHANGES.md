# GeologyByMass - Changes

## 1.4.0
- With a gamepad, the D-pad goes down from the switch at the top of the mod's OMS tab through the *Base* slider and
  each mineral's, and back up, and no longer leaves the tab (`SettingsUI.gd` `_linkFocus()`).
- A slider's description shows when its value is selected with the D-pad, and when the mouse is on its value, not
  only on its bar.
- The rule reads the mod's saved entry once per question instead of once per mass it needs (new `Settings.gd`
  `massRule()` and `extraMassIn()`): the arm and the drones ask about every chunk they look at, and every read of the
  ship's config takes its lock.
- `SettingsUI.gd`: new `GAME_SLIDER_VALUE`, `GAME_SLIDER_BAR` and `DESCRIPTION_SUFFIX`, for the paths and the suffix
  that were written inline.
- `OmsScreen.gd`: `_GEOLOGIST_TAB` renamed `_GEOLOGY_BY_MASS_AFTER`, so that it starts with the mod's name, as
  DroneAltPriorities's extension of the same script names its own `_DRONE_ALT_PRIORITIES_AFTER`.
- README: the D-pad and the descriptions on the tab, `massRule()` and `extraMassIn()`, the renamed constant.

## 1.3.0
- With the switch on, the masses now decide for every row of the Geologist tab, not only the HUD's: the AR-1500 arm,
  the MPI Tug drones, the MLF Haul Drones and the NT Mining Companion go for a chunk your geologist has identified when
  it holds enough of a mineral switched on in their row, whatever it is worth. Each row keeps its own mineral
  switches; one set of masses serves them all.
- New H2O row on the mod's OMS tab, for the rows that can switch H2O on (the arm's and the drones').
- `Code.gd` now holds the rule, as a script extension of `ships/ship-ctrl.gd` (`isValidMineralTarget(object,
  config)`), which every system asks with its own row. The HUD extension, now only the tab, is renamed `OmsScreen.gd`,
  and no longer overrides `isValidMineralTarget(body)`; it adds the tab only to a HUD with mineral targeting.
- `Settings.gd` is made from the ship (it reads the ship's `hud.config`, new `HUD_CONFIG`) instead of the HUD;
  `minerals()` lists every mineral of the market. The saved entry is unchanged.
- Texts `GEOLOGYBYMASS_HINT`, `GEOLOGYBYMASS_BASE_MASS_DESC` and `GEOLOGYBYMASS_EXTRA_MASS` reworded for every row.
- While the switch is on, the Geologist tab hides the *Minimum value* of the rows the masses replace it in (the HUD,
  the arm, the drones, the NT Mining Companion), as the game hides it for the cargo containers' rows, and the title of
  that column; switched off, the title and the sliders are back, with their values.
- New script extension `GeologistTab.gd`, of `hud/SystemMineralList.gd` (the Geologist tab's rows): overrides
  `updateSystems`, adds `_process`.
- README: the *Warning*, the rows, the callers of the rule, the hidden Minimum values and their title, the three
  extensions and their members.

## 1.2.1
- The README's *Disclaimer* no longer names the author.

## 1.2.0
- The mod's OMS tab is now titled *GBM* (was *Ore mass*): text `GEOLOGYBYMASS_TAB`.
- The README has a new *Disclaimer*: the game belongs to Kodera Software, the author has no tie to it or to the
  company, and the mod is provided as is, for free, without warranty.

## 1.1.1
- The mod's id is now `AGlezB.GeologyByMass`, and its author is capitalized the same way (both were lowercase).
  Settings saved under the old id are not read: they start from the defaults.

## 1.1.0
- New *Base* slider at the top of the mod's OMS tab: the least mass for every mineral. Each mineral's slider is now
  its extra mass on top of the base (shown with a `+`), and a new column shows each mineral's total, the least mass
  it needs.
- Masses saved by earlier versions keep their thresholds: they become the extra masses, over the default base.
- `Settings.gd`: new `BASE_MASS`; `MIN_MASS` renamed `EXTRA_MASS`; new `getBaseMass` / `setBaseMass` and
  `getExtraMass` / `setExtraMass`, replacing `setMinMass`; `getMinMass` now returns the base plus the extra.
  `FORMAT_VERSION` bumped: the saved entry holds `baseMass` and `extraMass` in place of `minMass`, which is still read
  where `extraMass` is missing.
- `SettingsUI.gd`: new `EXTRA_FORMAT` and `TOTAL_FORMAT`; the grid has three columns.
- New texts `GEOLOGYBYMASS_BASE_MASS` and `GEOLOGYBYMASS_BASE_MASS_DESC`; `GEOLOGYBYMASS_MIN_MASS` renamed
  `GEOLOGYBYMASS_EXTRA_MASS`; `GEOLOGYBYMASS_HINT` reworded.
- README: the base and extra masses, the tab's layout, the saved entry and its migration.
- The README starts with a *Warning*: what the mod changes compared to vanilla, and to check a bug without the mod
  before reporting it to the game's developers.
