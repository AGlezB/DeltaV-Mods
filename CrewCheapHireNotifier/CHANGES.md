# CrewCheapHireNotifier - Changes

## 1.10.2
- Licensed under the MIT License instead of the GNU GPLv3: the LICENSE in the zip and the README's *About* and
  *Disclaimer* say so.

## 1.10.1
- With a gamepad, the Shift badge's tooltip shows while the Crew entry is highlighted: a gamepad shows no hover
  (`attachTooltip()` with the entry as its `focusOwner`).
- Comments in `Code.gd` name `Badge.gd`'s `PAD_BUTTON` instead of the button it holds.
- This file: 1.10.0's entry on `Badge.gd` corrected: of the Hire screen badge it holds only the tooltip, and
  `HireScreen.gd` `_cheapHireBadge()` still builds its look.
- README: the badge's tooltip with a gamepad.

## 1.10.0
- Shift+Click has a gamepad twin: on the highlighted Crew entry, the `PAD_BUTTON` button pressed while the
  `PAD_MODIFIER` one is held opens the settings too (constants of the new `Badge.gd`).
- A small badge beside the station menu's Crew entry tells how to open the settings: it reads Shift, or the gamepad
  twin (`PAD_TEXT`) while the game is played with a gamepad (the game's Controls setting, or with Auto the device last
  used). Hovering it shows how, in a tooltip that follows the control scheme too. The tooltip was the Crew entry's: the
  entry has none now.
- The settings screen has a description window, as the game's Tuning screen does: under the title, what the selected
  setting does, then the details.
- The Hire screen badge's tooltip shows sooner, without the hover sound; with a gamepad, it shows while the entry's
  Hire button has the focus.
- New script, `Badge.gd` (the same file in every mod that has a Shift badge): the Shift badge's look and tooltip, the
  Hire screen badge's tooltip, and the gamepad's twin of Shift+Click. Constants `PAD_MODIFIER`, `PAD_BUTTON`,
  `PAD_MODIFIER_NAME`, `PAD_BUTTON_NAME`, `PAD_TEXT`, `SMALL_FONT_THEME`, `TOOLTIP_DELAY`, `TOOLTIP_FADE` and
  `BUTTON_HOVER_MUTE`; `isPadShortcut()`, `dress()`, `hangBeside()`, `setShiftTooltips()` and `attachTooltip()`.
- `i18n/en.po`: `CREWCHEAPHIRENOTIFIER_SETTINGS_TOOLTIP` reworded (it is the badge's); new
  `CREWCHEAPHIRENOTIFIER_SETTINGS_TOOLTIP_PAD`, `CREWCHEAPHIRENOTIFIER_SALARY_THRESHOLD_DESC`,
  `CREWCHEAPHIRENOTIFIER_SALARY_TOLERANCE_DESC` and `CREWCHEAPHIRENOTIFIER_CREW_LIMIT_DESC`.
- `Code.gd`: `_crewButton`, `_crewKey` and `_settings` renamed `_cheapHireButton`, `_cheapHireKey` and
  `_cheapHireModel`; new `_CHEAP_HIRE_SETTINGS_TOOLTIP_PAD`, `_CHEAP_HIRE_TUNING_SCREEN`, `_CHEAP_HIRE_BADGE_SCRIPT`,
  `_cheapHireShiftBadge` and `_makeCheapHireShiftBadge()`.
- `HireScreen.gd`: new `_CHEAP_HIRE_CURRENCY` and `_CHEAP_HIRE_BADGE_SCRIPT`; the badge is a `Badge.gd`.
- `SettingsUI.gd`: new `GAME_ROW_VALUE`, `GAME_WINDOW_MARGIN`, `GAME_WINDOW`, `GAME_WINDOW_INSIDE`,
  `DESCRIPTION_SUFFIX`, `DESCRIPTION_LINES`, `_description`, `_descriptionWindow()`, `_copyMargins()` and
  `_keepDescriptionHeight()`; `_colorBelowLimit`, the crew screens' colour for an equal stat, colours a Crew limit row
  with fewer hired than its limit (white, as before).
- README: the Shift badge, the gamepad twin, the descriptions, `Badge.gd`; the other mods on the station menu.

## 1.9.2
- The README's *Disclaimer* no longer names the author.

## 1.9.1
- The README has a new *Disclaimer*: the game belongs to Kodera Software, the author has no tie to it or to the
  company, and the mod is provided as is, for free, without warranty.

## 1.9.0
- On the settings screen, a Crew limit row's value turns light red (the crew screens' colour for a worse stat) while
  more crew members with that job are hired than its limit, and green (their colour for a better stat) when exactly as
  many.
- `SettingsUI.gd`: `GAME_CREW_ENTRY` and `_colorCrewLimit()` added.
- README: the colours.

## 1.8.0
- On the settings screen, each Crew limit row shows how many crew members with that job you have hired before the
  limit, as the Hire screen badge does.
- `i18n/en.po`: `CREWCHEAPHIRENOTIFIER_CREW_LIMIT_VALUE` added. `SettingsUI.gd`: `CREW_LIMIT_VALUE` and
  `_hiredFormat()` added.
- README: the Crew limit rows' value.

## 1.7.0
- The Hire screen badge shows, after the capitals of the mod's name, how many crew members with that job you have
  hired (active, benched or on leave) out of its crew limit, the same two numbers as its tooltip's second line.
- `i18n/en.po`: `CREWCHEAPHIRENOTIFIER_BADGE` added. `HireScreen.gd`: `_CHEAP_HIRE_BADGE_TEXT` and
  `_cheapHireBadgeText()` added.
- README: the badge's text.

## 1.6.1
- The mod's id is now `AGlezB.CrewCheapHireNotifier`, and its author is capitalized the same way (both were lowercase).
  Settings saved under the old id are not read: they start from the defaults.

## 1.6.0
- The Hire screen badge's tooltip has a second line: how many crew members with that job you have hired (active,
  benched or on leave) out of its crew limit.
- `i18n/en.po`: `CREWCHEAPHIRENOTIFIER_HIRED_TOOLTIP` added. `HireScreen.gd`: `_CHEAP_HIRE_HIRED_TOOLTIP` added.
- README: the tooltip's second line.

## 1.5.0
- The settings screen lists the crew limits in alphabetical order of the jobs' names, in the game's language, instead
  of the game's order.
- `SettingsUI.gd`: `_jobsByName()` added. README: the order of the rows.

## 1.4.0
- New *Crew limit* for each job (the game's jobs, `CurrentGame.occupations`), in a second group of the settings
  screen, starting at `CREW_LIMIT_MAX`. A job with that many crew members or more (active, benched or on leave) is
  full: a hire in it counts only while earning less than your best-paid crew member in that job, whatever the
  threshold and the tolerance say. With a limit of 0 and nobody in the job, nobody in it counts.
- On the Hire screen, a full job's badge says the job is full and gives the salary to beat.
- The mod's texts are in `i18n/en.po`, loaded by `ModMain.gd`, so they can be translated. The Crew entry's tooltip
  now follows a language change too.
- `Code.gd`: `ALERT_FORMAT` and `SETTINGS_TOOLTIP_FORMAT` are replaced by the translation keys `_CHEAP_HIRE_ALERT`
  and `_CHEAP_HIRE_SETTINGS_TOOLTIP`. `HireScreen.gd`: `LIMIT_TOOLTIP_FORMAT` by `_CHEAP_HIRE_LIMIT_TOOLTIP`;
  `_CHEAP_HIRE_FULL_TOOLTIP` and `_cheapHireTooltip()` added. Their texts are edited in `en.po`.
- `Settings.gd`:
  - every `label` in `SETTINGS` is a translation key; `perJob` added, for a setting with one value per job;
  - `CREW_LIMIT_MAX`, `jobs()`, `isPerJob()`, `crewCount()`, `bestPaid()` and `isJobFull()` added; `getValue()` and
    `setValue()` take the job of a per-job setting;
  - values are snapped to their step;
  - `FORMAT_VERSION` raised: the crew limit is saved as a dictionary by job key.
- `SettingsUI.gd`: `GROUP_LABEL` is a translation key; the groups are in an `Items` box, as in the Tuning screen.
- README: the crew limit, the settings screen, the texts, the rule, the model and the members.

## 1.3.0
- The *Salary tolerance* can be negative, down to the minimum in `SETTINGS`: a hire must then earn at least that much
  less than your best-paid crew member in that job.
- The tolerance applies only to that salary, never to the *Salary threshold*, which is now a floor of its own: with
  nobody in a job, or a best-paid below the threshold even after the tolerance, a hire counts at or below the
  threshold. Before, the tolerance raised the threshold too.
- Fix: hovering the Hire screen badge shows its tooltip in the game. The released game shows no Godot tooltips; the
  badge is now registered with the game's own tooltip node (`PlaySoundsOnTheseButtons`), which also plays its hover
  sound.
- `Settings.gd`: `limitFor()` changed accordingly. README: the tolerance, the threshold and the tooltip.

## 1.2.2
- The Hire screen's badge sits above the values of the entry's details, right-aligned with them, instead of above the
  labels.
- README: where the badge sits and how it is placed.

## 1.2.1
- The Hire screen's badge sits directly above the entry's details (Name, Occupation, …), left-aligned with them,
  instead of in the entry's top-left corner.
- `HireScreen.gd`: `_cheapHireAnchor()` added.
- README: where the badge sits and how it is placed.

## 1.2.0
- The Hire screen's mark is now a badge in the top-left corner of each qualifying entry: the capitals of the mod's
  name in the game's button frame, outlined and lettered in the entry's `colorBetter`. It replaces the green Hire
  button label, which was hard to notice; the Hire button is the game's again.
- The limit's tooltip (`LIMIT_TOOLTIP_FORMAT`) is on the badge.
- `HireScreen.gd`: `_HIRE_COLOR_NAMES`, `_markCheapHire()` and `_unmarkCheapHire()` removed; `_CHEAP_HIRE_BADGE`,
  `_cheapHireBadge()` and `_cheapHireInitials()` added.
- README: the badge, how it is placed and drawn, and the members.

## 1.1.0
- The Hire screen shows who triggered the mark: everyone who qualifies has their Hire button's label in the screen's
  "better" green (each state's color tinted with the entry's `colorBetter`), and a tooltip on it with the limit for
  their job (`LIMIT_TOOLTIP_FORMAT`).
- New script extension `HireScreen.gd`, of `res://enceladus/HireableCrew.gd`, installed by `ModMain.gd`. It stacks with
  CrewPerfectSort, which extends the same script, in either load order.
- The rule moved from `Code.gd` into the settings model, as `limitFor(occupation)` and `isCheapHire(member)`, shared by
  the menu and the Hire screen; `_cheapHireAvailable()` uses it. No change in behaviour.
- README: the Hire screen's mark, the new constant, the new members and how they were tested. `Mod.manifest`'s
  description mentions the Hire screen.
