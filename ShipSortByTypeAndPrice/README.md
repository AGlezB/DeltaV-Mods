# ShipSortByTypeAndPrice - ΔV: Rings of Saturn

Sorts the ship list on the Dealer screen by type, then by price (cheapest first).

## What it does and why
- **What:** the Dealer's list is sorted by **type** (as shown on screen, e.g. `K37 TNTRL`, in alphabetical order),
  then by **price** (cheapest first). The Fleet list is not changed. The highlight the Dealer puts on its first entry,
  for the keyboard and the gamepad, moves to the new first entry.
- **Why:** ships of the same type come together, so you can compare their prices at a glance.

## For modders
- Scene-tree observer: `ModMain.gd` adds a node with `Code.gd`, which watches the tree's `node_added` for the entries
  of `res://enceladus/SystemBuyUI.gd`, the script of the Dealer's and Fleet's entries. No game script is changed.
- Whenever entries are added to the Dealer list, or finish filling in their data (the entry's `done` signal), the mod
  collects them for `SETTLE_TIME` seconds, then sorts them by the translated text of their `shipLabel` and by the
  number in their `stickerPriceLabel`. Only entries that aren't `owned` move, from the first one's place, so the
  Fleet's entries and anything above the entries stay where they are.
- The Dealer focuses the entry it put first (`enceladus/Dealer.gd` `doAddShips`, the entry's `focus()`); if that one
  still has the focus after the sort, the new first entry's `focus()` is called.
- Tested in the harness (`_tests\`, suite `dealer`): the sort, the highlight, and Fleet left as it is.

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
