# ShipHighlightTypeAndPrice - Changes

## 1.0.5
- The README's *Disclaimer* no longer names the author.

## 1.0.4
- The README has a new *Disclaimer*: the game belongs to Kodera Software, the author has no tie to it or to the
  company, and the mod is provided as is, for free, without warranty.

## 1.0.3
- The code moved from `ModMain.gd` to `ShipHighlightTypeAndPrice/Code.gd`, which `ModMain.gd` now adds as a node:
  edit `TYPE_COLOR` and `DIM_COLOR` there. No change in behaviour.
- Adds this CHANGES.md.
- The README no longer states the version (it is in `Mod.manifest` and here), and its Install step says to remove
  any other version of the mod from the `mods` folder.
- The mod's id is now `AGlezB.ShipHighlightTypeAndPrice`, and its author is capitalized the same way (both were
  lowercase).

## 1.0.2
- Adds a `Mod.manifest` (ManifestV2.2).
- The README ends with a note: made with the help of Claude, licensed under the GNU GPLv3.

## 1.0.1
- Fix: the dealer removes and re-adds every entry each in-game hour, and each re-add made another copy of the bold
  font. The bold font is now made once and reused.
