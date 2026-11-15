# GeologyByMass - Changes

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
