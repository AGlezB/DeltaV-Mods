# ΔV: Rings of Saturn - mods by aglezb

Mods for ΔV: Rings of Saturn. Each folder is one independent mod and ships as one zip. Its README says what it does,
how to set it up and how to install it.

## Mods

| Mod | What it does |
|---|---|
| [ArmAltPullBehavior](ArmAltPullBehavior/README.md) | Changes how the ship's AR-1500 arm brings a target in: through the opening of the grinder or excavator, clear of the rotors, claws and hull. |
| [ArmAltTargetSelection](ArmAltTargetSelection/README.md) | Changes how the ship's AR-1500 arm chooses its target: only what it can reach, preferring targets lined up with its intake. |
| [BootSkipLogos](BootSkipLogos/README.md) | The game starts on the title screen, where the save slots are, without the logo sequence first. |
| [CrewCheapHireNotifier](CrewCheapHireNotifier/README.md) | Marks the Crew entry of the Enceladus Prime menu while someone cheap is for hire, and shows who on the Hire screen. |
| [CrewHighlightJobAndSalary](CrewHighlightJobAndSalary/README.md) | Makes the job and the salary of every crew entry (hired and unhired) stand out on the crew screens, and dims the rest. |
| [CrewPerfectSort](CrewPerfectSort/README.md) | Sorts the crew lists at Enceladus Prime: the Hire screen by salary, then occupation; Your crew by occupation, then salary. |
| [DiveDisableAdrenalineBooster](DiveDisableAdrenalineBooster/README.md) | The Adrenaline Booster of your ship starts every dive switched off. |
| [GeologyByMass](GeologyByMass/README.md) | Judges the ore your geologist identifies by the mass of each mineral in it instead of its value, as set on a new tab of the OMS. |
| [HudHideLabels](HudHideLabels/README.md) | Hides the titles on the screens of the dive HUD. |
| [LidarLouderPing](LidarLouderPing/README.md) | The lidar's ping for sensor contacts plays louder, by as much as you set in the ship's Tuning. |
| [ShipHighlightTypeAndPrice](ShipHighlightTypeAndPrice/README.md) | Makes the type of every ship in the dealer and fleet lists stand out, and hides the ship image behind each row. |
| [ShipSortByTypeAndPrice](ShipSortByTypeAndPrice/README.md) | Sorts the ship list on the dealer screen by type, then by price (cheapest first). |

The two arm mods work together or alone. Do not install CrewPerfectSort together with `CrewSortByJobAndSalary`, the
older mod it replaces: both sort the same lists.

## Mods that change how the game plays

These change how something works in a dive, compared to vanilla. The *Warning* in each one's README says what, in
short.

- [ArmAltTargetSelection](ArmAltTargetSelection/README.md#warning): which targets the arm takes, and which one first.
- [ArmAltPullBehavior](ArmAltPullBehavior/README.md#warning): how the arm brings a chunk in, on ships with a grinder or
  an excavator.
- [DiveDisableAdrenalineBooster](DiveDisableAdrenalineBooster/README.md#warning): the Adrenaline Booster starts every
  dive switched off, which also damps the bullet time from the pilot and the smart camera.
- [GeologyByMass](GeologyByMass/README.md#warning): with its switch on, which chunks keep a full info box.

Before reporting a bug in those parts of the game to the game's developers, check that it also happens without these
mods.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the zip of each mod you want in it, and keep only one version of each mod there: they would all load. Do not
   unzip them.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).
