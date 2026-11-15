# CrewCheapHireNotifier - ΔV: Rings of Saturn

Version 0.1.1. Marks the Crew entry of the Enceladus Prime menu while someone cheap is for hire.

## What it does and why
- **What:** the limit for a job is the higher of `SALARY_THRESHOLD` and the salary of your best-paid crew member with
  that job, plus `SALARY_TOLERANCE` of it. While the Hire list has someone whose salary is at most the limit for
  their job (equal counts), the station menu's Crew entry gets a mark: it reads as `ALERT_FORMAT` says, with the
  entry's own text (in the game's language) in place of `%s`. While nobody qualifies, the entry is the game's own.
- **The tolerance:** `SALARY_TOLERANCE` is a fraction of the limit: 0.5 would let a salary up to 50 % above the limit
  count, and 0 means none. It applies with nobody in a job too, on top of `SALARY_THRESHOLD`.
- **Who counts as your crew:** everyone you have hired, active, benched or on leave, since all of them draw wages.
- **When it updates:** as you arrive at the station, every in-game day (the Hire list only changes from one day to the
  next), whenever you hire or fire someone, and when the game's language changes.
- **Why:** so you know when the Hire screen is worth a look without opening it every day.
- To change the rule or the mark, edit `SALARY_THRESHOLD`, `SALARY_TOLERANCE` or `ALERT_FORMAT` at the top of
  `CrewCheapHireNotifier/Code.gd` inside the zip.

## For modders
- Script extension of `res://enceladus/EnceladusMenu.gd` (`installScriptExtension` in `ModMain.gd`): the script of the
  station menu, the `Options` root of `enceladus/EnceladusMenu.tscn` instanced in `enceladus/Enceladus.tscn`. Its only
  function is `disable()`, which the mod leaves alone. The tag `group = EnceladusMenu` in `Mod.manifest` names that
  game script.
- The Crew entry is the menu's `Crew` child, a plain `Button` with no script whose text is the translation key
  `ENCELADUS_CREW`. A Godot 3 `Button` translates its own text. The mod reads the key from the button and puts it back
  while nobody qualifies, so the game shows its own label. While marked, the text is `ALERT_FORMAT % tr(key)`. A
  language change (`Settings.gd` calls `TranslationServer.set_locale`) sends every node
  `NOTIFICATION_TRANSLATION_CHANGED`, and the mod then sets the text again, because the button cannot translate text
  that is already translated.
- The data are the game's own: `CurrentGame.getAvailableCrew()`, the call `HireableCrew.gd` `fillCrew` fills the Hire
  list with, and `CurrentGame.state.crew`, your crew by full name. Every entry has `occupation` and `salary`. A salary
  never changes once someone is hired (`randomizeAvailableCrewMember` sets it).
- It updates on `CurrentGame`'s `dayPassed` (`advanceTimeBySeconds` emits it once the clock has moved, so the new
  day's list is ready) and `employmentChanged` (`hireCrewmember`, `fireCrewmember`, `setMemberActive`, among others).
  The menu is rebuilt on every return to the station, and its connections go with it.
- Overrides `_ready` and `_notification`, which the parent does not have, and does not call the parent's: the mod
  loader runs every level of them by itself. A menu without a `Crew` button is left alone.
- Members: `SALARY_THRESHOLD`, `SALARY_TOLERANCE` and `ALERT_FORMAT` (constants a user may edit), `_crewButton`, `_crewKey`,
  `_updateCheapHire()` and `_cheapHireAvailable()`.
- Tested only outside the game, in a headless Godot 3.6 with the game's `EnceladusMenu.gd`, menus built in code as its
  scene nests them, and a stub of `CurrentGame` (the `crew` suite of the repository's test harness). It has not been
  checked in a real game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put `CrewCheapHireNotifier-0.1.1.zip` in it. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).
