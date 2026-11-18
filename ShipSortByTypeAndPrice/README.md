# ShipSortByTypeAndPrice - ΔV: Rings of Saturn

Sorts the ship list on the dealer screen by **type** (as shown on
screen, e.g. `K37 TNTRL`, in alphabetical order), then by **price** (cheapest
first). The fleet list is not changed.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

## How it works
Ships are `res://enceladus/SystemBuyUI.gd` entries. Whenever entries are added to
the dealer list, or finish filling in their data (the entry's `done` signal), the
mod sorts them by the translated text of their `shipLabel` and by the number in
their `stickerPriceLabel`.

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
