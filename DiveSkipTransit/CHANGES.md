# DiveSkipTransit - Changes

## 1.1.2
- Licensed under the MIT License instead of the GNU GPLv3: the LICENSE in the zip and the README's *About* and
  *Disclaimer* say so.

## 1.1.1
- Fix: the game's notices that leaving the ring brings (*Acquired* with the name of the ship the arm held, a drone's
  cargo in transit) were cut short when the station loaded at once, and with the transit played fast, *Acquired* stood
  on screen without the ship's name. What the ring's notification panel still had to show when the ring scene goes to
  the station now shows on the station's, in full; a sped-up exit too short for the panel hides the ring's from its
  start.
- With a gamepad, the Shift badge's tooltip shows while the Launch Ring Dive entry is highlighted: a gamepad shows no
  hover (`attachTooltip()` with the entry as its `focusOwner`). Comments in `StationMenu.gd` name `Badge.gd`'s
  `PAD_BUTTON` instead of the button it holds.
- `Code.gd`: new `_DST_NOTICES`, `_dstNotices`, `_dstHidden`, `_dstFitNotices()`, `_dstExitSecondsLeft()`,
  `_dstNoticeSecondsLeft()`, `_dstHideNotices()`, `_dstListenToNotices()`, `_dstOnNotice1()`, `_dstOnNotice3()`,
  `_dstOnNotice4()`, `_dstNote()`, `_dstNoticePlayer()` and `_dstNoticesShowing()`; it overrides `goToEnceladus`.
- `Station.gd`: new `_DST_STATION_NOTICES` and `_dstShowCarriedNotices()`. `Settings.gd`: new `NOTICES` and
  `carriedNotices` (not a setting, never saved).
- README: the notices, at the station instead; the badge's tooltip with a gamepad.

## 1.1.0
- A Shift badge beside the station menu's Launch Ring Dive entry tells how to open the settings: it reads Shift with
  keyboard and mouse, and the gamepad's twin of Shift+Click (`PAD_TEXT` in `Badge.gd`) while the game is played with
  a gamepad (the game's Controls setting, which with Auto follows the device last used). Hovering it shows its
  tooltip, which the entry no longer has.
- With a gamepad, the settings open from the highlighted Launch Ring Dive entry: hold `PAD_MODIFIER` and press
  `PAD_BUTTON` (`Badge.gd`). Opening them no longer needs a mouse and a keyboard.
- New `Badge.gd`, the badge, kept identical in every mod with a Shift badge (CombatSimulator, CrewCheapHireNotifier,
  DealerNotifier, MarketAdvisor, ServiceNotifier).
- `StationMenu.gd`: new `_DST_SETTINGS_TOOLTIP_PAD`, `_DST_TUNING_SCREEN`, `_DST_BADGE_SCRIPT`, `_dstShiftBadge` and
  `_dstMakeShiftBadge()`. Removed: `_notification` and `_dstUpdateTooltip()`, since the badge writes its tooltip again
  by itself after a change of language or of control scheme.
- `i18n/en.po`: `DIVESKIPTRANSIT_SETTINGS_TOOLTIP` reworded, now the badge's tooltip; new
  `DIVESKIPTRANSIT_SETTINGS_TOOLTIP_PAD`, the same with a gamepad.
- `Code.gd` keeps the settings and the title card player from `_ready` (new `_dstModel`, `_dstTitles`) instead of
  looking them up on every physics frame.
- `Settings.gd`: new `toShown()` / `fromShown()`, the settings API's conversion between stored and shown values, which
  here give the value back as it is; `SettingsUI.gd` fills and reads its rows through them.
- The description in `Mod.manifest` only says what the mod does; the details are in the README.
- README: the badge, the gamepad's twin of Shift+Click and `Badge.gd`; the other mods on the station menu
  (DealerNotifier, MarketAdvisor, ServiceNotifier) in the chain of `EnceladusMenu.gd` extensions; CombatSimulator and
  GeologyByMass, which extend `Enceladus.gd` and `ship-ctrl.gd` too.

## 1.0.2
- The README's *Disclaimer* no longer names the author.

## 1.0.1
- The README has a new *Disclaimer*: the game belongs to Kodera Software, the author has no tie to it or to the
  company, and the mod is provided as is, for free, without warranty.
- Adds this CHANGES.md.
