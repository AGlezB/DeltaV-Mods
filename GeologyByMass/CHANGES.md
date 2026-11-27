# GeologyByMass - Changes

## 2.1.0
- New switch on the mod's OMS tab, *Enable all minerals at the start of a dive*, between the line on what the tab does
  and the mineral rows, off at first. On, every mineral's switch on the tab turns on when a dive starts, H2O too, so the
  set narrowed during a dive doesn't carry over to the next; the switch at the top and the least masses stay as they
  are. It is kept with the ship, as the other settings are, and dimmed with the rows while the switch at the top is
  off. With a gamepad, the D-pad goes down from the switch at the top to it, then into the mineral switches.
- `Settings.gd`: new `ALL_AT_DIVE`, `isAllAtDive()` / `setAllAtDive()` and `diveStarted()`; the saved entry holds
  `allAtDive` too, read as its default where it is missing, so `FORMAT_VERSION` is unchanged.
- `Code.gd`: new `_ready()`, which calls `diveStarted()` for the player's ship built for a dive.
- The tab's parts stand closer together, so that with the new switch they still fit the OMS, the line on the geologist
  included: new `SettingsUI.gd` `SECTION_SPACING`.
- `SettingsUI.gd`: new `_allAtDive`, `_allAtDiveRow` and `_onAllAtDiveToggled()`.
- New text `GEOLOGYBYMASS_ALL_AT_DIVE`.
- README: the new switch, when a dive starts, the members.

## 2.0.3
- The line at the bottom of the mod's OMS tab shows the crew's Price prediction accuracy, the figure the Your Crew
  screen shows (morale included), with the game's own text for its name, so it comes in the game's language. It used to
  show the best geologist's Education and the most error the game's estimates have at that level, without morale. The
  info boxes' mass error comes from that same figure.
- `SettingsUI.gd`: `GEOLOGIST` and `PERCENT_FORMAT` removed; new `GAME_PREDICTION`, `PREDICTION_FORMAT` and
  `STAT_FORMAT`; `_geologistLine()` asks the game's `getCrewNumberWithRole` and `getCrewStats`.
- Text `GEOLOGYBYMASS_GEOLOGIST` removed.
- README: the line on the geologist.

## 2.0.2
- Licensed under the MIT License instead of the GNU GPLv3: the LICENSE in the zip and the README's *About* and
  *Disclaimer* say so.

## 2.0.1
- The line on the geologist aboard reads "You have a Geologist with Basic education. …" instead of "You have a Basic
  Geologist. …", so that the level reads as their Education's (text `GEOLOGYBYMASS_GEOLOGIST`).

## 2.0.0
- The mod's OMS tab has a switch in front of each mineral's name. With the mod's switch on, an identified chunk passes
  every row of the Geologist tab when it holds at least the least mass of a mineral switched on there: the rows' own
  mineral switches no longer count. So with H2O switched on, chunks with enough water keep a full info box too, though
  the HUD's row can't switch H2O on. The switches start as the game's own for a new row: every mineral on but H2O.
- The *Base* slider is gone: each mineral's slider is now its least mass. Saved settings keep every threshold: a
  mineral's base plus its extra mass becomes its least mass, up to the slider's most.
- After each mineral's least mass, what that mass is worth at the day's price.
- At the bottom of the tab, a line on the geologist aboard: a warning when there is none (no info boxes, so no masses),
  else the best one's Education and the most error the game's estimates have at that level.
- While the switch is on, the Geologist tab no longer hides the *Minimum value* of the rows the mod judges, nor its
  column's title: those rows' mineral switches and *Minimum value* stay in place, with their values, disabled and
  dimmed. The cargo containers' rows are left alone, as before.
- `Settings.gd`: `BASE_MASS`, `getBaseMass` / `setBaseMass`, `getExtraMass` / `setExtraMass` and `extraMassIn`
  removed; `EXTRA_MASS` renamed `MIN_MASS`, with a new `setMinMass`; `getMinMass` gives the least mass as stored; new
  `MINERAL_SWITCH`, `mineralDefault`, `isMineralOn` / `setMineralOn`; `massRule()` gives the least mass of each mineral
  switched on. `FORMAT_VERSION` bumped: the saved entry holds `minMass` and `mineralOn` for every mineral; format 2's
  `baseMass` and `extraMass` and format 1's `minMass` are still read, and the first change rewrites the entry.
- `SettingsUI.gd`: a grid of four columns (switch, name, least mass, worth); `EXTRA_FORMAT`, `TOTAL_FORMAT`,
  `DESCRIPTION_SUFFIX`, `_baseSlider`, `_totals`, `_showTotals()`, `_showTotal()` and `_onBaseMassChanged()` removed;
  `_onExtraMassChanged()` renamed `_onMinMassChanged()`; new `GAME_TOOLTIP`, `GAME_GEOLOGIST`, `GEOLOGIST`,
  `NO_GEOLOGIST`, `MASS_FORMAT`, `VALUE_FORMAT`, `PERCENT_FORMAT`, `_switches`, `_values`, `_geologist`, `_link()`,
  `_showValues()`, `_showValue()`, `_geologistLine()` and `_onMineralToggled()`. With a gamepad, the D-pad goes down
  from the switch at the top into the mineral switches, up and down either column, and left and right between a row's
  switch and its slider's value.
- `GeologistTab.gd`: `_GEOLOGY_BY_MASS_GAME_DISABLED`, `_GEOLOGY_BY_MASS_HEADER`, `_GEOLOGY_BY_MASS_GAME_HEADER`,
  `_geologyByMassHidden`, `_geologyByMassPrices()`, `_geologyByMassHeader()` and `_geologyByMassPriceBoxes()` replaced
  by `_GEOLOGY_BY_MASS_VALUE`, `_GEOLOGY_BY_MASS_BAR`, `_GEOLOGY_BY_MASS_GAME`, `_geologyByMassOverridden`,
  `_geologyByMassOverride()` and `_geologyByMassControls()`.
- Texts: `GEOLOGYBYMASS_BASE_MASS` and `GEOLOGYBYMASS_BASE_MASS_DESC` removed; `GEOLOGYBYMASS_EXTRA_MASS` renamed
  `GEOLOGYBYMASS_MIN_MASS`; new `GEOLOGYBYMASS_MINERAL_SWITCH`, `GEOLOGYBYMASS_GEOLOGIST` and
  `GEOLOGYBYMASS_NO_GEOLOGIST`; `GEOLOGYBYMASS_ENABLED` and `GEOLOGYBYMASS_HINT` reworded.
- README: the mineral switches, the least masses and their worth, the line on the geologist, the disabled controls,
  the members; the *Warning* names the NT Mining Companion's row too.

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
