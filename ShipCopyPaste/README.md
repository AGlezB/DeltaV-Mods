# ShipCopyPaste - ΔV: Rings of Saturn

On the Fleet screen, copies one ship's setup onto the current ship when both are the same model: the equipment, bought
at the Equipment screen's prices, the tuning, the mineral targeting and the crew aboard.

## What it does and why
- **What:** every ship on the Fleet screen but the one you fly gets a *Copy* button (two sheets), right before *Switch
  ship*. *Copy* makes that ship the template: its button lights up in the colour of the *Owned* label. The ship you fly
  then gets a *Paste* button (a clipboard) when the template is of the exact same model. *Paste* asks for
  confirmation, then makes the ship you fly like the template.
- **Why:** repairs take hours. With two identical ships you can switch to the spare and dive while the other one is
  repaired, but each ship keeps its own equipment, tuning, mineral targeting and crew list, and the game has no way to
  carry them from one ship to another.
- **Equipment:** each piece that differs from the template's is bought as on the Equipment screen: its price (times
  the number of slots, for pieces that fill several), minus the trade-in of the piece it replaces; a refund when the
  template's piece is the cheaper one. Replacing a damaged piece adds its repair time, as on the Equipment screen.
  Pieces already the same are not touched, and keep their damage. A piece the Equipment screen doesn't sell (one found
  on a salvaged ship, or one the story hasn't unlocked yet) is left as it is, and the confirmation lists it.
- **Settings and crew:** then the ship gets the template's tuning, the Geologist tab's mineral targeting (other mods'
  settings kept there too, such as GeologyByMass's), the mineral filters of the arm and the drone plants, and the same
  crew aboard, at once: the portraits at the station change with it. The crew belongs to you, not to a ship: a ship
  only remembers who goes aboard once you have hired, fired or changed who dives while flying it. A template that
  never had such a change has no crew list: the crew is then left as it is, and the confirmation says so.
- **Not copied:** the ship's name and registration, its age, its own repair time, the damage of the pieces it keeps,
  its cargo, and its propellant, ammunition and drone parts, which are topped up at launch as always.
- **The confirmation** names the template and shows the price (or the refund), the repair time it adds, what can't be
  fitted, and whether the crew is left as it is. *OK* is disabled when you don't have the money. If anything changed
  while it was open, *OK* shows the new figures first and pastes on the next press.
- **The template lasts while the Fleet screen is open**, through switching ships. Closing the screen forgets it, and
  nothing is saved.
- **Typical use:** *Switch ship* to the spare, *Copy* on the ship going into repair, *Paste* on the spare, dive.

## For modders
- Script extension of `res://enceladus/SystemBuyUI.gd` (`installScriptExtension` in `ModMain.gd`), the script of the
  ship entries on the Fleet screen (`enceladus/Owned.tscn`, an instance of `Dealer.tscn`) and on the ship market
  (`Dealer.tscn`). Only the Fleet's entries (`owned`) are changed. The tag `group = Fleet` in `Mod.manifest` names the
  screen.
- **The buttons:** `_ready` adds *Copy* and *Paste* to `HBox`, right before `Use`, as copies of `Use` without its
  connections, so they keep its look, size and smooth scrolling. Their icons are drawn in code from `Use`'s icon
  (`enceladus/Upgrades/switch.png`): its size and flags, light strokes in the mean colour of its light pixels, edged in
  the mean colour of its dark ones. `_SHIP_COPY_PASTE_ICON_FALLBACK` is the size used only when `Use` has no icon.
  `checkCurrentAndOwned()`, which the game calls when `current` is set and once the ship is set up, calls the parent's,
  then shows the buttons: *Copy* on every entry but the current ship's, *Paste* only on the current ship's.
- **The template:** its transponder is kept as metadata (`shipCopyPasteTemplate`) of the Fleet screen node, the
  entry's first ancestor with `addShips()` (`Dealer.gd`). Each entry connects to that node's `visibility_changed`: when
  it goes invisible (the end of `Dealer.gd` `hide()`'s `hide` animation), the template is removed. Nothing is written
  to the game's state.
- **The crew:** a ship's crew list is its config's `preferredCrew`, which `CurrentGame.gd` writes to the current ship
  only (`hireCrewmember`, `fireCrewmember`, `setMemberActive`) and `validateEmployment` puts aboard when the ship is
  set up (and on every new day); without one, the crew aboard stays as it was. A template with a `preferredCrew` gives
  it, and Paste calls `CurrentGame.validateEmployment()` right after writing it, so the crew goes aboard at once and
  the station's portraits (`enceladus/CurrentCrew.gd`, on `employmentChanged`) follow. A template without one: its crew
  is unknown, the current ship's `preferredCrew` is left as it is, and the confirmation says so.
- **Paste** shows on the current entry when the template is in `CurrentGame.state.garage` with the same `model` as
  `CurrentGame.state.ship`; a template no longer owned (sold) is forgotten.
- **The confirmation:** a copy of the entry's `ConfirmationCenter/BuyPanel` without its connections (a Fleet entry
  never uses the Buy confirmation), shown and hidden by `ShipCopyPasteShow` and `ShipCopyPasteHide`: copies of the
  entry's `BuyShow` and `BuyHide` animations, retargeted to the copy and to *Paste*. The game's `BuyHide` would show
  the entry's Buy button on a Fleet entry. The game's label there holds one short price in the menu font; the copy's
  holds several lines, so it wraps, in the small font of the entry's registration label (`HBox/V/Registration`), at
  `_SHIP_COPY_PASTE_TEXT_SHARE` of the entry's width, and never so wide that the confirmation passes the entry's width:
  the game right-aligns it in the entry (`ConfirmationCenter`, shrink to the end), and a wider one would widen every
  entry of the list.
- **The plan:** the Equipment screen is the node `Upgrades` next to the Fleet screen (`enceladus/Enceladus.tscn`). On
  *Paste* and on *OK*, the mod calls its `updatePricesAndAvailability()` (as it does when it shows), then goes through
  `getItems()` by `slot`. A slot's value is read from each ship's config as that function reads the player's: a missing
  `lidar.type` is the ship's `defaultLidar`, a missing number is 0; values are the same when they have the same type
  (an int counting as a float) and value. Where the template's value differs, the item with that value is bought if
  it `isAvailable()`: its `getNetPrice()`, and its `actualReplacementTime` (non-zero only when the piece it replaces is
  damaged: `ships/ship-ctrl.gd` `getSlotTime`). Otherwise the slot is kept and listed: a system's name translated, or
  the slot's group title (`UpgradeGroup.gd` `openButton`) with the number. Several items count as the default of a
  slot in the game, so a value the template lacks is matched to none of them.
- **Applying**, as `Upgrades.gd` `buy()` does, for the whole plan at once: each item's `clearDamageInSlot(slot)` and
  `setConfig(slot, value)` on the player's ship, whose `shipConfig` is `CurrentGame.state.ship.config`; then the
  settings; then `CurrentGame.changeMoney(-total)` (without insurance, as the Equipment screen), one
  `logEvent("LOG_EVENT_UPGRADE", …)` with every item, and `addShipMaintanenceTime(sum)` when there is any. The settings:
  the template's `tuning`, plus the ship's own entries for the pieces it kept (a slot-mounted piece's are filed under
  `<slot>_<system>`: `WeaponSlot.gd`, `ThrusterSlot.gd` `loadPlaceholder`); `hud.config` and each weapon slot's
  `config`, but for the slots kept, removed where the template has none; the crew, as `preferredCrew`, put aboard with
  `validateEmployment()`. Then, as `Dealer.gd` `use()` does after a switch, the Fleet screen emits `shipChanged`
  (`Enceladus.gd` `shipChanged` rebuilds the docked ship, which emits `playerShipChanged`) and calls `addShips()`.
- `_ready` (only for Fleet entries; the parent's runs by itself) and `checkCurrentAndOwned()`, an ordinary function
  that calls the parent's with `.checkCurrentAndOwned()`.
- Members of the extension: the constants `_SHIP_COPY_PASTE_*`, the variables `_shipCopyPasteCopy`,
  `_shipCopyPastePaste`, `_shipCopyPastePanel`, `_shipCopyPasteText`, `_shipCopyPasteOk` and `_shipCopyPasteShown`, and
  the functions `_shipCopyPaste*` (the buttons, icons, template, plan, confirmation and applying).
- ShipHighlightTypeAndPrice and ShipSortByTypeAndPrice find the entries by their script's path, which the extension
  keeps (`take_over_path`); tested together.
- Tested only outside the game, in a headless Godot 3.6 with the game's `SystemBuyUI.gd` and `SystemShipUpgradeUI.gd`
  in stubs of their scenes (with the game's confirmation animations and `Use` icon), stubs of the Fleet and Equipment
  screens, of the ships and of `CurrentGame` (the `fleet` suite of the repository's test harness). It has not been
  checked in a real game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).
