# MarketAdvisor - Changes

## 1.3.3
- The row under your cash in the Mineral Market's header reads *Parked in ore:*, with a colon, and its value sits a
  space's width further from the caption, clear of the colon (`MARKETADVISOR_PARKED`).
- `Code.gd`: `_maBuildParked()` widens the row's `separation` by the width of a space in the caption's font, once the
  row is in the tree.
- README: the header's row.

## 1.3.2
- Licensed under the MIT License instead of the GNU GPLv3: the LICENSE in the zip and the README's *About* and
  *Disclaimer* say so.

## 1.3.1
- The Shift badge sits inside the Trade button, on its left, as CombatSimulator's sits on the simulator's button,
  instead of just left of it: the button widens to fit it and keeps its text on the right, clear of it, and a click on
  the badge is the button's, Shift+Click too.
- `Code.gd`: `_maMakeShiftBadge()` takes no row; new `_maBadgeInset()` and `_maFitBadge()`.

## 1.3.0
- The settings open from the Mineral Market's Trade button: Shift+Click on it, or with a gamepad, on the highlighted
  button, `PAD_BUTTON` while `PAD_MODIFIER` is held (`Badge.gd`), even while the button is disabled (nothing to trade),
  and never trading. The Shift badge, with its tooltip, sits just left of the button. Esc, or the controller's B or
  Start button, closes the settings and brings the market back with the Trade button highlighted. The station menu's
  Mineral Market entry no longer has a badge or a Shift+Click of its own: a Shift+Click there opens the market, and the
  entry is free for other mods.
- New setting, *Mark the Mineral Market entry* (`alertMark`, last in the Trading group, on at first): switched off, the
  station menu's entry never gets the alert mark. A save without it gets the default.
- The advice and the line comparing today's prices with the chart's average are in the small font the Shift badge is
  lettered in (`Badge.gd` `SMALL_FONT_THEME`) instead of the menu font.
- The Trade button has the game's hover and focus sounds, as the sliders above it: the row has its own copy of the
  game's tooltip node, which also shows the badge's tooltip.
- `Code.gd`: `_MA_SETTINGS_UI`, `_MA_BADGE_SCRIPT`, `_MA_SETTINGS_TOOLTIP` and `_MA_SETTINGS_TOOLTIP_PAD` moved here
  from `StationMenu.gd`; new `_MA_GAME_TOOLTIPS`, `_MA_TUNING`, `_MA_HEADER_TITLE` (the settings screen's title, the
  market's own), `_maShiftBadge`, `_maSettingsScreen`, `_maMakeShiftBadge()`, `_maAttachTooltips()`,
  `_maOnTradeInput()`, `_maOpenSettings()` and `_maOnSettingsClosed()`; `_ready()` loads the save's settings
  (`loadFromState()`), which `StationMenu.gd` used to; the row and its button are named `Row` and `Trade`
  (`Details/MarketAdvisor/Row/Trade`).
- `StationMenu.gd` keeps only the alert mark: `_MA_SETTINGS_UI`, `_MA_SETTINGS_TOOLTIP`, `_MA_SETTINGS_TOOLTIP_PAD`,
  `_MA_BADGE_SCRIPT`, `_maShiftBadge`, `_maScreens`, `_maMarket`, `_maTuning`, `_maSettingsScreen`,
  `_maMakeShiftBadge()`, `_maOnMarketInput()` and `_maOpenSettings()` removed; new `_MA_MARKET_SCREEN`, the path
  that was written inline; `_maUpdate()` also follows `settingsChanged`.
- `SettingsUI.gd`: new signal `closed`, emitted when Esc or the controller's B or Start button closes the screen (not
  when another screen takes its place).
- `Settings.gd`: new `alertMark`. `i18n/en.po`: new `MARKETADVISOR_ALERT_ENTRY` and `MARKETADVISOR_ALERT_ENTRY_DESC`;
  the comments of the badge's tooltips name the Trade button.
- README: the settings from the Trade button, the new setting, the advice's font.

## 1.2.1
- With a gamepad, the Shift badge's tooltip shows while the Mineral Market entry is highlighted: a gamepad shows no
  hover (`attachTooltip()` with the entry as its `focusOwner`).
- Comments in `StationMenu.gd` name `Badge.gd`'s `PAD_BUTTON` instead of the button it holds.
- README: the badge's tooltip with a gamepad.

## 1.2.0
- A Shift badge beside the station menu's Mineral Market entry tells how to open the settings: it reads Shift with
  keyboard and mouse, and the gamepad's twin of Shift+Click (`PAD_TEXT` in `Badge.gd`) while the game is played with
  a gamepad (the game's Controls setting, which with Auto follows the device last used). Hovering it shows its
  tooltip, which the entry no longer has.
- With a gamepad, the settings open from the highlighted Mineral Market entry: hold `PAD_MODIFIER` and press
  `PAD_BUTTON` (`Badge.gd`). Opening them no longer needs a mouse and a keyboard.
- New `Badge.gd`, the badge, kept identical in every mod with a Shift badge (CombatSimulator, CrewCheapHireNotifier,
  DealerNotifier, DiveSkipTransit, ServiceNotifier).
- `StationMenu.gd`: new `_MA_SETTINGS_TOOLTIP_PAD`, `_MA_BADGE_SCRIPT`, `_maShiftBadge` and `_maMakeShiftBadge()`;
  `_maUpdate()` writes only the entry's text.
- `i18n/en.po`: `MARKETADVISOR_SETTINGS_TOOLTIP` reworded, now the badge's tooltip; new
  `MARKETADVISOR_SETTINGS_TOOLTIP_PAD`, the same with a gamepad.
- `Code.gd`: new `_MA_DETAILS`, `_MA_LIST_MARGIN` and `_MA_PRICES_OPACITY`, for the paths and the value that were
  written inline; `_MA_HEADER_BOX` starts from `_MA_DETAILS`.
- `SettingsUI.gd`: `_labelArg()` removed, since no setting has a `labelArg` (nor does `SETTINGS` describe one any
  more); a row's name is its label, translated.
- README: the badge, the gamepad's twin of Shift+Click and `Badge.gd`; the advice warns about a sale below average
  only when it sells to get the cash back up to the range, as it always has.

## 1.1.0
- New setting, *Tolerance* (`tolerance`, in the cash reserve's group, shown in percent): the cash reserve gets a range,
  the reserve less and plus that share of it. The Trade button buys only once your cash is above the range, and sells
  only once it is below, either way back to the reserve itself; inside the range, nothing is traded and the Mineral
  Market entry isn't marked. So a small change in your cash no longer makes it sell ore at a bad price, or buy at a
  high one, only to match the reserve exactly. At a tolerance of 0, it trades as before.
- The settings screen's Cash reserve row and the advice show the reserve as its range (`MARKETADVISOR_RANGE`), or the
  reserve alone at a tolerance of 0. "Not enough ore to sell" now means selling everything can't reach the range.
- The Services entry's alert mark and its two switches (*Alert for Jameson's Insurance*, *Alert for Scrapwright
  Recovery Operations*) moved to a mod of their own, ServiceNotifier, which watches every service that can be bought
  again after a cooldown or as a compensation. The settings screen has two groups. A save's old switches are dropped
  the next time the settings are written (a new `FORMAT_VERSION`).
- `Settings.gd`: new `tolerance`, `shown` on every slider, `toShown()` / `fromShown()`, `floorRange()`, the static
  `formatCash()` (any whole amount; `formatFloor()` now writes through it) and `RANGE`; `floorText()` gives the range.
  Removed: `alertInsurance`, `alertScrapwright` and the `service` field.
- `Advisor.gd` `plan()` takes the range (`low`, `high`) besides the reserve (`floor`).
- `SettingsUI.gd`: a slider's values go through `toShown()` / `fromShown()`; `GROUPS` without `services`.
- `StationMenu.gd`: only the Mineral Market entry. Removed: `_MA_SERVICE_ROWS`, `_maServicesButton`, `_maServicesKey`,
  `_maServiceDue`, `_maQueued`, `_maQueueServices()` and `_maCheckServices()`.
- `i18n/en.po`: new `MARKETADVISOR_CASH_TOLERANCE`, `MARKETADVISOR_CASH_TOLERANCE_DESC` and `MARKETADVISOR_RANGE`;
  `MARKETADVISOR_CASH_AMOUNT_DESC` and `MARKETADVISOR_CASH_POWER_DESC` tell about the range. Removed:
  `MARKETADVISOR_GROUP_SERVICES`, `MARKETADVISOR_ALERT_INSURANCE`, `MARKETADVISOR_ALERT_SCRAPWRIGHT` and their
  descriptions.
- README: the tolerance, the range and the settings' two groups; the mark is the Mineral Market's alone; ServiceNotifier
  in the chain of `EnceladusMenu.gd` mods.
