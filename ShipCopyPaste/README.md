# ShipCopyPaste - ΔV: Rings of Saturn

On the Fleet screen, copies one ship's setup onto the current ship when both are the same model: the equipment, bought
at the Equipment screen's prices, the tuning, the mineral targeting and the crew aboard.

## What it does and why
- **What:** on the Fleet screen, right before *Switch ship*, every other ship gets a *Copy* button (two sheets), and
  the ship you fly a *Paste* button (a clipboard). *Copy* is enabled on the ships of the exact same model as the one you
  fly; it makes that ship the template, and its button lights up in the colour of the *Owned* label. *Paste* is
  enabled once a template is copied; it opens a confirmation dialog, then makes the ship you fly like the template. A
  disabled button's tooltip says why.
- **Why:** repairs take hours. With two identical ships you can switch to the spare and dive while the other one is
  repaired, but each ship keeps its own equipment, tuning, mineral targeting and crew list, and the game has no way to
  carry them from one ship to another.
- **Equipment:** each piece that differs from the template's is bought as on the Equipment screen: its price (times
  the number of slots, for pieces that fill several), minus the trade-in of the piece it replaces; a refund when the
  template's piece is the cheaper one. Replacing a damaged piece adds its repair time, as on the Equipment screen.
  Pieces already the same are not touched, and keep their damage. A piece the Equipment screen doesn't sell (one found
  on a salvaged ship, or one the story hasn't unlocked yet) is left as it is, and the dialog lists it.
- **Settings and crew:** then the ship gets the template's tuning, the Geologist tab's mineral targeting (other mods'
  settings kept there too, such as GeologyByMass's), the mineral filters of the arm and the drone plants, and the same
  crew aboard, at once: the portraits at the station change with it. The crew belongs to you, not to a ship: a ship
  only remembers who goes aboard once you have hired, fired or changed who dives while flying it. A template that
  never had such a change has no crew list: the crew is then left as it is, and the dialog says so.
- **Not copied:** the ship's name and registration, its age, its own repair time, the damage of the pieces it keeps,
  its cargo, and its propellant, ammunition and drone parts, which are topped up at launch as always.
- **The confirmation dialog**, in the game's own dialog style, asks to make the ship you fly like the template, and
  lists side by side what will be copied (each piece bought, with its price; the tuning, the mineral targeting, the
  mineral filters if a ship has any; the crew aboard, by name) and what won't (pieces not sold here; the crew if the
  template has no crew list; then what Paste never copies). Under the lists: the equipment's price or refund, the repair
  time it adds, and whether you lack the money, in which case *OK* is disabled. If anything changed while it was open,
  *OK* shows the new figures first and pastes on the next press. *Cancel*, Esc or the pause button close it, and only
  it: the Fleet screen stays open.
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
  Both start hidden; `checkCurrentAndOwned()`, which the game calls when `current` is set and once the ship is set up,
  calls the parent's, then shows only the one that can be used there: *Copy* on the other ships' entries, *Paste* on
  the current ship's. Being the same size in the same place, the shown one keeps the entries' buttons lined up (an
  `HBoxContainer` gives no space to a hidden child). *Copy* is enabled when the ship's `model` is the current ship's
  (`CurrentGame.state.ship`), *Paste* once there is a valid template; a disabled one gets a tooltip saying why (another
  model; nothing copied). The menu theme dims a disabled button's icon.
- **The template:** its transponder is kept as metadata (`shipCopyPasteTemplate`) of the Fleet screen node, the
  entry's first ancestor with `addShips()` (`Dealer.gd`). Each entry connects to that node's `visibility_changed`: when
  it goes invisible (the end of `Dealer.gd` `hide()`'s `hide` animation), the template is removed. Nothing is written
  to the game's state.
- **The crew:** a ship's crew list is its config's `preferredCrew`, which `CurrentGame.gd` writes to the current ship
  only (`hireCrewmember`, `fireCrewmember`, `setMemberActive`) and `validateEmployment` puts aboard when the ship is
  set up (and on every new day); without one, the crew aboard stays as it was. Firing someone takes them off the current
  ship's list only (`fireCrewmember`), so a template's list can still name them: Paste gives the template's list
  without anyone who is no longer in `CurrentGame.state.crew`, and calls `CurrentGame.validateEmployment()` right after
  writing it, so the crew goes aboard at once and
  the station's portraits (`enceladus/CurrentCrew.gd`, on `employmentChanged`) follow. A template without one: its crew
  is unknown, the current ship's `preferredCrew` is left as it is, and the dialog says so.
- **Paste** is enabled on the current entry when the template is in `CurrentGame.state.garage` with the same `model`
  as `CurrentGame.state.ship`; a template no longer owned (sold) is forgotten.
- **The confirmation dialog**, made on the first *Paste* as a child of the entry: a `ConfirmationDialog`, as the game's
  own (the station's pause menu, `enceladus/PauseLayerEnceladus.tscn`: no title, `popup_centered()`, *Cancel*
  focused), with the game's button keys `OK` and `CANCEL` (the entry's Buy confirmation's). It inherits the entry's menu
  theme (`menu/MenuTheme.tres`: the window frame, the buttons, the big menu font for the question and the headings);
  the lists and the summary take the Fleet screen's prose font, the Label font of the entry's `HBox/Margin`
  (`enceladus/Subwindow.theme`, as the ship's description). Each list wraps at `_SHIP_COPY_PASTE_COLUMN_SHARE` of the
  screen's width; the labels get their width before their text, so they wrap at once, and the dialog takes its least
  size, centered, again two frames later, once laid out. A Popup draws on top and isn't laid out by the entry, so it
  neither widens nor clips the list. `dialog_hide_on_ok` is off, so *OK* can show a changed plan instead of pasting.
  Closing it gives the focus back to *Paste*. Esc and `pause` while it shows close it alone: the extension's `_input`
  marks them handled, and children get `_input` before their parents, so `Dealer.gd` `_input` (which closes the Fleet
  screen on them) doesn't see them; as `Dealer.gd` checks `Input.is_action_just_pressed`, which stays true for the
  whole frame, every later event of that frame is marked handled too.
- **The plan:** the Equipment screen is the node `Upgrades` next to the Fleet screen (`enceladus/Enceladus.tscn`). On
  *Paste* and on *OK*, the mod calls its `updatePricesAndAvailability()` (as it does when it shows), then goes through
  `getItems()` by `slot`. A slot's value is read from each ship's config as that function reads the player's: a missing
  `lidar.type` is the ship's `defaultLidar`, then a missing value is that of the slot's default item (the item with
  `default`, as a hardpoint's None), and a missing number is 0; values are the same when they have the same type
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
- `_ready` (only for Fleet entries, the Dealer's turning `_input` off; the parent's runs by itself), `_input` (the
  game's script has none) and `checkCurrentAndOwned()`, an ordinary function that calls the parent's with
  `.checkCurrentAndOwned()`.
- Members of the extension: the constants `_SHIP_COPY_PASTE_*`, the variables `_shipCopyPasteCopy`,
  `_shipCopyPastePaste`, `_shipCopyPasteDialog`, `_shipCopyPasteTitle`, `_shipCopyPasteLists`, `_shipCopyPasteSummary`,
  `_shipCopyPasteShown` and `_shipCopyPasteClosedFrame`, and the functions `_shipCopyPaste*` (the buttons, icons,
  template, plan, dialog and applying).
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

## Disclaimer
ΔV: Rings of Saturn is made and owned by Kodera Software. The game's name, and everything from the game this mod uses
or shows, belong to Kodera Software.

The author of this mod has no tie of any kind to the game or to Kodera Software. Kodera Software didn't make,
check or approve this mod, and doesn't support it.

This mod is provided as is, for free, and without warranty of any kind, express or implied: use it at your own risk.
The GNU GPLv3 it is licensed under says so in full, in its sections 15 and 16.
