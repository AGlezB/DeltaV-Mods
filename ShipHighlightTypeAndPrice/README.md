# ShipHighlightTypeAndPrice - ΔV: Rings of Saturn

Makes the **type** of every ship in the dealer and fleet lists stand
out when scanning:

- **Type** (e.g. `K37 TNTRL`): bold amber.
- **Name and price:** unchanged, original white.
- **Registration and year:** dimmed gray, so the type pops.
- The ship image stretched behind each row is hidden, so the text is easier to read.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

To change a color, edit `TYPE_COLOR` or `DIM_COLOR` at the top of
`ShipHighlightTypeAndPrice/Code.gd` inside the zip (red, green, blue, each 0 to 1).

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).
