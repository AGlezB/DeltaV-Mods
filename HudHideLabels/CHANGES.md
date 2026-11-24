# HudHideLabels - Changes

## 1.0.5
- Licensed under the MIT License instead of the GNU GPLv3: the LICENSE in the zip and the README's *About* and
  *Disclaimer* say so.

## 1.0.4
- The README names the K225's HUD by its file (`Display-K225.tscn`), and the Equipment screen and the Onboard
  Maintenance System as the game does.

## 1.0.3
- The README's *Disclaimer* no longer names the author.

## 1.0.2
- The README's *For modders* says the mod was also seen in the real game, on every HUD, in the users' wiki's
  screenshot runs.
- The README has a new *Disclaimer*: the game belongs to Kodera Software, the author has no tie to it or to the
  company, and the mod is provided as is, for free, without warranty.

## 1.0.1
- The code moved from `ModMain.gd` to `HudHideLabels/Code.gd`, which `ModMain.gd` now adds as a node: edit
  `HIDDEN_KEYS` there. No change in behaviour.
- Adds this CHANGES.md.
- The README no longer states the version (it is in `Mod.manifest` and here), and its Install step says to remove
  any other version of the mod from the `mods` folder.
- The mod's id is now `AGlezB.HudHideLabels`, and its author is capitalized the same way (both were lowercase).
