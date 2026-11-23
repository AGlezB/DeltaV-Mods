# LidarContactCallout - ΔV: Rings of Saturn

In a dive or a simulator, a crew member calls out each new LIDAR contact on the comms line, with its bearing and
distance, the way a sonar operator calls out what they hear.

## Warning
This mod changes how the game plays, a little. Compared to vanilla:
- you learn roughly where an object with no transponder is as soon as the LIDAR has seen it, before the astrogator
  marks it: pirate ships, pirate lifepods and pirate drones. With an astrogator aboard, that includes the oddities the
  astrogator can't mark at all (the Tesla, the Serenity torbernite crystal, the Singularity Core, the icosahedral ice
  crystal), which the game never points out: without the mod they are only returns on the LIDAR among the chunks.
- you get an approximate bearing and distance for a contact the OMS `Pilot` tab lists without them (a row the
  astrogator hasn't marked; the game's `hud/ShipList.gd`).

Before reporting a bug with the LIDAR, the Pilot tab or the comms line to the game's developers, check that it also
happens without the mod.

## What it does and why
- **What:** when the LIDAR finds something new, a crew member says so on the comms line, as the game's crew lines
  show: on the HUD, replacing the line there, and in the OMS's Comms log, with their face and "[Name, Occupation]".
  One line covers every case: `{New|Updated|Anomalous} contact, {identified <transponder>|UIO}, {approximate }bearing
  <bearing>, distance <distance>`, for example "New contact, identified SE1-1234, approximate bearing 251, distance
  4,000".
- **What is called out:** every new row of the OMS Pilot tab, except the ship's own drones; and every object with no
  transponder that the LIDAR has seen and the Pilot tab doesn't list: pirate ships before they are marked, pirate
  lifepods and drones, and the oddities (objects worth a reward of their own) the astrogator can't mark. A row is
  called out once while it stays (one the Pilot tab drops and finds again later is called out again), an object with
  no row once per dive. Bullets are oddities too, and are left out (`CALLOUT_IGNORED_ODDITIES`).
- **New, Updated or Anomalous:** New the first time. Updated when a contact first called out with approximate figures
  is marked by the astrogator, so its exact figures are known. Anomalous for an oddity the astrogator can't mark (in
  none of `CALLOUT_MARKABLE_GROUPS`): called out once, with approximate figures, never updated. Those are the Tesla,
  the Serenity torbernite crystal, the Singularity Core, the icosahedral ice crystal, and the AI core, the only one
  with a transponder (so it has a Pilot tab row).
- **Identified or UIO:** identified with its transponder when it broadcasts one; otherwise "UIO", the game's own text
  for that, as the Pilot tab shows it (shorter than "unidentified", and easier to tell apart at a glance).
- **Exact or approximate figures:** exact for a row the astrogator has marked: the Pilot tab's own bearing and
  distance. Otherwise approximate: those of a random point in a circle around the contact, whose radius is the
  contact's distance times `CALLOUT_ERROR_RADIUS` times (1 − the speaking astrogator's experience), the largest when
  no astrogator speaks. An approximate distance is rounded to `CALLOUT_DISTANCE_STEP`. Bearings show as three digits
  (`045`), distances in metres with the game's thousands separator.
- **Who speaks:** watching the LIDAR is the astrogator's job. With one aboard, an astrogator makes every callout (one
  at random among several), even one off duty, called to the bridge. Only with no astrogator aboard does anyone else
  with a job speak, at random; never a passenger. With nobody, nothing is said. Each report picks its speaker anew, as
  a ship going on alert calls whoever is on stand-by.
- **What needs an astrogator:** anyone can notice a contact, but only an astrogator can tell an anomalous object from
  the chunks around it. With no astrogator aboard, an anomalous object with no row is never called out, and the AI
  core is called out as a plain New contact.
- **When:** the callouts wait until no new one has come for `CALLOUT_SETTLE` seconds (but the first waits no longer
  than `CALLOUT_MAX_WAIT`), then go in one report: one callout alone, or several as a numbered list under "Lidar
  contact updates:". They hold during a cutscene or a conversation, and for `CALLOUT_AFTER_COMMS` seconds after the
  game's last comms line to the ship, so a callout doesn't replace a line still being read.
- **Where:** in a dive, in the station's simulator and in CombatSimulator's fights, on the player's ship only.
- **Why:** in a dive a new contact shows up in the Pilot tab with no notice at all, and objects with no transponder
  never do, so they are easy to miss. Figures for what the astrogator hasn't marked are approximate because exact
  ones would be a cheat: the game shows them only for marked rows. An approximate spot still tells you where to look,
  and a more experienced astrogator gives a closer one.
- The constants at the top of `LidarContactCallout/Code.gd` (`CALLOUT_SETTLE`, `CALLOUT_MAX_WAIT`,
  `CALLOUT_AFTER_COMMS`, `CALLOUT_IGNORED_ODDITIES`, `CALLOUT_MARKABLE_GROUPS`, `CALLOUT_ERROR_RADIUS`,
  `CALLOUT_DISTANCE_STEP` and `CALLOUT_UIO_FALLBACK`) may be edited inside the zip. The callouts' texts are in
  `LidarContactCallout/i18n/en.po`.

## For modders
- Script extension of `res://hud/Hud.gd` (`installScriptExtension` in `ModMain.gd`), the HUD of every ship and of the
  Tuning and Upgrades previews. The tag `group = Hud` in `Mod.manifest` names that game script.
- **Set-up.** The mod overrides `instance()`, where the game builds the OMS, calls the parent's first, then defers its
  set-up to the idle frame, as DroneAltPriorities and GeologyByMass add their OMS tabs (the HUD's `_ready` can call
  `instance()`). It sets up only on a player-controlled ship whose zone is in `_CALLOUT_ZONES`: `"rings"`, which
  `Game.gd` `_respawn_ship` sets before the ship's HUD is built, and `"sim"`, which the station's simulator
  (`enceladus/Simulator/SimulationLayer.gd` `startSimulation`) and CombatSimulator's arena set the same way. The
  previews' ships aren't player-controlled, and NPC ships' HUDs get nothing: no Timer, no connections. The set-up
  adds a physics-mode Timer (`_CALLOUT_TICK`) and a crew-spoken Conversation, and connects the ship's
  `identifiedShipsChanged` and `CurrentGame`'s `broadcast`.
- **The Pilot tab's rows** are the ship's `identifiedShips`, `[transponder, shipName, object, marked, flags]` by the
  object's hash (`ships/ship-ctrl.gd` `addIdentifiedShip`, `removeIdentifiedShip`, which emit
  `identifiedShipsChanged` when a row comes, goes or changes). The LIDAR adds a row for each object with a transponder
  it hits (`hud/LIDAR.gd` `_physics_process`); the astrogator's mark adds or marks one, also for an object with no
  transponder (`hud/ShipMark.gd` `scanTarget`, for the groups `hud/AutopilotOverlay.gd` `astrogatorTacticalMarkers`
  names inline). The Pilot tab (`hud/ShipList.gd`) leaves out the ship's `temporaryCargo` and shows bearing and
  distance only for a marked row. `_calloutContactsChanged` compares the rows with those it saw before: a new one is
  added as New (Anomalous for an oddity in none of `CALLOUT_MARKABLE_GROUPS`), a row first called out with
  approximate figures and now marked as Updated, and a row gone takes its waiting callout with it. Left out: objects
  freed or in `temporaryCargo`, and the ship's own drones, whose code is the ship's and a dash
  (`ships/modules/ClaimOwner.gd`; TransponderAltCodes keeps that form).
- **Objects with no row.** Every tick, `_calloutScan` walks the field's children (the ship's parent): an oddity
  (`CurrentGame.isOddity`, its `specialName` not in `CALLOUT_IGNORED_ODDITIES`) or a member of the `ships` group, with
  no transponder (no `getTransponder`, or an empty one) and no row, not gone (freed, queued for deletion, in
  `temporaryCargo`, `inCargoHold` or `dead`), which the LIDAR has seen (`LIDAR.gd` `hasSeen`, as
  `astrogatorTacticalMarkers` asks), is added once per object for the HUD's life. An anomalous one only while an
  astrogator is aboard (`CurrentGame.getCrewNumberWithRole`).
- **The report.** `_calloutTick` waits as *When* says above (`ship.cutscene`, `ship.talkingWith`, and the time of the
  last `broadcast` to the ship with a message), then `_calloutSpeak` drops the callouts whose object is gone or whose
  row went, picks the speaker (`_calloutSpeaker`: the crew of `CurrentGame.getCrew()` that `isCrewMemberActive`, that
  is hired and not on leave), turns an Anomalous callout into New when the speaker isn't an astrogator and it has a
  row (and drops it when it hasn't), and clears the waiting list whether anyone speaks or not.
- **The figures** (`_calloutValues`). A marked row's are the Pilot tab's
  (`hud/components/ShipOnOMSBearingDistance.gd` `compute`): the distance in metres rounded up, the bearing clockwise
  from the screen's up. Approximate ones add to the ship-to-contact vector a point of the circle, `radius *
  sqrt(randf())` from its centre at a random angle (the square root spreads the points evenly over the circle instead
  of crowding its centre); as a share of the distance, the bearing's error is the same angle at any distance and the
  circle never reaches the ship. The speaker's experience is the member's `experience`, 0 to 1, 0 for anyone but an
  astrogator. A New callout said with approximate figures is kept in `_calloutApprox` until its row is marked.
- **The UIO text** is the `placeholder` of the root of `hud/components/ShipOnOMSLabel.tscn`, what the Pilot tab shows
  for an empty transponder (`ShipOnOMSLabel.gd` `set_text`), read once from the scene's `SceneState` without
  instancing it, and passed through `tr()` as a Label would; `CALLOUT_UIO_FALLBACK` if it can't be read.
- **The line** is added as `hud/Hud.gd` `gotMessage` adds the game's: the HUD's `dialogDisplay` children freed, an
  instance of the HUD's `dialogLineNode` (`comms/MessageLine.tscn`) added there, fading, and another in the OMS's
  `dialogNode`, not fading, each with the ship as origin and target. Their `dialogConversation` is one
  `comms/ConversationPlayer.gd` node, a child of the HUD, with `agendaNPC` set and `cachedAgendaMember` set to the
  speaker before each report, so `comms/MessageLine.gd` `_ready` shows that member's face and "[Name, Occupation]".
  The callout's values go into the line's `dict` after it is added (its `_ready` fills `dict` from the game), then
  `translate()` formats the text. The mod doesn't emit the game's `broadcast`: that would cancel the reply buttons of
  an open conversation (`comms/PlayerReply.gd` `_heardBroadcast`).
- **The texts.** `i18n/en.po` holds `LIDARCONTACTCALLOUT_CONTACT` (the one line) and the parts it is filled from, and
  the list's heading and items. `ModMain.gd` loads it with `load()` and `TranslationServer.add_translation`, as the
  game loads its own `.po` files. English is Godot's fallback language, so every language shows it until it gets its
  own file. The mod loader's `addTranslationsFromCSV` is not used: it reads nothing from a mod's zip.
- **Stacking.** DroneAltPriorities and GeologyByMass extend `hud/Hud.gd` too, and override `instance()` as well, each
  calling the parent's first: by path the chain is game ← DroneAltPriorities ← GeologyByMass ← LidarContactCallout.
- Overrides `instance()` (calls the parent's). Members: the constants `CALLOUT_SETTLE`, `CALLOUT_MAX_WAIT`,
  `CALLOUT_AFTER_COMMS`, `CALLOUT_IGNORED_ODDITIES`, `CALLOUT_MARKABLE_GROUPS`, `CALLOUT_ERROR_RADIUS`,
  `CALLOUT_DISTANCE_STEP` and `CALLOUT_UIO_FALLBACK` (which a user may edit), `_CALLOUT_TICK`, `_CALLOUT_ZONES`,
  `_CALLOUT_ASTROGATOR`, `_CALLOUT_PASSENGER`, `_CALLOUT_UIO_SCENE`, `_CALLOUT_UIO_PROPERTY` and the text keys
  `_CALLOUT_CONTACT`, `_CALLOUT_IDENTIFIED`, `_CALLOUT_APPROXIMATE`, `_CALLOUT_LIST`, `_CALLOUT_LIST_ITEM`,
  `_CALLOUT_NEW`, `_CALLOUT_UPDATED` and `_CALLOUT_ANOMALOUS`; the variables `_calloutOn`, `_calloutTimer`,
  `_calloutConversation`, `_calloutUio`, `_calloutClock`, `_calloutLastComms`, `_calloutWaiting`,
  `_calloutWaitingKeys`, `_calloutRows`, `_calloutApprox` and `_calloutSighted`; the functions `_calloutSetup()`,
  `_calloutInZone()`, `_calloutReadUio()`, `_calloutHeard()`, `_calloutContactsChanged()`, `_calloutAdd()`,
  `_calloutRemove()`, `_calloutIsOwn()`, `_calloutIsOddity()`, `_calloutIsAnomalous()`, `_calloutHasNoTransponder()`,
  `_calloutIsGone()`, `_calloutScan()`, `_calloutTick()`, `_calloutSpeaker()`, `_calloutSpeak()`, `_calloutValues()`,
  `_calloutSay()` and `_calloutAddLine()`.
- Tested in the game's dives, and outside the game in a headless Godot 3.6 with the game's `Hud.gd`, comms line
  (`MessageLine.tscn`, `MessageLine.gd`), `ConversationPlayer.gd` and the Pilot tab's label and figures
  (`ShipOnOMSLabel.tscn`, `ShipOnOMSBearingDistance.gd`), and stubs of the ship, its LIDAR and the objects around
  it (the `callout` suite of the repository's test harness, also with DroneAltPriorities and GeologyByMass loaded).
  The real check is playing the game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).

## Disclaimer
ΔV: Rings of Saturn is made and owned by Kodera Software. The game's name, and everything from the game this mod uses
or shows, belong to Kodera Software.

The author of this mod has no tie of any kind to the game or to Kodera Software. Kodera Software didn't make,
check or approve this mod, and doesn't support it.

This mod is provided as is, for free, and without warranty of any kind, express or implied: use it at your own risk.
The GNU GPLv3 it is licensed under says so in full, in its sections 15 and 16.
