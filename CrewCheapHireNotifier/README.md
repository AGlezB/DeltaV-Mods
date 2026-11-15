# CrewCheapHireNotifier - ΔV: Rings of Saturn

Marks the Crew entry of the Enceladus Prime menu while someone cheap is for hire, and shows who on the Hire screen.

## What it does and why
- **What:** the limit for a job is the higher of the *Salary threshold* setting and the salary of your best-paid crew
  member with that job changed by the *Salary tolerance* setting. While the Hire list has someone whose salary is at
  most the limit for their job (equal counts), the station menu's Crew entry gets a mark: it reads as `ALERT_FORMAT`
  says, with the entry's own text (in the game's language) in place of `%s`. While nobody qualifies, the entry is the
  game's own.
- **On the Hire screen:** everyone who qualifies gets a badge above the values of their details (their name,
  occupation, …), right-aligned with them: the capitals of the mod's name (CCHN) in the game's button frame, outlined
  and lettered in the light green the screen already uses for a better stat. Hovering the badge shows the limit for
  their job in the game's own tooltip, as `LIMIT_TOOLTIP_FORMAT` says. It is the same rule as the menu entry's, so the
  menu is marked exactly when someone there has a badge.
- **The tolerance:** a percentage of your best-paid crew member's salary in that job. A positive one lets a hire earn
  up to that much more and still count (50 % would let a salary up to half as much again count); a negative one
  requires them to earn at least that much less (−20 %: a fifth less, or more); 0 % means as much or less. Its range is
  in `SETTINGS` (see *Settings*).
- **The threshold** is a floor of its own, whatever crew you have hired: the tolerance never changes it. With nobody in
  a job, or with your best-paid in it below the threshold even after the tolerance, a hire counts at or below the
  threshold.
- **Who counts as your crew:** everyone you have hired, active, benched or on leave, since all of them draw wages.
- **When it updates:** as you arrive at the station, every in-game day (the Hire list only changes from one day to the
  next), whenever you hire or fire someone, when you change a setting, and when the game's language changes. The Hire
  screen also when it is first opened.
- **Why:** so you know when the Hire screen is worth a look without opening it every day, and who to look at once
  there.
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
    `CrewCheapHireNotifier/Code.gd`, the badge's tooltip (`LIMIT_TOOLTIP_FORMAT`) at the top of
    `CrewCheapHireNotifier/HireScreen.gd`.

## For modders
- Four scripts: `Code.gd` (the station menu's script extension: the Crew entry, opening the settings), `HireScreen.gd`
  (the Hire screen's script extension), `SettingsUI.gd` (the settings screen) and `Settings.gd` (the settings model
  and the rule, which the other three share).
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
  never changes once someone is hired (`randomizeAvailableCrewMember` sets it, in whole hundreds).
- **The rule** is the settings model's, so the menu and the Hire screen can't disagree: `limitFor(occupation)` (the
  higher of the threshold and the best-paid salary in that job in `CurrentGame.state.crew` times one plus the
  tolerance; the tolerance never applies to the threshold) and `isCheapHire(member)` (`salary` at most that limit). It takes a hire list member or a Hire screen
  entry alike, since both have `occupation` and `salary`.
- It updates on `CurrentGame`'s `dayPassed` (`advanceTimeBySeconds` emits it once the clock has moved, so the new
  day's list is ready) and `employmentChanged` (`hireCrewmember`, `fireCrewmember`, `setMemberActive`, among others),
  and on the settings' `settingsChanged`. The menu is rebuilt on every return to the station, and its connections go
  with it.
- **Shift+Click:** Godot 3 emits a Control's `gui_input` signal before it calls the Control's own `_gui_input`, and
  `accept_event()` there stops the event (`Viewport::_gui_call_input`). The mod accepts a left press with Shift on the
  enabled Crew entry, so the button never presses and the Crew screen stays closed, and opens the settings instead.
  The tooltip (`hint_tooltip`) names the key with `OS.get_scancode_string(KEY_SHIFT)`, the key the check uses, and the
  mod's name from `Mod.manifest`.
- **The Hire screen:** `HireScreen.gd` is a script extension of `res://enceladus/HireableCrew.gd` (also installed in
  `ModMain.gd`), the script of the `HireableCrew` node of the Hire tab in `enceladus/Crew.tscn`. Each person is an
  `enceladus/CrewBio.tscn` entry (`CrewBio.gd`) in its `hireableCrew` list. The game keeps an entry from one day to
  the next while that person is still for hire.
  - Overrides `fillCrew`, which the game calls on `dayPassed`, after a hire and when the tab is first shown. It calls
    the parent's, then marks. It also marks again on `CurrentGame`'s `employmentChanged`, on the settings'
    `settingsChanged`, and on `NOTIFICATION_TRANSLATION_CHANGED`, since the tooltip holds the job's name already
    translated. Every entry is judged each time, as the game keeps entries from one day to the next.
  - **The badge** is a `PanelContainer` named `_CHEAP_HIRE_BADGE`, a child of the entry's top value
    (`_cheapHireAnchor()`: the game's `fullNameNode`, which spans the details grid's values column to its right edge,
    its text right-aligned, in `CrewBio.tscn`). The mod makes it the first time the entry qualifies, and then only
    shows or hides it; the game never touches it.
  - **Where:** a Label is no container, so it leaves the badge where its anchors and margins put it: anchored to the
    top value's top-right corner (`PRESET_TOP_RIGHT`), its bottom edge one grid row gap (the grid's `vseparation`)
    above the value, and both grow directions set to `GROW_DIRECTION_BEGIN`, so it grows left and up to its minimum
    size and its right edge stays on the values' right edge. It follows the values wherever the layout puts them (font,
    language), and no game node is moved, so the paths of the game's `hire` animation still hold. The space above the
    details is empty: they sit at the bottom of the entry and the portrait sets its height (`CrewBio.tscn`), so the
    badge takes no room. As a child of the details it flashes and fades with them in the `hire` animation, and with
    the entry in its `grow` animation.
  - **Look:** its frame is a copy of the Hire button's `normal` stylebox (`menu/ButtonRoundCorners.tres` through
    `enceladus/Subwindow.theme`), duplicated so the game's shared resource is never edited. A `StyleBoxFlat` frame gets
    its border in the entry's `colorBetter`: the game's border is an overbright white, and the game renders without HDR,
    so tinting it would clip to white. The letters, `_cheapHireInitials()` (the capitals of `modName()`), are a Label in
    the entry's font, colored the Hire button's `font_color` times `colorBetter`. That is the green the entry shows for
    a better stat: `CrewBio.gd` `compareStats` sets `colorBetter` as that stat button's `modulate`.
  - **The tooltip** is the badge's `hint_tooltip`: the job, translated, and the limit, formatted as `CrewBio.gd` formats
    a salary (`CurrentGame.formatThousands` and ` E$`), rounded down. Salaries are whole hundreds, so that is exact.
  - **How the game shows it:** the released game shows no Godot tooltips. Its `project.godot` sets
    `display/mouse_cursor/tooltip_position_offset.release` off screen and a long `gui/timers/tooltip_delay_sec.release`.
    Its own tooltips come from the entry's `PlaySoundsOnTheseButtons` (`menu/sfx/PlaySoundsOnTheseButtons.gd`), which
    registers only the buttons and sliders it finds when the entry is made. The mod registers the badge with its
    `connectSounds`: that takes over the badge's `hint_tooltip`, shows it below the badge on hover (with the game's
    hover sound, as on the entry's stat buttons), and reads it again on every hover, so the mod keeps setting it.
  - The badge's `mouse_filter` is `PASS`, so it gets the mouse's enter and exit and the mouse wheel still scrolls the
    list.
  - The Hire button and the entry's labels are left as the game draws them, for other mods too
    (CrewHighlightJobAndSalary colors the labels).
  - **With CrewPerfectSort**, which extends the same script and overrides `fillCrew` too: mods load by path, so the
    chain is game ← CrewCheapHireNotifier ← CrewPerfectSort. CrewPerfectSort calls the parent's `fillCrew` first and
    only reorders the entries, so the badges stay. Both load orders are tested.
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
- Both extensions override `_ready` and `_notification`, which their parents do not have, and do not call the
  parent's: the mod loader runs every level of them by itself. A menu without a `Crew` button is left alone.
- Members of the menu's extension (`Code.gd`): `ALERT_FORMAT` and `SETTINGS_TOOLTIP_FORMAT` (constants a user may
  edit), `CrewCheapHireNotifier` and `_CHEAP_HIRE_SETTINGS_UI` (preloads), `_crewButton`, `_crewKey`, `_settings`,
  `_cheapHireSettings`, `_cheapHireScreens`, `_cheapHireTuning`, `_updateCheapHire()`, `_cheapHireAvailable()`,
  `_onCrewInput()` and `_openCheapHireSettings()`.
- Members of the Hire screen's extension (`HireScreen.gd`): `LIMIT_TOOLTIP_FORMAT` (a constant a user may edit),
  `CrewCheapHireNotifier` (preload), `_CHEAP_HIRE_BADGE`, `_markCheapHires()`, `_cheapHireAnchor()`,
  `_cheapHireBadge()` and `_cheapHireInitials()`.
- Tested only outside the game, in a headless Godot 3.6 with the game's `EnceladusMenu.gd`, `HidingMarginContainer.gd`,
  `TuningItems.gd`, `TuningFloatValue.gd`, `AnalogControlSlider.gd`, `HireableCrew.gd`, `CrewBio.gd`,
  `PlaySoundsOnTheseButtons.gd` and `Shower.tscn`. The station and the Hire tab are built in code as their scenes nest
  them, with a stub of a Hire screen entry's scene and stubs of `CurrentGame` and of the Crew and Tuning screens (the
  `crew` suite of the repository's test harness), alone and with CrewPerfectSort in both load orders. The badge's
  tooltip is checked with a mouse moved through the scene tree's input. It has not been checked in a real game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).
