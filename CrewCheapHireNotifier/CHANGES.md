# CrewCheapHireNotifier - Changes

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
