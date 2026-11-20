# DealerNotifier - Changes

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
