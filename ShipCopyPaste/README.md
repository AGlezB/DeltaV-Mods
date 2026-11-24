# ShipCopyPaste - ΔV: Rings of Saturn

On the Fleet screen, copies another ship's setup onto the ship you fly when both are the same model, in the parts you
choose: its settings (the tuning and the mineral targeting), its crew aboard, and its equipment, bought at the Equipment
screen's prices.

## What it does and why
- **What:** on the Fleet screen, right before *Switch ship*, every other ship gets a *Copy* button (two sheets). It is
  enabled on the ships of the exact same model as the one you fly, and opens a confirmation dialog that makes the ship
  you fly like that ship. A disabled *Copy*'s tooltip says why. The ship you fly has no *Copy*: there is nothing to copy
  onto itself.
- **Why:** repairs take hours. With two identical ships you can switch to the spare and dive while the other one is
  repaired, but each ship keeps its own equipment, tuning, mineral targeting and crew list, and the game has no way to
  carry them from one ship to another.
- **The confirmation dialog**, in the game's own dialog style, asks to make the ship you fly like the other one, with a
  row per part, each with the game's Tuning switch where the two ships differ (on when the dialog opens), and *Same*
  where they don't. Only what is switched on is copied; *OK* is disabled while nothing is. *Cancel*, Esc or the pause
  button close it, and only it: the Fleet screen stays open. If anything changed while it was open, *OK* shows the new
  figures first and copies on the next press.
- **Ship settings**, as one switch: the tuning, the Geologist tab's mineral targeting (other mods' settings kept there
  too, such as GeologyByMass's) and the mineral filters of the arm and the drone plants, whatever they hold. They read
  the same when the Tuning screen would show the same values on both ships and the rest holds the same, in any order.
  Pieces the equipment switch leaves as they are keep their own tuning and filters.
- **Crew aboard:** the other ship's crew list, put aboard at once: the portraits at the station change with it. The crew
  belongs to you, not to a ship: a ship only remembers who goes aboard once you have hired, fired or changed who dives
  while flying it. A ship without such a list has no crew, so copying its crew leaves nobody aboard (the game, when you
  switch to such a ship, keeps whoever is aboard instead). People you have fired since are left out. The same people in
  another order read the same.
- **Equipment:** each piece that differs is bought as on the Equipment screen: its price (times the number of slots,
  for pieces that fill several), minus the trade-in of the piece it replaces; a refund when the other ship's piece is
  the cheaper one. Replacing a damaged piece adds its repair time, as on the Equipment screen. Pieces already the same
  are not touched, and keep their damage. Under the row, each piece with its price, then the total and the repair time:
  a cost negative, in the Fleet screen's red, a refund positive, in its green. When you can't pay, *OK* reads
  *Insufficient funds* and is disabled, but only while the equipment is switched on. A piece the Equipment screen
  doesn't sell (one found on a salvaged ship, or one the story hasn't unlocked yet) makes the equipment impossible to
  copy: the row reads *Incompatible equipment*, and the list shows only those pieces.
- **Never copied:** the ship's name and registration, its age, its own repair time, the damage of the pieces it keeps,
  its cargo, and its propellant, ammunition and drone parts, which are topped up at launch as always. Nothing is saved
  but what *OK* copies.
- **Typical use:** *Switch ship* to the spare, then *Copy* on the ship going into repair, check the dialog, *OK*, dive.

## For modders
- Script extension of `res://enceladus/SystemBuyUI.gd` (`installScriptExtension` in `ModMain.gd`), the script of the
  ship entries on the Fleet screen (`enceladus/Owned.tscn`, an instance of `Dealer.tscn`) and on the ship market
  (`Dealer.tscn`). Only the Fleet's entries (`owned`) are changed. The tag `group = Fleet` in `Mod.manifest` names the
  screen.
- **The button:** `_ready` adds *Copy* to `HBox`, right before `Use`, as a copy of `Use` without its connections, so it
  keeps its look, size and smooth scrolling. Its icon is drawn in code from `Use`'s icon
  (`enceladus/Upgrades/switch.png`): its size and flags, light strokes in the mean colour of its light pixels, edged in
  the mean colour of its dark ones. `_SHIP_COPY_PASTE_ICON_FALLBACK` is the size used only when `Use` has no icon. Next
  to it goes a spacer (`_SHIP_COPY_PASTE_SPACER_NODE`), an empty `Control` the mouse and the focus pass by.
  `checkCurrentAndOwned()`, which the game calls when `current` is set and once the ship is set up, calls the parent's,
  then shows *Copy* on the other ships' entries and the spacer, sized as *Copy*, on the current ship's: the ship's name
  stretches and the rest of the row is packed at its right end (`SystemBuyUI.tscn`), and an `HBoxContainer` gives no
  space to a hidden child, so without it that entry's details would sit further right than the others'. *Copy* is
  enabled when the ship's `model` is the current ship's (`CurrentGame.state.ship`) and its config is in
  `CurrentGame.state.garage`; a disabled one gets a tooltip saying why. The menu theme dims a disabled button's icon.
- **The confirmation dialog**, made on the first *Copy* as a child of the entry: a `ConfirmationDialog`, as the game's
  own (the station's pause menu, `enceladus/PauseLayerEnceladus.tscn`: no title, `popup_centered()`, *Cancel*
  focused), with the game's button keys `OK` and `CANCEL` (the entry's Buy confirmation's). It inherits the entry's menu
  theme (`menu/MenuTheme.tres`: the window frame, the buttons, the big menu font for the question and the rows); the
  equipment's list takes the Fleet screen's prose font, the Label font of the entry's `HBox/Margin`
  (`enceladus/Subwindow.theme`, as the ship's description). The rows are the game's Tuning switch
  (`enceladus/Tuning/TuningBoolValue.tscn`, `_SHIP_COPY_PASTE_SWITCH`), named by `_SHIP_COPY_PASTE_ROWS`, without its
  reset button and with its name never clipped, plus a label shown in the switch's place. The switch sends its value
  again when it gets the focus (`TuningBoolValue.gd` `_focus`, from `tune.current`, which it never updates), so the mod
  keeps `tune.current` up to date. The rows and the list sit in a `VBoxContainer` that shrinks to them, centered under
  the question, with `_SHIP_COPY_PASTE_COLUMN_GAP` (in heights of the prose font) between names and values; the
  question gets the width it needs on one line, up to `_SHIP_COPY_PASTE_MAX_WIDTH_SHARE` of the screen, where it wraps,
  and never less than the rows. The dialog takes its least size, centered, and again two frames later, once laid out.
  A Popup draws on top and isn't laid out by the entry, so it neither widens nor clips the entry. The D-pad goes down
  the switches shown, then to *Cancel* (explicit focus neighbours), and back up. `dialog_hide_on_ok` is off, so *OK* can
  show a changed plan instead of copying. Closing it gives the focus back to *Copy*; closing the Fleet screen (its
  `visibility_changed`) closes it. Esc and `pause` while it shows close it alone: the extension's `_input` marks them
  handled, and children get `_input` before their parents, so `Dealer.gd` `_input` (which closes the Fleet screen on
  them) doesn't see them; as `Dealer.gd` checks `Input.is_action_just_pressed`, which stays true for the whole frame,
  every later event of that frame is marked handled too.
- **The plan:** the Equipment screen is the node `Upgrades` next to the Fleet screen (`enceladus/Enceladus.tscn`). On
  *Copy* and on *OK*, the mod calls its `updatePricesAndAvailability()` (as it does when it shows), then goes through
  `getItems()` by `slot`. A slot's value is read from each ship's config as that function reads the player's: a missing
  `lidar.type` is the ship's `defaultLidar`, then a missing value is that of the slot's default item (the item with
  `default`, as a hardpoint's None), and a missing number is 0; values are the same when they have the same type (an
  int counting as a float) and value. Where the other ship's value differs, the item with that value is bought if it
  `isAvailable()`: its `getNetPrice()`, and its `actualReplacementTime` (non-zero only when the piece it replaces is
  damaged: `ships/ship-ctrl.gd` `getSlotTime`). Otherwise the equipment is incompatible, and the piece is listed: a
  system's name translated, or the slot's group title (`UpgradeGroup.gd` `openButton`) with the number. Several items
  count as the default of a slot in the game, so a value the other ship lacks is matched to none of them. With the
  equipment switched off or incompatible, every differing slot is kept.
- **Sameness:** the settings compare what the copy would write with what the ship has. The tuning as `Tuning.gd`
  `fillTuneableSystems` lists the current ship's systems (`getSystems()`, each system's `getTuneables()`, a
  slot-mounted one under its `slotName`), each value read as the screen reads it (the stored one or the default, a
  number snapped to its step, `TuningFloatValue.gd`), but for the systems on the slots being replaced, whose bought
  pieces' entries (`<slot>_<system>`) are compared as stored: opening the Tuning screen stores every value it shows, so
  the stored tunings alone would tell apart two ships that show the same. Without systems to list, the stored tunings.
  The mineral targeting and each slot's `config` (but the slots kept) compare by what they hold: numbers by value,
  dictionaries by key, arrays in any order; a missing or empty one reads as what the game gives a system without one
  (`CurrentGame.traceMinerals`, `_SHIP_COPY_PASTE_MINERALS_DEFAULT`; `hud/Hud.gd`, `DockingArm.gd`,
  `weapons/drone-plant.gd` `_ready`). The crew compares the other ship's list with the current ship's (or, without one,
  those aboard), in any order.
- **The crew:** a ship's crew list is its config's `preferredCrew`, which `CurrentGame.gd` writes to the current ship
  only (`hireCrewmember`, `fireCrewmember`, `setMemberActive`) and `validateEmployment` puts aboard when the ship is set
  up (and on every new day); without one, the game keeps the crew aboard as it was. The mod reads a missing list as
  an empty one. Firing someone takes them off the current ship's list only (`fireCrewmember`), so another ship's list
  can still name them: the copy leaves out anyone no longer in `CurrentGame.state.crew`, and calls
  `CurrentGame.validateEmployment()` right after writing it, so the crew goes aboard at once and the station's
  portraits (`enceladus/CurrentCrew.gd`, on `employmentChanged`) follow.
- **Applying**, as `Upgrades.gd` `buy()` does, for the whole plan at once, each part only if switched on: each item's
  `clearDamageInSlot(slot)` and `setConfig(slot, value)` on the player's ship, whose `shipConfig` is
  `CurrentGame.state.ship.config`; then the settings; then the crew; then `CurrentGame.changeMoney(-total)` (without
  insurance, as the Equipment screen), one `logEvent("LOG_EVENT_UPGRADE", …)` with every item, and
  `addShipMaintanenceTime(sum)` when there is any. The settings: the other ship's `tuning`, plus the current ship's own
  entries for the pieces kept (a slot-mounted piece's are filed under `<slot>_<system>`: `WeaponSlot.gd`,
  `ThrusterSlot.gd` `loadPlaceholder`), and none of the other ship's for a kept piece the current ship has none for;
  `hud.config` and each weapon slot's `config`, but for the slots kept, removed where the other ship has none. Then, as
  `Dealer.gd` `use()` does after a switch, the Fleet screen emits `shipChanged` (`Enceladus.gd` `shipChanged` rebuilds
  the docked ship, which emits `playerShipChanged`) and calls `addShips()`.
- **Colours:** a cost and a refund take the Fleet screen's `colorMinus` and `colorPlus`, as `Dealer.gd` `displayShip`
  colours a trade-in, with `_SHIP_COPY_PASTE_COLOR_MINUS_FALLBACK` and `_SHIP_COPY_PASTE_COLOR_PLUS_FALLBACK` only where
  the screen has none.
- `_ready` (only for Fleet entries, the Dealer's turning `_input` off; the parent's runs by itself), `_input` (the
  game's script has none) and `checkCurrentAndOwned()`, an ordinary function that calls the parent's with
  `.checkCurrentAndOwned()`.
- Members of the extension: the constants `_SHIP_COPY_PASTE_*`, the variables `_shipCopyPasteCopy`,
  `_shipCopyPasteSpacer`, `_shipCopyPasteDialog`, `_shipCopyPasteTitle`, `_shipCopyPasteParts`, `_shipCopyPasteRows`,
  `_shipCopyPasteStates`, `_shipCopyPasteList`, `_shipCopyPasteProseFont`, `_shipCopyPasteChoices`,
  `_shipCopyPastePlanShown`, `_shipCopyPasteShown`, `_shipCopyPasteFilling` and `_shipCopyPasteClosedFrame`, and the
  functions `_shipCopyPaste*` (the button, icon, plan, comparisons, dialog and applying).
- ShipHighlightTypeAndPrice and ShipSortByTypeAndPrice find the entries by their script's path, which the extension
  keeps (`take_over_path`); tested together.
- Tested outside the game, in a headless Godot 3.6 with the game's `SystemBuyUI.gd` and `SystemShipUpgradeUI.gd` in
  stubs of their scenes (with the game's confirmation animations and `Use` icon), the game's Tuning switch, stubs of the
  Fleet and Equipment screens, of the ships and of `CurrentGame` (the `fleet` suite of the repository's test harness),
  and in the game.

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
