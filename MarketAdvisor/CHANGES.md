# MarketAdvisor - Changes

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
