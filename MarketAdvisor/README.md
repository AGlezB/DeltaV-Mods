# MarketAdvisor - ΔV: Rings of Saturn

Keeps the cash reserve you set by putting the rest of your cash in ore at the Mineral Market, with a Trade button that
buys and sells for you on the best days the price charts show, and marks the station menu's Mineral Market entry when
a trade is due.

## What it does and why
- **What:** a row at the bottom of the Mineral Market: a line of advice, a line comparing today's prices with each
  chart's average, both in a small font, and a Trade button that makes exactly the trades the advice names. With your
  cash above the cash reserve's range, it buys ore with the cash above the reserve; below the range, it sells that ore
  back up to the reserve. Either way, your cash ends up within one tonne's price above the reserve. Inside the range,
  nothing is traded.
- **The range:** the reserve, give or take its *Tolerance*, a share of it you set. So a small change in your cash, such
  as a repair or a sale, doesn't make the Trade button sell ore at a bad price, or buy ore at a high one, only to match
  the reserve exactly. A trade brings your cash back to the reserve itself, the middle of the range, which leaves room
  for the next change either way. At a tolerance of 0, every difference of a tonne's price is traded. The screens show
  the reserve as its range: its lowest and its highest cash, as the `MARKETADVISOR_RANGE` text writes them.
- **Which ore:** the cash goes into the main mineral (`MAIN_MINERAL` in `Settings.gd`), or, with *Trade all ores*,
  into every mineral the market trades: the ones furthest below their chart's average first, each up to the most the
  market lets you hold; selling takes those furthest above their average first, and ends with the cheapest tonnes, so
  the cash lands close to the reserve. When it sells to get your cash back up to the range, the advice warns about each
  of them it sells more than `WARN_BELOW_AVERAGE` (in `Advisor.gd`) below its average.
- **The ore you bring back** from your dives is sold too (*Sell stored ore*, on at first). The mod keeps, with your
  save, the tonnes the Trade button bought (*parked* in ore), so it tells them from the ore of your dives, even of the
  same mineral; only the rest is sold. Selling a parked tonne by hand takes it off the record. A save made before the
  mod, or a new game, takes what it holds of the parking minerals as parked, once, so ore bought before isn't sold as
  ore of a dive.
- **The best day:** while your ship is in maintenance (repairs and new equipment keep it at the station until a time),
  the advice can wait: it sells on a later day of the stay when the chart forecasts a higher price then, and buys on one
  with a lower price, naming the mineral and the date. With the ship ready, it trades now. The forecast is the chart's,
  as good as your crew's geologist makes it (GAME.md *Mineral Market*).
- **The header:** a row right under your cash, *Parked in ore:*, with what the parked tonnes would sell for today. It
  is the game's own row for your insurance, which the market's header keeps hidden, copied, with a space's width more
  between its caption and its value, so the value stays clear of the colon.
- **The alert mark** (the " (*)" after a menu entry's text): on the station menu's Mineral Market entry while the
  advice is to trade now, unless *Mark the Mineral Market entry* is off. That text is all the mod changes in the menu:
  the entry's Shift+Click is left free for other mods.
- **Why:** the market buys and sells at the same price, with no fee, and every price drifts back towards its average.
  So cash you don't need now is better kept in ore bought below its average, and sold above it, than left idle; doing
  that by hand means reading every chart at every visit. The mark saves opening the market to check.
- **Settings:**
  - **Shift+Click** the Trade button to open them, as the Shift badge inside it, on its left, says: it reads Shift, and
    hovering it shows how. It works while the button is disabled too (nothing to trade), and never trades; a plain
    click still trades. With a gamepad (the game's *Controls* setting at *Gamepad*, or at *Auto* once the gamepad was
    used last), the badge reads the gamepad's twin of Shift+Click instead, `PAD_TEXT` in `Badge.gd`, and highlighting
    the button (the D-pad reaches it from the last slider, disabled or not) shows how: on the highlighted button,
    holding the first button and pressing the second opens them. They open in the market's place, with the same frame
    and title. Esc, or the controller's B or Start button, closes them and brings the market back with the Trade
    button highlighted; picking another entry of the menu closes them too, for that entry's screen.
  - Laid out as the Tuning screen: a window with the description of the selected setting, then two groups:
    - *Cash reserve*: *Use scientific notation* (instead of thousands, millions and billions), *Amount* and *Power of
      ten*, two sliders that make the reserve, the amount times ten to the power, and *Tolerance*, in percent; then a
      row under them with the reserve's range.
    - *Trading*: *Trade all ores*, *Sell stored ore* and *Mark the Mineral Market entry* (the alert mark; switch it
      off to check the market yourself, or when another mod marks that entry too).
  - Each setting's default, range and step are in `SETTINGS` at the top of `MarketAdvisor/Settings.gd`, inside the zip.
  - Your settings and the parked tonnes are kept in your save game, each save with its own, and written to disk the
    next time the game saves. A new game, or a save made before the mod, starts from the defaults.
  - The mod's texts are in `MarketAdvisor/i18n/en.po`, inside the zip.

## For modders
- Six scripts: `Code.gd` (the Mineral Market's script extension: the row, the header's row, trading, opening the
  settings, the Shift badge inside the Trade button), `StationMenu.gd` (the station menu's script extension: the alert
  mark),
  `Advisor.gd` (the advice), `Badge.gd` (the badge), `SettingsUI.gd` (the settings screen) and `Settings.gd` (the
  settings model the others share). The texts are in `i18n/en.po`.
- **The market** (GAME.md *Mineral Market*): one slider row per mineral of `CurrentGame.mineralPrices`
  (`enceladus/MineralSellSlider.gd`, the market's `minerals`), each trading whole tonnes (`multiplier`) at the day's
  price (`price`), the same buying and selling, up to `maxOre` held. A move of the slider trades the difference from
  the tonnes held, changes the money and logs the trade. Each row's chart (`enceladus/MineralPriceChart.gd`) shows a
  point a day, its last `lookAhead` hours a forecast blended by the crew's prediction error.
- Script extension of `res://enceladus/MineralMarket.gd` (`Code.gd`), the script of the station's Mineral Market
  screen (`enceladus/MineralMarket.tscn`). The tag `group = MineralMarket` in `Mod.manifest` names it.
  - `_ready()` (the game's runs first and builds the slider rows) loads the save's settings (`loadFromState()`: the
    station is built anew after every load and new game), builds the row under the list (`_maBuildRow()`, inside the
    list's side margins, its nodes named so a path reaches the button: `Details/MarketAdvisor/Row/Trade`; its two lines
    in the Label font of `Badge.gd`'s `SMALL_FONT_THEME`, a font override, so their colours stay the theme's) and the
    parked row (`_maBuildParked()`: a copy of the header's hidden `Insurence` row, `_MA_HEADER_ROW`, without its
    scripts, signals and `Pinger` sound, captioned `_MA_PARKED`, its value written with the `Money` label's `format`;
    once it is in the tree, its `separation` is the theme's plus the width of a space in the caption's font, the gap
    before the value),
    and works the advice out again, once per frame and after the game's own handlers (`_maQueue()`), on
    `CurrentGame`'s `dayPassed`, `hourPassed`, `moneyChanged`, `moneyOrInsuranceChanged` and `employmentChanged`, on
    the settings' `settingsChanged` and when the screen shows.
  - Overrides `setKidsFocus()`, calling the parent's: the sliders' focus chain goes on down to the Trade button. A
    disabled button keeps its focus mode, so the D-pad reaches it while there is nothing to trade.
  - **The settings, from the Trade button.** Where the market is one of the station's right-hand screens (its parent
    has `hidefoka`, `enceladus/HidingMarginContainer.gd`), the button's `gui_input` signal goes to
    `_maOnTradeInput()`: a Shift+left click, or the gamepad's twin (`Badge.gd` `isPadShortcut`), accepts the event and
    opens the settings (`_maOpenSettings()`). Godot 3 sends a control's `gui_input` signal before its own
    `_gui_input`, and only a Button's `_gui_input` ignores it while disabled, so this works on a disabled button; the
    accepted event never reaches an enabled one's `_gui_input`, so nothing is traded. `_maOpenSettings()` makes the
    screen once (`SettingsUI.gd` `setup()` with the market, the sibling Tuning screen, `_MA_TUNING`, and the market
    header's title, `_MA_HEADER_TITLE`), adds it among the right-hand screens, hides them all (`hidefoka()`) and shows
    it. Its `closed` signal (Esc, B or Start) calls `_maOnSettingsClosed()`, which shows the market again as
    `_on_MineralMarket_pressed` does (the `Shower`'s `show`, `setKidsFocus()`) but focuses the Trade button and keeps
    the market's `lastFocus`, the menu entry its own Esc goes back to. Another entry of the menu taking the focus hides
    the settings without `closed`, so the market stays hidden. Without the right-hand screens there is no badge, and
    Shift+Click is a plain click.
  - **The Shift badge** (`_maMakeShiftBadge()`, with `Badge.gd` `dress()`: the button's frame and font colour, the small
    font, `PAD_TEXT` with a gamepad) hangs inside the Trade button: a child of the button, which doesn't lay out its
    children, anchored to the middle of its left side and growing right, up and down, as far from its left edge as the
    button keeps its text from its edges (its normal stylebox's left margin, `_maBadgeInset()`). The button aligns its
    text right and is as wide as its text, the badge and that gap need (`_maFitBadge()`, again whenever the badge or the
    button changes its minimum size: the badge follows the control scheme, the button the language), so the badge never
    covers the text. The badge lets the mouse through, so a click on it is the button's, Shift+Click too; `hangBeside()`
    isn't used, since the row's right margin reaches the panel's edge. It keeps its look while the button is disabled,
    since Shift+Click still works then. `_maAttachTooltips()` adds the game's tooltip node (`_MA_GAME_TOOLTIPS`, as each
    slider row has one) to the row, which shows the badge's tooltip (`attachTooltip()` with the button as its
    `focusOwner`, `setShiftTooltips()` with `_MA_SETTINGS_TOOLTIP` and `_MA_SETTINGS_TOOLTIP_PAD`): on hover, and with a
    gamepad while the button is highlighted. The node also takes the button in, which gets the sliders' hover and focus
    sounds; its `hint_tooltip` stays empty, so it shows none.
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
  mineral is full (`capped`), the reserve out of reach (`short`) or, while selling back up to the range, a sale more
  than `WARN_BELOW_AVERAGE` below average (`warnings`). Stored ore is sold today unless the forecast has a higher price
  later in the stay. Its input
  has the reserve (`floor`) and its range (`low` and `high`, from `Settings.gd` `floorRange()`). Cash above the range
  is parked down to the reserve, in the parking minerals cheapest against their average first, up to `maxTonnes`,
  unless the first one's forecast is lower later; cash below it (the ore left for a better day counted) sells parked
  tonnes back up to the reserve, dearest against average first in whole tonnes that don't overshoot, then the cheapest
  tonnes, unless the first one's forecast is higher later. `short` is when selling every parked tonne can't bring the
  cash into the range.
- Script extension of `res://enceladus/EnceladusMenu.gd` (`StationMenu.gd`), the script of the station menu. The
  Mineral Market entry is its `MineralMarket` button, a plain button whose text is a translation key. While marked, its
  text is `tr(_MA_ALERT) % tr(key)`; otherwise the key again. The mark follows `_maAdviceChanged` from the market
  screen (`_MA_MARKET_SCREEN`) and the `alertMark` setting (`settingsChanged`). That text is all it changes: the entry
  keeps the game's input, so its Shift+Click is free for other mods. Overrides `_ready` and `_notification` (the game's
  script has neither): the menu is ready before the screens, so `_ready` only takes the shared settings, whose save
  values the market loads; on `NOTIFICATION_TRANSLATION_CHANGED` it writes the entry's text again, since a marked one
  holds translated text. Without the market screen there is no mark. It leaves every other entry alone.
- **The settings model** (`Settings.gd`) has the API MODDING.md *Conventions* describes (`shared()`, `SETTINGS`, `cfg`,
  `getValue` / `setValue`, `loadFromState` / `saveToState`, `modId()`, `modName()`, `modVersion()`, `toShown()` /
  `fromShown()`). Each setting has a `type` (`"bool"` or `"float"`, a slider with `min`, `max`, `step`, `unit`, `format`
  and `shown`, the factor from the stored value to the one shown: the tolerance is stored as a fraction and shown in
  percent) and a `group`; the power of ten's has `power` (its row shows the power it stands for) and *Trade all ores* a
  `descriptionArg` (`MAIN_MINERAL`). `floorCash()` gives the reserve, `floorRange()` its range in whole E$ (the reserve
  less and plus its tolerance's share of it), and `floorText()` the range as the screens show it (`RANGE`, or the
  reserve alone where the range has none to give: a tolerance of 0, or a reserve of 0). The static `formatCash()` writes
  any whole amount with the largest of `THOUSANDS_SUFFIXES` that fits and no trailing zeros, or in scientific notation;
  `formatFloor()` writes an amount times a power of ten through it. `parkingMinerals()` gives the minerals cash is kept
  in. A slider's value is clamped and snapped to its step, a switch's a bool; anything else gives the default, so a save
  edited by hand can't break anything.
- **The save:** in `CurrentGame.state.ui` under the mod's id from `Mod.manifest`: `formatVersion` (`FORMAT_VERSION`),
  `modVersion`, one value per setting, and `parked` (whole tonnes by mineral, through `getParked` / `setParked`, which
  store without `settingsChanged`: not a setting). A save without `parked` takes its holdings of the parking minerals
  as parked, once.
- **The settings screen** (`SettingsUI.gd`) is one more of the station's right-hand screens, built from the game's
  Tuning parts; it copies the live Mineral Market screen's theme, panel, minimum size and size flags, so it opens in the
  market's place with its frame. It closes as the game's screens do, and emits `closed` only when Esc or the
  controller's B or Start button closes it, for the market to come back. Under the header (the market's title), the
  description window, nested as `enceladus/Tuning.tscn` nests its own (`GAME_WINDOW_MARGIN`, `GAME_WINDOW`,
  `GAME_WINDOW_INSIDE`) with the live Tuning screen's theme, margins and panel, keeping room for `DESCRIPTION_LINES`
  lines; then an `Items` box of `enceladus/Tuning/TuningItems.tscn` groups, one per `GROUPS` entry, with a
  `TuningBoolValue` or `TuningFloatValue` row per setting, named by its label in the game's language, a slider's range,
  step and value as the screen shows them (`toShown()`). Under the cash group's rows, the cash reserve's row
  (`_addCashRow()`): a copy of a slider row's line without its signals, named `CASH_TOTAL`, its name and reset button
  out of reach, its value `floorText()`. On `tuningChanged` (a change, or a row taking the focus) it sets the row's
  `tune.current` (a switch doesn't update it itself), calls `setValue` (a slider's value through `fromShown()`), and
  shows the row's description, its label + `DESCRIPTION_SUFFIX`.
- **The texts.** `i18n/en.po` holds every text the mod shows, under keys that start with `MARKETADVISOR_`. `ModMain.gd`
  loads it with `load()` and `TranslationServer.add_translation`, as the game loads its own `.po` files (the mod
  loader's `addTranslationsFromCSV` reads nothing from a mod's zip).
- **Stacking.** Other mods may extend `EnceladusMenu.gd` for their own entries: `StationMenu.gd` overrides `_ready` and
  `_notification` without calling the parent's and writes only the Mineral Market entry's text, and opening the mod's
  settings screen (from the Trade button) hides the other screens (`hidefoka`), as theirs hide it.
- Members of the market's extension (`Code.gd`): the signal `_maAdviceChanged`, `MarketAdvisor`, `_MA_ADVISOR`,
  `_MA_SETTINGS_UI` and `_MA_BADGE_SCRIPT` (preloads), `_MA_SETTINGS_TOOLTIP` and `_MA_SETTINGS_TOOLTIP_PAD` (the
  badge's tooltips), `_MA_GAME_TOOLTIPS` (the game's tooltip node), `_MA_TUNING` (the Tuning screen, a sibling),
  `_MA_CHART`, `_MA_AVERAGE_SAMPLES`, the translation keys `_MA_TRADE`, `_MA_TONNES`, `_MA_SELL`, `_MA_BUY`,
  `_MA_LEAVES`, `_MA_WAIT_SELL`, `_MA_WAIT_BUY`, `_MA_WARN`, `_MA_CAPPED`, `_MA_SHORT`, `_MA_AT_FLOOR`,
  `_MA_VS_AVERAGE`, `_MA_LOWER`, `_MA_HIGHER`, `_MA_SAME` and `_MA_PARKED`, the paths of the market's box under its
  header and of the list's margins, `_MA_DETAILS` and `_MA_LIST_MARGIN`, `_MA_PRICES_OPACITY` (how faint the prices'
  line is), the header's paths `_MA_HEADER_BOX`, `_MA_HEADER_MONEY`, `_MA_HEADER_ROW`, `_MA_HEADER_CAPTION`,
  `_MA_HEADER_VALUE`, `_MA_HEADER_SOUND` and `_MA_HEADER_TITLE`, `_MA_MONEY_FORMAT_FALLBACK`, `_maSettings`,
  `_maParkedValue`, `_maMoneyFormat`, `_maAdvice`, `_maPrices`, `_maButton`, `_maShiftBadge`, `_maSettingsScreen`,
  `_maPlan`, `_maAverage`, `_maAverageDay`, `_maQueued`, `_maBuildParked()`, `_maBuildRow()`, `_maMakeShiftBadge()`,
  `_maBadgeInset()`, `_maFitBadge()`, `_maAttachTooltips()`, `_maOnTradeInput()`, `_maOpenSettings()`,
  `_maOnSettingsClosed()`, `_maQueue()`, `_maRefresh()`, `_maTrade()`, `_maParkedWorth()`, `_maClampedParked()`,
  `_maSlider()`, `_maInput()`, `_maNames()`, `_maDaysLeft()`, `_maForecast()`, `_maAverages()`, `_maHistoryAverage()`,
  `_maAdviceText()` and `_maPricesText()`.
- Members of the menu's extension (`StationMenu.gd`): `MarketAdvisor` (preload), `_MA_ALERT` (translation key),
  `_MA_MARKET_SCREEN`, `_maMarketButton`, `_maMarketKey`, `_maSettings`, `_maTradeNow`, `_maOnAdvice()` and
  `_maUpdate()`. Both extensions declare `_maSettings`, which is fine: they extend different game scripts.
- **`Badge.gd`** is the same file in every mod of the repository that has a Shift badge, each preloading its own copy
  under its own constant: keep the copies identical. Constants: `SMALL_FONT_THEME`, `TOOLTIP_DELAY`, `TOOLTIP_FADE`,
  `BUTTON_HOVER_MUTE` (how long the game's tooltip node keeps its hover sound off as the mouse crosses the edge of a
  badge that lets it through to a button), `PAD_MODIFIER`, `PAD_BUTTON`, `PAD_MODIFIER_NAME` and `PAD_BUTTON_NAME` (as
  the game's gamepad glyphs name them, `hud/components/controls-xbox-key-sheet.png`) and `PAD_TEXT`. Functions: the
  static `isPadShortcut(event)`, `dress(button, text, padText)`, `hangBeside(button, gap)`,
  `setShiftTooltips(keyKey, padKey, modName)` and `attachTooltip(tooltips, focusOwner)`.
- Tested outside the game in a headless Godot 3.6 with the game's `EnceladusMenu.gd`, `HidingMarginContainer.gd`,
  `MineralMarket.gd`, `MineralSellSlider.gd`, `MineralPriceChart.gd`, `ServiceUI.gd`, the Tuning screen's groups and
  rows, `HeaderWithMoney.tscn` and `Shower.tscn`: the station built in code as its scene nests it, the market and the
  Services rows (which the mod leaves alone) from stubs of their scenes with the game's scripts and values, and the
  game's market prices drawn from each save's seed, and the badge and the gamepad's twin on the Trade button, enabled
  and disabled, with either control scheme (the `market` suite of the repository's test harness, which also runs a year
  of stays); with the other mods that extend `EnceladusMenu.gd` in every load order (the `dealer` suite); and in the
  game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the MIT License.

## Disclaimer
ΔV: Rings of Saturn is made and owned by Kodera Software. The game's name, and everything from the game this mod uses
or shows, belong to Kodera Software.

The author of this mod has no tie of any kind to the game or to Kodera Software. Kodera Software didn't make,
check or approve this mod, and doesn't support it.

This mod is provided as is, for free, and without warranty of any kind, express or implied: use it at your own risk.
The MIT License it is licensed under says so in full.
