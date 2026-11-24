# ShipHighlightTypeAndPrice - ΔV: Rings of Saturn

Makes the type of every ship in the Dealer and Fleet lists stand out, and hides the ship image behind each row.

## What it does and why
- **What:** every entry of the Dealer and Fleet lists shows:
  - **Type** (e.g. `K37 TNTRL`): bold amber.
  - **Name and price:** unchanged, original white.
  - **Registration and year:** dimmed gray, so the type pops.

  The ship image stretched behind each row is hidden.
- **Why:** the type is what you look for when scanning the lists, and the image behind the text makes it harder to
  read.

## For modders
- Scene-tree observer: `ModMain.gd` adds a node with `Code.gd`, which watches the tree's `node_added` for the entries
  of `res://enceladus/SystemBuyUI.gd`, the script of the Dealer's and Fleet's entries. No game script is changed.
- An entry fills its labels from its `_ready` (`SystemBuyUI.gd` `addShip`), which runs after `node_added`, so the mod
  waits `SETTLE_TIME` seconds, then gives `shipLabel` a `font_color` override and a bold copy of its font, and
  `transponder` and `makeYearLabel` the dimmed colour. The picture behind the row (`background`) gets a
  `self_modulate` alpha of 0, not `visible = false`, which the game toggles.
- The bold look is a faint outline in the type's colour (`BOLD_OUTLINE_SIZE`, `BOLD_OUTLINE_ALPHA`). The entries share
  the game's font, which must not change, so one bold copy is made per font and kept: the Dealer adds its entries
  again every hour (`enceladus/Dealer.gd` `doAddShips`), and an entry added again already has it.
- Constants at the top of `ShipHighlightTypeAndPrice/Code.gd` inside the zip: `TYPE_COLOR` and `DIM_COLOR` (red,
  green, blue, each 0 to 1), the bold outline's, and `SETTLE_TIME`.
- Tested in the harness (`_tests\`, suite `dealer`): the colours, the bold copy shared by every entry and the game's
  font untouched, the picture behind each row hidden, on the Dealer's entries and Fleet's.

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
