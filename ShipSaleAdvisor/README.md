# ShipSaleAdvisor - ΔV: Rings of Saturn

On the Fleet screen, a ship's sell button offers to prepare the ship first when that brings more cash: its equipment
taken down to the cheapest the Equipment screen offers, and its pieces fixed click by click where a fix adds more than
it costs. Shift+Click on the sell button opens its settings.

## What it does and why
- **What:** Sell (*Sell this ship*) on a stored ship works out whether preparing the ship first would bring more cash,
  by at least the minimum gain set. If it would, a dialog replaces the game's confirmation. It offers to prepare the
  ship, to sell it as it is, or to cancel. Otherwise the game's confirmation shows as usual. The game disables Sell on
  the ship you fly and on a ship in maintenance, so those are never offered anything.
- **Why:** selling pays `CurrentGame.shipSellMarkdown` of the ship's value (90 % in game 1.93.1), while the Equipment
  screen takes the whole value of the piece it replaces off the new one's price, and the Repairs screen's *Fix* raises
  a damaged piece's value, sometimes by more than it costs. So taking a piece down to the cheapest brings, in cash, the
  share of its value the sale would keep. Some fixes add more to the price than they cost. Doing that by hand means
  switching to the ship, working through both screens with the sums for every piece, and switching back.
- **The plan**, worked out from what the Fleet, Equipment and Repairs screens show (`Advisor.gd`):
  - **Slots:** each slot of the Equipment screen whose cheapest item for that ship is cheaper than the one fitted is
    taken down to it when that refunds money, and the share of the refund the sale wouldn't pay reaches the minimum
    gain. A slot of pieces (a hardpoint, the thrusters, the engine) refunds what its pieces are worth, damage included,
    less the cheap item's price, so a damaged piece worth less than the cheapest item stays. A slot priced by its items
    (the capacitor, the LIDAR, the autopilot) refunds the difference between their prices.
  - **Fix clicks**, as the Repairs screen allows them: each click halves every damage of the piece and costs its fix
    price again. Clicks are only made while the piece is under the crew's Repair limit, when none of its damages is past
    what a fix can take on, and while replacing would cost more than fixing. A click is planned only if what it adds
    to the cash is more than its price, whoever pays: insurance is money all the same. On a piece that stays, it adds
    the markdown's share of the value it adds; on a piece taken down afterwards, it adds the whole of it (it raises the
    refund). Its cash gain, what it adds less the part of its price paid in cash, must also reach the minimum gain. A
    piece's value goes with the square of its condition, so what a click adds grows over the first clicks. The clicks
    are judged in runs, so a click that doesn't pay alone can pay together with the next one. The runs with the most
    per E$ go first. The insurance pays first, as at the Repairs screen, then the cash, as far as it goes.
  - Slots and clicks are chosen again from each other, a few rounds (`ROUNDS` in `Advisor.gd`): a click can make a
    slot worth taking down, and taking a slot down makes its pieces' clicks worth more.
  - **Never Replace:** a replacement adds to the ship's value exactly what it costs, and the sale pays back only the
    markdown's share of that.
- **The dialog**, in the game's dialog style: a line at the top, then the rows:
  - *Sale price now*: the game's own price for the ship as it is;
  - *Insurance cost* and *Cash cost*: what the clicks take from each;
  - *Maintenance time*: the clicks' hours, shortened by the mechanics aboard as at the Repairs screen, plus the
    replacement hours of the damaged pieces taken off;
  - *Cash gain from the prepared sale*: the refunds, less the cash cost, plus the prepared ship's price over the price
    now. The prepared ship's price is measured on a copy of it, built out of sight and priced as the Fleet screen
    prices a ship.

  Money coming in has a + and the Fleet screen's green, money going out a - and its red, as the screen writes a
  trade-in. When preparing takes time, a warning under the rows says the sale will have to wait. The buttons are
  *Prepare*, *Sell* and *Cancel*, with Cancel highlighted, as on the game's confirmation.
  - **Prepare** works the plan out again. If anything changed (money, insurance, the crew, the setting), it shows the
    new figures first, and prepares on the next press. Otherwise it prepares the ship as the two screens would: the
    clicks paid and logged, with the mechanics' XP and the achievement, the slots refunded and logged, the maintenance
    added. The Fleet screen then lists its ships again. It never sells: Sell, once the maintenance is over, finds
    nothing more to do and shows the game's confirmation, at the higher price.
  - **Sell** sells the ship as it is, as the game's confirmation does.
  - **Cancel**, Esc or the pause button close the dialog, and only it: the Fleet screen stays open. Closing the Fleet
    screen closes it too.
- **Without switching ships:** the stored ship is prepared where it is, so the ship you fly, the crew aboard and the
  fleet's order stay as they are.
- **Not covered:** the Dealer's trade-in, which pays for a ship in part with the one you fly.
- **Settings:**
  - **Shift+Click** any enabled sell button to open them; it never sells. With a gamepad, highlight a sell button, hold
    `PAD_MODIFIER_NAME` and press `PAD_BUTTON_NAME` (in `Badge.gd`). Every ship's entry has a sell button, so instead of
    a Shift badge beside each, one note at the bottom of the Fleet screen says how, in small letters, and changes to the
    gamepad's buttons while the game's *Controls* setting is at *Gamepad* (or at *Auto*, once the gamepad was used
    last).
  - They open in the Fleet screen's place, with the same frame and title, laid out as the Tuning screen: a window with
    the description of the setting, then *Minimum gain*, the least cash each step (a click, a slot taken down) must
    bring, and the whole preparation for the sell button to offer it. Esc, or the controller's B or Start button, closes
    them and brings the Fleet screen back with that sell button highlighted; picking another entry of the menu closes
    them too.
  - Its default, range and step are in `SETTINGS` at the top of `ShipSaleAdvisor/Settings.gd`, inside the zip.
  - The setting is kept in your save game, each save with its own, and written to disk the next time the game saves.
    A new game, or a save made before the mod, starts from the default.
  - The mod's texts are in `ShipSaleAdvisor/i18n/en.po`, inside the zip.

## For modders
- Script extension of `res://enceladus/SystemBuyUI.gd` (`installScriptExtension` in `ModMain.gd`), the script of the
  ship entries on the Fleet screen (`enceladus/Owned.tscn`, an instance of `Dealer.tscn`) and on the ship market. Only
  the Fleet's entries (`owned`) are changed. The tag `group = Fleet` in `Mod.manifest` names the screen. Its files:
  `Code.gd` (the extension), `Advisor.gd` (the plan: static functions of plain data, which touch neither the game nor
  the scene), `Settings.gd` and `SettingsUI.gd` (the setting and its screen, as MarketAdvisor's), `FleetNote.gd` (the
  note) and `Badge.gd`, the same file as the other mods' (its gamepad twin, `isPadShortcut`, and its small font; its
  badge isn't used).
- **What it reads:** Sell is enabled only on a stored ship out of maintenance (`checkCurrentAndOwned`, `ship-ctrl.gd`
  `canBeSold`), and the entry's `ship` is built from that ship's config in `CurrentGame.state.garage`
  (`CurrentGame.gd` `getOwnedShips`). Its systems are the list it made at its setup, which the Fleet screen's ships
  never refresh (`getSystems`), and Sell prices the ship by that very list (`Dealer.gd` `sell`: `getShipValue()` times
  `shipSellMarkdown`). A stored ship's damage doesn't change while it is stored, and its parts work out their condition
  from the saved damage before that list is made, so the list is right (GAME.md *Fleet*).
- **The slots** (`_ssaSlots`), from the Equipment screen, the node `Upgrades` next to the Fleet screen
  (`enceladus/Enceladus.tscn`): `getItems()` by `slot`, as `Upgrades.gd` `updatePricesAndAvailability` reads the
  player's ship, but against the stored one: the item fitted (`_ssaInstalled`), the items available to that ship
  (`_ssaAvailable`, as `SystemShipUpgradeUI.gd` `isAvailable`: shown in the scene, the story condition, the ship's
  capability and upgrade limits) and the groups it shows (`_ssaGroupShown`, as `UpgradeGroup.gd` `reexamine`). A slot of
  pieces is priced by `getSlotValue` for every slot of the kind (`getNumberOfSlots`), with `getSlotTime`; one without
  pieces by the fitted item's price.
- **The clicks** (`_ssaClicks`), as `SystemShipRepairUI.gd` allows them: `isFixable` (under `getRepairLimit(true)`),
  `isFubar` (a damage past `_SSA_FIXABLE_DAMAGE` of its capacity, the game's `maxDamageThatCanBeFixed`), and
  `shouldBeFixed` (replacing would cost more than fixing). Each click leaves `_SSA_FIX_SHARE` of every damage (the game's
  `repairStepAmount`), and the piece's value after it is the game's own (`ship.getSystemPrice` with the new condition),
  up to `_SSA_MAX_CLICKS` per piece. A shortfall from 100 % that the listed damage doesn't explain, by more than
  `_SSA_UNEXPLAINED`, is kept as a floor no click lowers: the arm's condition reads an overheat its Repairs entry
  doesn't list (`DockingArm.gd` `doComputeStatus`). The hours per click are `repairFixTime` times the game's mechanic
  factor (`getMechanicMultiplier`, from the mechanics aboard, `_SSA_MECHANIC`).
- **The figures** (`_ssaOfferNow`): the sale now is the entry's ship's value times the markdown; the sale after is
  measured on a trial ship built from a copy of the prepared config (`_ssaPrepared`), in a viewport of its own world on
  the Fleet screen (`_SSA_TRIAL_NODE`, `_SSA_TRIAL_SIZE`, never drawn), set up as an entry sets up its ship (a dummy,
  reactor off, in a cutscene; up to `_SSA_TRIAL_FRAMES` frames), read once set up as the entry made for the prepared
  ship will read it, then freed. Sell stays disabled meanwhile. The dialog shows only when the cash gain reaches the
  minimum gain (`Advisor.gd` `reaches`); otherwise `._on_Sell_pressed()` shows the game's confirmation.
- **The dialog** (`_ssaDialogBuild`, `_ssaShow`), made on the first offer as a child of the entry: a
  `ConfirmationDialog`, as ShipCopyPaste's, in the entry's menu theme (the line at the top in the menu font), the rows
  and the warning in the Fleet screen's prose font (the Label font of the entry's `HBox/Margin`). The rows are a
  two-column grid that shrinks to them, centred, `_SSA_COLUMN_GAP` (in heights of that font) between names and values;
  the contents are as wide as the grid, the warning on one line and the line at the top on two need, up to
  `_SSA_MAX_WIDTH_SHARE` of the screen, where they wrap. Money takes the Fleet screen's `colorPlus` and `colorMinus`,
  as `Dealer.gd` `displayShip` colours a trade-in, with `_SSA_COLOR_PLUS_FALLBACK` and `_SSA_COLOR_MINUS_FALLBACK` only
  where the screen has none; the warning, the colour of the game's maintenance label (`_SSA_WARNING_SCENE`, read from
  the scene without making it; `_SSA_WARNING_FALLBACK`). The buttons are put in order with a spacer at each end and
  between them, and the D-pad goes along them (explicit focus neighbours). `dialog_hide_on_ok` is off, so Prepare can
  show a changed offer: the offer's texts are compared as JSON (`_ssaShown`). Esc and `pause` close it alone, as in
  ShipCopyPaste: the extension's `_input` marks them handled, and every later event of that frame too, so `Dealer.gd`
  `_input` doesn't close the Fleet screen. Sell emits the entry's `sell` signal, as `_on_SellConfirm_pressed` does.
- **Prepare** (`_ssaApply`) works on a copy of the stored config, without switching ships: each click as `doFixSystem`
  makes it (every damage less half of what it reads then) and pays it (`changeMoney(-price, true)`, insurance first),
  two `LOG_EVENT_REPAIR` entries, `giveXp` for the mechanics, the `FIX_PART` achievement; each slot as `Upgrades.gd`
  `buy` does (its pieces' damage cleared as `clearDamageInSlot` does, the item's value set, the refund, a
  `LOG_EVENT_UPGRADE` entry); `maintaineceUntil` moved on as `addShipMaintanenceTime` moves it. Under
  `CurrentGame.shipMutex`, the copy replaces the stored config, and the instance built from it is dropped
  (`removeOwnedShipByHash`, as `switchShipTo` drops one); then the Fleet screen's `addShips()` makes a new entry.
- **The settings screen** (`SettingsUI.gd`), made on first use among the station's screens
  (`_SSA_SETTINGS_NODE`), copies the Fleet screen's frame and title and the Tuning screen's description window, and
  behaves as MarketAdvisor's: `hidefoka`, the Shower, Esc, B and Start bringing the Fleet screen back with the focus on
  the sell button that opened it. Shift+Click is read on Sell's `gui_input`, before the button presses
  (`_ssaOnSellInput`, `accept_event`), and on `_on_Sell_pressed` with Shift held.
- **The note** (`FleetNote.gd`), added once to the Fleet screen's column (`_SSA_FLEET_COLUMN`) by its first entry, in
  `Badge.gd`'s `SMALL_FONT_THEME`, its text by the control scheme (`controlSchemeChaged`), loads the save's setting with
  it: the station is built anew after every load and new game.
- `_ready` (only for Fleet entries, the Dealer's turning `_input` off; the parent's runs by itself), `_input` (the
  game's script has none) and `_on_Sell_pressed()`, an ordinary function that falls through to the parent's with
  `._on_Sell_pressed()` on the current ship and where there is nothing to offer.
- Members of the extension: the preload constant `ShipSaleAdvisor` (`Settings.gd`), the constants `_SSA_*`, the
  variables `_ssaDialog`, `_ssaIntro`, `_ssaGrid`, `_ssaWarning`, `_ssaSellButton`, `_ssaProseFont`, `_ssaOffer`,
  `_ssaShown`, `_ssaBusy`, `_ssaSold` and `_ssaClosedFrame`, and the functions `_ssa*` (the offer, the plan's data,
  the trial ship, the dialog, the settings and Prepare).
- ShipCopyPaste extends the same script and touches nothing of Sell; its `checkCurrentAndOwned`, which Sell calls once
  an offer is worked out, calls the game's first (tested in both load orders). ShipHighlightTypeAndPrice and
  ShipSortByTypeAndPrice find the entries by their script's path, which the extension keeps (`take_over_path`).
- Tested outside the game, in a headless Godot 3.6 with the game's `SystemBuyUI.gd` in a stub of its scene, stubs of
  the Fleet and Equipment screens among the game's `HidingMarginContainer.gd`, ships whose systems follow the game's
  price formulas, and a `CurrentGame` stub (the `sale` suite of the repository's test harness, and `fleet` with it
  loaded); in an isolated copy of the game, on a used ship made and aged as the Dealer makes them (the wiki's
  screenshot tool); and in the game.

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
