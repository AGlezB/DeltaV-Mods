# DealerNotifier - ΔV: Rings of Saturn

Marks the Dealer entry of the Enceladus Prime menu when a ship you are waiting for comes up for sale, and that ship on
the Dealer screen. You pick the ships with Shift+Click on Dealer.

## What it does and why
- **What:** in the settings, every ship model the dealer can offer has a switch, all off at first. When the dealer gets
  a ship of a model you switched on, the station menu's Dealer entry gets a mark: it reads as the
  `DEALERNOTIFIER_ALERT` text says, with the entry's own text (in the game's language) in place of `%s`.
- **Only new ships:** a ship marks the entry only if it came after you last opened the Dealer screen, and after you
  switched its model on. Switching a model on never marks the entry by itself, even with a ship of it already for sale.
  Opening the Dealer screen clears the mark, and it comes back only when another such ship arrives. A ship you sold
  yourself, which the dealer offers again for a while, never marks it.
- **On the Dealer screen:** the ships that set the mark get a badge at the right end of their name, until you
  leave the station: the capitals of the mod's name in the game's button frame, outlined and lettered in the green of
  the Fleet screen's Owned label. Hovering it shows the `DEALERNOTIFIER_BADGE_TOOLTIP` text in the game's own tooltip.
- **When it updates:** whenever the game refreshes the dealer's stock: as you arrive at the station, every in-game hour
  you spend there, and when you open the Dealer screen. A dive doesn't refresh it, so ships that arrived meanwhile mark
  the entry as you get back. Also when you switch a model on or off, and when the game's language changes.
- **Why:** so you know when a ship you want is for sale without opening the Dealer screen every hour, and which entry
  it is once there.
- **Settings:**
  - **Shift+Click** the Dealer entry to open them, as the entry's tooltip says. A plain click still opens the Dealer
    screen. They open where the Dealer screen does, with the same frame, and close the way the game's screens do: Esc,
    the controller's B or Start button, or picking another entry of the menu.
  - Laid out as the Dealer screen: a window with the description of the selected ship (the game's own, as the Dealer
    shows it), a note on what the switches do, then one row per ship model: its picture, its name and its switch,
    where the Dealer has Buy. Hovering a switch shows the `DEALERNOTIFIER_WATCHED` text.
  - The ships are grouped by series, each group titled by the series' name; series and ships in alphabetical order of
    their names in the game's language. Ships alone in their series (in game 1.92.5: the Eon Interstellar Model E, the
    ND-LIS Kitsune and the OCP-209) are grouped last, under *Others*.
  - The pictures show each ship as the dealer sells it, but with nothing on its hardpoints. They are drawn the first
    time you open the settings, all at once, as the Dealer draws its own, and kept until you quit the game.
  - Your switches are kept in your save game, each save with its own, and written to disk the next time the game saves
    (when you launch a dive, or quit through the pause menu). A new game, or a save made before the mod, starts with
    every switch off.
  - Opening them needs a mouse and a keyboard; a controller can use and close them.
  - The mod's texts (the mark, the tooltips, the note, the *Others* title) are in `DealerNotifier/i18n/en.po`, inside
    the zip.

## For modders
- Five scripts: `Code.gd` (the station menu's script extension: the Dealer entry, opening the settings),
  `DealerScreen.gd` (the Dealer screen's script extension: the stock, the ships seen, the badges), `SettingsUI.gd` (the
  settings screen) and `Settings.gd` (the settings model and the rule, which the other three share), plus `ModMain.gd`.
  The texts are in `i18n/en.po`.
- **The dealer's stock** is stored nowhere. `CurrentGame.gd` `getShipsAvailableForSale` builds it anew on every call
  from the in-game day and week and `state.seed`: a few ships new every week (named in its code: the mod's
  `NEW_STOCK`), one used ship a day kept 10 days (drawn from `CurrentGame.usedShipsPool`),
  and the ships the player sold (`state.soldShips`), for 10 days; ships the player owns are left out. Only `Dealer.gd`
  `doAddShips` calls it: when the station loads (`_ready`), on `CurrentGame`'s `hourPassed`, and from `show()`. The
  game signals no change. A ship's transponder is the same from one refresh, visit or save to the next (seeded:
  `getNewTransponder`), so it is what tells ships apart; `shipHashFromConfig` is not (it holds the moment the ship was
  instanced).
- Script extension of `res://enceladus/EnceladusMenu.gd` (`Code.gd`): the script of the station menu, the `Options`
  root of `enceladus/EnceladusMenu.tscn` instanced in `enceladus/Enceladus.tscn`. The Dealer entry is the menu's
  `ShipMarket` child, a plain `Button` whose text is the translation key `ENCELADUS_SHIP_MARKET` and whose `pressed`
  the station connects to the Dealer screen's `show`. The mod reads the key from the button and puts it back while
  nothing is new; while marked, the text is `tr(_DN_ALERT) % tr(key)`. It updates on the settings model's
  `settingsChanged` and `stockChanged`, and on `NOTIFICATION_TRANSLATION_CHANGED`. Shift+Click, the tooltip and the
  settings screen's place are CrewCheapHireNotifier's (see its README): the press is accepted in the button's
  `gui_input`, so the Dealer screen stays closed. Without the right-hand screens' container or its `Dealer` child
  there is no settings screen, no tooltip, and Shift+Click is a plain click. A menu without a `ShipMarket` button is
  left alone.
- Script extension of `res://enceladus/Dealer.gd` (`DealerScreen.gd`): the script of `enceladus/Dealer.tscn`,
  instanced in `Enceladus.tscn` as the station's `Dealer` (with `showOwned` off) and, through `enceladus/Owned.tscn`, as
  Fleet (with `showAvailable` off). Everything it does is gated on `showAvailable`, so Fleet is untouched. The tag
  `group = Dealer` in `Mod.manifest` names that game script.
  - Overrides `doAddShips()`: calls the parent's and waits for its end when it yields (it waits for the player's ship,
    and for an idle physics frame per ship while the screen is hidden; the end is when its first
    `GDScriptFunctionState` emits `completed`). A call made while another runs returns at once with `shipAddFlag`
    still set; then the running one reports. It reads the stock from the screen's entries
    (`enceladus/SystemBuyUI.gd`: each entry's `ship`, its `model` and `transponder`) and calls the model's
    `setStock(entries, seen)`, `seen` while the screen is visible.
  - Overrides `show()`: calls the parent's, then keeps the transponders of `newShips()` in `_dnFresh` (the ships that
    get a badge; the screen is built anew on every visit, so they last until the station is left) and calls
    `markSeen()`, which clears the mark at once. The game's `show()` refreshes the stock, and that refresh, done while
    the screen is visible, sees everything again.
  - Overrides `_notification`, which the game's script doesn't have: on `NOTIFICATION_TRANSLATION_CHANGED` it sets the
    badges' tooltips again, since they hold translated text.
  - **The badge** is a `PanelContainer` named `_DN_BADGE`, built as CrewCheapHireNotifier's: only the capitals of the
    mod's name (`_dnInitials()`), a copy of the entry's Buy button `normal` frame (never the game's shared resource)
    with its border in the `modulate` of the entry's Owned label (`HBox/V/Owned`, the overbright green ShipCopyPaste
    marks its template with), the letters in the button's `font_color` times that colour, as the label draws, and in
    the font a Label gets in the entry's picture (`HBox/Margin`, whose theme, `enceladus/Subwindow.theme`, has a small
    one): the name sets no theme, so a Label there would get the entry's, the menu's big font. It sits at the right end
    of the entry's name column (`HBox/ShipName`, a flat Button that fills the column between the picture and the
    specs), inside the right margin the button keeps around its text (its `normal` stylebox's, which a flat button still
    lays its text out in), centred on it from top to bottom. A Button doesn't lay out its children, so the badge hangs
    from it directly, anchored to the middle of its right side and growing left, up and down to its minimum size. A name
    long enough to reach the column's end would run under it (the button clips its text at its own edge); a ship's name
    is two words in a column many times wider. The badge lets the mouse through (`MOUSE_FILTER_PASS`), so the wheel
    still scrolls the list and a click is the name's: it focuses the name, which shows the ship (`Dealer.gd`). Its
    tooltip (`tr(_DN_BADGE_TOOLTIP)`) goes through the entry's `PlaySoundsOnTheseButtons` (`connectSounds`), as
    CrewCheapHireNotifier's badge does, since the released game shows no Godot tooltips. The game keeps an entry from
    one refresh to the next and never touches the badge, so `_dnMarkFresh()` only shows or hides it.
- **The rule** (`Settings.gd`): `stock` is the last refresh's `{model, transponder}` list (not saved; `loadFromState`
  empties it, since it is another save's or the last visit's). `known` is the transponders that never mark: those the
  dealer had while the Dealer screen was open, and those it had when their model was switched on (`setValue`). Every
  refresh drops from `known` the ships no longer for sale. `newShips()` is the stock's ships of a model switched on,
  not in `known`, and not in `CurrentGame.getSoldTransponders()`. `setStock` and `markSeen` save `known` when it
  changes and emit `stockChanged`.
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
  `loadFromState` / `saveToState`, `modId()`, `modName()`, `modVersion()`), with one switch, `watched`, that has
  `perModel`: a value for each model, a dictionary by model key in `cfg`, all sharing its default. Anything that isn't
  a bool gives the default, so a save edited by hand can't break anything. The autoloads are read with `get()`
  (`CurrentGame.get("usedShipsPool")`, `Shipyard.get("ships")`): the mod's scripts are compiled while the autoloads
  after `ModLoader` are still null, and Godot would work out `"key" in CurrentGame` then, failing.
- **The save:** in `CurrentGame.state.ui` under the mod's id from `Mod.manifest`: `formatVersion` (`FORMAT_VERSION`),
  `modVersion`, `watched` (a copy of the dictionary by model) and `known` (a copy of the list).
- **The settings screen** (`SettingsUI.gd`) is built as CrewCheapHireNotifier's and DiveSkipTransit's, but copies the
  live **Dealer** screen's theme, panel, minimum size and size flags, so it opens in the Dealer's place with its frame.
  Under the header (the Dealer entry's key):
  - The description window, nested as `Dealer.tscn` nests its own (`GAME_WINDOW_MARGIN`, `GAME_WINDOW`,
    `GAME_WINDOW_INSIDE`, `GAME_WINDOW_TEXTS`), without the tabs and the ship's view behind the text, with the Dealer's
    theme, margins, panel, least size and spacing, its texts clipped. For the focused row it shows what `Dealer.gd`
    `displayShip` shows: `baseShipName` + `DESCRIPTION_SUFFIX` where it differs from `shipName`, then `shipName` +
    `DESCRIPTION_SUFFIX`, keys the Labels translate.
  - The note: the setting's description, its `label` + `DESCRIPTION_SUFFIX`.
  - An `Items` box in the scroll with one `enceladus/Tuning/TuningItems.tscn` group per series, of
    `TuningBoolValue.tscn` switches named by each model's `shipName` key (`_groups()`): series with two or more models,
    titled by the base model's `shipName`, sorted by the titles' translated names, each one's models by theirs (case
    ignored); then the models alone in their series, under `OTHERS_LABEL`. Filled each time it opens, so the order
    follows a language change. On `tuningChanged` (a change, or a row taking the focus) it sets the row's
    `tune.current` (DiveSkipTransit's fix: a switch doesn't update it itself), calls `setValue` and shows the row's
    description.
  - Each row is dressed as a Dealer entry (`_dressRow()`): a `Picture` Control first, of the size of the entry's
    picture (`GAME_ENTRY_PICTURE`), with a Sprite placed, scaled and flipped as the entry's (`GAME_ENTRY_SPRITE`); the
    reset button hidden; the switch's slot at least as wide as the entry's Buy button (`GAME_ENTRY_BUY`), at the row's
    right end; the switch's tooltip the setting's `label`. Those are read once from an instance of
    `enceladus/SystemBuyUI.tscn` that never enters the tree. No picture is stretched behind the row (the Dealer's `BG`,
    which ShipHighlightTypeAndPrice hides).
  - **The pictures** (`_drawPictures()`) are made the way the Dealer makes its entries' (`SystemBuyUI.gd` `addShip`,
    `checkPrice`, `stopUpdating`): every model at once (`_drawPicture()`), each ship drawn in a viewport of its own (the
    entry's, `GAME_ENTRY_VIEWPORT`: camera, lights, environment, taken out of a new instance of the entry's scene) under
    a hidden Node2D, for `PICTURE_DELAY` once set up, then `get_texture().get_data()` into an `ImageTexture`; then the
    ship is removed and its viewport freed (`Tool.remove`), with anything the ship put beside itself (a cradle lets its
    drone go into the ship's parent, `ships/modules/ClaimOwner.gd` `_ready`). The ships set themselves up together,
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
    read from one instance of the hardpoint scene, never added to the tree (`_hardpointSceneSlot()`). In game 1.92.5
    only ship scenes, the Tsukuyomi's turret module and the habitat use them.
- **The texts.** `i18n/en.po` holds every text the mod shows, under keys that start with `DEALERNOTIFIER_`. `ModMain.gd`
  loads it with `load()` and `TranslationServer.add_translation`, as CrewCheapHireNotifier does (its README says why).
- **With CrewCheapHireNotifier and DiveSkipTransit**, which extend `EnceladusMenu.gd` too: mods load by path, so the
  chain is game ← CrewCheapHireNotifier ← DealerNotifier ← DiveSkipTransit. All three override `_ready` and
  `_notification` (the game's script has neither) without calling the parent's; their members are distinct, and
  opening one's screen hides the others' (`hidefoka`).
- **With the ship-list mods:** ShipCopyPaste extends `SystemBuyUI.gd`, the Dealer's entries; ShipHighlightTypeAndPrice
  and ShipSortByTypeAndPrice change and reorder them. The badge is a child of the entry's name, which none of them
  changes, and the stock is read from every entry, whatever their order, so they work together.
- Members of the menu's extension (`Code.gd`): `DealerNotifier` and `_DN_SETTINGS_UI` (preloads), `_DN_ALERT` and
  `_DN_SETTINGS_TOOLTIP` (translation keys), `_dnMarketButton`, `_dnMarketKey`, `_dnSettingsScreen`, `_dnScreens`,
  `_dnDealer`, `_dnSettings`, `_dnUpdate()`, `_dnOnMarketInput()` and `_dnOpenSettings()`.
- Members of the Dealer screen's extension (`DealerScreen.gd`): `DealerNotifier` (preload), `_DN_BADGE_TOOLTIP`
  (translation key), `_DN_BADGE`, `_dnFresh`, `_dnStock()`, `_dnIsOffer()`, `_dnMarkFresh()`,
  `_dnBadge()` and `_dnInitials()`.
- Tested only outside the game, in a headless Godot 3.6 with the game's `EnceladusMenu.gd`, `HidingMarginContainer.gd`,
  `Dealer.gd`, `SystemBuyUI.gd`, `WeaponSlot.gd`, `TuningItems.gd`, `TuningBoolValue.gd`, `PlaySoundsOnTheseButtons.gd`
  and `Shower.tscn`: the station built in code as its scene nests it, with stubs of the Dealer screen's, its entries'
  and the hardpoint's scenes, of `CurrentGame` and `Shipyard`, and ship models of the harness's own (the `dealer` suite
  of the repository's test harness), alone, with CrewCheapHireNotifier and DiveSkipTransit in every load order, and
  with the ship-list mods. It has not been checked in a real game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).
