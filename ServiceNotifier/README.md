# ServiceNotifier - ΔV: Rings of Saturn

Marks the Services entry of the Enceladus Prime menu when a service you pick can be bought again: one with a cooldown,
such as The Twins or Jameson's Insurance, or a compensation to a faction. You pick the services with Shift+Click on
Services.

## What it does and why
- **What:** the station menu's Services entry gets a mark while a service whose switch is on can be bought: it reads as
  the `SERVICENOTIFIER_ALERT` text says, with the entry's own text (in the game's language) in place of `%s`.
- **Which services:** those that can't be bought again right after you buy them. Every switch is on at first.
  - **After a cooldown:** The Twins (a day), and the three with a monthly fee: Jameson's Insurance, Scrapwright Recovery
    Operations and Minding Premium Virtual Flight Service (30 days each). Each marks the entry once its cooldown is
    over, when you have the money.
  - **Compensation:** Local Vilcy Branch, The Miner's Guild and Obonto Habitats. Each pays a faction to forget what you
    did to it: its price follows that faction's hostility and fear towards you, and buying it sets both back to
    nothing, so it costs nothing, and can't be bought, until you give that faction a new reason. Each marks the entry
    while there is something to pay, when you have the money. The game sells Local Vilcy Branch only until the Big Bad
    Wolf is destroyed.
  - The hotels, which can be bought again at once, never mark it.
- **As the game decides:** the mark follows the game's own row for each service on the Services screen: its cooldown,
  its price against your money, and the story condition some rows have. So what marks the entry is exactly what the
  Services screen would let you buy.
- **Read from the game:** the services are the Services screen's rows with a cooldown or a faction to compensate, in
  the screen's order, not a list in the mod. A service a game update adds of either kind gets its own switch by itself.
- **When it updates:** as you arrive at the station, every in-game hour and day you spend there, when your money or
  your insurance changes, when your crew changes (some prices count the crew), when you switch something on or off,
  and when the game's language changes.
- **Why:** so you know when The Twins can lift your crew's morale again, when a monthly service has run out, or when a
  faction can be paid off, without opening the Services screen to check.
- **Settings:**
  - **Shift+Click** the Services entry to open them, or use its gamepad twin: highlight the entry, hold the
    `PAD_MODIFIER` button and press the `PAD_BUTTON` one (constants of `ServiceNotifier/Badge.gd`). A plain click still
    opens the Services screen. A small badge beside the entry says so: it reads Shift, or the gamepad twin as
    `PAD_TEXT` names it while the game is played with a gamepad (the game's *Controls* setting, or with *Auto* the
    device last used). Hovering it shows the `SERVICENOTIFIER_SETTINGS_TOOLTIP` text; with a gamepad, which shows no
    hover, highlighting the entry shows the `SERVICENOTIFIER_SETTINGS_TOOLTIP_PAD` one. The settings open where the
    Services screen does, with the same frame, and close the way the game's screens do: Esc, the gamepad's B or Start
    button, or picking another entry of the menu.
  - Laid out as the Tuning screen: a window with the description of the selected service, then a group of switches per
    kind of service, *After a cooldown* and *Compensation*, a switch per service, named as the game names it. Hovering
    a switch shows the `SERVICENOTIFIER_SWITCH` text.
  - The description says what the switch does for that kind of service, with the service's name and, for a cooldown,
    how long it lasts, then the game's own offer for the service, as the Services screen shows it.
  - Your switches are kept in your save game, each save with its own, and written to disk the next time the game saves.
    A new game, or a save made before the mod, starts with every switch on.
  - The mod's texts are in `ServiceNotifier/i18n/en.po`, inside the zip.

## For modders
- Four scripts: `Code.gd` (the station menu's script extension: the Services entry, opening the settings),
  `SettingsUI.gd` (the settings screen), `Settings.gd` (the settings model and the rule of which services are watched,
  which the other two share) and `Badge.gd` (the Shift badge beside the Services entry, and the gamepad's twin of
  Shift+Click). The texts are in `i18n/en.po`.
- **The services** (GAME.md *Services*): one row each on the Services screen (`enceladus/Services.tscn`), a
  `enceladus/ServiceUI.gd` named by its `serviceName`. A row's Buy button (`buyButton`) is enabled by its own
  `checkPrice`: the row costs something, isn't in its cooldown (`cooldownHours`, kept per save in the UI store as
  `cooldown.<serviceName>`), the money covers its price (or the row allows debt) and its story condition holds; a row
  whose condition fails is greyed out, or hidden with `storyHide`. The compensation rows are
  `enceladus/ServiceUIFactionChange.gd`: `getPrice` adds the faction's (`factionBased`) hostility and fear towards the
  player, times `hostilityPrice` and `fearPrice`, and `buy` takes both back to 0 (`Factions.adjustFactionDisposition`),
  so the price drops to 0 and the row can't be bought until the faction holds a grudge again.
- Script extension of `res://enceladus/EnceladusMenu.gd` (`Code.gd`): the script of the station menu, the `Options`
  root of `enceladus/EnceladusMenu.tscn` instanced in `enceladus/Enceladus.tscn`. The Services entry is the menu's
  child `_SN_SERVICES_ENTRY`, a plain `Button` whose text is the translation key `ENCELADUS_SERVICES`. The mod reads
  the key from the button and puts it back while nothing is due; while marked, the text is `tr(_SN_ALERT) % tr(key)`.
  The tag `group = Services` in `Mod.manifest` names the part of the game it watches.
  - The watched rows (`_snRows()`) are the children of the Services screen's `_SN_SERVICE_ROWS` that have
    `serviceName`, `buyButton` and `checkPrice`, and a kind (`Settings.gd` `kindOf`).
  - `_snCheck()` runs the game's `checkPrice()` of each watched row whose switch is on, so its state is current, and
    marks the entry while one is visible with its Buy button enabled. It runs once per frame at most, deferred after
    the game's own handlers (`_snQueue()`), on `CurrentGame`'s `dayPassed`, `hourPassed`, `moneyChanged`,
    `moneyOrInsuranceChanged` and `employmentChanged`, and on the settings' `settingsChanged`.
  - Overrides `_ready` and `_notification` (the game's script has neither). The station is built anew after every load
    and new game, so `_ready` loads the save's settings (`loadFromState()`); on `NOTIFICATION_TRANSLATION_CHANGED` it
    writes the entry's text again, since a marked entry holds translated text.
  - Shift+Click and its gamepad twin (`Badge.gd` `isPadShortcut`), the Shift badge and its tooltip, and the settings
    screen's place are CrewCheapHireNotifier's (see its README): the press is accepted in the button's `gui_input`, so
    the Services screen stays closed. The badge (`_snMakeShiftBadge()`, kept in `_snShiftBadge`) hangs beside the
    entry; its tooltips are `_SN_SETTINGS_TOOLTIP` and, with a gamepad, `_SN_SETTINGS_TOOLTIP_PAD`, shown on hover and,
    with a gamepad, while the entry has the focus (its `focusOwner`); the entry itself has none. Without the right-hand
    screens' container or its Services screen (`_SN_SERVICES_SCREEN`) there is no settings screen, no Shift badge and no
    mark, Shift+Click is a plain click and its gamepad twin does nothing. A menu without a Services entry is left alone.
  - **`Badge.gd`** is the same file in every mod that has a Shift badge, CrewCheapHireNotifier's among them, whose
    README lists its members: keep the copies identical.
- **The rule** (`Settings.gd`): `kindOf(row)` is a key of `KINDS`, `"cooldown"` for a row with `cooldownHours` above 0,
  `"compensation"` for one with a `factionBased`, or `""` for a row the mod doesn't watch; a row with both counts as a
  cooldown's. `KINDS`, in the order the screen groups them, gives each kind its group's title and its description's
  translation key, and whether the description has a `%s` for the cooldown (`withCooldown`).
- **The settings model** follows CrewCheapHireNotifier's (`shared()`, `SETTINGS`, `cfg`, `getValue` / `setValue`,
  `loadFromState` / `saveToState`, `modId()`, `modName()`, `modVersion()`), with one switch, `alert`, that has
  `perService` (`isPerService()`): a value for each service, a dictionary by `serviceName` in `cfg`, all sharing its
  default. The services aren't listed in the model: one with no value stored gives the default, and loading keeps every
  saved service with a bool value, so a service missing for a while keeps its own. Anything that isn't a bool gives the
  default, so a save edited by hand can't break anything.
- **The save:** in `CurrentGame.state.ui` under the mod's id from `Mod.manifest`: `formatVersion` (`FORMAT_VERSION`),
  `modVersion` and `alert` (a copy of the dictionary by service).
- **The settings screen** (`SettingsUI.gd`) is built as MarketAdvisor's, but copies the live **Services** screen's
  theme, panel, minimum size and size flags, so it opens in the Services screen's place with its frame. Under the
  header (the Services entry's key):
  - The description window, nested as `enceladus/Tuning.tscn` nests its own (`GAME_WINDOW_MARGIN`, `GAME_WINDOW`,
    `GAME_WINDOW_INSIDE`) with the live Tuning screen's (`Code.gd` `_SN_TUNING_SCREEN`) theme, margins and panel,
    keeping room for `DESCRIPTION_LINES` lines. For the focused row it shows its kind's description, with the
    service's name, its cooldown where the kind has one (written as the game writes a time, `Tool.readableTimeSpan`,
    without zero hours), and the game's own offer: the row's `serviceOffer`, or its `serviceName` +
    `GAME_OFFER_SUFFIX`, as `ServiceUI.gd` `view` makes the key; an offer the game has no text for is left out.
  - An `Items` box in the scroll of `enceladus/Tuning/TuningItems.tscn` groups, one per kind with watched rows, titled
    by it, with a `TuningBoolValue.tscn` switch per service in the Services screen's order, named by its `serviceName`
    key, which the game's Buttons translate; each switch's tooltip is the setting's `label` (`GAME_ROW_SWITCH`). Filled
    each time it opens, so the description follows a language change; the first row takes the focus. On
    `tuningChanged` (a change, or a row taking the focus) it sets the row's `tune.current` (DiveSkipTransit's fix: a
    switch doesn't update it itself), calls `setValue` and shows the row's description.
- **The texts.** `i18n/en.po` holds every text the mod shows, under keys that start with `SERVICENOTIFIER_`.
  `ModMain.gd` loads it with `load()` and `TranslationServer.add_translation`, as CrewCheapHireNotifier does (its
  README says why).
- **With CrewCheapHireNotifier, DealerNotifier, DiveSkipTransit and MarketAdvisor**, which extend `EnceladusMenu.gd`
  too: mods load by path, so the chain is game ← CrewCheapHireNotifier ← DealerNotifier ← DiveSkipTransit ←
  MarketAdvisor ← ServiceNotifier. Each overrides `_ready`, and all but DiveSkipTransit `_notification` (the game's
  script has neither), without calling the parent's; their members are distinct, and opening one's screen hides the
  others' (`hidefoka`). Each writes only its own entry's text: the Services entry is this mod's alone.
- Members of the menu's extension (`Code.gd`): `ServiceNotifier`, `_SN_SETTINGS_UI` and `_SN_BADGE_SCRIPT`
  (preloads), `_SN_ALERT`, `_SN_SETTINGS_TOOLTIP` and `_SN_SETTINGS_TOOLTIP_PAD` (translation keys),
  `_SN_SERVICES_SCREEN`, `_SN_SERVICES_ENTRY`, `_SN_TUNING_SCREEN`, `_SN_SERVICE_ROWS`, `_snButton`, `_snKey`,
  `_snShiftBadge`, `_snScreens`, `_snServices`, `_snTuning`, `_snSettingsScreen`, `_snSettings`, `_snDue`,
  `_snQueued`, `_snUpdate()`, `_snMakeShiftBadge()`, `_snQueue()`, `_snRows()`, `_snCheck()`, `_snOnServicesInput()`
  and `_snOpenSettings()`.
- Tested outside the game in a headless Godot 3.6 with the game's `EnceladusMenu.gd`, `HidingMarginContainer.gd`,
  `ServiceUI.gd`, `ServiceUIInsurance.gd`, `ServiceUIFactionChange.gd`, the Tuning screen's groups and rows,
  `HeaderWithMoney.tscn` and `Shower.tscn`: the station built in code as its scene nests it, with stubs of the Services
  rows' scenes at the game's values and of `Factions` (the `services` suite of the repository's test harness), the
  Shift badge's text and tooltip with each control scheme and Shift+Click's gamepad twin with gamepad button events
  among its checks; with CrewCheapHireNotifier, DealerNotifier, DiveSkipTransit and MarketAdvisor in every load order
  (the `dealer` suite); and in the game.

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
