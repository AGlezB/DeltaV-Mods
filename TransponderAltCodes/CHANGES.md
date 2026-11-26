# TransponderAltCodes - Changes

## 1.1.0
- A ship the game meets again with a code it made before the mod was installed (the miners in the rings, a rescue's
  MAD-CERF and derelict, a crew agenda's derelict, the ring races' racer and drone, the ATLAS drone, Vilcy's ships)
  gets a code of its model the next time the game asks for it, once, so an older save no longer keeps the game's codes
  on them for good. Its name, its disposition, its encounter and its build's entry in the save move to the new code;
  its captain's name, which the game makes from the code, changes. A sold ship's code is kept.
- New members `_tacIsGameCode`, `_tacRecode` and `_tacKeepName` (the name keeping `_tacAddSuffix` did, which both now
  share), and the constants `_TAC_GAME_DIGITS` and `_TAC_RECODE_TRIES`.
- The README says so: *What it does and why*, *Removing it* and *For modders*.

## 1.0.4
- Licensed under the MIT License instead of the GNU GPLv3: the LICENSE in the zip and the README's *About* and
  *Disclaimer* say so.

## 1.0.3
- The game's script paths, formats and names the mod matches are prefixed constants: `_TAC_SHIP_SCRIPT`,
  `_TAC_BODY_SCRIPT`, `_TAC_DOCK_SCRIPT`, `_TAC_DOCK_FORMAT`, `_TAC_STORY_BEACON_SCRIPTS`, `_TAC_STORY_BEACON_FORMAT`,
  `_TAC_BODY_BEACON_SCENE`, `_TAC_LIFEPOD_NAME` and `_TAC_AI_CORE_NAME`, so their names can't clash with another mod's
  on the same script.
- The README calls the game's New Game+ screen by its name, New Game Options, and says how the mod goes with
  CombatSimulator, which extends the same script.

## 1.0.2
- The README's *Disclaimer* no longer names the author.

## 1.0.1
- The README has a new *Disclaimer*: the game belongs to Kodera Software, the author has no tie to it or to the
  company, and the mod is provided as is, for free, without warranty.
- Adds this CHANGES.md.
