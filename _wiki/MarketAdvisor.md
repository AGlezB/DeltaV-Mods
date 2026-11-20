A Trade button at the Mineral Market keeps the cash you want at hand and puts the rest in ore, and the station menu
tells you when there is a trade to make, or a service worth buying.

## What changes

- **The Mineral Market.** Under the list of minerals, a new row tells you what to trade, compares today's prices with
  each price chart's average, and has a **Trade** button that makes those trades for you, at the day's prices, as if
  you moved the sliders yourself. You choose a **cash reserve**, the cash you want to keep at hand. When you have more,
  Trade buys ore with the rest; when you have less, it sells that ore back. Your cash ends up a little above the
  reserve, by less than the price of one tonne.
- **Why ore.** At the market, buying and selling cost the same, with no fee, and every price keeps drifting back
  towards its average. So spare cash kept in ore bought below its average, and sold above it, earns money instead of
  sitting idle. The cash goes into Be, or into every mineral with *Trade all ores*: then into the ones furthest below
  their average, selling first the ones furthest above it.
- **The ore from your dives.** Trade also sells the ore you bring back, on the best day before your ship is ready. The
  mod remembers which tonnes Trade bought, so it never sells those as ore from a dive.
- **The best day.** While your ship is in maintenance (repairs and new equipment keep it at the station for a while),
  the advice may tell you to wait, and for which day: the chart forecasts a better price then. The forecast is the
  chart's, as good as your geologist makes it. With your ship ready, it trades now.
- **Parked in ore.** At the top of the screen, under your cash, a new line shows what the ore Trade bought would sell
  for today.
- **The station menu.** The **Mineral Market (\*)** entry tells you there is a trade to make now. The **Services (\*)**
  entry tells you that Jameson's Insurance or Scrapwright Recovery Operations can be bought: Jameson's Insurance adds
  more insurance than it costs, and insurance pays for repairs before your money does; the derelicts Scrapwright
  Recovery Operations brings to the rings are worth more than it costs.

| Without the mod | With the mod |
|---|---|
| ![The station menu, as the game shows it](images/MarketAdvisor-menu-without.png) | ![The station menu, with Mineral Market (*) and Services (*)](images/MarketAdvisor-menu-with.png) |
| ![The Mineral Market, as the game shows it](images/MarketAdvisor-market-without.png) | ![The Mineral Market, with Parked in ore under your cash and, at the bottom, the advice and the Trade button](images/MarketAdvisor-market-with.png) |

## Settings

Hold **Shift** and click the Mineral Market entry to open the settings (a plain click still opens the market). They
show where the market does, laid out like the Tuning screen: at the top, what the setting you have selected does;
below it, the settings in three groups. They close with Esc or when you pick another entry of the menu. A change
applies at once. Each save game keeps its own settings.

- **Cash reserve**:
  - **Use scientific notation**: shows the cash reserve as, for example, 5e5 instead of 500K. Off at first.
  - **Amount** and **Power of ten**: the cash reserve is the amount, from 0 to 9, times the power of ten, from 10K to
    1B. They start at 5 and 100K. The **Cash reserve** line under them shows the result. At an amount of 0, all your
    cash goes into ore.
- **Trading**:
  - **Trade all ores**: keeps your cash in every mineral, not only Be. Off at first. Spread over more minerals, your
    trading moves each price less in the months after.
  - **Sell stored ore**: Trade also sells the ore you bring back from your dives. On at first. At the end of a dive,
    pick *Store Minerals* instead of *Sell all*, so the ore can wait for its best day.
- **Services**: **Alert for Jameson's Insurance** and **Alert for Scrapwright Recovery Operations** put the mark on
  the Services entry. Both on at first.

![The settings: the description at the top, then the Cash reserve, Trading and Services groups](images/MarketAdvisor-settings.png)

## Works with other mods

It works with [CrewCheapHireNotifier](CrewCheapHireNotifier), [DealerNotifier](DealerNotifier) and
[DiveSkipTransit](DiveSkipTransit), whose settings also open with Shift and a click on their menu entries.

## Install

See [Installing mods](Home#installing-mods).

<!-- wiki-values (checked by wiki.ps1)
game-checked: 1.93.1
MarketAdvisor/i18n/en.po MARKETADVISOR_ALERT = "%s (*)" -> Mineral Market (*) | images/MarketAdvisor-menu-with.png
MarketAdvisor/i18n/en.po MARKETADVISOR_TRADE = "Trade" | images/MarketAdvisor-market-with.png
MarketAdvisor/i18n/en.po MARKETADVISOR_PARKED = "Parked in ore" | images/MarketAdvisor-market-with.png
MarketAdvisor/Settings.gd MAIN_MINERAL = "Be" -> Be
MarketAdvisor/Settings.gd SETTINGS.scientific.default = false -> Off at first
MarketAdvisor/i18n/en.po MARKETADVISOR_SCIENTIFIC = "Use scientific notation" | images/MarketAdvisor-settings.png
MarketAdvisor/i18n/en.po MARKETADVISOR_CASH_AMOUNT = "Amount" | images/MarketAdvisor-settings.png
MarketAdvisor/Settings.gd SETTINGS.cashAmount.default = 5
MarketAdvisor/Settings.gd SETTINGS.cashAmount.min = 0
MarketAdvisor/Settings.gd SETTINGS.cashAmount.max = 9
MarketAdvisor/i18n/en.po MARKETADVISOR_CASH_POWER = "Power of ten" | images/MarketAdvisor-settings.png
MarketAdvisor/Settings.gd SETTINGS.cashPower.default = 5 -> 100K
MarketAdvisor/Settings.gd SETTINGS.cashPower.min = 4 -> 10K
MarketAdvisor/Settings.gd SETTINGS.cashPower.max = 9 -> 1B
MarketAdvisor/i18n/en.po MARKETADVISOR_CASH_TOTAL = "Cash reserve" | images/MarketAdvisor-settings.png
MarketAdvisor/i18n/en.po MARKETADVISOR_TRADE_ALL = "Trade all ores" | images/MarketAdvisor-settings.png
MarketAdvisor/Settings.gd SETTINGS.tradeAll.default = false -> Off at first
MarketAdvisor/i18n/en.po MARKETADVISOR_SELL_ORE = "Sell stored ore" | images/MarketAdvisor-settings.png
MarketAdvisor/Settings.gd SETTINGS.sellOre.default = true -> On at first
MarketAdvisor/i18n/en.po MARKETADVISOR_ALERT_INSURANCE = "Alert for %s" -> Alert for Jameson's Insurance
MarketAdvisor/Settings.gd SETTINGS.alertInsurance.default = true -> Both on at first
MarketAdvisor/i18n/en.po MARKETADVISOR_ALERT_SCRAPWRIGHT = "Alert for %s" -> Alert for Scrapwright Recovery Operations | images/MarketAdvisor-settings.png
MarketAdvisor/Settings.gd SETTINGS.alertScrapwright.default = true -> Both on at first
note: 500K and 5e5, the cash reserve from the defaults of Amount and Power of ten, in both notations: change them with those
-->
