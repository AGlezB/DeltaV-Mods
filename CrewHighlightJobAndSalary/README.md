# CrewHighlightJobAndSalary - ΔV: Rings of Saturn

Makes the job and the salary of every crew entry (hired and unhired) stand out on the crew screens, and dims the rest.

## What it does and why
- **What:** every entry on the Crew screen's tabs, Your Crew and Hire, shows:
  - **Job:** bright yellow.
  - **Salary:** amber.
  - **Name, education, experience, next salary due, leave until:** dimmed gray, so the two above pop.
- **Why:** job and salary are what you look for when scanning the crew lists, and the game shows every detail of an
  entry alike.

## For modders
- Scene-tree observer: `ModMain.gd` adds a node with `Code.gd`, which watches the tree's `node_added` for the entries
  of `res://enceladus/CrewBio.gd`, the script of every crew entry on both tabs. No game script is changed.
- An entry fills its labels from its `_ready` (`CrewBio.gd` `fillData`), which runs after `node_added`, so the mod
  waits `SETTLE_TIME` seconds, then gives each label a `font_color` override: `occupationNode` and `salaryNode` their
  colours, and `fullNameNode`, `educationNode`, `experienceNode`, `salaryDue` and `leaveUntil` the dimmed one. The last
  two aren't always Labels, and anything else is skipped.
- Constants at the top of `CrewHighlightJobAndSalary/Code.gd` inside the zip: `JOB_COLOR`, `SALARY_COLOR` and
  `DIM_COLOR` (red, green, blue, each 0 to 1), and `SETTLE_TIME`.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the MIT License.

## Disclaimer
ΔV: Rings of Saturn is made and owned by Kodera Software. The game's name, and everything from the game this mod uses
or shows, belong to Kodera Software.

The author of this mod has no tie of any kind to the game or to Kodera Software. Kodera Software didn't make,
check or approve this mod, and doesn't support it.

This mod is provided as is, for free, and without warranty of any kind, express or implied: use it at your own risk.
The MIT License it is licensed under says so in full.
