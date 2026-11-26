# TransponderAltCodes - ΔV: Rings of Saturn

New transponder codes say what carries them: a ship's code names its series and model, and the codes made from it say
whether it is that ship's lifepod, its drones, or frozen crew.

## Warning
This mod changes how the game plays, a little. Compared to vanilla:
- you can tell a ship's model before it is in sight: its code shows on the LIDAR's label once the LIDAR has swept it,
  and in the OMS's `Pilot` tab with its bearing and distance (the game's `hud/LIDAR.gd`, `hud/ShipList.gd`), and on
  the astrogator's marks within their range (`hud/ShipMark.gd`). Without the mod a code tells nothing about the ship,
  so you only know what it is once you see it. Pirates still broadcast no code.

Before reporting a bug with ship identification, the LIDAR or the Pilot tab to the game's developers, check that it
also happens without the mod.

## What it does and why
- **What:** the game makes every transponder code from a place of registry and four digits, at random. With the mod a
  new ship's code starts with a short code of its model instead (one per model, all of the same length), then a dash
  and a serial of `SERIAL_LENGTH` letters and digits from `SERIAL_CHARS` (without the letters that read like digits),
  enough for every ship of a model. Both come from the seed the game draws its code from, so a ship always gets the
  same code. Every ship gets one this way: the Dealer's stock, the ships met in a dive, the player's first ship (also
  the one the New Game Options screen offers).
- **What:** the objects whose code the game makes from a ship's get a suffix that says what they are:
  - a ship's lifepod: the ship's code and `LIFEPOD_SUFFIX`; a lifepod found floating: a random ship's code (drawn as
    the Dealer draws its used ships) and the same suffix. The pod keeps the name the game gives its ship's code.
  - the ATLAS drone's AI core: the drone's code and `AI_CORE_SUFFIX`.
  - frozen bodies: their beacon shows a random ship's code and `CREW_SUFFIX`, and each body adds its initials. The
    bodies around the destroyed habitat get the suffix after the habitat's code.
  - the drones a ship launches (THI Cargo and Monocargo Containers, the NT Mining Companion, the B8 Claim Beacon,
    also the story's claim beacons): the ship's code, a type from `DRONE_CODES`, a dash and the game's number.
- **What not:** codes already in a save stay as they are: the ships you own and those you sold, the ships the game
  remembers. The game makes a ship's name, its captain's name and what it remembers about the ship from its code, so
  changing a stored code would rename the ship and lose its history. Fixed codes (stations, habitats, beacons, named
  ships such as the Big Bad Wolf) stay too, since the story quotes some of them. Pirates still broadcast no code.
- **What:** the one exception, a ship the game meets again with a code it made before the mod was installed. Some
  events often or always bring back a ship met before, with its stored code (the miners in the rings, a rescue's
  MAD-CERF and derelict, a crew agenda's derelict, the ring races' racer and drone, the ATLAS drone, Vilcy's ships), so
  in an older save those would never show a mod code. The next time the game asks for such a ship, it gets a code of
  its model instead, once, always the same one for the same old code, and what the game keeps under the old code moves
  to it: its entry among the builds the game remembers, its name, its disposition and its encounter. Its captain's
  name, which the game makes from the code, changes. A sold ship's code is kept, since the Dealer may offer the ship
  again under it.
- **Why:** a code in the Pilot tab, on a LIDAR label or in comms says nothing about the ship in the game; with the
  mod it tells the model at a glance, and which pod, drone or body belongs to which ship.
- **Removing it:** the save loads as before. A code is plain text in the save, the mod stores nothing else there, and
  no game script reads a code's format, only whole codes. The game never makes a new code for something that has one
  (`Shipyard.gd` `createShipByConfig` keeps the config's `transponder`; `CurrentGame.gd` `validateState` only fills an
  empty one), so the ships that already have a mod code keep it, with their names: the player's ships, the ships sold,
  and the NPC ships the game remembers by build (`state.transponders`). New codes are the game's again (the Dealer's
  stock, made fresh each time, new NPC ships, lone lifepods, bodies), and a ship's drones get the game's type after
  the ship's code. Lifepods and bodies picked up are kept in the cargo by scene, not by code (`ship-ctrl.gd`
  `appendToCargo`). Installing the mod again changes none of the codes it made; a game code made meanwhile, on a ship
  met again, is replaced as above.

## For modders
- Script extension of `res://CurrentGame.gd`, the `CurrentGame` autoload, and of `res://menu/NewGamePlus.gd`, the
  New Game Options screen (`installScriptExtension` in `ModMain.gd`, in that order). The tag `group = Transponder` in
  `Mod.manifest` names what it changes.
- Installed in `ModMain`'s `_init`: the game's `ModLoader.gd` runs it while the engine creates its autoloads, and
  `CurrentGame` comes after `ModLoader` in the game's `project.godot`, so the engine creates the autoload from the
  extended script. Its throwaway instance is safe: `CurrentGame.gd` has no `_init` and no initializer that needs
  another autoload.
- Overrides, each calling the parent's except `getNewTransponder`:
  - `getNewTransponder(s)` makes the whole code from the seed's draws (`srai(s, 1 + SERIAL_LENGTH)`): the model's code
    (the model in `_tacModel`, or a ship of the game's `usedShipsPool` picked by the first draw, as the game picks its
    prefix), a dash, and one character of `SERIAL_CHARS` from each of the other draws. Each draw starts from the
    previous one's output, so neighbouring seeds give unrelated serials, and a seed always gives the same code (the
    Dealer's ships keep theirs from day to day). With no model given and an empty `usedShipsPool`, the game's code.
  - `getTransponder(new, config, sd)`, through which `Shipyard.gd` `createShipByConfig` codes every ship without one:
    sets `_tacModel` to `config.model` around the parent's call. A config's code comes back unchanged, and so does a
    code the save keeps for the ship's build (handed back only for a ship not new: `TheRing.gd` `oddityDigger`,
    `story/RescueOperation.gd`, `AgendaSpecificDerelict.gd`, `RingRace.gd`, `Vilcy.gd`), unless the game made it
    (`_tacIsGameCode`: one of the game's own `transponderFormats`, with `_TAC_GAME_DIGITS` digits in place of `%s`) and
    it isn't a sold ship's (the game's `getSoldTransponders`). Then `_tacRecode` codes the ship by `_tacModel` with the
    first of `_TAC_RECODE_TRIES` seeds from the old code (`hash(old) + i`) whose code isn't in
    `state.transponders.lookup` (with none free, the old code stays), and moves to the new code the old one's `lookup`
    entry and its place in `hashes` (so the next meeting gets it back), its name (`_tacKeepName`), its `dispositions`
    and `encounteredShips` entries, and its place in `justRequestedTransponders`. The player's ships never get there:
    their configs hold their codes.
  - `validateState()` (a save loaded) and `createPlayerShip()` (a new game): `_tacModel` set to `state.ship.model`
    around the parent's call, which gives the player's ship a code when it has none.
  - `_ready` (the game's runs first) connects the tree's `node_added` to `_tacNodeAdded`, which matches the new node's
    `get_script().resource_path` (kept by `take_over_path`, so other mods' extensions still match) and acts before the
    node's own `_ready`: a lifepod (`ship-ctrl.gd` with `specialName` `ODDITY_LIFEPOD`) and the AI core
    (`ODDITY_AICORE`) get their suffix, a lone lifepod a code first (so `ships/LifepodFeedback.gd` keeps it); the
    frozen bodies' beacon (scene `story/DeadTalkingBeacon.tscn`) and the bodies (`story/body.gd`) the crew suffix; a
    drone dock on a ship (`ships/modules/ClaimOwner.gd`) and the story's claim beacons (`story/ClaimBeacon-1.gd`,
    `ClaimBeaconForeign.gd`) a new `transponderFormat`. Each step leaves a code that already has its suffix, so a node
    added again isn't changed twice. The destroyed habitat's beacon gets its code later, from its dock, which isn't on
    a ship: it keeps the game's.
  - `NewGamePlusScreen.gd` overrides `rerollNames()`: `_tacModel` set to the model of `CurrentGame.initialShip` (the
    new game's ship) around the parent's call, through `set` and `get`.
- With CombatSimulator, which extends `CurrentGame.gd` too, from `_init` as well: by path the chain is game ←
  CombatSimulator ← TransponderAltCodes. They override different functions (CombatSimulator `giveXp`, `setStory`,
  `recordEncounter`, `setDestinationHighlight` and `addShip`), and their members differ (the `transponder` and
  `combat` suites of the repository's test harness load them together).
- New members, all prefixed `_tac`: `_tacModel`, `_tacModelCode`, `_tacIsGameCode`, `_tacRecode`, `_tacNodeAdded`,
  `_tacShipAdded`, `_tacAddSuffix`, `_tacKeepName` (the name a suffixed or re-coded object keeps: the old code's
  stored name, or the one the game makes from it), `_tacDockAdded`, and the constants of what it matches in the game
  (script paths, transponder formats, scene and `specialName`, the digits of the game's codes, the game's bail count
  for a free code), `_TAC_SHIP_SCRIPT`, `_TAC_BODY_SCRIPT`, `_TAC_DOCK_SCRIPT`, `_TAC_DOCK_FORMAT`,
  `_TAC_STORY_BEACON_SCRIPTS`, `_TAC_STORY_BEACON_FORMAT`, `_TAC_BODY_BEACON_SCENE`, `_TAC_LIFEPOD_NAME`,
  `_TAC_AI_CORE_NAME`, `_TAC_GAME_DIGITS` and `_TAC_RECODE_TRIES`.
- Constants (`Code.gd`) a player may edit inside the zip: `MODEL_CODES` (one code per model key of the game's
  `ships/Shipyard.gd`, all the same length), `MODEL_CODE_PAD` (fills the code of a model missing from the table, made
  from its key), `SERIAL_LENGTH` and `SERIAL_CHARS` (the serial), `LIFEPOD_SUFFIX`, `AI_CORE_SUFFIX`, `CREW_SUFFIX`
  and `DRONE_CODES` (the drone types, by the game's). The rest are the game's paths and formats.
- Tested in a headless Godot 3.6 (the harness's `transponder` suite) against the game's own `CurrentGame.gd`,
  `ship-ctrl.gd`, `body.gd`, `ClaimOwner.gd`, claim beacon scripts and `NewGamePlus.gd`; the suite also checks that
  every model of the game's Shipyard has its own code, that the serials use every character of `SERIAL_CHARS`, and
  what re-coding a ship met again moves, and which codes it keeps.
  Not checked in a real game yet.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Do not install it together with `AltTransponderCodes`, the mod it replaces (the same mod under its old name): both
would load.

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
