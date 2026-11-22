# DealerNotifier - ΔV: Rings of Saturn

Marks the Dealer entry of the Enceladus Prime menu when a ship you are waiting for comes up for sale, and that ship on
the Dealer screen. You pick the ships with Shift+Click on Dealer.

## What it does and why
- **What:** in the settings, every ship model the dealer can offer has a switch, all off at first. When the dealer gets
  a ship of a model you switched on, the station menu's Dealer entry gets a mark: it reads as the
  `DEALERNOTIFIER_ALERT` text says, with the entry's own text (in the game's language) in place of `%s`.
- **New and used:** two more switches, New and Used, both on at first, say which of those ships count. New is a ship
  the Dealer marks NEW: the dealer's weekly new ones, and a used one only in the rare case it was made less than a
  year ago. Used is every other. With New off, a used ship of a model you switched on still marks the entry, but a new
  one doesn't; with Used off, the other way round. So you can wait for a used K37 TNTRL without the mark coming back for
  the new one the dealer gets every week.
- **Only ships that just arrived:** a ship marks the entry only if it came after you last opened the Dealer screen, and
  after you switched on its model and its condition. Switching any of them on never marks the entry by itself, even
  with such a ship already for sale. Opening the Dealer screen clears the mark, and it comes back only when another
  such ship arrives. A ship you sold yourself, which the dealer offers again for a while, never marks it.
- **On the Dealer screen:** the ships that set the mark get a badge at the right end of their name, until you
  leave the station: the capitals of the mod's name in the game's button frame, outlined and lettered in the green of
  the Fleet screen's Owned label. Hovering it shows the `DEALERNOTIFIER_BADGE_TOOLTIP` text in the game's own tooltip;
  with a gamepad, the tooltip shows while the ship's name is highlighted.
- **When it updates:** whenever the game refreshes the dealer's stock: as you arrive at the station, every in-game hour
  you spend there, and when you open the Dealer screen. A dive doesn't refresh it, so ships that arrived meanwhile mark
  the entry as you get back. Also when you switch something on or off, and when the game's language changes.
- **Why:** so you know when a ship you want is for sale without opening the Dealer screen every hour, and which entry
  it is once there.
- **Settings:**
  - **Shift+Click** the Dealer entry to open them, or use its gamepad twin: highlight the entry, hold the
    `PAD_MODIFIER` button and press the `PAD_BUTTON` one (constants of `DealerNotifier/Badge.gd`). A plain click still
    opens the Dealer screen. A small badge beside the entry says so: it reads Shift, or the gamepad twin as `PAD_TEXT`
    names it while the game is played with a gamepad (the game's *Controls* setting, or with *Auto* the device last
    used). Hovering it shows the `DEALERNOTIFIER_SETTINGS_TOOLTIP` text; with a gamepad, which shows no hover,
    highlighting the entry shows the `DEALERNOTIFIER_SETTINGS_TOOLTIP_PAD` one. The settings open where the Dealer
    screen does, with the same frame, and close the way the game's screens do: Esc, the gamepad's B or Start button, or
    picking another entry of the menu.
  - Laid out as the Dealer screen: a window with the description of the selected ship (the game's own, as the Dealer
    shows it), then the switches. First New and Used, in a group of their own, then one row per ship model: its
    picture, its name and its switch, where the Dealer has Buy. Hovering a ship's switch shows the
    `DEALERNOTIFIER_WATCHED` text. The screen has no note on what the switches do: this README and the mod's page in
    the users' wiki explain them. Under the list, Select all and Select none switch every switch on or off, New and
    Used too.
  - The window keeps the Dealer's height whatever the ship, so the switches under it don't move. A longer description
    scrolls, with the mouse wheel or the right stick, and each ship's starts at its top. The list opens at its top.
  - The ships are grouped by series, each group titled by the series' name; series and ships in alphabetical order of
    their names in the game's language. Ships alone in their series (in game 1.93.1: the Eon Interstellar Model E, the
    ND-LIS Kitsune and the OCP-209) are grouped last, under *Others*.
  - The pictures show each ship as the dealer sells it, but with nothing on its hardpoints. They are drawn the first
    time you open the settings, all at once, as the Dealer draws its own, and kept until you quit the game.
  - Your switches are kept in your save game, each save with its own, and written to disk the next time the game saves
    (when you launch a dive, or quit through the pause menu). A new game, or a save made before the mod, starts with
    every ship's switch off and New and Used on, as does a save made before New and Used for those two.
  - The mod's texts (the mark, the tooltips, the titles of the groups, New and Used, the buttons) are in
    `DealerNotifier/i18n/en.po`, inside the zip.

## For modders
- Five scripts: `Code.gd` (the station menu's script extension: the Dealer entry, opening the settings),
  `DealerScreen.gd` (the Dealer screen's script extension: the stock, the ships seen, the badges), `SettingsUI.gd` (the
  settings screen), `Settings.gd` (the settings model and the rule, which the other three share) and `Badge.gd` (the
  badges: the Shift badge beside the Dealer entry and the Dealer screen's, and the gamepad's twin of Shift+Click). The
  texts are in `i18n/en.po`.
- **The dealer's stock** is stored nowhere. `CurrentGame.gd` `getShipsAvailableForSale` builds it anew on every call
  from the in-game day and week and `state.seed`: a few ships new every week (named in its code: the mod's
  `NEW_STOCK`), one used ship a day kept 10 days (drawn from `CurrentGame.usedShipsPool`),
  and the ships the player sold (`state.soldShips`), for 10 days; ships the player owns are left out. Some of the weekly
  models are in the pool too, so the dealer can have the same model new and used. Only `Dealer.gd`
  `doAddShips` calls it: when the station loads (`_ready`), on `CurrentGame`'s `hourPassed`, and from `show()`. The
  game signals no change. A ship's transponder is the same from one refresh, visit or save to the next (seeded:
  `getNewTransponder`), so it is what tells ships apart; `shipHashFromConfig` is not (it holds the moment the ship was
  instanced).
- Script extension of `res://enceladus/EnceladusMenu.gd` (`Code.gd`): the script of the station menu, the `Options`
  root of `enceladus/EnceladusMenu.tscn` instanced in `enceladus/Enceladus.tscn`. The Dealer entry is the menu's
  `ShipMarket` child, a plain `Button` whose text is the translation key `ENCELADUS_SHIP_MARKET` and whose `pressed`
  the station connects to the Dealer screen's `show`. The mod reads the key from the button and puts it back while
  nothing is new; while marked, the text is `tr(_DN_ALERT) % tr(key)`. It updates on the settings model's
  `settingsChanged` and `stockChanged`, and on `NOTIFICATION_TRANSLATION_CHANGED`. Shift+Click and its gamepad twin
  (`Badge.gd` `isPadShortcut`), the Shift badge and its tooltip, and the settings screen's place are
  CrewCheapHireNotifier's (see its README): the press is accepted in the button's `gui_input`, so the Dealer screen
  stays closed. The badge (`_dnMakeShiftBadge()`, kept in `_dnShiftBadge`) hangs beside the entry; its tooltips are
  `_DN_SETTINGS_TOOLTIP` and, with a gamepad, `_DN_SETTINGS_TOOLTIP_PAD`, shown on hover and, with a gamepad, while the
  entry has the focus (its `focusOwner`); the entry itself has none. Without the right-hand screens' container or its
  Dealer screen (`_DN_DEALER_SCREEN`) there is no settings screen and no Shift badge, Shift+Click is a plain click and
  its gamepad twin does nothing. A menu without a `ShipMarket` button is left alone.
- Script extension of `res://enceladus/Dealer.gd` (`DealerScreen.gd`): the script of `enceladus/Dealer.tscn`,
  instanced in `Enceladus.tscn` as the station's `Dealer` (with `showOwned` off) and, through `enceladus/Owned.tscn`, as
  Fleet (with `showAvailable` off). Everything it does is gated on `showAvailable`, so Fleet is untouched. The tag
  `group = Dealer` in `Mod.manifest` names that game script.
  - Overrides `doAddShips()`: calls the parent's and waits for its end when it yields (it waits for the player's ship,
    and for an idle physics frame per ship while the screen is hidden; the end is when its first
    `GDScriptFunctionState` emits `completed`). A call made while another runs returns at once with `shipAddFlag`
    still set; then the running one reports. It reads the stock from the screen's entries
    (`enceladus/SystemBuyUI.gd`: each entry's `ship`, its `model` and `transponder`, and whether it is used) and calls
    the model's `setStock(entries, seen)`, `seen` while the screen is visible.
  - **New or used** (`_dnIsNew()`) is the rule of an entry's NEW mark (`SystemBuyUI.gd` `checkPrice`): not owned,
    pristine (every system at 99 % or more) and younger than `_DN_GAME_NEW_AGE`. A ship that young is always pristine
    (`CurrentGame.gd` `ageToDamageWithSeed` damages none under ten years), so the age alone decides: the in-game time
    less the ship's `madeTimestamp`, set as the ship is made (`Shipyard.gd` `createShipByConfig`), before its entry has
    set it up and run `checkPrice`. The weekly ships are made a week old at most; a used one gets a random age up to its
    pool entry's (`CurrentGame.usedShipsPool`), so it is new only in the rare case that falls under the limit, and the
    Dealer marks it NEW too.
  - Overrides `show()`: calls the parent's, then keeps the transponders of `newShips()` in `_dnFresh` (the ships that
    get a badge; the screen is built anew on every visit, so they last until the station is left) and calls
    `markSeen()`, which clears the mark at once. The game's `show()` refreshes the stock, and that refresh, done while
    the screen is visible, sees everything again.
  - Overrides `_notification`, which the game's script doesn't have: on `NOTIFICATION_TRANSLATION_CHANGED` it sets the
    badges' tooltips again, since they hold translated text.
  - **The badge** is a `Badge.gd` (`_DN_BADGE_SCRIPT`, a `PanelContainer`) named `_DN_BADGE`, built as
    CrewCheapHireNotifier's Hire screen badge: only the capitals of the mod's name (`_dnInitials()`), a copy of the
    entry's Buy button (`_DN_ENTRY_BUY`) `normal` frame (never the game's shared resource) with its border in the
    `modulate` of the entry's Owned label (`_DN_ENTRY_OWNED`, the overbright green ShipCopyPaste marks its template
    with), the letters in the button's `font_color` times that colour, as the label draws, and in the font a Label gets
    in the entry's picture (`_DN_ENTRY_PICTURE`, whose theme, `enceladus/Subwindow.theme`, has a small one): the name
    sets no theme, so a Label there would get the entry's, the menu's big font. It sits at the right end of the entry's
    name column (`_DN_ENTRY_NAME`, a flat Button that fills the column between the picture and the specs), inside the
    right margin the button keeps around its text (its `normal` stylebox's, which a flat button still lays its text out
    in), centred on it from top to bottom. A Button doesn't lay out its children, so the badge hangs from it directly,
    anchored to the middle of its right side and growing left, up and down to its minimum size. A name long enough to
    reach the column's end would run under it (the button clips its text at its own edge); a ship's name is two words
    in a column many times wider. The badge lets the mouse through (`MOUSE_FILTER_PASS`), so the wheel still scrolls
    the list and a click is the name's: it focuses the name, which shows the ship (`Dealer.gd`). Its tooltip
    (`tr(_DN_BADGE_TOOLTIP)`) goes through the entry's `PlaySoundsOnTheseButtons` with `Badge.gd` `attachTooltip()`,
    as CrewCheapHireNotifier's badge does, since the released game shows no Godot tooltips: shown on hover sooner than
    the game's own and without the hover sound (`BUTTON_HOVER_MUTE` keeps the name under the badge from playing its own
    again as the mouse crosses the badge's edge), and, with the name as `focusOwner`, while the name has the focus and
    the game is played with a gamepad. The game keeps an entry from one refresh to the next and never touches the
    badge, so `_dnMarkFresh()` only shows or hides it.
- **The rule** (`Settings.gd`): `stock` is the last refresh's `{model, transponder, used}` list (not saved;
  `loadFromState` empties it, since it is another save's or the last visit's). `_watchedShips()` is the stock's ships of
  a model switched on whose condition is switched on too (`watchUsed` for a used one, `watchNew` for a new one).
  `known` is the transponders that never mark: those the dealer had while the Dealer screen was open, and those a
  switch let in when it went on (`setValue`: the ships `_watchedShips()` gives after the change and not before, for a
  model, New or Used alike). Every refresh drops from `known` the ships no longer for sale. `newShips()` is
  `_watchedShips()` less those in `known` and in `CurrentGame.getSoldTransponders()`. `setStock` and `markSeen` save
  `known` when it changes and emit `stockChanged`.
- **The models** (`models()`): `NEW_STOCK` (the weekly ones, a constant because the game names them only in its code),
  then the names in `CurrentGame.usedShipsPool`, each once, keeping those `Shipyard.ships` has a scene for, so a model a
  game update adds to the pool gets its own switch by itself. `series(model)` is `Shipyard.getShipAlias(model)` (the
  game's `configAlias`, which folds the variants into their base model). `shipNameKey(model)` and
  `baseShipNameKey(model)` are the translation keys a ship of the model holds in `shipName` and `baseShipName`, read
  from the model's scene without making a ship: its root's values in the scene's `SceneState`, then in the scene it
  inherits from (`get_node_instance(0)` of an inherited scene's root). Where the scenes leave a value to
  `ships/ship-ctrl.gd`'s default (`RA-TRTL.tscn`'s `shipName`), one ship is instanced, never added to the tree, read and
  freed. The names are kept for the session.
- **The settings model** follows CrewCheapHireNotifier's (`shared()`, `SETTINGS`, `cfg`, `getValue` / `setValue`,
  `loadFromState` / `saveToState`, `modId()`, `modName()`, `modVersion()`), with three switches, in the screen's order
  as `SETTINGS` lists them: `watchNew` and `watchUsed`, which aren't per model and have a `group`, the translation key
  of the title of the screen's group they show in, then `watched`, that has `perModel` (a value for each model, a
  dictionary by model key in `cfg`, all sharing its default). Anything that isn't a bool gives the default, so
  a save edited by hand can't break anything. The autoloads are read with `get()`
  (`CurrentGame.get("usedShipsPool")`, `Shipyard.get("ships")`): the mod's scripts are compiled while the autoloads
  after `ModLoader` are still null, and Godot would work out `"key" in CurrentGame` then, failing.
- **The save:** in `CurrentGame.state.ui` under the mod's id from `Mod.manifest`: `formatVersion` (`FORMAT_VERSION`),
  `modVersion`, `watchNew`, `watchUsed`, `watched` (a copy of the dictionary by model) and `known` (a copy of the
  list). A save without `watchNew` or `watchUsed` (one made before them) gets their defaults.
- **The settings screen** (`SettingsUI.gd`) is built as CrewCheapHireNotifier's and DiveSkipTransit's, but copies the
  live **Dealer** screen's theme, panel, minimum size and size flags, so it opens in the Dealer's place with its frame.
  Under the header (the Dealer entry's key):
  - The description window, nested as `Dealer.tscn` nests its own (`GAME_WINDOW_MARGIN`, `GAME_WINDOW`,
    `GAME_WINDOW_INSIDE`, `GAME_WINDOW_TEXTS`), without the tabs and the ship's view behind the text, with the Dealer's
    theme, margins, panel, least size and spacing. For the focused row it shows what `Dealer.gd` `displayShip` shows:
    `baseShipName` + `DESCRIPTION_SUFFIX` where it differs from `shipName`, then `shipName` + `DESCRIPTION_SUFFIX`, keys
    the Labels translate. A row that isn't a ship's empties it.
  - The texts are in a `ScrollContainer` with no horizontal scroll (`_descriptionScroll`), so they wrap to the window's
    width; the Dealer only clips its own. `_keepDescriptionHeight()` makes the `ScrollContainer` as tall as the room
    inside the window at the Dealer's least height (`_descriptionPanel`'s, less its panel's and margins' share), so the
    window keeps that height whatever the ship and the switches below don't move; where the game gives no height,
    `DESCRIPTION_LINES` lines. A longer description scrolls with the mouse wheel (the `ScrollContainer`'s own) and with
    the right stick: `_process` reads `DESCRIPTION_SCROLL_UP` and `DESCRIPTION_SCROLL_DOWN`, at up to
    `DESCRIPTION_SCROLL_SPEED`, in real time, kept in fractions of a pixel (`_descriptionAt`), as
    `enceladus/ScrollWithAnalog.gd` scrolls the game's lists. The list of switches has no `ScrollWithAnalog`: the D-pad
    moves through it, and it follows the focus. `_describe()` scrolls the texts back to their top for each ship.
  - No note: unlike the game's Tuning settings, the switches have no description on the screen. This README and the
    mod's page in the users' wiki explain them.
  - An `Items` box in the scroll of `enceladus/Tuning/TuningItems.tscn` groups of `TuningBoolValue.tscn` switches.
    First one group per `group` of the settings that aren't per model (`_keyGroups()`, New and Used), its switches
    named by their `label`s. Then one group per series, its switches named by each model's `shipName` key
    (`_groups()`): series with two or more models, titled by the base model's `shipName`, sorted by the titles'
    translated names, each one's models by theirs (case ignored); then the models alone in their series, under
    `OTHERS_LABEL`. Filled each time it opens, so the order follows a language change; New's switch takes the focus.
    That scrolls the list to the switch (the `ScrollContainer`'s `follow_focus`, before the rows are laid out), hiding
    the first group's title, so `_scrollToTop()` then scrolls it back to the top.
    On `tuningChanged` (a change, or a row taking the focus) it sets the row's `tune.current` (DiveSkipTransit's fix:
    a switch doesn't update it itself), calls `setValue` and shows the row's description, or empties the window for New
    and Used.
  - Each ship's row is dressed as a Dealer entry (`_dressRow()`): a `Picture` Control first, of the size of the entry's
    picture (`GAME_ENTRY_PICTURE`), with a Sprite placed, scaled and flipped as the entry's (`GAME_ENTRY_SPRITE`); the
    switch's tooltip the setting's `label`. Every row's switch, New's and Used's too, sits where the entry has Buy
    (`_alignSwitch()`): the reset button hidden, the switch's slot at least as wide as the entry's Buy button
    (`GAME_ENTRY_BUY`), at the row's right end, so the switches line up. Those are read once from an instance of
    `enceladus/SystemBuyUI.tscn` that never enters the tree. No picture is stretched behind the row (the Dealer's `BG`,
    which ShipHighlightTypeAndPrice hides).
  - Under the scroll, a `Buttons` box with Select all and Select none (`SELECT_ALL`, `SELECT_NONE`), side by side as
    CombatSimulator's dialog has its buttons, with an instance of the game's `PlaySoundsOnTheseButtons`
    (`GAME_BUTTON_SOUNDS`) for their sounds (`_buttons()`). Both call `_selectAll(on)`, which sets `pressed` on every
    switch (`_switches`: New's and Used's, then the ships'). Each switch then takes its own path (`toggled`, then
    `tuningChanged`, then `setValue`), so the rows' `tune.current`, the save, `known` and the mark stay right; `_bulk`
    keeps the window as it was meanwhile.
  - **The pictures** (`_drawPictures()`) are made the way the Dealer makes its entries' (`SystemBuyUI.gd` `addShip`,
    `checkPrice`, `stopUpdating`): every model at once (`_drawPicture()`), each ship drawn in a viewport of its own (the
    entry's, `GAME_ENTRY_VIEWPORT`: camera, lights, environment, taken out of a new instance of the entry's scene) under
    a hidden Node2D, for `PICTURE_DELAY` once set up, then `get_texture().get_data()` into an `ImageTexture`; then the
    viewport is freed with the ship still in it, and anything the ship put beside itself (a cradle lets its drone go
    into the ship's parent, `ships/modules/ClaimOwner.gd` `_ready`). That way the ship's areas are freed before the
    viewport's physics space: a ship taken out first leaves its monitoring areas pointing into that space, and freeing
    them afterwards writes into freed memory, an intermittent crash (Godot 3's `CollisionObject2DSW` `_set_space`, fixed
    only in Godot 4.3, PR #81809). The ships set themselves up together,
    sharing the game's budget for that (`Tool.gd`'s idle queue, at most half of every frame), and wait for their
    pictures together: drawn one after another, the waits would add up to seconds. Each picture shows as soon as it is
    taken. They are kept in the script's metadata for the session. Every ship is made with
    `Shipyard.createShipByConfig`, with what keeps it out of the save game: a `transponder` (else the game registers a
    new one in `state.transponders`), a `shipName` (else `getShipName()` stores one in `state.shipNames`), a `madeIn`
    (else it is aged at random), and the dealer's faction (`GAME_DEALER_FACTION`).
  - **Empty hardpoints.** Each ship is pictured as the dealer sells it (`Shipyard.getDefaultConfigByName`), thrusters,
    main engine and the rest, but with nothing on its hardpoints (`_emptyHardpoints()`), so the picture shows the ship
    itself: every `weaponSlot.<hardpoint>.type` holds `GAME_NO_SYSTEM`, the Equipment screen's None (every hardpoint of
    `enceladus/Upgrades/WeaponSlotUpgrade.tscn` offers it, free, as its default); a hardpoint's other settings stay.
    It is set with `setConfig` before the ship enters the tree, and the ship keeps its config by reference, so that is
    what its hardpoints mount (`ships/WeaponSlot.gd` `_ready`). Emptied are the hardpoints the dealer's config names and
    those of the ship's scene (`_hardpoints()`): its nodes with the hardpoint script (`GAME_HARDPOINT_SCRIPT`), inline
    and sometimes nested (the ND-LIS Kitsune's is `Front/WeaponSlot`), and its placeholders of the hardpoint scene
    (`GAME_HARDPOINT_SCENE`: RA-TRTL's, the Vulture Prospector's, the OCP-209's). A placeholder stores only the values
    it overrides (`get_stored_values()`), and RA-TRTL's and the VP's main hardpoint leaves `slot` to the scene: that is
    read from one instance of the hardpoint scene, never added to the tree (`_hardpointSceneSlot()`). In game 1.93.1
    only ship scenes, the Tsukuyomi's turret module and the habitat use them.
- **The texts.** `i18n/en.po` holds every text the mod shows, under keys that start with `DEALERNOTIFIER_`. `ModMain.gd`
  loads it with `load()` and `TranslationServer.add_translation`, as CrewCheapHireNotifier does (its README says why).
- **With the other mods on the station menu** (CrewCheapHireNotifier, DiveSkipTransit, MarketAdvisor and
  ServiceNotifier), which extend `EnceladusMenu.gd` too, each for its own entry: mods load by path, so the chain is
  game ← CrewCheapHireNotifier ← DealerNotifier ← DiveSkipTransit ← MarketAdvisor ← ServiceNotifier. Each overrides
  `_ready`, and all but DiveSkipTransit `_notification` (the game's script has neither), without calling the
  parent's; their members are distinct, and opening one's screen hides the others' (`hidefoka`).
- **With the ship-list mods:** ShipCopyPaste extends `SystemBuyUI.gd`, the Dealer's entries; ShipHighlightTypeAndPrice
  and ShipSortByTypeAndPrice change and reorder them. The badge is a child of the entry's name, which none of them
  changes, and the stock is read from every entry, whatever their order, so they work together.
- Members of the menu's extension (`Code.gd`): `DealerNotifier`, `_DN_SETTINGS_UI` and `_DN_BADGE_SCRIPT` (preloads),
  `_DN_ALERT`, `_DN_SETTINGS_TOOLTIP` and `_DN_SETTINGS_TOOLTIP_PAD` (translation keys), `_DN_DEALER_SCREEN`,
  `_dnMarketButton`, `_dnMarketKey`, `_dnShiftBadge`, `_dnSettingsScreen`, `_dnScreens`, `_dnDealer`, `_dnSettings`,
  `_dnUpdate()`, `_dnMakeShiftBadge()`, `_dnOnMarketInput()` and `_dnOpenSettings()`.
- Members of the Dealer screen's extension (`DealerScreen.gd`): `DealerNotifier` and `_DN_BADGE_SCRIPT` (preloads),
  `_DN_BADGE_TOOLTIP` (translation key), `_DN_BADGE`, `_DN_ENTRY_NAME`, `_DN_ENTRY_BUY`, `_DN_ENTRY_OWNED`,
  `_DN_ENTRY_PICTURE`, `_DN_GAME_NEW_AGE`, `_dnFresh`, `_dnStock()`, `_dnIsNew()`, `_dnIsOffer()`, `_dnMarkFresh()`,
  `_dnBadge()` and `_dnInitials()`.
- **`Badge.gd`** is the same file in every mod that has a Shift badge, CrewCheapHireNotifier's among them, whose
  README lists its members: keep the copies identical.
- Tested only outside the game, in a headless Godot 3.6 with the game's `EnceladusMenu.gd`, `HidingMarginContainer.gd`,
  `Dealer.gd`, `SystemBuyUI.gd`, `WeaponSlot.gd`, `TuningItems.gd`, `TuningBoolValue.gd`, `PlaySoundsOnTheseButtons.gd`
  and `Shower.tscn`: the station built in code as its scene nests it, with stubs of the Dealer screen's, its entries'
  and the hardpoint's scenes, of `CurrentGame` and `Shipyard`, and ship models of the harness's own (the `dealer` suite
  of the repository's test harness), alone, with CrewCheapHireNotifier and DiveSkipTransit, and with MarketAdvisor
  and ServiceNotifier as well, in every load order, and with the ship-list mods. The Shift badge's text and tooltip are
  checked with each control scheme, Shift+Click's gamepad twin with gamepad button events, the Dealer screen badge's
  tooltip on the name's focus with a gamepad, and the description's scrolling with a long text and the right stick. The
  real check is playing the game.

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
