# ServiceNotifier - Changes

## 1.1.2
- Licensed under the MIT License instead of the GNU GPLv3: the LICENSE in the zip and the README's *About* and
  *Disclaimer* say so.

## 1.1.1
- With a gamepad, the Shift badge's tooltip shows while the Services entry is highlighted: a gamepad shows no hover
  (`attachTooltip()` with the entry as its `focusOwner`).
- Comments in `Code.gd` name `Badge.gd`'s `PAD_BUTTON` instead of the button it holds.
- README: the badge's tooltip with a gamepad.

## 1.1.0
- Shift+Click has a gamepad twin: on the highlighted Services entry, the `PAD_BUTTON` button pressed while the
  `PAD_MODIFIER` one is held opens the settings too (constants of the new `Badge.gd`).
- A small badge beside the station menu's Services entry tells how to open the settings: it reads Shift, or the gamepad
  twin (`PAD_TEXT`) while the game is played with a gamepad (the game's Controls setting, or with Auto the device last
  used). Hovering it shows how, in a tooltip that follows the control scheme too. The tooltip was the Services entry's:
  the entry has none now.
- New script, `Badge.gd` (the same file in every mod that has a Shift badge): the Shift badge, its look and its
  tooltips, and the gamepad's twin of Shift+Click. Constants `PAD_MODIFIER`, `PAD_BUTTON`, `PAD_MODIFIER_NAME`,
  `PAD_BUTTON_NAME`, `PAD_TEXT`, `SMALL_FONT_THEME`, `TOOLTIP_DELAY`, `TOOLTIP_FADE` and `BUTTON_HOVER_MUTE`;
  `isPadShortcut()`, `dress()`, `hangBeside()`, `setShiftTooltips()` and `attachTooltip()`.
- `i18n/en.po`: `SERVICENOTIFIER_SETTINGS_TOOLTIP` reworded (it is the badge's); new
  `SERVICENOTIFIER_SETTINGS_TOOLTIP_PAD`.
- `Code.gd`: new `_SN_SETTINGS_TOOLTIP_PAD`, `_SN_SERVICES_ENTRY`, `_SN_TUNING_SCREEN`, `_SN_BADGE_SCRIPT`,
  `_snShiftBadge` and `_snMakeShiftBadge()`.
- README: the Shift badge, the gamepad twin, `Badge.gd`; the scripts' count; only the hotels never mark the entry (the
  one bar, The Twins, has a cooldown); the other mods on the station menu.
