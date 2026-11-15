# CrewCheapHireNotifier - ΔV: Rings of Saturn

Marks the Crew entry of the Enceladus Prime menu while someone cheap is for hire.

## What it does and why
- **What:** the limit for a job is the higher of the *Salary threshold* setting and the salary of your best-paid crew
  member with that job, plus the *Salary tolerance* setting of it. While the Hire list has someone whose salary is at
  most the limit for their job (equal counts), the station menu's Crew entry gets a mark: it reads as `ALERT_FORMAT`
  says, with the entry's own text (in the game's language) in place of `%s`. While nobody qualifies, the entry is the
  game's own.
- **The tolerance:** a percentage of the limit: 50 % would let a salary up to half as much again count, and 0 % means
  none. It applies with nobody in a job too, on top of the threshold.
- **Who counts as your crew:** everyone you have hired, active, benched or on leave, since all of them draw wages.
- **When it updates:** as you arrive at the station, every in-game day (the Hire list only changes from one day to the
  next), whenever you hire or fire someone, when you change a setting, and when the game's language changes.
- **Why:** so you know when the Hire screen is worth a look without opening it every day.
- **Settings:**
  - **Shift+Click** the Crew entry to open them, as the entry's tooltip says. A plain click still opens the Crew
    screen. The settings open where the Tuning screen does, with the same frame and the game's own Tuning sliders, and
    close the way the game's screens do: Esc, the controller's B or Start button, or picking another entry of the
    menu.
  - *Salary threshold* and *Salary tolerance* each have a slider and a button that resets it to its default. A change
    applies at once.
  - They are kept in your save game, each save with its own, and written to disk the next time the game saves (when
    you launch a dive, or quit through the pause menu). A new game, or a save made before the mod, starts from the
    defaults.
  - Opening them needs a mouse and a keyboard; a controller can use and close them.
  - Each setting's default, range and step are in `SETTINGS` at the top of `CrewCheapHireNotifier/Settings.gd`, inside
    the zip. The mark (`ALERT_FORMAT`) and the tooltip (`SETTINGS_TOOLTIP_FORMAT`) are at the top of
    `CrewCheapHireNotifier/Code.gd`.

## For modders
- Three scripts: `Code.gd` (the script extension: the rule, the Crew entry, opening the settings), `SettingsUI.gd`
  (the settings screen) and `Settings.gd` (the settings model both share).
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
  day's list is ready) and `employmentChanged` (`hireCrewmember`, `fireCrewmember`, `setMemberActive`, among others),
  and on the settings' `settingsChanged`. The menu is rebuilt on every return to the station, and its connections go
  with it.
- **Shift+Click:** Godot 3 emits a Control's `gui_input` signal before it calls the Control's own `_gui_input`, and
  `accept_event()` there stops the event (`Viewport::_gui_call_input`). The mod accepts a left press with Shift on the
  enabled Crew entry, so the button never presses and the Crew screen stays closed, and opens the settings instead.
  The tooltip (`hint_tooltip`) names the key with `OS.get_scancode_string(KEY_SHIFT)`, the key the check uses, and the
  mod's name from `Mod.manifest`.
- **The settings screen** is one more of the station's right-hand screens: a child of
  `EnceladusMenu/MenuContainer/MarginContainer/CanvasLayer/MarginContainer` (`enceladus/HidingMarginContainer.gd`,
  whose `hideOnFocusOf` is the menu, so it is `../../CanvasLayer/MarginContainer` from there). It copies the live
  `Tuning` screen's theme, panel style, minimum size and size flags, so it opens in the same place with the same frame,
  and is built from the game's parts as `enceladus/Tuning.tscn` nests them: `enceladus/Shower.tscn` (the fade),
  `enceladus/HeaderWithMoney.tscn` (the title: the Crew entry's key) and one `enceladus/Tuning/TuningItems.tscn` group
  of `TuningFloatValue.tscn` rows, filled from `SETTINGS` as `Tuning.gd` `fillTuneableSystems` fills its groups. Its
  `show()`, `hide()`, `_ready`, `_input` and `unfocus()` are those of `enceladus/Tuning.gd` and `enceladus/Crew.gd`:
  `ui_cancel` or `pause` closes it, and the container's `hidefoka` (a menu entry took the focus) hides it. The mod
  creates it on first use and calls `hidefoka()` before showing it, as focusing an entry does. Without the container
  or its `Tuning` child (the demo's menu), there is no settings screen, no tooltip, and Shift+Click is a plain click.
- **The settings model** (`Settings.gd`, a `Reference`): `shared()` returns the one instance, kept as metadata of the
  script, since Godot 3 has no static variables. `SETTINGS` describes each setting (label, default, min, max, step,
  unit, and `shown`, the factor between the stored value and the one shown: a fraction is shown as %); `cfg` holds the
  current values. `getValue(key)`, `setValue(key, value)` (clamps; on a change saves and emits `settingsChanged`),
  `toShown` / `fromShown`, `loadFromState()` (the defaults, overlaid by the saved values, each clamped, so a save
  edited by hand can't break anything) and `saveToState()`. `modId()`, `modName()` and `modVersion()` read
  `Mod.manifest`. Scripts reach it through the preload constant `CrewCheapHireNotifier`, never `Settings`, which would
  hide the game's autoload.
- **The save:** `CurrentGame.state.ui` is the game's per-save store for UI values (`setUiValue` / `getUiValue`, used by
  `enceladus/CheckButtonWithSavedState.gd`); `CurrentGame.saveToFile` writes it with the state as JSON, so numbers
  come back as floats. The mod's entry is keyed by its id from `Mod.manifest`, so it can't collide with another
  author's mod, and holds `formatVersion` (`FORMAT_VERSION`), `modVersion` and one value per setting. A saved key
  renamed without a migration, or a new id, would lose the saved values.
- Overrides `_ready` and `_notification`, which the parent does not have, and does not call the parent's: the mod
  loader runs every level of them by itself. A menu without a `Crew` button is left alone.
- Members of the extension: `ALERT_FORMAT` and `SETTINGS_TOOLTIP_FORMAT` (constants a user may edit),
  `CrewCheapHireNotifier` and `_CHEAP_HIRE_SETTINGS_UI` (preloads), `_crewButton`, `_crewKey`, `_settings`,
  `_cheapHireSettings`, `_cheapHireScreens`, `_cheapHireTuning`, `_updateCheapHire()`, `_cheapHireAvailable()`,
  `_onCrewInput()` and `_openCheapHireSettings()`.
- Tested only outside the game, in a headless Godot 3.6 with the game's `EnceladusMenu.gd`, `HidingMarginContainer.gd`,
  `TuningItems.gd`, `TuningFloatValue.gd`, `AnalogControlSlider.gd` and `Shower.tscn`, a station built in code as its
  scenes nest it, and stubs of `CurrentGame` and of the Crew and Tuning screens (the `crew` suite of the repository's
  test harness). It has not been checked in a real game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).
