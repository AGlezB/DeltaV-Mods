# ShipRepairAdvisor - ΔV: Rings of Saturn

Adds two buttons to the bottom of the Repairs screen. **Repair** brings every damaged system of the ship up to the
condition you set, the cheapest way, with a table beside it of what that costs and how long it takes. **Park** readies
the ship to hold cash: every slot of the Equipment screen gets its cheapest piece, empty where it can be, and every
system is brought to full condition, after a confirmation of what that costs or brings. Shift+Click on Repair opens its
settings.

## What it does and why
- **What:** a row at the bottom of the Repairs screen, under the list of systems: on the right the Repair and Park
  buttons, and before them a table of the target condition, what Repair will cost (*Insurance cost*, *Cash cost*,
  *Total cost*) and the *Maintenance time* it adds. The table follows everything that changes it as it happens: the
  money, the crew, the time, the settings, a repair by hand, a new ship.
- **Why:** the Repairs screen offers two buttons per system, and the cheapest way to a given condition takes sums for
  every one of them. *Fix* halves every damage of the piece, at its full fix price each click; *Replace* clears it all,
  for the piece's price less what it is still worth, which grows as Fixes raise its condition. So the cheapest way can
  be Fixes alone, or some Fixes and then Replace, and the Fixes may stop working before the target (the crew's Repair
  limit, damage beyond repair). And getting a ship ready to hold cash (buying expensive equipment for a ship that stays
  at the station, to sell it back later at its full price) means taking every slot down to its cheapest piece at the
  Equipment screen and then bringing every system to full condition, since a damaged piece trades in for less.
- **Only the game's own buttons.** Both buttons do only what a player can do by hand, faster: they press the Repairs
  screen's own Fix and Replace, and Park also the Equipment screen's own Buy, each only while the game has it enabled.
  So every price, maintenance hour, payment (Fix and Replace from the insurance first, purchases from the cash), Logs
  entry, mechanic's XP and achievement is the game's, as a click makes it.
- **Repair**, as `Advisor.gd` plans it for each system below the target:
  - the cheapest way that reaches the target, then the one with the fewest hours: Fixes alone, or some Fixes and then
    Replace;
  - insurance counts as money: what it pays for one repair can't pay for the next;
  - Replaces that need money are kept, cheapest first, while their systems' whole cost fits in cash and insurance, and
    pressed before anything else, so each one can be paid when its turn comes; a system that no longer fits falls back
    to Fixes alone, and a system no way reaches is fixed as far as Fix raises it;
  - then the Replaces of systems beyond repair, which need no money, and the Fixes alone, which can take the cash below
    zero, as a Fix by hand can. The cash's part of the table turns red when that would happen.

  It works in rounds: each round presses at most one button per row, the plan worked out again from the systems as
  they are, and waits for them to show the repair, since a row's buttons work on what it last read. A press that
  doesn't raise its system's condition leaves that system out until the button is done. Repair is disabled while
  there is nothing to repair.
- **Park**, as `Advisor.gd` plans it, in three steps, each worked out again before every press:
  1. **Fixes before trading in**: a damaged piece on a hardpoint, a thruster or the LIDAR trades in by its condition,
     so it gets Fix clicks first where they raise what it trades in for by more than they cost (insurance counting as
     money).
  2. **Purchases** at the Equipment screen, from the cash: the cheapest piece the screen offers for each slot (nothing,
     where the screen offers to empty it; on a tie, the piece fitted stays), refunds first, then costs, cheapest first.
     A slot with no piece fitted is left alone. Where the cheapest piece is already fitted but worn at 99.5 % or more,
     short of full condition, which neither Fix nor Replace touches (GAME.md *Repairs*), the slot is bought out and
     back: another piece, then the cheapest again, new.
  3. **Repairs** to `_SRA_PARK_TARGET` (in `Code.gd`) of every system still below it, as Repair's plan with that
     target, keeping only ways that get there. The systems of the other slots (the reactor, the turbine, the MPU, …)
     keep their damage through a purchase, so they are repaired afterwards, at the new piece's prices.

  Parking is all or nothing: if the money would fall short at a step the game only allows with the money for it (a
  purchase that costs, a Replace that needs money), the confirmation says how much more is needed, and its OK is
  disabled. A system that no button can bring to that condition (one on another slot, worn at 99.5 % or more) is named
  in the confirmation; OK stays enabled, since nothing better can be done by hand. Park is disabled while there is
  nothing to do, while either button works, and without the Equipment screen.
- **The confirmation**, in the style of the game's dialogs: the question, then *Insurance*, *Cash* and *Total*, signed
  and coloured as the Fleet screen writes a trade-in (money coming in with a + in its green, going out with a - in its
  red), and the *Maintenance time*; under them, the notes. The figures are worked out on a copy of the ship as the
  purchases will leave it, so they match what Park does. Cancel is highlighted. Esc, the controller's B or Start, and
  Cancel close only the confirmation; then, and once Park is done, Park is highlighted again.
- **Settings:**
  - **Shift+Click** the Repair button to open them, as the Shift badge inside it, on its left, says: it reads Shift,
    and hovering it shows how. It works while the button is disabled too, and never repairs. With a gamepad (the
    game's *Controls* setting at *Gamepad*, or at *Auto* once the gamepad was used last), the badge reads the gamepad's
    twin of Shift+Click, `PAD_TEXT` in `Badge.gd`, and highlighting the button (the D-pad goes down to it from the last
    row) shows how: hold the first button and press the second.
  - They open in the Repairs screen's place, with the same frame and title, laid out as the Tuning screen: a window
    with the description of the setting, then *Target condition*, the condition Repair brings every damaged system up
    to, with two rows under it estimating what a system at that condition loses: the *failure rate* (how often it fails
    outright while in use) and the *performance degradation* (how much output it loses while it works), from the
    game's equipment scripts (`failureRate` and `performanceLoss` in `Settings.gd`, which say how). Esc, or the
    controller's B or Start button, closes them and brings the Repairs screen back with Repair highlighted; picking
    another entry of the menu closes them too.
  - Its default, range and step are in `SETTINGS` at the top of `ShipRepairAdvisor/Settings.gd`, inside the zip. The
    least is what the pre-flight inspection asks of each system.
  - The setting is kept in your save game, each save with its own, and written to disk the next time the game saves.
    A new game, or a save made before the mod, starts from the default.
  - The mod's texts are in `ShipRepairAdvisor/i18n/en.po`, inside the zip.

## For modders
- Script extension of `res://enceladus/Repairs.gd` (`installScriptExtension` in `ModMain.gd`), the Repairs screen's
  script. The tag `group = Repairs` in `Mod.manifest` names the screen. Its files: `Code.gd` (the extension),
  `Advisor.gd` (the plans: static functions of plain data, which touch neither the game nor the scene), `ParkDialog.gd`
  (Park's confirmation), `Settings.gd` and `SettingsUI.gd` (the setting and its screen, as MarketAdvisor's) and
  `Badge.gd`, the same file as the other mods'.
- **The row** (`_sraBuildRow`): a `MarginContainer` named `ShipRepairAdvisor` added to the screen, which lays each of
  its children over its whole panel, so the row asks for the bottom only (`SIZE_SHRINK_END`), and the list's margin
  (`_SRA_LIST_MARGIN`) keeps the rows clear of it (`_sraFitList`). Inside, `Row`: the `Table` (a two-column grid at its
  own width) and the `Actions`, the buttons `Repair` and `Park`, in the badge's small font (`Badge.gd`
  `SMALL_FONT_THEME`). The row ends as far above the panel's frame as Park's frame ends from its side
  (`_sraBottomMargin`, from the panel's and the button's styleboxes). The D-pad goes down from the last row's buttons
  to Repair, and up from Repair and Park to its Fix and Replace (`createRepairMenuFor`).
- **What it reads** (`_sraData`, `_sraSystem`): the screen's own rows (`SystemShipRepairUI.gd`), made for the player's
  ship as it is now (`_sraRows`), and the ship's systems after a full poll (`fillInSystems`). For each damaged system,
  its condition after 0, 1, 2… Fix clicks is predicted as the game makes it (every damage less the row's
  `repairStepAmount` of it, the condition from the worst damage for what it can take), up to `_SRA_MAX_CLICKS`; each
  step is judged by the row's own rules (`shouldBeFixed`, `isReplaceable` without its money check, `isFubar`) and
  priced by its own (`fixPrice`, `replacementPrice`), and what the piece is worth there is the ship's own
  (`getSystemPrice`). A shortfall from 100 % that the listed damage doesn't explain, by more than `_SRA_UNEXPLAINED`,
  stays as a floor (the arm's condition reads an overheat its row doesn't list, `DockingArm.gd` `doComputeStatus`).
  The hours per click are `repairFixTime` times the row's mechanic factor (`getMechanicMultiplier`).
- **The rounds** (`_sraRounds`, for Repair and for Park's Fixes and repairs): the rows' own `_on_Fix_pressed` and
  `_on_Replace_pressed`, only while the button is enabled, then `_SRA_SETTLE_FRAMES` physics frames (thrusters and the
  arm work out their condition on the next one), up to `_SRA_MAX_ROUNDS`; a press that raises the condition by less
  than `_SRA_PROGRESS` leaves its system out (`_sraLeftOut`).
- **Park's data** (`_sraParkInfo`): the Equipment screen, the node `Upgrades` beside the Repairs screen
  (`_SRA_EQUIPMENT`, `enceladus/Enceladus.tscn`), priced first with its own `updatePricesAndAvailability` (the piece
  fitted, each one's `getNetPrice()` against it, its `actualReplacementTime`, its Buy button enabled or not). A slot's
  offers are the items the screen shows for this ship (`_sraOffered`: `isAvailable()`, in groups `UpgradeGroup.gd`
  `reexamine` shows) and the piece fitted. A slot's members are the systems whose script names the slot as its `type`
  (`_sraMembers`: `WeaponSlot.gd`, `ThrusterSlot.gd`, `LIDAR.gd`): the Equipment screen prices them by condition
  (`ship-ctrl.gd` `getSlotValue`) and the purchase clears their damage (`clearDamageInSlot`); the other slots trade in
  at the fitted item's price and keep their system's damage (GAME.md *Equipment*). Replace and Fix stop at
  `_SRA_REPLACE_BELOW` (the game's 99.5 %: `isReplaceable`, and `CurrentGame.getRepairLimit`'s cap), so a member worn
  above it makes its slot an out-and-back (`_sraWornPast`), and another system there is unreachable.
- **The purchases** (`_sraParkPurchases`): the item's own `_on_Buy_pressed`, only while its `buttonBuy` is enabled.
  `Upgrades.gd` `buy` fits the piece and builds the player's ship again; Park waits for `CurrentGame`'s
  `playerShipChanged` (counted in `_sraShipChanges`, up to `_SRA_SHIP_WAIT_FRAMES` physics frames), and the rows are
  made again for the new ship, as showing the screen makes them (`_sraShipChanged`, `_sraRebuildRows`). A slot whose
  Buy is disabled, or whose piece didn't get fitted, is left out (`_sraLeftOutSlots`).
- **The confirmation's figures** (`_sraParkExact`) are read on a trial ship (`_sraTrial`), built with
  `Shipyard.createShipByConfig` from a copy of the player's config with every slot bought for on the piece it gets and
  its members' damage cleared, in a viewport of its own world on the screen (`_SRA_TRIAL_NODE`, `_SRA_TRIAL_SIZE`,
  never drawn), set up as ShipSaleAdvisor's trial ships are (a dummy, reactor off, in a cutscene; up to
  `_SRA_TRIAL_FRAMES` frames), then freed (`_sraTrialDone`). From it: the repairs of the systems that keep their damage
  (priced and judged by a copy of a row's script, out of the tree, told the trial ship), the systems no button
  reaches, and each out-and-back's second purchase (the cheapest piece's price less what the other piece's systems are
  worth new). Park ignores further presses meanwhile (`_sraParkChecking`).
- **The dialog** (`ParkDialog.gd`), made on first use as a child of the screen, so it takes the station's menu theme: a
  `ConfirmationDialog` as the game's (no title, `popup_centered`, the game's `OK` and `CANCEL`, Cancel focused). The
  question and the notes in the dialog's font, wrapping at `MAX_WIDTH_SHARE` of the screen; the lines a two-column
  grid in the small font, `COLUMN_GAP` (in heights of that font) between names and values. Money takes the Fleet
  screen's `colorPlus` and `colorMinus` (`_SRA_FLEET`, as `Dealer.gd` `displayShip` colours a trade-in), with
  `_SRA_COLOR_PLUS_FALLBACK` and `_SRA_COLOR_MINUS_FALLBACK` only where the screen has none; the table's cash, the
  rows' `colorBad` (`_SRA_WARNING_FALLBACK`). A condition in the notes is rounded down to `_SRA_CONDITION_DECIMALS`
  (above float error, `_SRA_CONDITION_GUARD`), so one just short of the target never reads as it. Esc and `pause`
  close it alone: its `_input` runs before the screen's (`Repairs.gd` `_input`, which asks the action, not the event),
  and marks every later event of that frame handled too. It closes when the screen hides.
- **The settings screen** (`SettingsUI.gd`), made on first use among the station's screens, copies the Repairs screen's
  frame and title and the Tuning screen's description window (`_SRA_TUNING`), is built from the game's Tuning parts,
  and behaves as MarketAdvisor's: `hidefoka`, the Shower, Esc, B and Start bringing the Repairs screen back with Repair
  highlighted. The estimates' rows are copies of the slider's line. Shift+Click and its gamepad twin are read on the
  Repair button's `gui_input`, before the button presses (`_sraOnRepairInput`, `accept_event`), disabled or not.
- **The Shift badge** (`_sraMakeShiftBadge`, `Badge.gd` `dress`) hangs inside the Repair button, as CombatSimulator's on
  the simulator's button: anchored to the middle of its left side, as far from its edge as the button keeps its text
  (`_sraBadgeInset`); the button aligns its text right and widens to fit both (`_sraFitBadge`, whenever either changes
  size), and the badge lets the mouse through, so a click on it is the button's. The row has its own copy of the game's
  tooltip node (`_SRA_GAME_TOOLTIPS`), which shows the badge's tooltip (`_SRA_SETTINGS_TOOLTIP`,
  `_SRA_SETTINGS_TOOLTIP_PAD`) on hover and, with a gamepad, while Repair is highlighted, and gives both buttons the
  rows' hover and focus sounds; at the bottom of the screen the tooltip goes above the badge (`_process`,
  `_sraPlaceTooltip`).
- `_ready` (the parent's runs first, by itself), `_process` (the game's script has none) and `createRepairMenuFor`, an
  ordinary function that calls the parent's first.
- Members of the extension: the preload constant `ShipRepairAdvisor` (`Settings.gd`), the constants `_SRA_*`, the
  variables `_sraSettings`, `_sraRow`, `_sraTargetValue`, `_sraValues`, `_sraButton`, `_sraParkButton`,
  `_sraParkDialog`, `_sraShiftBadge`, `_sraTooltips`, `_sraTooltipOffset`, `_sraSettingsScreen`, `_sraQueued`,
  `_sraRunning`, `_sraLeftOut`, `_sraLeftOutSlots`, `_sraShipChanges` and `_sraParkChecking`, and the functions `_sra*`
  (the row, the badge and its tooltip, the settings, the plans' data, the rounds, Park's purchases, the trial ship and
  the confirmation). `Badge.gd`'s members are listed in DiveSkipTransit's README. No other mod extends `Repairs.gd`.
- Tested outside the game, in a headless Godot 3.6 with the game's `Repairs.gd`, `Repairs.tscn` and its rows
  (`SystemShipRepairUI.gd`), the game's Equipment items (`SystemShipUpgradeUI.gd`) under a stub of the Equipment screen
  with the game's `updatePricesAndAvailability` and `buy`, ships whose systems follow the game's price formulas and keep
  their damage in their config as the game does, and a `CurrentGame` stub (the `repairs` suite of the repository's test
  harness); in an isolated copy of the game, on a used ship made and aged as the Dealer makes them (the wiki's
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
