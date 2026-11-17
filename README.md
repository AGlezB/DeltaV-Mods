# ΔV: Rings of Saturn - mods by AGlezB

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

Mods for ΔV: Rings of Saturn. Each folder is one independent mod and ships as one zip. The
[wiki](../../wiki) explains each mod for players, with pictures: the links below go to its pages. Each mod's README,
in its folder, has the details for modders.

## Mods

| Mod | What it does |
|---|---|
| [ArmAltPullBehavior](../../wiki/ArmAltPullBehavior) | Changes how the ship's AR-1500 arm brings a target in: through the opening of the grinder or excavator, clear of the rotors, claws and hull. |
| [ArmAltTargetSelection](../../wiki/ArmAltTargetSelection) | Changes how the ship's AR-1500 arm chooses its target: only what it can reach, preferring targets lined up with its intake. |
| [BootSkipLogos](../../wiki/BootSkipLogos) | The game starts on the title screen, where the save slots are, without the logo sequence first. |
| [CrewCheapHireNotifier](../../wiki/CrewCheapHireNotifier) | Marks the Crew entry of the Enceladus Prime menu while someone cheap is for hire, and shows who on the Hire screen. |
| [CrewHighlightJobAndSalary](../../wiki/CrewHighlightJobAndSalary) | Makes the job and the salary of every crew entry (hired and unhired) stand out on the crew screens, and dims the rest. |
| [CrewPerfectSort](../../wiki/CrewPerfectSort) | Sorts the crew lists at Enceladus Prime: the Hire screen by salary, then occupation; Your crew by occupation, then salary. |
| [DealerNotifier](../../wiki/DealerNotifier) | Marks the Dealer entry of the Enceladus Prime menu when a ship you are waiting for comes up for sale, and that ship on the Dealer screen. You pick the ships with Shift+Click on Dealer. |
| [DiveDisableAdrenalineBooster](../../wiki/DiveDisableAdrenalineBooster) | The Adrenaline Booster of your ship starts every dive switched off. |
| [DiveSkipTransit](../../wiki/DiveSkipTransit) | Skips a dive's cutscenes (the transit both ways, launch, astrogation, rescue, game over, the station's fade-in), charging the remass and in-game time they would have cost, or plays the transit faster without holding Space. Each skip has its own switch (Shift+Click Launch Ring Dive). |
| [GeologyByMass](../../wiki/GeologyByMass) | Judges the ore your geologist identifies by the mass of each mineral in it instead of its value, as set on a new tab of the OMS. |
| [HudHideLabels](../../wiki/HudHideLabels) | Hides the titles on the screens of the dive HUD. |
| [LidarLouderPing](../../wiki/LidarLouderPing) | The lidar's ping for sensor contacts plays louder, by as much as you set in the ship's Tuning. |
| [ShipCopyPaste](../../wiki/ShipCopyPaste) | On the Fleet screen, copies one ship's setup onto the current ship when both are the same model: the equipment, bought at the Equipment screen's prices, the tuning, the mineral targeting and the crew aboard. |
| [ShipHighlightTypeAndPrice](../../wiki/ShipHighlightTypeAndPrice) | Makes the type of every ship in the dealer and fleet lists stand out, and hides the ship image behind each row. |
| [ShipSortByTypeAndPrice](../../wiki/ShipSortByTypeAndPrice) | Sorts the ship list on the dealer screen by type, then by price (cheapest first). |
| [TransponderAltCodes](../../wiki/TransponderAltCodes) | New transponder codes say what carries them: a ship's series and model, and whether it is a ship's lifepod, its drones, an AI core or frozen crew. |

The two arm mods work together or alone. Do not install `CrewPerfectSort` together with `CrewSortByJobAndSalary`, the
older mod it replaced: both sort the same lists. Nor `TransponderAltCodes` together with `AltTransponderCodes`, the
same mod under its old name: both would load.

## Mods that change how the game plays

These change how something works in a dive, compared to vanilla. Each one's wiki page says what, in short, as does the
*Warning* in its README.

- [ArmAltTargetSelection](../../wiki/ArmAltTargetSelection#changes-how-the-game-plays): which targets the arm takes, and which one first.
- [ArmAltPullBehavior](../../wiki/ArmAltPullBehavior#changes-how-the-game-plays): how the arm brings a chunk in, on ships with a grinder or
  an excavator.
- [DiveDisableAdrenalineBooster](../../wiki/DiveDisableAdrenalineBooster#changes-how-the-game-plays): the Adrenaline Booster starts every
  dive switched off, which also damps the bullet time from the pilot and the smart camera.
- [DiveSkipTransit](../../wiki/DiveSkipTransit#changes-how-the-game-plays): a dive's cutscenes are skipped, with their remass and in-game
  time charged from the game's formulas (the switches marked in its settings affect remass); the burn away from the
  ring is an estimate. The transit, when played, can run faster than the game's own fast-forward, without sound.
- [GeologyByMass](../../wiki/GeologyByMass#changes-how-the-game-plays): with its switch on, which chunks keep a full info box depends
  on ore mass instead of value.
- [TransponderAltCodes](../../wiki/TransponderAltCodes#changes-how-the-game-plays): a ship's model shows in its
  transponder code, on the LIDAR and in the Pilot tab, before the ship is in sight.

Before reporting a bug in those parts of the game to the game's developers, check that it also happens without these
mods.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the zip of each mod you want in it, and keep only one version of each mod there: they would all load. Do not
   unzip them.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## For modders

How the code is laid out, how the game loads a mod and how these mods hook in, the conventions they follow and the
game's terms are in [MODDING.md](MODDING.md); the test harness is in [`_tests/README.md`](_tests/README.md).

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the [GNU General Public License v3.0](LICENSE) (GNU GPLv3).
