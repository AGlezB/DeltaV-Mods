<!-- This wiki is published from the _wiki folder of the repository (MODDING.md, The users' wiki): edit it there.
Changes made on the website are overwritten at the next publish. -->

**WARNING**: Mods might break or work in unexpected ways if another mod or a DLC touches the same parts or changes the
behavior of the base game functions the mod uses.

Mods for **ΔV: Rings of Saturn**. Each mod is a small add-on that changes one thing in the game.
Pick the ones you like: every mod works on its own.

These pages explain what each mod does, for players. The code, and the notes for people who make mods, are in the
[repository](https://github.com/AGlezB/DeltaV-Mods).

## The mods

### The arm

- [ArmAltTargetSelection](ArmAltTargetSelection): your arm only goes for chunks it can really reach, and picks the
  one that is easiest to bring in.
- [ArmAltPullBehavior](ArmAltPullBehavior): your arm brings each chunk into the grinder or excavator along a smooth
  curve, clear of the rotors, the claws and the hull, and holds it steady while you turn and thrust.

### Crew

- [CrewCheapHireNotifier](CrewCheapHireNotifier): the station menu tells you when someone cheap is for hire, and the
  Hire screen shows you who.
- [CrewHighlightJobAndSalary](CrewHighlightJobAndSalary): on the crew screens, each person's job and salary stand out.
- [CrewPerfectSort](CrewPerfectSort): sorts the crew lists: people for hire by salary, your crew by job, also when you
  pick who goes over to a derelict.

### Dives

- [DiveDisableAdrenalineBooster](DiveDisableAdrenalineBooster): your ship's Adrenaline booster starts every dive
  switched off.
- [DiveSkipTransit](DiveSkipTransit): skips the cutscenes of a dive, or plays the trip to and from the rings faster.
- [DroneAltPriorities](DroneAltPriorities): your tug and haul drones go for the most valuable chunks first.
- [GeologyByMass](GeologyByMass): your geologist, your arm and your drones judge chunks by how much of a mineral they
  hold, not by what they are worth.

### The HUD

- [HudHideLabels](HudHideLabels): hides the titles on the screens of your ship's HUD.
- [LidarLouderPing](LidarLouderPing): makes the LIDAR's ping louder, by as much as you choose.

### Money

- [MarketAdvisor](MarketAdvisor): a Trade button at the Mineral Market keeps the cash you want at hand and puts the
  rest in ore, and the station menu tells you when there is a trade to make.
- [ServiceNotifier](ServiceNotifier): the station menu tells you when a service you pick can be bought again, such as
  The Twins, a monthly service or paying off a side.

### Ships

- [CombatSimulator](CombatSimulator): try your ship in a fight at the station, against the enemy ships you pick,
  without risking it. Its page also explains every ship and weapon in a fight.
- [DealerNotifier](DealerNotifier): the station menu tells you when a ship you are waiting for is for sale, and the
  Dealer shows you which one.
- [ShipCopyPaste](ShipCopyPaste): copies one ship's setup onto another ship of the same model.
- [ShipHighlightTypeAndPrice](ShipHighlightTypeAndPrice): makes each ship's type stand out in the Dealer and Fleet
  lists.
- [ShipSortByTypeAndPrice](ShipSortByTypeAndPrice): sorts the Dealer's ships by type, then by price.
- [TransponderAltCodes](TransponderAltCodes): a ship's transponder code tells you its model, and the codes of its
  drones and other things tell you whose they are.

### Starting the game

- [BootSkipLogos](BootSkipLogos): the game opens straight on the title screen, without the logos first.

Some mods have settings, or a screen of their own, that you open by holding Shift and clicking a station menu entry or
the simulator's button: a small **Shift** tab beside it reminds you. With a gamepad, the tab shows the two buttons to
use instead: highlight the entry or the button, hold the first and press the second.

## Mods that change how the game plays

Most of these mods only change what you see on screen. These also change how something works in a dive:

- [ArmAltTargetSelection](ArmAltTargetSelection#changes-how-the-game-plays): which chunks the arm goes for, and which
  one first.
- [ArmAltPullBehavior](ArmAltPullBehavior#changes-how-the-game-plays): how the arm brings a chunk in and holds it.
- [DiveDisableAdrenalineBooster](DiveDisableAdrenalineBooster#changes-how-the-game-plays): the Adrenaline booster
  starts every dive switched off, and that also holds back bullet time.
- [DiveSkipTransit](DiveSkipTransit#changes-how-the-game-plays): the cutscenes are skipped, and what they would have
  cost is worked out instead.
- [DroneAltPriorities](DroneAltPriorities#changes-how-the-game-plays): which chunks your tug and haul drones work on
  first.
- [GeologyByMass](GeologyByMass#changes-how-the-game-plays): which chunks keep a full info box, and which ones the arm
  and the drones go for.
- [TransponderAltCodes](TransponderAltCodes#changes-how-the-game-plays): you can tell a ship's model from its code
  before you see it.

If something goes wrong in those parts of the game, try again without the mod before you report a bug to the game's
developers: the problem may be the mod's, not the game's.

## Installing mods

Each mod comes as a zip file. Download the zips of the mods you want from the
[newest release](https://github.com/AGlezB/DeltaV-Mods/releases/latest), named *All mods*: it holds the newest
version of every mod, at the bottom under *Assets*.

1. Find the game's folder: the one with `Delta-V.exe` in it.
2. In it, make a new folder named `mods`.
3. Put the zip of each mod you want in the `mods` folder. Don't unzip it. To update a mod, put its new zip there the
   same way: it has the same name as the old one, so it replaces it. Keep only one zip of each mod there: if there are
   two, both load. Zips you downloaded before may have the mod's version in their name: take those out.
4. Start the game with the option `--enable-mods`:
   - On Steam: right-click the game in your library, pick *Properties*, and type `--enable-mods` under *Launch
     Options*.
   - Anywhere else: make a shortcut to `Delta-V.exe`, open its *Properties*, and add ` --enable-mods` at the end of
     its *Target*. Start the game from that shortcut.

To remove a mod, take its zip out of the `mods` folder. To play without any mods, start the game without
`--enable-mods`.

Mods are unofficial: the game's developers didn't make them, and a game update can break them. **Keep a backup of
your save.** On Windows your save is the file `savegame.dv` in the folder `%APPDATA%\dV` (type that in the address
bar of File Explorer to open it).

## Disclaimer

ΔV: Rings of Saturn is made and owned by Kodera Software. The game's name, and everything from the game these pages
show (its screens, words and pictures), belong to Kodera Software.

The author of these mods has no tie of any kind to the game or to Kodera Software. Kodera Software didn't make,
check or approve these mods, and doesn't support them.

Everything in the [repository](https://github.com/AGlezB/DeltaV-Mods) (the mods, their code and these pages) is
given as is, for free, and without warranty of any kind: nobody promises that it works or that it suits any use, and
you use it at your own risk. The [GNU GPLv3](https://github.com/AGlezB/DeltaV-Mods/blob/main/LICENSE), the license
the mods come under, says this in full.
