# MarketAdvisor - ΔV: Rings of Saturn

Keeps the cash reserve you set by putting the rest of your cash in ore at the Mineral Market, with a Trade button that
buys and sells for you on the best days the price charts show, and marks the station menu's Mineral Market entry when
a trade is due.

## What it does and why
- **What:** a row at the bottom of the Mineral Market: a line of advice, a line comparing today's prices with each
  chart's average, and a Trade button that makes exactly the trades the advice names. With your cash above the cash
  reserve's range, it buys ore with the cash above the reserve; below the range, it sells that ore back up to the
  reserve. Either way, your cash ends up within one tonne's price above the reserve. Inside the range, nothing is
  traded.
- **The range:** the reserve, give or take its *Tolerance*, a share of it you set. So a small change in your cash, such
  as a repair or a sale, doesn't make the Trade button sell ore at a bad price, or buy ore at a high one, only to match
  the reserve exactly. A trade brings your cash back to the reserve itself, the middle of the range, which leaves room
  for the next change either way. At a tolerance of 0, every difference of a tonne's price is traded. The screens show
  the reserve as its range: its lowest and its highest cash, as the `MARKETADVISOR_RANGE` text writes them.
- **Which ore:** the cash goes into the main mineral (`MAIN_MINERAL` in `Settings.gd`), or, with *Trade all ores*,
  into every mineral the market trades: the ones furthest below their chart's average first, each up to the most the
  market lets you hold; selling takes those furthest above their average first, and ends with the cheapest tonnes, so
  the cash lands close to the reserve. The advice warns when it sells one of them more than `WARN_BELOW_AVERAGE` (in
  `Advisor.gd`) below its average.
- **The ore you bring back** from your dives is sold too (*Sell stored ore*, on at first). The mod keeps, with your
  save, the tonnes the Trade button bought (*parked* in ore), so it tells them from the ore of your dives, even of the
  same mineral; only the rest is sold. Selling a parked tonne by hand takes it off the record. A save made before the
  mod, or a new game, takes what it holds of the parking minerals as parked, once, so ore bought before isn't sold as
  ore of a dive.
- **The best day:** while your ship is in maintenance (repairs and new equipment keep it at the station until a time),
  the advice can wait: it sells on a later day of the stay when the chart forecasts a higher price then, and buys on one
  with a lower price, naming the mineral and the date. With the ship ready, it trades now. The forecast is the chart's,
  as good as your crew's geologist makes it (GAME.md *Mineral Market*).
- **The header:** a row right under your cash, *Parked in ore*, with what the parked tonnes would sell for today. It is
  the game's own row for your insurance, which the market's header keeps hidden, copied.
- **The alert mark** (the " (*)" after a menu entry's text): on the station menu's Mineral Market entry while the
  advice is to trade now. The Services entry's mark, for services that can be bought again, is ServiceNotifier's.
- **Why:** the market buys and sells at the same price, with no fee, and every price drifts back towards its average.
  So cash you don't need now is better kept in ore bought below its average, and sold above it, than left idle; doing
  that by hand means reading every chart at every visit. The mark saves opening the market to check.
- **Settings:**
  - **Shift+Click** the Mineral Market entry to open them, as the entry's tooltip says. A plain click still opens the
    market. They open where the market does, with the same frame, and close the way the game's screens do: Esc, the
    controller's B or Start button, or picking another entry of the menu.
  - Laid out as the Tuning screen: a window with the description of the selected setting, then two groups:
    - *Cash reserve*: *Use scientific notation* (instead of thousands, millions and billions), *Amount* and *Power of
      ten*, two sliders that make the reserve, the amount times ten to the power, and *Tolerance*, in percent; then a
      row under them with the reserve's range.
    - *Trading*: *Trade all ores* and *Sell stored ore*.
  - Each setting's default, range and step are in `SETTINGS` at the top of `MarketAdvisor/Settings.gd`, inside the zip.
  - Your settings and the parked tonnes are kept in your save game, each save with its own, and written to disk the
    next time the game saves. A new game, or a save made before the mod, starts from the defaults.
  - Opening them needs a mouse and a keyboard; a controller can use and close them.
  - The mod's texts are in `MarketAdvisor/i18n/en.po`, inside the zip.

## For modders
- Six scripts: `Code.gd` (the Mineral Market's script extension: the row, the header's row, trading), `StationMenu.gd`
  (the station menu's script extension: the alert mark, opening the settings), `Advisor.gd` (the advice), `SettingsUI.gd`
  (the settings screen) and `Settings.gd` (the settings model the others share), plus `ModMain.gd`. The texts are in
  `i18n/en.po`.
- **The market** (GAME.md *Mineral Market*): one slider row per mineral of `CurrentGame.mineralPrices`
  (`enceladus/MineralSellSlider.gd`, the market's `minerals`), each trading whole tonnes (`multiplier`) at the day's
  price (`price`), the same buying and selling, up to `maxOre` held. A move of the slider trades the difference from
  the tonnes held, changes the money and logs the trade. Each row's chart (`enceladus/MineralPriceChart.gd`) shows a
  point a day, its last `lookAhead` hours a forecast blended by the crew's prediction error.
- Script extension of `res://enceladus/MineralMarket.gd` (`Code.gd`), the script of the station's Mineral Market
  screen (`enceladus/MineralMarket.tscn`). The tag `group = MineralMarket` in `Mod.manifest` names it.
  - `_ready()` (the game's runs first and builds the slider rows) builds the row under the list (`_maBuildRow()`,
    inside the list's side margins) and the parked row (`_maBuildParked()`: a copy of the header's hidden `Insurence`
    row, `_MA_HEADER_ROW`, without its scripts, signals and `Pinger` sound, captioned `_MA_PARKED`, its value written
    with the `Money` label's `format`), and works the advice out again, once per frame and after the game's own
    handlers (`_maQueue()`), on `CurrentGame`'s `dayPassed`, `hourPassed`, `moneyChanged`, `moneyOrInsuranceChanged`
    and `employmentChanged`, on the settings' `settingsChanged` and when the screen shows.
  - Overrides `setKidsFocus()`, calling the parent's: the sliders' focus chain goes on down to the Trade button.
  - `_maInput()` feeds `Advisor.plan()` only what the player sees: the cash, the whole tonnes held, each slider's day
    price, each parking mineral's average over the chart's history (`_maAverages()`, `_MA_AVERAGE_SAMPLES` points,
    once per chart day), and each chart's forecast for the days left until the ship's maintenance ends
    (`_maForecast()`, as `MineralPriceChart.gd` `updateChart` draws it: the true price blended into the price at the
    mirrored time by `CurrentGame.getMineralPricePredictionError`), plus the parked tonnes, held to what is held.
  - The Trade button (`_maTrade()`) works the advice out again, then makes each trade through its mineral's slider, as
    a drag would: `updateMineralCount()` and `_onMoneyUpdated(money)` first, since the game emits `moneyChanged` a
    frame after the money changes and each trade changes what the next can spend; then the slider to the tonnes held
    (which trades nothing), then to the trade's tonnes. Each trade is the game's: its price, limits, money and log.
    The parked tonnes the advice ends with are stored, down to what the sliders left.
  - Emits `_maAdviceChanged(tradeNow)`, which the menu's extension follows for the alert mark.
- **The advice** (`Advisor.gd`, static functions of their input, which touch neither the game nor the scene):
  `plan(input)` returns the trades to make now (one per mineral, sales first, in whole tonnes), the parked tonnes
  after them, the trades worth waiting for (mineral, date, sell or buy), the cash after, and whether every parking
  mineral is full (`capped`), the reserve out of reach (`short`) or a sale more than `WARN_BELOW_AVERAGE` below
  average (`warnings`). Stored ore is sold today unless the forecast has a higher price later in the stay. Its input
  has the reserve (`floor`) and its range (`low` and `high`, from `Settings.gd` `floorRange()`). Cash above the range
  is parked down to the reserve, in the parking minerals cheapest against their average first, up to `maxTonnes`,
  unless the first one's forecast is lower later; cash below it (the ore left for a better day counted) sells parked
  tonnes back up to the reserve, dearest against average first in whole tonnes that don't overshoot, then the cheapest
  tonnes, unless the first one's forecast is higher later. `short` is when selling every parked tonne can't bring the
  cash into the range.
- Script extension of `res://enceladus/EnceladusMenu.gd` (`StationMenu.gd`), the script of the station menu. The
  Mineral Market entry is its `MineralMarket` button, a plain button whose text is a translation key. While marked, its
  text is `tr(_MA_ALERT) % tr(key)`; otherwise the key again. The mark follows `_maAdviceChanged`. Shift+Click, the
  tooltip and the settings screen's place are CrewCheapHireNotifier's (see its README): the press is accepted in the
  button's `gui_input`, so the market stays closed. Overrides `_ready` and `_notification` (the game's script has
  neither): the station is built anew after every load and new game, so `_ready` loads the save's settings
  (`loadFromState()`); on `NOTIFICATION_TRANSLATION_CHANGED` it writes the entry's text again, since a marked one holds
  translated text. Without the right-hand screens' container or the market screen there are no settings, tooltip or
  mark, and Shift+Click is a plain click. It leaves every other entry alone.
- **The settings model** (`Settings.gd`) follows CrewCheapHireNotifier's (`shared()`, `SETTINGS`, `cfg`, `getValue` /
  `setValue`, `loadFromState` / `saveToState`, `modId()`, `modName()`, `modVersion()`, `toShown()` / `fromShown()`).
  Each setting has a `type` (`"bool"` or `"float"`, a slider with `min`, `max`, `step`, `unit`, `format` and `shown`,
  the factor from the stored value to the one shown: the tolerance is stored as a fraction and shown in percent) and a
  `group`; the power of ten's has `power` (its row shows the power it stands for) and *Trade all ores* a
  `descriptionArg` (`MAIN_MINERAL`). `floorCash()` gives the reserve, `floorRange()` its range in whole E$ (the reserve
  less and plus its tolerance's share of it), and `floorText()` the range as the screens show it (`RANGE`, or the
  reserve alone where the range has none to give: a tolerance of 0, or a reserve of 0). The static `formatCash()` writes
  any whole amount with the largest of `THOUSANDS_SUFFIXES` that fits and no trailing zeros, or in scientific notation;
  `formatFloor()` writes an amount times a power of ten through it. `parkingMinerals()` gives the minerals cash is kept
  in. A slider's value is clamped and snapped to its step, a switch's a bool; anything else gives the default, so a
  save edited by hand can't break anything.
- **The save:** in `CurrentGame.state.ui` under the mod's id from `Mod.manifest`: `formatVersion` (`FORMAT_VERSION`),
  `modVersion`, one value per setting, and `parked` (whole tonnes by mineral, through `getParked` / `setParked`, which
  store without `settingsChanged`: not a setting). A save without `parked` takes its holdings of the parking minerals
  as parked, once.
- **The settings screen** (`SettingsUI.gd`) is built as DiveSkipTransit's, but copies the live Mineral Market screen's
  theme, panel, minimum size and size flags, so it opens in the market's place with its frame. Under the header (the
  entry's key), the description window, nested as `enceladus/Tuning.tscn` nests its own (`GAME_WINDOW_MARGIN`,
  `GAME_WINDOW`, `GAME_WINDOW_INSIDE`) with the live Tuning screen's theme, margins and panel, keeping room for
  `DESCRIPTION_LINES` lines; then an `Items` box of `enceladus/Tuning/TuningItems.tscn` groups, one per `GROUPS`
  entry, with a `TuningBoolValue` or `TuningFloatValue` row per setting, named by its label in the game's language, a
  slider's range, step and value as the screen shows them (`toShown()`). Under the cash group's rows, the cash
  reserve's row (`_addCashRow()`): a copy of a slider row's line without its signals, named `CASH_TOTAL`, its name and
  reset button out of reach, its value `floorText()`. On `tuningChanged` (a change, or a row taking the focus) it sets
  the row's `tune.current` (DiveSkipTransit's fix: a switch doesn't update it itself), calls `setValue` (a slider's
  value through `fromShown()`), and shows the row's description, its label + `DESCRIPTION_SUFFIX`.
- **The texts.** `i18n/en.po` holds every text the mod shows, under keys that start with `MARKETADVISOR_`. `ModMain.gd`
  loads it with `load()` and `TranslationServer.add_translation`, as CrewCheapHireNotifier does (its README says why).
- **With CrewCheapHireNotifier, DealerNotifier, DiveSkipTransit and ServiceNotifier**, which extend `EnceladusMenu.gd`
  too: mods load by path, so the chain is game ← CrewCheapHireNotifier ← DealerNotifier ← DiveSkipTransit ←
  MarketAdvisor ← ServiceNotifier. All five override `_ready` and `_notification` without calling the parent's; their
  members are distinct, each writes only its own entry's text, and opening one's screen hides the others'
  (`hidefoka`).
- Members of the market's extension (`Code.gd`): the signal `_maAdviceChanged`, `MarketAdvisor` and `_MA_ADVISOR`
  (preloads), `_MA_CHART`, `_MA_AVERAGE_SAMPLES`, the translation keys `_MA_TRADE`, `_MA_TONNES`, `_MA_SELL`, `_MA_BUY`,
  `_MA_LEAVES`, `_MA_WAIT_SELL`, `_MA_WAIT_BUY`, `_MA_WARN`, `_MA_CAPPED`, `_MA_SHORT`, `_MA_AT_FLOOR`, `_MA_VS_AVERAGE`,
  `_MA_LOWER`, `_MA_HIGHER`, `_MA_SAME` and `_MA_PARKED`, the header's paths `_MA_HEADER_BOX`, `_MA_HEADER_MONEY`,
  `_MA_HEADER_ROW`, `_MA_HEADER_CAPTION`, `_MA_HEADER_VALUE` and `_MA_HEADER_SOUND`, `_MA_MONEY_FORMAT_FALLBACK`,
  `_maSettings`, `_maParkedValue`, `_maMoneyFormat`, `_maAdvice`, `_maPrices`, `_maButton`, `_maPlan`, `_maAverage`,
  `_maAverageDay`, `_maQueued`, `_maBuildParked()`, `_maBuildRow()`, `_maQueue()`, `_maRefresh()`, `_maTrade()`,
  `_maParkedWorth()`, `_maClampedParked()`, `_maSlider()`, `_maInput()`, `_maNames()`, `_maDaysLeft()`,
  `_maForecast()`, `_maAverages()`, `_maHistoryAverage()`, `_maAdviceText()` and `_maPricesText()`.
- Members of the menu's extension (`StationMenu.gd`): `MarketAdvisor` and `_MA_SETTINGS_UI` (preloads), `_MA_ALERT`
  and `_MA_SETTINGS_TOOLTIP` (translation keys), `_maMarketButton`, `_maMarketKey`, `_maScreens`, `_maMarket`,
  `_maTuning`, `_maSettingsScreen`, `_maSettings`, `_maTradeNow`, `_maOnAdvice()`, `_maUpdate()`, `_maOnMarketInput()`
  and `_maOpenSettings()`. Both extensions declare `_maSettings`, which is fine: they extend different game scripts.
- Tested outside the game in a headless Godot 3.6 with the game's `EnceladusMenu.gd`, `HidingMarginContainer.gd`,
  `MineralMarket.gd`, `MineralSellSlider.gd`, `MineralPriceChart.gd`, `ServiceUI.gd`, the Tuning screen's groups and
  rows, `HeaderWithMoney.tscn` and `Shower.tscn`: the station built in code as its scene nests it, the market and the
  Services rows (which the mod leaves alone) from stubs of their scenes with the game's scripts and values, and the
  game's market prices drawn from each save's seed (the `market` suite of the repository's test harness, which also
  runs a year of stays); with CrewCheapHireNotifier, DealerNotifier, DiveSkipTransit and ServiceNotifier in every load
  order (the `dealer` suite); and in the game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).

## Disclaimer
ΔV: Rings of Saturn is made and owned by Kodera Software. The game's name, and everything from the game this mod uses
or shows, belong to Kodera Software.

The author of this mod has no tie of any kind to the game or to Kodera Software. Kodera Software didn't make,
check or approve this mod, and doesn't support it.

This mod is provided as is, for free, and without warranty of any kind, express or implied: use it at your own risk.
The GNU GPLv3 it is licensed under says so in full, in its sections 15 and 16.
