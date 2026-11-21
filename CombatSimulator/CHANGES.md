# CombatSimulator - Changes

## 1.1.0
- With a gamepad, the dialog opens with the twin of Shift+Click, `PAD_BUTTON` pressed on the highlighted simulator's
  button while `PAD_MODIFIER` is held (`Badge.gd` `isPadShortcut`), and with the twin of Shift plus the simulator's
  key, its gamepad button (Back) while `PAD_MODIFIER` is held (`_csIsShortcut()`).
- Each simulator's button gets a Shift badge inside it, on the left, mirroring the button's key glyph on the right. It
  reads the Shift key's name, or `PAD_TEXT` while the game is played with a gamepad (the game's Controls setting, or
  with Auto the device last used). The tooltip moved from the button to the badge, shown sooner when the mouse is on
  it, with a shorter text (`COMBATSIMULATOR_TOOLTIP`) and one of its own with a gamepad (`COMBATSIMULATOR_TOOLTIP_PAD`).
  It names only the Shift key, so it no longer changes with a rebound key.
- The dialog with a gamepad: LB and RB switch only its own tabs while it is open, and no longer reach the screen behind
  it at its first or last tab; the right stick scrolls the description window of the tab shown
  (`DESCRIPTION_SCROLL_UP`, `DESCRIPTION_SCROLL_DOWN`, `DESCRIPTION_SCROLL_SPEED`, as the game's `ScrollWithAnalog.gd`
  scrolls its lists); Start and Cancel play the game's focus and hover sounds (`attachTooltips()`).
- The end confirmation opens with No focused, as the game's own confirmations do, so confirming at once goes back to
  the fight instead of ending it.
- A Start that can't run (no ship to fly, or no ring map) gives the focus back to the simulator's button, instead of
  leaving nothing focused.
- The dialog draws on the layer of the CanvasLayer holding the Tuning screen; `LAYER` is now `LAYER_FALLBACK`, used
  only without that screen.
- The autoload's overrides check `_csArena` with `is_instance_valid`, so an arena gone without clearing it no longer
  keeps dropping experience, story flags, encounters, highlights and new ships for the rest of the session.
- New file `Badge.gd`, the Shift badge, kept identical in the other mods that have one. In `Code.gd`: new
  `_CS_TOOLTIP_PAD`, `_CS_KEY_HINT`, `_CS_BADGE_SCRIPT`, `_CS_SHIFT_BADGE`, `_csMakeShiftBadge()` and
  `_csIsShortcut()`; `_notification`, `_csUpdateTooltip()` and `_csActionKey()` removed, since the badge follows the
  control scheme and the language by itself.
- `DESCRIPTION_SUFFIX` (from `SettingsUI.gd` and `ShipList.gd`) and `GAME_TUNING_ITEMS` (from both) moved to
  `Settings.gd`. `SettingsUI.gd`'s `pageTheme` is a member, which the end confirmation takes. `CombatLayer.gd`'s
  `setup(station, simulation, confirmTheme)` takes the simulator's layer and that theme; its `GAME_THEME`,
  `STATION_SIMULATION`, `STATION_SIMULATION_UPSCALE` and `STATION_TUNING` removed, `SIMULATION_UPSCALE` added,
  `_upscale` and `_picture` no longer members.
- The README describes the gamepad controls, the Shift badge and `Badge.gd`, and the dialog's scrolling.

## 1.0.2
- Fixes a crash the game could have the first time the dialog's ship list drew its pictures in a game session: each
  picture's viewport is now freed with its ship still in it (`_drawPicture()`), which avoids a Godot 3 bug.

## 1.0.1
- The README's *Disclaimer* no longer names the author.
- Adds this CHANGES.md.
