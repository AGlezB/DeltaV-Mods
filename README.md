# ΔV: Rings of Saturn mods

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

**WARNING**: Mods might break or work in unexpected ways if another mod or a DLC touches the same parts or changes the
behavior of the base game functions the mod uses.

Mods for ΔV: Rings of Saturn. Each folder is one independent mod and ships as one zip. The
[wiki](../../wiki) explains each mod for players, with pictures: the links below go to its pages. Each mod's README,
in its folder, has the details for modders.

## Mods

| Mod | What it does |
|---|---|
| [ArmAltPullBehavior](../../wiki/ArmAltPullBehavior) | Changes how the ship's AR-1500 arm brings a target in and holds it: along curved paths through the opening of the grinder or excavator, clear of the rotors, claws and hull, and steady against the ship's turns and thrust. |
| [ArmAltTargetSelection](../../wiki/ArmAltTargetSelection) | Changes how the ship's AR-1500 arm chooses its target: only what it can reach, preferring targets lined up with its intake. |
| [BootSkipLogos](../../wiki/BootSkipLogos) | The game starts on the title screen, where the save slots are, without the logo sequence first. |
| [CombatSimulator](../../wiki/CombatSimulator) | Shift+Click on the simulator's button runs a fight at the station instead, against the enemy ships, distance, rocks and remass you pick, with nothing carried over to the save. Its wiki page explains every ship and weapon in a fight. |
| [CrewCheapHireNotifier](../../wiki/CrewCheapHireNotifier) | Marks the Crew entry of the Enceladus Prime menu while someone cheap is for hire, and shows who on the Hire screen. |
| [CrewHighlightJobAndSalary](../../wiki/CrewHighlightJobAndSalary) | Makes the job and the salary of every crew entry (hired and unhired) stand out on the crew screens, and dims the rest. |
| [CrewPerfectSort](../../wiki/CrewPerfectSort) | Sorts the crew lists: at Enceladus Prime, the Hire screen by salary, then occupation, and Your Crew by occupation, then salary; in a dive, the crew a derelict's conversation offers to send over on EVA, as Your Crew. |
| [DealerNotifier](../../wiki/DealerNotifier) | Marks the Dealer entry of the Enceladus Prime menu when a ship you are waiting for comes up for sale, and that ship on the Dealer screen. You pick the ships with Shift+Click on Dealer. |
| [DiveDisableAdrenalineBooster](../../wiki/DiveDisableAdrenalineBooster) | The Adrenaline booster of your ship starts every dive switched off. |
| [DiveSkipTransit](../../wiki/DiveSkipTransit) | Skips a dive's cutscenes (the transit both ways, launch, astrogation, rescue, game over, the station's fade-in), charging the remass and in-game time they would have cost, or plays the transit faster without holding Space. Each skip has its own switch (Shift+Click Launch Ring Dive). |
| [DroneAltPriorities](../../wiki/DroneAltPriorities) | Changes which chunk the tug and haul nanodrones work on first: the most valuable, as set on a new tab of the OMS. |
| [GeologyByMass](../../wiki/GeologyByMass) | Judges the ore your geologist identifies by the mass of each mineral in it instead of its value, as set on a new tab of the OMS. |
| [HudHideLabels](../../wiki/HudHideLabels) | Hides the titles on the screens of the dive HUD. |
| [LidarLouderPing](../../wiki/LidarLouderPing) | The LIDAR's ping for sensor contacts plays louder, by as much as you set in the ship's Tuning. |
| [MarketAdvisor](../../wiki/MarketAdvisor) | Keeps the cash reserve you set, within a tolerance, by putting the rest of your cash in ore at the Mineral Market, with a Trade button that trades on the best days the price charts show, and marks the Mineral Market entry when a trade is due. You set it with Shift+Click on Mineral Market. |
| [ServiceNotifier](../../wiki/ServiceNotifier) | Marks the Services entry of the Enceladus Prime menu when a service you pick can be bought again: one with a cooldown, such as The Twins or Jameson's Insurance, or a compensation to a faction. You pick the services with Shift+Click on Services. |
| [ShipCopyPaste](../../wiki/ShipCopyPaste) | On the Fleet screen, copies one ship's setup onto the current ship when both are the same model: the equipment, bought at the Equipment screen's prices, the tuning, the mineral targeting and the crew aboard. |
| [ShipHighlightTypeAndPrice](../../wiki/ShipHighlightTypeAndPrice) | Makes the type of every ship in the Dealer and Fleet lists stand out, and hides the ship image behind each row. |
| [ShipSortByTypeAndPrice](../../wiki/ShipSortByTypeAndPrice) | Sorts the ship list on the Dealer screen by type, then by price (cheapest first). |
| [TransponderAltCodes](../../wiki/TransponderAltCodes) | New transponder codes say what carries them: a ship's series and model, and whether it is a ship's lifepod, its drones, an AI core or frozen crew. |

Where a mod opens its settings, or a screen of its own, with Shift+Click on a station menu entry or a button, a small
Shift badge beside it is the reminder. With a gamepad, the badge shows the two buttons to use instead: hold the first
and press the second on the highlighted entry or button.

The two arm mods work together or alone. Do not install `CrewPerfectSort` together with `CrewSortByJobAndSalary`, the
older mod it replaced: both sort the same lists. Nor `TransponderAltCodes` together with `AltTransponderCodes`, the
same mod under its old name: both would load.

## Mods that change how the game plays

These change how something works in a dive, compared to vanilla. Each one's wiki page says what, in short, as does the
*Warning* in its README.

- [ArmAltTargetSelection](../../wiki/ArmAltTargetSelection#changes-how-the-game-plays): which targets the arm takes, and which one first.
- [ArmAltPullBehavior](../../wiki/ArmAltPullBehavior#changes-how-the-game-plays): how the arm brings a chunk in and holds it, on ships with a
  grinder or an excavator.
- [DiveDisableAdrenalineBooster](../../wiki/DiveDisableAdrenalineBooster#changes-how-the-game-plays): the Adrenaline booster starts every
  dive switched off, which also damps the bullet time from the pilot and the smart camera.
- [DiveSkipTransit](../../wiki/DiveSkipTransit#changes-how-the-game-plays): a dive's cutscenes are skipped, with their remass and in-game
  time charged from the game's formulas (the switches marked in its settings affect remass); the burn away from the
  ring is an estimate. The transit, when played, can run faster than the game's own fast-forward, without sound.
- [DroneAltPriorities](../../wiki/DroneAltPriorities#changes-how-the-game-plays): with its switch on, the tug and haul drones work first
  on the chunks with the most valuable ore (haul drones also on those near the excavator), instead of the heaviest,
  fastest ones, and stay on a chunk until a much better one comes.
- [GeologyByMass](../../wiki/GeologyByMass#changes-how-the-game-plays): with its switch on, which chunks keep a full info box, and
  which ones the arm and the drones go for, depends on ore mass instead of value.
- [TransponderAltCodes](../../wiki/TransponderAltCodes#changes-how-the-game-plays): a ship's model shows in its
  transponder code, on the LIDAR and in the Pilot tab, before the ship is in sight.

Before reporting a bug in those parts of the game to the game's developers, check that it also happens without these
mods.

## Install
1. Download the zip of each mod you want from the [newest release](../../releases/latest), *All mods*, which holds the
   newest version of every mod.
2. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
3. Put the zips in it. Do not unzip them. A mod's newer zip has the same name as the older one, and replaces it. Keep
   only one zip of each mod there: they would all load. Zips from older releases have the version in their names:
   take those out.
4. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## For modders

How the code is laid out, how the game loads a mod and how these mods hook in, the conventions they follow and the
game's terms are in [MODDING.md](MODDING.md); how the game works behind those terms, in [GAME.md](GAME.md); the test
harness, in [`_tests/README.md`](_tests/README.md).

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the [GNU General Public License v3.0](LICENSE) (GNU GPLv3).

## Disclaimer
ΔV: Rings of Saturn is made and owned by Kodera Software. The game's name, and everything from the game this
repository uses or shows, belong to Kodera Software.

The author of these mods has no tie of any kind to the game or to Kodera Software. Kodera Software didn't
make, check or approve these mods, and doesn't support them.

Everything in this repository is provided as is, for free, and without warranty of any kind, express or implied: use
it at your own risk. The [GNU GPLv3](LICENSE) says so in full, in its sections 15 and 16.
