# DealerNotifier - Changes

## 1.2.0
- Shift+Click has a gamepad twin: on the highlighted Dealer entry, the `PAD_BUTTON` button pressed while the
  `PAD_MODIFIER` one is held opens the settings too (constants of the new `Badge.gd`).
- A small badge beside the station menu's Dealer entry tells how to open the settings: it reads Shift, or the gamepad
  twin (`PAD_TEXT`) while the game is played with a gamepad (the game's Controls setting, or with Auto the device last
  used). Hovering it shows how, in a tooltip that follows the control scheme too. The tooltip was the Dealer entry's:
  the entry has none now.
- The settings' description window stays at the height of the Dealer's whatever the ship, so the switches under it
  don't move, and a longer description scrolls, with the mouse wheel or the right stick; each ship's starts at its top.
- Fix: the settings' list opens at its top, with the Condition group's title in sight.
- The Dealer screen's badge: its tooltip shows sooner, without the hover sound (nor the ship name's again); with a
  gamepad, it shows while the ship's name has the focus.
- New script, `Badge.gd` (the same file in every mod that has a Shift badge): the Shift badge and the Dealer screen's
  badge, their look and their tooltips, and the gamepad's twin of Shift+Click. Constants `PAD_MODIFIER`, `PAD_BUTTON`,
  `PAD_MODIFIER_NAME`, `PAD_BUTTON_NAME`, `PAD_TEXT`, `SMALL_FONT_THEME`, `TOOLTIP_DELAY`, `TOOLTIP_FADE` and
  `BUTTON_HOVER_MUTE`; `isPadShortcut()`, `dress()`, `hangBeside()`, `setShiftTooltips()` and `attachTooltip()`.
- `i18n/en.po`: `DEALERNOTIFIER_SETTINGS_TOOLTIP` reworded (it is the badge's); new
  `DEALERNOTIFIER_SETTINGS_TOOLTIP_PAD`.
- `Code.gd`: new `_DN_SETTINGS_TOOLTIP_PAD`, `_DN_DEALER_SCREEN`, `_DN_BADGE_SCRIPT`, `_dnShiftBadge` and
  `_dnMakeShiftBadge()`.
- `DealerScreen.gd`: new `_DN_ENTRY_NAME`, `_DN_ENTRY_BUY`, `_DN_ENTRY_OWNED`, `_DN_ENTRY_PICTURE` and
  `_DN_BADGE_SCRIPT`; the badge is a `Badge.gd`.
- `SettingsUI.gd`: new `GAME_ROW`, `GAME_ROW_RESET`, `GAME_ROW_VALUE`, `DESCRIPTION_LINES`, `DESCRIPTION_SCROLL_UP`,
  `DESCRIPTION_SCROLL_DOWN`, `DESCRIPTION_SCROLL_SPEED`, `_descriptionPanel`, `_descriptionScroll`, `_descriptionAt`,
  `_keepDescriptionHeight()`, `_scrollToTop()` and `_process`.
- README: the Shift badge, the gamepad twin, the description's scrolling, `Badge.gd`; the scripts' count, the game
  version the series were checked in, and the other mods on the station menu.

## 1.1.0
- New settings, New and Used, in a group above the ships, both on at first: a ship of a model you switched on marks
  the Dealer entry only if its condition is switched on too. New is what the Dealer marks NEW (a ship younger than
  `_DN_GAME_NEW_AGE`, the game's limit), Used everything else. Switching one on doesn't mark the ships the dealer has
  already, as switching a model on doesn't.
- Select all and Select none, under the ships, switch every switch on or off, New and Used too.
- The note above the ships is gone (`DEALERNOTIFIER_WATCHED_DESC` removed): the README and the wiki explain the
  switches. New texts in `i18n/en.po`: `DEALERNOTIFIER_CONDITION`, `DEALERNOTIFIER_NEW`, `DEALERNOTIFIER_USED`,
  `DEALERNOTIFIER_SELECT_ALL`, `DEALERNOTIFIER_SELECT_NONE`.
- Fix: the settings screen frees each picture's viewport with its ship still in it, avoiding an intermittent crash of
  Godot 3 (`CollisionObject2DSW` `_set_space`).
- For modders: `Settings.gd` adds `watchNew` and `watchUsed` (settings that aren't per model, with a `group`), the
  stock's entries a `used` flag, and `_watchedShips()`; `setValue` makes known every ship a switch turned on lets in.
  `FORMAT_VERSION` goes up: a save without the new settings gets their defaults. `DealerScreen.gd` adds
  `_DN_GAME_NEW_AGE` and `_dnIsNew()`. `SettingsUI.gd` adds `GAME_BUTTON_SOUNDS`, `SELECT_ALL`, `SELECT_NONE`,
  `_buttons()`, `_keyGroups()`, `_alignSwitch()`, `_selectAll()`, `_switches`, `_keyRows`, `_keys` and `_bulk`, and
  drops `_note`.

## 1.0.2
- The README's *Disclaimer* no longer names the author.

## 1.0.1
- The README has a new *Disclaimer*: the game belongs to Kodera Software, the author has no tie to it or to the
  company, and the mod is provided as is, for free, without warranty.
- Adds this CHANGES.md.
