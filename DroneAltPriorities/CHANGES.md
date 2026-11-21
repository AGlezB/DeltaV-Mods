# DroneAltPriorities - Changes

## 1.1.0
- With a gamepad, the D-pad goes down from the switch at the top of the mod's OMS tab through each slider to *Reset to
  defaults*, and back up, and no longer leaves the tab (`SettingsUI.gd` `_linkFocus()`).
- A slider's description shows when its value is selected with the D-pad, and when the mouse is on its value, not
  only on its bar.
- *Reset to defaults* shows its description (`DRONEALTPRIORITIES_RESET_DESC`) on hover and when selected: the released
  game draws only the tooltips of its own tooltip node, which the button's row now has.
- `SettingsUI.gd`: new `GAME_SLIDER_VALUE`, `GAME_SLIDER_BAR`, `GAME_TOOLTIPS` and `DESCRIPTION_SUFFIX`, for the paths
  and the suffix that were written inline.
- `Code.gd`: new `WORLD_UNITS_PER_METRE`, for the figure that was written inline. `_dapCriteria()` takes the plant's
  range from `scanForTarget`, and gives a chunk's figures by the key of their weight (`value`, `mass`, `intake`), which
  `_dapChoose()` reads by key instead of by position.
- README: the D-pad and the descriptions on the tab, the new constants, `_dapCriteria()`'s figures by key; the list of
  scripts leaves out `ModMain.gd`.
- Adds this CHANGES.md.
