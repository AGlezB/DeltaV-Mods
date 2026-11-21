# DiveSkipTransit - Changes

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
