# ShipSortByTypeAndPrice - ΔV: Rings of Saturn

Version 1.0.3. Sorts the ship list on the dealer screen by **type** (as shown on
screen, e.g. `K37 TNTRL`, in alphabetical order), then by **price** (cheapest
first). The fleet list is not changed.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put `ShipSortByTypeAndPrice-1.0.3.zip` in it. Do not unzip it.
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
