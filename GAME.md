# ΔV: Rings of Saturn mods - how the game works

How the base game works behind the terms of [MODDING.md](MODDING.md)'s *Glossary*: formulas, figures, spawn rules and
what decides what, found in the decompiled game while making these mods. Each section is named as its Glossary entry,
which says what the term is, its key and where it lives in the game; *Section* names a section of this file, and every
other game term is in the Glossary. Like the rest of the docs, this file cites game behaviour with the game file and
function it comes from, checked in the newest decompiled game (MODDING.md *Folders outside the repo*), and quotes only
the base game's values, never a mod's constants (MODDING.md *Conventions*). A game update can change what it says.

## Adrenaline

Three things raise it: the Adrenaline booster; the smart camera (a display setting, `Settings.cfg.display.smartCamera`;
`ships/camera.gd`) when objects close in fast; and the pilot, when their Course anticipation
(`CREW_STATS_PILOT_ANTICIPATION`) foresees a collision (`ship-ctrl.gd` `handlePilotAdrenaline`). How slow time gets at
full adrenaline is the pilot's Adrenal slowdown (`CREW_STATS_PILOT_ADRENALINE`, `CurrentGame.getAdrenalSlowdown`), set
by their talent (see *Crew stats*).

## Antonoff Ore Purifier

It strips each chunk's water into remass (`remassEfficiency`), extracts no ore (`mineralEfficiency` 0) and never
removes a chunk (`removeChunks` false): chunks taken in stay in the hold. Its walls line the hold (the scene's root
polygon, part of the ship's collision).

## Arm

Values are the AR-1500's (`ships/modules/SalvageArm.tscn` over `DockingArm.tscn` and `DockingArm.gd`'s defaults); all
of it is `DockingArm.gd` `_physics_process`.

- The pull: the arm wants its target moving, relative to the dock slot (`areaDockSlot`, 33.75 m ahead of the arm base),
  towards the dock slot at `maxVelocity` (20 m/s), slowing down over the last `easeDistance` (10 m), plus, while the
  player feeds, `feed` times `feedVelocity` (28 m/s straight back along the direction the arm faces). The force is
  `max(thrust, mass × targetMassThrust)` (100 and 80) times the difference between that velocity and the target's, over
  `easeDistance`, at most `maxThrust`: about 0.8 per second of speed difference for any target over 1.25 t, a weak
  pull that acts only once the target lags, and overshoots the dock slot by several metres. Above `maxVelocity` of
  relative speed the force grows towards `fullThrust` (1000), reached at `maxVelocityConsidered` (100 m/s). Each frame's
  impulse is blended with the last (`response`, 0.8), costs energy (`powerDraw`, capped by the Tuning power limit) and
  wears the arm. The speeds are measured against the dock slot's own velocity, which a turning ship swings far faster
  than its nose.
- When it holds on: the arm is `locked`, and pulls, only while `dv` is 0. A target more than `maxDist` (35 m) from the
  dock slot makes it more than 0, sooner the faster the target moves relative to the dock slot (that speed's excess
  over `maxVelocity` adds to the distance's share of `conDist` − `maxDist`, 25 m), and so does one more than two arm
  lengths (45 m) from the arm base (`reachDv`). Then the arm lets go, and takes hold again once the target is back
  within both; a ship target's lock and release also play the lock sounds and set its AI. `hardLock` (off on the
  AR-1500) would pin a target within `distanceToHardLock` of the dock slot to it.

## Astrogation

- The trip: the ship first speeds up to the tab's travel velocity (`HUD_VELOCITY`), flown by the autopilot while Use
  autopilot (`HUD_ASTROGATION_AUTOPILOT_MATCH`) is on (`Game.gd` `initiateFastTravel`). Then it jumps to the
  destination, in-game time advances by the distance divided by that velocity, and the autopilot brakes the ship
  (`ship-ctrl.gd` `fastTravelTo`). A faster trip takes less time and more remass, for speeding up and braking. A
  destination too close can't be picked (`HINT_POI_TOO_CLOSE`). Enceladus (`DESTINATION_ENCELADUS`) is always
  listed: picking it leaves the ring, through the exit cutscene and the transit back.
- Destinations: kept per save in `CurrentGame.state.astrogation`, each with a deadline (`time`). A trackable one
  stays usable until the crew's Coordinate tracking time (see *Crew stats*) after its deadline
  (`getTimeLeftForDestination`, shown next to its name). Entering its spot again moves the deadline to that moment,
  plus the spot's own extra days (`story/Discovery.gd`, `discoverPoi`).
- Past that time a destination is lost: listed only with Show lost destinations (`HUD_ASTROGATION_SHOW_EXPIRED`),
  and a trip to it lands off target, by an error that grows to `expiredAstrogationPeakError` (18 km) over one more
  tracking time (`getDestinationUncertinty`). Destinations that aren't trackable (timed events) drop off the list
  at their deadline. Every in-game hour counts against them: transit, the dive itself, astrogation and the hours
  spent at the station.

## ATLAS

- Spawn: a random event of the rings (`AtlasRandom` in `story/TheRing.tscn`, a `story/RingRace.gd` with
  `racerModel = "ATLAS"`). It passes at any depth, with no roll and no chaos limit, so it spawns once every pass of
  the shuffled event list (see *Salvage*).
- The audit (`comms/conversation/AtlasConversation.tscn`): curious about the player's ship, it comes to talk once,
  asking for an AT audit (Artificial Threat, `DIALOG_ATLAS_WHATS_AT_SCAN_EXPLAIN`). Granting access ends it with a
  scan and one of three random closing lines, none of which has an effect ("Autopilot shackles upgraded",
  `DIALOG_ATLAS_SHACKLES_ADJUSTED`, changes nothing). Refusing, or not answering within the line's `timeout`
  (30 s), brings a threat (`DIALOG_ATLAS_AUTHORIZED_FORCE`). Refusing again, or not answering, makes it hostile
  (`DIALOG_ATLAS_PREPARE_FOR_AUDIT`, `changeHostility`): it closes in and fires its MWGs (`ship-ctrl.gd`, the AI's
  hunter mode). After the line's `noReplyTimeout` (20 s) it declares the scan complete and stops being hostile
  (`DIALOG_ATLAS_SCAN_COMPLETE`). An ATLAS that is already hostile when it starts talking skips straight to that
  forced audit.
- Crew agendas (see *EVA*): with the AI conspiracy theorist (`AGENDA_CONSPIRACY_AI_THEORIST`) in the dive crew, the
  player can ask for a human in charge; the agent recognises them and authorizes deadly force. With the android
  (`AGENDA_ANDROID`), they can answer for the ship (`AGENDA_ANDROID_ATLAS_PROTECTED`), and ATLAS lets it go. After
  an audit, the theorist complains (their morale drops by 0.2). If the android is there too and replies, the game
  grants the Short Circuit achievement (`ACHIEVEMENT_CREW_SHORTCIRCUT`).
- Destroyed, it leaves an AI core (`ships/drone/AICore.tscn`, the ship's `lifepod`). The core is an oddity: an
  object the station pays a fixed price for when it comes back as cargo (`CurrentGame.isOddity`, `specialPrice`),
  here 250,000 E$ (`ODDITY_AICORE`, "Quantum computer retrieval reward"). The drone itself has a transponder, so
  holding it with the arm never adds it to the fleet (`CurrentGame.isShipSalvageable`, see *Salvage claim*).

## Chaos

Random events of the rings need a minimum chaos where they spawn (each event's `chaosLimit` in `story/TheRing.tscn`;
see *Salvage*). The dive entry point's Environmental damages fee (`MAP_FEE_ENVIRONMENT`) grows with chaos × density
(`DiveTarget.gd` `getPrices`, `chaosPricePerChaos`), less the geologist's cut (see *Crew stats*), so of two spots of
the same density the dearer is the more chaotic. By depth, on the 1.93.1 map: under 0.35 in the first 10 km; from 10
to 600 km about 0.35–0.4 on average, 0.4 or more in 20–60 % of spots and 0.5 or more in under 10 %; deeper, 0.45–0.5
on average, 0.5 or more in 20–50 % of spots.

## Combat capacity

`getCombatCapacity` is the lowest status of the ship's systems, doubled and capped at 100 % (so 1 while every system
is at 50 % or more), less the share of its systems switched off, never below 0 (`getRealStatus`, cached and read again
about one call in ten). It is the status the ship's sensors report (`getStatus`, times 100), weights the AI's hate and
fear (`aiControl`) and how fast its fear fades (`erodeDispositions`), makes a damaged ship's autopilot careful
(`autopilotControl`), fills the bars of the HUD's ship marks (`hud/ShipMark.gd`), brings the station's EVA workers
(`faces/EVA.gd`, see *EVA*), and gates some combat events of the rings (see *Difficulty*).
## Control scheme

`Settings.controlScheme` reads the setting (`cfg.ui.controller`: 1 Keyboard + Mouse, 2 Gamepad), or with Auto (0) the
scheme `menu/Mouse.gd` last set: the gamepad when a stick or trigger of the gamepad in use is past 0.2 of its travel or
a gamepad is connected, keyboard and mouse when the mouse moves or the gamepad is disconnected. Buttons and keys alone
don't switch it. Every change emits `controlSchemeChaged`, and the control hints follow
(`hud/components/ContextSensitiveControlDisplay.gd`). With a gamepad (`project.godot`): the D-pad moves the focus, A
presses, B and Start close a screen (`ui_cancel`, `pause`), LB and RB switch tabs (`ui_page_up` / `ui_page_down`,
`menu/TabsWithGamepadControl.gd`), the right stick scrolls a list (`ui_scroll_up2` / `ui_scroll_down2`,
`enceladus/ScrollWithAnalog.gd`) and Back is the simulator's key (`jury_rig`). LT (`ship_excavator`) and X
(`ship_strafe_left`) are flight actions, with no use at the station. The game's tooltip node
(`menu/sfx/PlaySoundsOnTheseButtons.gd`) shows a control's tooltip on focus as on hover, so the D-pad shows what the
mouse does.

## Crew stats

Each occupation's two stats, one from talent (shown as Education, `CREW_EDUCATION`) and one from experience
(`CREW_EXPERIENCE`), as `CurrentGame.skillMatrix` pairs them:

| Occupation | From Education (talent) | From Experience |
|---|---|---|
| Pilot | Adrenal slowdown (`CREW_STATS_PILOT_ADRENALINE`) | Course anticipation (`CREW_STATS_PILOT_ANTICIPATION`) |
| Mechanic | Jury-rig efficiency (`CREW_STATS_MECHANIC_JURYRIG`) | Repair limit (`CREW_STATS_MECHANIC_FIX`) |
| Geologist | Price prediction accuracy (`CREW_STATS_GEOLOGIST_PREDICTION`), also the info boxes' estimation error | Mineral discovery range (`CREW_STATS_GEOLOGIST_RANGE`) |
| Astrogator | Tactical awareness range (`CREW_STATS_ASTROGATOR_RANGE`) | Coordinate tracking time (`CREW_STATS_ASTROGATOR_TIME`) |

A crew entry shows each of the two as one of four levels, by quarters of its value from 0 to 1 (`translateLevel`,
`talentLevels`, `experienceLevels`): below 0.25 Self-taught / No experience, below 0.5 Basic / Beginner, below 0.75
High / Journeyman, else Master / Expert (`CREW_EDUCATION_NO`, `_BASIC`, `_HIGH`, `_MASTER`; `CREW_EXPERIENCE_NO`,
`_BEGINNER`, `_JOURNEYMAN`, `_EXPERT`). The levels go by the member's own value, morale left out.

- The crew's value for an occupation is the best among the dive crew in it, not counting those on leave, raised by
  that member's good morale and lowered by bad (see *Morale*; `CurrentGame.getCrewStats`).
- Each occupation's talent and experience give one stat each, shown on Your Crew (`deriveStats`, `skillMatrix`).
  With no one of an occupation in the dive crew, its values are 0, and its stats still apply where 0 gives them a
  value.
  - Pilot. Adrenal slowdown (`CREW_STATS_PILOT_ADRENALINE`, from talent; see *Adrenaline*): game time at full
    adrenaline runs at 0.7 − 0.5 × talent of its normal speed, from 0.7 with no pilot to 0.2 (`getAdrenalSlowdown`,
    `BulletTimer.gd`); Your Crew shows it as the gain in the pilot's perception of time, 43 % to 400 %. Course
    anticipation (`CREW_STATS_PILOT_ANTICIPATION`, from experience): how far ahead, 4 s × experience, the pilot
    checks the ship's course for collisions; one foreseen raises adrenaline (`ship-ctrl.gd`
    `handlePilotAdrenaline`), so with no pilot only the other sources do.
  - Mechanic. Jury-rig efficiency (`CREW_STATS_MECHANIC_JURYRIG`, from talent; 25 % + 75 % × talent). Jury-rigging
    is the OMS Mechanic tab's slider on each kind of damage a piece of equipment can take, from -1 to 1; moving one
    moves the piece's others the opposite way by as much in total (`ship-ctrl.gd` `setSystemJuryRig`). A slider
    multiplies that kind's damage capacity by 1 + slider × efficiency, at least 0.1
    (`getCrewAdjustedJuryRigFactorForSystem`), and the damage counts against that capacity: at full efficiency the
    same damage counts half at 1 and ten times at -1. Repair limit (`CREW_STATS_MECHANIC_FIX`, from experience;
    71 % + 29 % × experience, at most 99.5 %; `getRepairLimit`): the Repairs screen offers Fix only for a piece
    whose condition is below it, and fixes it only up to it; past it, only Replace
    (`enceladus/SystemShipRepairUI.gd`). It counts the whole crew not on leave, not only the dive crew. How long a
    Fix takes depends on the number of mechanics, not on their stats (`getMechanicMultiplier`).
  - Geologist. Price prediction accuracy (`CREW_STATS_GEOLOGIST_PREDICTION`, from talent; 10 % + 80 % × talent). At
    the Mineral Market, the price forecast's error is (time ahead / 40 days)² / accuracy, and at 1 the forecast is
    noise (`getMineralPricePredictionError`, `enceladus/MineralPriceChart.gd`): about 13 days ahead at 10 %, 38 days
    at 90 %. In a dive, each chunk's info box (`hud/MineralMark.gd`: the box the HUD shows by a chunk, with the mass
    of each mineral in it and its value) gets one random error within ±(1 − accuracy), from ±90 % to ±10 %, on both
    the masses and the value, and the ship records the chunk with those figures (`addIdentifiedObject`). Mineral
    discovery range (`CREW_STATS_GEOLOGIST_RANGE`, from experience; 100 m + 1000 m × experience, 0 with no geologist
    in the dive crew): only chunks within it get an info box (`hud/AutopilotOverlay.gd` `geologistMineralMarkers`).
    It also sets how many past finds of each mineral the Geologist tab's mineral map keeps
    (`getMineralHistoryLength`, `hud/components/MineralMap.gd`; see *Geologist*).
  - Astrogator. Tactical awareness range (`CREW_STATS_ASTROGATOR_RANGE`, from talent; 500 m + 5000 m × talent, 0
    with no astrogator in the dive crew): ships, stations and other tactical objects within it that the LIDAR has
    seen get a marker with their transponder and name, the more likely the closer they are (a chance of
    (1 − distance / range)² at each check; `hud/AutopilotOverlay.gd` `astrogatorTacticalMarkers`,
    `hud/ShipMark.gd`). Coordinate tracking time (`CREW_STATS_ASTROGATOR_TIME`, from experience): how long trackable
    destinations stay usable, see *Astrogation*; the longer of 12 h and 90 days × experience.
  - Launch fees, on the dive entry point screen (`DiveTarget.gd` `getPrices`): the dive crew's astrogator talent
    cuts the Xaser pathway burn fee (`MAP_FEE_DEPTH`), and its geologist experience the Environmental damages fee
    (`MAP_FEE_ENVIRONMENT`), each by 99 % × the value.
- Salary: the occupation's base (`CurrentGame.baseSalary`: Pilot 1700, Mechanic 1500, Geologist 2400, Astrogator
  2100 E$) × (1 + bias + experience + 3 × talent)², the bias a random -0.5 to 0.5 per person
  (`getExpectedSalaryFrom`), so talent counts three times as much as experience. It is fixed when the person is
  offered, rounded up to 100 E$, and doesn't follow their growth; a raise request compares it with this figure
  (see *Morale*). Each candidate on the Hire screen gets talent and experience as a uniform random number squared
  (`randomizeAvailableCrewMember`), so most are low.
- Growth (`giveXp`): a step of size x first pulls a value towards the best member of the occupation by
  `mentorXpGain` (0.5 %) × x of the difference, then closes `normalXpGain` (0.25 %) × x of what is left to 1.
  - Talent: one step per in-game day, wherever the ship is, for the whole crew, aboard, at the station or on leave
    (`daysPassed` → `grantXpAtStation`, despite its name). Alone, a member's gap to 1 halves in about 277 days.
  - Experience, from events: everyone aboard, a step of 0.5 about once a minute while the ship flies faster than
    5 m/s outside a cutscene (`ship-ctrl.gd` `handleExperience`); the pilot, the more the longer the ship has flown
    on through foreseen collisions without hitting anything (`leafOnTheWind`, reset by every impact); the
    geologist, for each chunk identified, more for a valuable one (`hud/MineralMark.gd`); the astrogator, for each
    ship identified (`hud/ShipMark.gd`) and each destination revisited after its deadline, more the later
    (`discoverPoi`); every mechanic hired, for each repair at the station, by its hours (`SystemShipRepairUI.gd`).

## Cutscene

Each plays a title card on `Game.tscn`'s `TitleAnimPlayer`; the arrival's, `intro`, shows `CUTSCENE_RINGS_OF_SATURN`,
the transponder, the date and the transit tip (`codex/TransitTip.gd`). Holding `cutscene_ff` runs a cutscene at up to
3x speed (`Game.gd` `_process`, through `CurrentGame.targetTimeScale`), with VHS stripes over the screen while
`Engine.time_scale` is above 1 and post-processing is on (`FastForward.gd`). In the arrival, the ship comes in fast
towards the dive entry point and brakes to a crawl, turned to face into the rings (`Game.gd` `_ready` and `_process`:
`initialSpeed` from `desiredAcceleration` and `initialCutsceneTime`, braking for `totalCutsceneTime`; `Game.tscn` sets
the two times, `totalCutsceneTime` 16 s in game 1.93.1). The arrival, astrogation and the exit really fly the ship:
its thrusters and its reactor's turbine burn remass, and in-game time passes.

## Dealer

- The stock is stored nowhere: `CurrentGame.getShipsAvailableForSale` builds it anew on every call from the in-game
  day, the week and the save's `state.seed`. It holds a few models new every week (named in its code), one used ship a
  day kept 10 days (its model drawn from `CurrentGame.usedShipsPool`, by weight), and the ships the player sold
  (`state.soldShips`), for 10 days; ships the player owns are left out. The weekly models are TRTL, PROSPECTOR, EIME
  and AT225; all but the EIME are in the pool too, so the same model can be for sale new and used (game 1.93.1).
- An entry marks its ship NEW, a green ribbon on its picture (`SystemBuyUI.gd` `checkPrice`, the `NewMark` sprite,
  `enceladus/Dealer/new-marker.png`), when the ship isn't owned, is pristine (every system at 99 % or more) and is
  younger than a year (the in-game time less `madeTimestamp`). A ship under ten years old is always pristine
  (`CurrentGame.gd` `ageToDamageWithSeed` gives it no damage), so the age alone decides. The weekly ships are made at
  most a week old (`createShipInstanceWithCache`, kept for the week); a used one gets a random share of its pool entry's
  age (15 to 200 years; `Shipyard.gd` `createShipByConfig`, `madeTimestamp` never before the model's
  `startProductionYear`), so it is NEW only in the rare case that falls under a year. Its systems write their age
  damage into its config as they enter the tree, ahead of its setup, so the price its entry shows includes it
  (measured in game 1.93.1), and the damage stays with the ship once bought.
- Only `Dealer.gd` `doAddShips` asks for it: when the station loads, every in-game hour (`hourPassed`) and when the
  screen opens; a dive doesn't, and nothing signals a change.
- A ship's transponder is the same from one refresh, visit or save to the next (`getNewTransponder` is seeded), so it
  tells ships apart; `shipHashFromConfig` doesn't (it holds the moment the ship was instanced, `madeIn`).

## Density

The ring map's blue channel (`ring/ring-map.png`) is the mass to share out and its green channel the bias towards big
or small roids; `TheRing.gd` `getTargetDensityAt` turns them into a target per size class, capped by `maxDensity`, and
`AsteroidSpawner.gd` `spawnProperThings` fills each 1 km cell with ceil(target / `cellDensity`) roids of each class,
1.5 to 3 km ahead of the ship. A typical spot holds about 10 roids per km², the densest 28 (game 1.93.1), nearly all
small. Chunks come only from roids breaking (`asteroid.gd`): a roid of the smallest class gives one chunk, the bigger
classes 2, 6, 24 and 96 (`splitsTo` over the classes below it), fewer when a hit makes one skip a class
(`obliterating`), and none beyond 1.2 km of the player's ship (`CurrentGame.isInSimulatiorRange`).

## Derelict

Derelicts are abandoned ships with their reactor off, in the `helpless` faction: a random event of the rings
(`story/RescueOperation.gd` in `story/TheRing.tscn`, sometimes with a rescue ship nearby), one on a rescue ship's path
(`story/FlightForRescue.gd`), and the one a crew agenda spawns (`story/AgendaSpecificDerelict.gd`, see *Crew agendas*
under *EVA*). A derelict can't be hailed. It opens its conversation (`comms/conversation/DerelictConversation.tscn`)
by itself, once, when the player's ship comes within its `aiCuriosityDisance` (150 m; `ship-ctrl.gd` `AI.examine`).
Unless a rescue ship (faction `helper`) is in sight (then it's taken: see *Salvage claim*), a random member of the
dive crew reports it (`DIALOG_DERELICT_RANDOM.tscn`), and the player can send them over to restart it
(`DIALOG_DERELICT_GO_AND_BRING_IT`), an EVA (see *EVA*), or pick another member of the dive crew to go. Those come as
one reply each, `DIALOG_DERELICT_SWITCH_CREW|0` to `|11` (agenda `CREW/<n>`, the n-th of
`CurrentGame.getActiveMembers` through `getSpecificMemberNr`), without the one reporting it, in the order the crew was
hired: `getActiveMembers` walks `state.crew`, a dictionary in insertion order, which the save's `to_json` and
`parse_json` keep. The largest crew is 12 (the Antonoff-Titan K225), so the 12 replies always suffice. Who reports it
comes from the same list, by a hash of both ships' transponders (`getRandomMember`), so it is the same for a given
derelict and ship. CrewPerfectSort lists the replies as Your Crew. On board, they may get it running, and it joins
the player's fleet (`getThisShip`). Or they come back with nothing, or injured (leave days, `addAgendaLeaveTime`).
What they find varies (the `DIALOG_DERELICT_*` subtrees: brick, junk, solo dead, hole, ghost ship). The arm can also
hold one until the dive ends at the station. Which models are derelicts, where they come from and how often: see
*Salvage*.

## Difficulty

Peaceful keeps the combat events of the rings from spawning: Vilcy's and the pirates' (`story/Vilcy.gd`,
`story/PirateCombat.gd`), the pirate trap (`story/PirateTrap.gd`, which spawns a harmless lifepod instead), the Hybrid
(`story/HybridHunter.gd`) and hostile minefields (`story/Minefield.gd`), and also the G4A pirate at the huge rock
(`HugeRock.gd`) and the abductor of a derelict (`story/RescueOperation.gd`). Balanced lets them spawn only while the
player has a minimum of money and combat capacity (see *Combat capacity*); Challenging, always. The setting is copied
into the save (`CurrentGame.storeDifficulty`, on `settingsChanged`) and restored when it loads.
## Drones

A physics frame after the cradle enters the tree, it lets its drone go into the ship's parent (`ClaimOwner.gd`
`_ready`, unless the cradle has left the tree by then), so the drone outlives the ship's node: whoever takes a ship out
of a scene takes its drones out too (`Upgrades.gd`'s preview removes every rigid body; DealerNotifier frees each
picture's whole viewport). The drone's code is the cradle's `transponderFormat` filled with the ship's code and a
number from 10 to 98, drawn from a hash of the ship's code and the cradle's name (`consistentClaim`), so a ship's
drones get the same codes every time: `{ship}-CC{nr}` for the cargo containers, `-CS` for the NT Mining Companion,
`-CB` for the B8 Claim Beacon.

## EMP

Sources: the MWG microwave emitter (`SYSTEM_MWG`, `weapons/emp.gd`; the ONMWG-650 turret, `SYSTEM_PDMWG`, is built on
it), whose EMP is its draw × 0.9 × (1 − its Water Resonance tuning, `TUNE_EMP_RESONANCE`), up to about 61 MW; the SPC
Gungnir (`SYSTEM_SYNCHRO`, `weapons/synchrotron.gd`), a quarter of its charge in one frame; ring storms
(`story/RingStormManager.gd`: arcs that a storm beacon, `story/StormBeacon.tscn`, strikes between two objects, a weak
corona for a few seconds, then a discharge of up to 2 s); the Singularity Core, 5 MW on everything within 40 m (see
*Hybrid*); and, in one go, some conversation lines (`damageEmp`) and the derelicts as they spawn (`extraEmp` in
`RescueOperation.gd`, `AgendaSpecificDerelict.gd`).

- EMP shielding (in the Dealer's specs, "EMP shielding: 100 MW"; no key of its own): the ship's `empShield`, the
  larger of its scene's value and its config's `shielding.emp`. It comes with the hull: no equipment changes it.
  Each hit loses the shielding's MW over that frame (`empShield × 1000 × delta`; 1000 per second is 1 MW, the scale
  the MWG's Tuning shows), and only the rest gets through, so it stops continuous sources up to that power and
  barely touches one-frame ones. It applies per hit: two sources at once are each cut by the whole of it. The
  Hybrid has 500 MW (the config its random event gives it, see *Hybrid*); the Runasimi KR37 TNTRL 200 MW; the
  Cothon-212, the Cothon-211 "Chonker", the Cothon-217 "Bender" and the Antonoff-Titan K225 (modified) (the
  derelict of the sibling agenda, see *EVA*) 100 MW; the Cothon-213 "Triplet" and every other ship model none.
- What gets through (the `damageEMP` signal): Short Circuit (`DAMAGE_SHORT_CIRCUIT`) on the HUD, which falsifies its
  readouts and may reboot it on each hit, the likelier the more damaged (`hud/Hud.gd` `_on_emp`); Pump Failure
  (`DAMAGE_LASER_PUMP`) on the lasers (`weapons/laser.gd`: the CL-150, the CL-600P, the laser turret); and, near a
  fission reactor, an emergency shutdown (`Reactor.gd` `_on_emp`, with the EMP falling off with the square of the
  distance from the reactor): the reactor disengages instead of engaging while the EMP lasts, so the ship loses
  power. The EIME's fusion reactor ignores EMP (`FusionReactor.gd`). The hull's sparks and their crackle (`empLevel`)
  are only effects.

## Enceladus

On every arrival the station fades in (`Enceladus.tscn`'s `AnimationPlayer`, `FadeInCRT`), and its menu stays disabled
until the animation calls `disable(false)` on it, a few seconds in.

## EVA

In flight an EVA is only a suited sprite with a lamp (`ships/modules/EVAflight.tscn`, `EVAflight.gd`), which flies
between the player's ship and the ship the player is talking with when a conversation line sets `evaDirection`
(`comms/ConversationPlayer.gd` `execute`, over the line's `evaTime`; `ship-ctrl.gd` `handleEvaProgress`). -1 flies from
the player's ship to the other ship, 1 from the other ship to the player's. The sprite is decoration: the line's other
fields decide what happens. The player can't order an EVA. The base game shows one only in the cases below. The first
three are conversations during a dive, and in them the one who goes out is a member of the dive crew, so a captain
flying alone never gets them:

- **Derelicts** (see *Derelict*): the crew member the player sends over to restart one.
- **Crew agendas**: an agenda is a crew member's personal story (`AGENDA_*`, followed in
  `CurrentGame.state.agenda`). The member looking for their child (`AGENDA_LOOKING_FOR_CHILD`, a branch of the same
  derelict conversation) and the one looking for their sibling (`AGENDA_LOOKING_FOR_SIBLING`, a derelict spawned for
  it by `story/AgendaSpecificDerelict.gd`, which talks within 250 m: `AI.playDeadButTalk`) go over to the ship
  they were looking for.
- **Vilcy** (faction `vilcy`, bounty hunters): a Vilcy ship hails the player about an ex-pirate in the crew
  (`AGENDA_EX_PIRATE`, `comms/conversation/VilcyConversation.tscn`). Handing them over
  (`AGENDA_EX_PIRATE_TAKE_HIM`) fires them, with an EVA.
- **At the station**, outside any conversation: the dock in Enceladus's background shows up to five suited
  workers with flickering welding lights (`faces/EVA.tscn`, `faces/EVA.gd`; `EVA01`–`EVA05` in
  `enceladus/Enceladus.tscn`). Each one is there while the player's ship is in maintenance
  (`CurrentGame.isShipMaintained`: the in-game hours that fitting equipment and repairs take) or damaged past its
  `damageRequired` (`1 - getCombatCapacity()`). They are scenery, not crew.

## Excavator key

`project.godot` binds `ship_excavator` to Enter, the middle mouse button and the gamepad's LT (button 6); its tooltip
is `TOOLTIP_EXCAVATOR` ("Open excavator / Double-press to hold open", on two lines). `ship-ctrl.gd` sends it, and the
LT axis, as the command `x` to the systems that answer it (`fireMatching`); a double press holds it (`doubleTapCommand`,
`handleDoubleTap`). The excavators open (`Bay.gd`, `Beak.gd`, `SpringOperated.gd`, `Front Bumper.gd`); the grinder opens
its arms and spins its wheels (`Grinder.gd`; backwards for a negative power, which only the AI sends); docking clamps
answer it too, and so does the AR-1500 (`ships/modules/SalvageArm.tscn` `command`), which feeds its target in while
the key is held (`DockingArm.gd` `fire`, `feed`; see *Arm*). With the smart camera, holding it also changes the zoom
(`excavatorSpecialZoom`).
## Faction

A ship's `faction` reads `player` while the player flies it, `helpless` while it is helpless (out of remass or power,
`isHelpless`; derelicts are made in it) and no faction (`Factions.noFaction`) in a cargo hold (`_getFaction`);
`getRealFaction` gives `player` or the one stored.

- Dispositions: what one faction feels towards another, as five values, `fear`, `curiosity`, `hostility`, `greed`
  and `support` (`Factions.disposition` names sets of them: `hostile` is hostility 0.8 and curiosity 0.3; `curious`,
  `cautious`, `fear`, `want`, …). `defaultDispositionOf` gives each faction's: pirates are hostile towards the player
  and Vilcy, fear the military and want minerals; miners are curious about the player and fear pirates; the player
  is hostile towards pirates. A pair it doesn't list is `noInterest`, all 0.
- The save's adjustments (`factionDispositionAdjustment`, which is `CurrentGame.state.factions`, taken on every new
  game and load, `newGame`) add to the defaults, each value clamped to -1 to 1 (`getDispositionTowards`). A row a read
  doesn't find is created, all 0 (`getDispositionAdjustment`), so plain reads write into the save too. They come
  from hits (weapons and thruster exhaust call the hit ship's `ship-ctrl.gd` `applyHostility` with the attacker's
  faction: its faction gains hostility and fear towards the attacker's and loses support, by a share of the hit,
  `factor`, that shrinks with each further hit, `hostileDiminish`) and from taking a ship to the station with the arm
  (`hostilityHitWhenEncelading`); from a ship's own changes of disposition (`changeDisposition`, half of the change
  by default, `factionRation`), made by conversations (`changeFear`, `changeHostility`, `changeSupport` in
  `comms/ConversationPlayer.gd`) and trading at the habitats (`story/habitat/TradingHub.gd`); and from the Services
  screen's Local Vilcy Branch, The Miner's Guild and Obonto Habitats (`enceladus/ServiceUIFactionChange.gd`), which
  clear `vilcy`'s, `civilian`'s or `obonto`'s hostility and fear towards the player, for a price that grows with
  them. So the more pirates the player has hit, the more pirates fear them, and the sooner they flee.
- Frozen factions (`frozenFactions`: `player`, `helpless`, `ai.berserk`) ignore the adjustments: their dispositions
  are always the defaults, as is every faction's towards itself.
- Each AI ship adds its own on top (`aiGetDispositionTowardsFaction`): a personal variation, kept in the save by
  transponder (`state.dispositions`, taken as the ship is set up, `setDummy`), each value first drawn within
  ±`dispositionRandomVariation` (0.2), moved by hits (`applyHostility`) and by the hostility it sees done to others
  (`seenHostileAction`), and moving back towards 0 by 1 every 600 s (`Factions.timeForDispositionErosion`), while
  fear also drops by 1 every 300 s (`timeForFearErosion`) times the ship's combat capacity (see *Hybrid*), down to -1
  (`erodeDispositions`); a temporary disposition from conversations (`temporaryDisposition`); and, on the player's
  ship, the IFF the player sets for a target in the OMS Pilot tab (`setIff`, `iffWeight`).
- `factionIndependent` (`ship-ctrl.gd`): a ship whose hits don't change its faction's disposition
  (`applyHostility`, unless `includeIndependents`), which doesn't get to know a ship by overhearing it talk to one of
  its faction (`aiKnow`), and which, held as cargo, keeps its faction when a conversation converts the faction of
  what the ship holds (`convertFactionInCargo`). Set on the derelicts (`RescueOperation.gd`,
  `AgendaSpecificDerelict.gd`) and the ring's diggers (`TheRing.gd` `oddityDigger`).

## Fleet

Each owned ship keeps its own config: equipment, Tuning, mineral targeting, damage, cargo (`CurrentGame.state.ship`,
the others in `state.garage`), and a crew list (`preferredCrew`), which the game writes only when the crew changes
while that ship is flown (hiring, firing, who dives) and puts aboard when the player switches to it (`CurrentGame.gd`
`validateEmployment`); a ship without one keeps whoever is aboard.

- **Selling** a stored ship (`GARAGE_SELL`, `Dealer.gd` `sell`) pays its value (`ship-ctrl.gd` `getShipValue`) times
  `CurrentGame.shipSellMarkdown` (0.9 in game 1.93.1): the price its entry and the confirmation show (`SystemBuyUI.gd`
  `checkPrice`). Sell is disabled on the current ship and on a ship in maintenance (`canBeSold`). The Equipment screen,
  by contrast, takes the whole value of the piece it replaces off the new one's price (`Upgrades.gd`
  `updatePricesAndAvailability`).
- **The value** is the hull's price (each scene's `hullPrice`) over an age factor, plus each system's value for its
  condition (see *Repairs*), plus the slots the Equipment screen prices by their items (`Shipyard.gd`
  `getNumericValueOfConfig`).
- **Age** counts from the ship's build date (`madeTimestamp`). The age factor is 1 + log₂(1 + (age − 1) / 10), capped
  at 2: a hull loses half its value by 11 years, and no more after. Inside `ship-ctrl.gd` the build date is read
  without its getter, which keeps it after the model's `startProductionYear` (Godot 3 calls a getter only from
  outside the script), so the year an entry shows can be later than the age priced. Besides the hull's value, age
  decides only the damage a ship gets when the game makes it, the year an entry shows, and the Dealer's NEW ribbon (see
  *Dealer*).
- **An entry's ship** is a dummy whose list of systems is made once, at its setup, and never refreshed (`ship-ctrl.gd`
  `getSystems` refreshes only the player's and AI ships), and Sell prices by that list. A stored ship's damage doesn't
  change while it is stored, and its parts work out their condition from the saved damage before the list is made
  (thrusters and weapons queue it in their `_ready`, ahead of the ship's `setupShip`; the reactor and the HUD read it
  on demand), so the price is right: in game 1.93.1, measured on used ships made and aged as the Dealer makes them
  (ShotRenderer's `used` and `appraise` steps, `_shots/README.md`).

## Frozen bodies

Groups of 2 to 9 (`story/DeadBody.gd`, one of `story/body1.tscn`–`body10.tscn` each, on `story/body.gd`) drift around
a talking beacon (`story/DeadTalkingBeacon.tscn`), in chaotic parts of the rings or on any spot from 25 October to
1 November by the computer's clock (`canBeAt`); up to 19 more float around the destroyed habitat
(`story/habitat/DestoryedHabitat.gd`) until one is picked up. A body's transponder is its group's (one random code,
which the beacon shows bare) plus its initials (`body.gd` `getTransponder`); its name is a random crew name. Picking
one up gives the achievement `DISCOVER_FROZEN_BODY`.

## Geologist

The Geologist tab's mineral targeting (`hud/SystemMineralList.gd` `updateSystems`) has one row per system of the ship
with `mineralTargetting` (a hardpoint's through its `system`), named as the system:

- Columns: Minimum Albedo (`CARGO_UNKNOWN_ALBEDO`, in %), a switch for each mineral of `CurrentGame.mineralPrices`
  (H2O first, as that dictionary lists them), and Minimum value (`HUD_MIN_PRICE`, in E$). A system with `onlyMinerals`
  can switch on only `CurrentGame.traceMinerals` (not H2O), and its Minimum Albedo is disabled; its Minimum value is
  disabled too unless it has `oreValueFilter` on. Both are the same control (`hud/components/PriceLabel.gd`; the
  Minimum Albedo's scene, `PercentLabel.tscn`, only changes its format and range), which, disabled, hides its slider
  and its value, leaving the cell empty (`_setDisabled`).
- The list is a `GridContainer` (a container that lays its children out in a fixed number of columns, leaving out the
  hidden ones, so hiding a cell shifts every cell after it). Its first row is the header: an empty label, a
  `hud/components/MineralLabel.tscn` (a flat button that takes focus) for the Minimum Albedo and for each mineral,
  then one titled `HUD_MIN_PRICE`; each system's row follows, its name first. `updateSystems` builds every row anew,
  the old ones freed at the end of the frame (`queue_free`), on the ship's `systemsChanged` and `setup` signals.
- The rows: the HUD (`hud/Hud.gd`: `mineralTargetting`, `onlyMinerals` and `oreValueFilter` all on), the AR-1500 arm
  (`ships/modules/SalvageArm.tscn`: `mineralTargetting`, `pickupOnlyMineralTargets`), the MPI Tug and MLF Haul drone
  plants (`weapons/drone-plant.gd`; not the OME Maintenance drones, `weapons/drone-fix-plant.tscn`), the NT Mining
  Companion's cradle (`ships/modules/CargoScoopDock-R.tscn`, which `-L` instances) and the THI cargo containers' docks
  (`ships/modules/StorageContainerDock.tscn`, `StorageContainerDockMono.tscn`, with `onlyMinerals`).
- Each row is the system's `mineralConfig`, `{minerals, minValue, albedo}`, kept in the ship's config at
  `getSlotName("config")`: `hud.config` for the HUD, `weaponSlot.<slot>.config` for a hardpoint's system. A system
  without one makes it with every trace mineral switched on, 0 and 0 (`Hud.gd`, `DockingArm.gd` and `drone-plant.gd`
  `_ready`). So the game saves it with the ship, per row.
- The rule (`ships/ship-ctrl.gd` `isValidMineralTarget(object, config)`, which every system asks with its own row): a
  ship that isn't the player's passes only its AI target (anything, without AI); a row without `minerals` and
  `minValue` passes anything. An identified object (`identifiedObjects`, see below) is refused when its estimated
  value is below `minValue`, except that a value of 0 (the masses known, the value not yet) gets through when the
  object's LIDAR return reaches `albedo` (`lidarResponse` / 4, or 1/4 without one, against `albedo` / 100); then it
  passes when it holds a mineral switched on in `minerals`. An object not identified passes when its LIDAR return
  reaches `albedo`.
- Who asks: the HUD for its info boxes (`Hud.gd` `isValidMineralTarget`, which each `hud/MineralMark.gd` asks about
  once a second, `mineralConfigReexamine`; a "no" shrinks the box, `diminish`, hiding its kg list and price); the arm,
  for each body in its queue (`DockingArm.gd` `isValidTarget`, with `pickupOnlyMineralTargets`); the tug and haul
  plants, for each chunk in reach at each scan (`drone-plant.gd` `scanForTarget`; the USV-GOT recon drone's queue,
  `droneQueue`, comes first and isn't asked); the NT Mining Companion's AI, which wants the chunks passing its cradle's
  row more the more they are worth (`ship-ctrl.gd`, `aiHomeCradle`); and a ship's AI catching a chunk with its haul
  drones (`AI.catch`). The cargo containers' docks don't ask: their row picks which processed ore they take from the
  ship (`DockingArm.gd` `hasMineralEnabled`, in the transfer).

The Geologist tab's mineral map (`MineralMapVoronoi`, `hud/components/MineralMap.tscn`; no text of its own), under the
tab's LIDAR picture at the same scale, shows where the mineral picked in the tab's list has been found around the ship,
in that mineral's colour.

- Finds: each chunk that gets an info box (see *Crew stats*, Mineral discovery range) is recorded by the ship
  (`hud/MineralMark.gd` → `ship-ctrl.gd` `addIdentifiedObject`) twice, when the box shows the masses
  (`identifyMinerals`) and when it shows the value (`identifyValue`; both in its `PopIn` animation). It is kept as a
  live object at the chunk's current position while the box lasts (`identifiedObjects`, dropped with the box,
  `AutopilotOverlay.gd` `removeMineralMarker`), and as one past find per mineral in it, at the spot where it was
  recorded (`addMineralHistory`, `mineralHistory`). Each mineral keeps its latest `getMineralHistoryLength` finds,
  500 plus the Mineral discovery range in metres, the oldest overwritten first. The finds live on the ship's node, so
  every dive starts with none; a chunk whose box is dropped can get another and add its finds again. A find's mass is
  stored but unused: every find counts the same.
- Drawing (`MineralMap.gd` `_draw`, every frame while the tab shows), on a viewport of its own: a near-black background
  (`colorBg`, with a trace of red), a blue square for the ship, a square for each live object, green if it holds the
  picked mineral and red if not, and a smaller one for each past find, green for the picked mineral's and red for
  every other mineral's (where squares overlap, the last drawn covers the others). Positions are offsets from the
  ship, not turned with it; the map's shorter side reaches 3.6 km each way (`distance`, `distanceScale`). With no
  mineral picked (`mineralFocus` empty), every square is red.
- Areas (`shader/voronoi.shader` on the `Voronoi` ColorRect over that canvas, with `shader/voronoi.material`): none of
  the squares shows. The shader reads the canvas blurred (its mipmap level `sample`, 2.6) and paints each pixel
  `colorNo` (black) where red outweighs green, `colorYes` (a dark grey, 0.086) where green is at least as strong, and
  `colorEdge` (4, overbright) where that result differs from the next pixel to the right or below. The background's
  trace of red makes empty space count as red. Despite the name it isn't a Voronoi diagram: it is a blurred majority
  of the nearby squares, which merges them into areas that look like cells.
- Colour: `recolor()` sets the ColorRect's `modulate` to the picked mineral's colour
  (`CurrentGame.specificMineralColors`), so the map is black, with a faint fill of that colour where the mineral makes
  up most of the finds nearby and a bright outline around each such area. A mineral is picked by focusing its entry in
  the tab's list (`hud/SystemMineralList.gd` `focusOnMineral` → `mineralFocusChanged` →
  `_on_SystemMineralList_mineralFocusChanged`).

## Hardpoint

An inline hardpoint may be nested (the ND-LIS Kitsune's is `Front/WeaponSlot`). A placeholder of
`weapons/WeaponSlot.tscn` stores only the values it overrides (RA-TRTL's and the Vulture Prospector's main hardpoint
leaves `slot` to the scene's own, `main`). A hardpoint the config names nothing for gets its node's `default` when the
ship enters the tree: `SYSTEM_NONE`, nothing, on every model the dealer sells. The Equipment screen offers None on
every hardpoint, free, as its default (`enceladus/Upgrades/WeaponSlotUpgrade.tscn`).

## Hybrid

- Spawn: a random event of the rings, `HybridHunterHuntingPlayer` in `story/TheRing.tscn`
  (`story/HybridHunter.gd`), only where the chaos is above 0.3 (see *Chaos*). It never spawns on the Peaceful
  difficulty (`SETTINGS_DIFFICULTY_0`). On Balanced (`SETTINGS_DIFFICULTY_1`) it needs the player to have at least
  30,000 E$ and their ship's combat capacity to be at least 0.6. Combat capacity (`getCombatCapacity`,
  `getRealStatus`) is the condition of the ship's worst piece of equipment, doubled and capped at 1, less the share of
  its pieces switched off: 0.6 needs every piece at 30 % or better and none switched off. The event fits it with one
  MWG and 500 MW of EMP shielding, which stops any MWG's EMP (see *EMP*).
- Behaviour: its faction's disposition towards the player (`keepsecret` in `Factions.gd`) is mostly curious and
  partly hostile. It first comes close to look at the player's ship. A crew member with one of five agendas (see
  *EVA*) may remark on it (`comms/conversation/HybridEnconters.tscn`: `AGENDA_EX_PIRATE`, `AGENDA_LOOKING_FOR_CHILD`,
  `AGENDA_ANDROID`, `AGENDA_HAS_CAT`, `AGENDA_SINGER`; the android's line, `AGENDA_ANDROID_HYBRID_SHIP`, is "This
  doesn't match any signature I know of."). Once it has looked, it attacks with its MWG (`ship-ctrl.gd`, the AI's
  choice of action). It only fires while its hostility, scaled by its own combat capacity and by the distance, is
  above `aiHostilityToFire`, so a damaged one stops firing.
- Destroyed, it leaves its Singularity Core (`story/SingularityCore.tscn`, `story/SingularityCore.gd`; the ship's
  `lifepod`). The core is an oddity: an object the station pays a fixed price for when it comes back as cargo
  (`CurrentGame.isOddity`, `specialPrice`), here 1,000,000 E$ (`ODDITY_SINGULARITY_CORE`, "Research material").
  While the core floats loose, two gravity areas (`Attractor`, `Repellant`) pull objects in from a few hundred
  metres and push back those that come within 50 to 90 m. The core also puts out 5 MW of EMP (`empPerSecond`) on
  everything within 40 m (`EmpArea`), and plays the game's mystery music. In a cargo hold the pull and push stop,
  but the EMP doesn't (`setInCargoHold`). Taking it in gives the achievement A touch of Singularity
  (`ACHIEVEMENT_TOUCH_SINGULARITY`).
- The same core also floats free, among 2 to 9 iron chunks, in another random event of the rings, `Singularity`
  (`story/Singularity.gd`): only where the chaos is above 0.5 and no other event is within 2 km.
- The ship has a transponder, so holding it with the arm never adds it to the fleet (`CurrentGame.isShipSalvageable`,
  see *Salvage claim*).

## IFF

The slider goes from Friendly to Hostile (`labels`: 1 Friendly, 0 Auto, -1 Hostile; the slider's value is negated), one
per identified object (`hud/ShipList.gd`). It calls `ship.setIff(target, value)`, which keeps the value in the player's
ship's `iffData`, by the object's hash, in memory only: it is forgotten when the object stops being identified
(`removeIdentifiedShip`). The ship's AI adds it, times `iffWeight` (3), to its support for the object and takes it
from its hostility and fear (`aiGetDispositionTowards`); a turret fires only at ships whose hostility reaches its
`iffRequired` (`ships/modules/PDT.gd`). Auto changes nothing.

## Info box

`hud/AutopilotOverlay.gd` `geologistMineralMarkers` makes them, one pass per geologist every half second, for the
chunks within the geologist's range (Mineral discovery range, see *Crew stats*), at most 200. A box lists each mineral
of the chunk with its kg, from the chunk's composition with the geologist's error, and its value in E$
(`hud/MineralMark.gd`), revealed by its `PopIn` animation. It hides while the chunk is in the hold. It is reduced
(`diminish`: a 16 px square without the list and the value) while the HUD's row of the Geologist tab doesn't let the
chunk through (`Hud.gd` `isValidMineralTarget`, which asks `ship-ctrl.gd` `isValidMineralTarget`; see *Geologist*),
and full again (`undiminish`) once it does.
## Insurance

A new game starts with 100,000 E$ of it (`CurrentGame.gd` `initialState`), kept apart from the money
(`state.insurance`, `getInsurance`; `getMoney()` counts it only when asked, `includeInsurance`). Repairs pay from it
first: `enceladus/SystemShipRepairUI.gd` charges a fix or a replacement with `changeMoney(-price, true)`, which takes
what the insurance covers and the rest from the money. The Repairs screen's header shows it (Insured for,
`enceladus/Repairs.tscn`); the screens built on `enceladus/HeaderWithMoney.tscn` keep that row (`Insurence`) hidden.
Jameson's Insurance
(`SERVICE_JAMESON`, on `enceladus/ServiceUIInsurance.gd`) adds 100,000 E$ (`insuranceGain`) for 50,000 E$, at most
once every 720 hours (see *Services*).

## Lifepod

Every ship model has one but the Tsukuyomi, the racing drone and the Obonto habitat. Others float alone in the rings
(`story/LifepodIsFloating.gd`) or are a pirate's bait (`story/PirateTrap.gd`, `ships/LifepodTrap.tscn`); a lone one
gets a random transponder (`ships/LifepodFeedback.gd`). A pirate's own lifepod (`ships/LifepodPirate.tscn`) is a bounty
(`ODDITY_LIFEPOD_BOUNTY`). It talks to the ship that picks it up (`comms/conversation/LifepodConversation.tscn`,
`DIALOG_LIFEPOD_*`). The ATLAS drone leaves an AI core instead (`ships/drone/AICore.tscn`, `ODDITY_AICORE`, "Quantum
computer retrieval reward").

## MAD-CERF

The abductor comes from `makeAbductor` in `story/RescueOperation.gd` (a chance with a derelict, `pirateChance`, never
on the Peaceful difficulty) and in `story/Vilcy.gd`. It is of the `pirate` faction, with 15 t of ammunition and six
weapons asked for, of which it mounts four ERFMD-17 and two MWG: its scene has two hardpoints with the slot `right2`
and none with `left2`. Its six hardpoints are slots the Equipment screen has no entry for.

## Mineral Market

- **Prices**: a mineral's price per kg is its base price (`CurrentGame.mineralPrices`, in E$/kg: H2O 0.1, Be 20.5, Fe
  0.9, Pd 2.5, Pt 2.7, V 3.0, W 6.5) times an adjustment (`getMineralPriceAdjustmentAt`): 1, plus the average of 100
  sines (`priceTotals`) times 0.99 (`mineralPriceFluctuationsRange`), plus the player's influence (below). Each
  mineral's sines are drawn from the save's seed (`initializePrices`; `state.seed`, 0 in every new game, the one given
  on the New Game Options screen), with periods from about half a minute to a year and amplitudes that grow with the
  period: the slow ones make the price, the fast ones barely show. So the prices are the same in every game with the
  same seed, and set in advance for any date.
- **The day's price**: a slider row (`enceladus/MineralSellSlider.gd`) reads the price when the screen is built and on
  `dayPassed`, `employmentChanged` and `settingsChanged` (`updatePrices`), and every trade until then is at that
  price, buying or selling: there is no spread, and moving the slider doesn't change it. The player's influence is
  kept per day too (`playerInfluenceCache`, cleared on `dayPassed` by `invalidateFutureCache`).
- **Limits**: whole tonnes (`multiplier`, 1,000 kg); the kilograms after the dot stay. The station keeps no stock: the
  slider's maximum is the tonnes the money buys at the day's price plus the tonnes held, at most `maxOre` (10,000 t)
  per mineral (`_onMoneyUpdated`). A move trades the difference from the tonnes held, changes the money and logs the
  trade (`_on_HSlider_value_changed`, `LOG_EVENT_TRADE`).
- **The player's influence** (`getPlayerInfluenceMineralMarketAt`): the trades in the log over the last 180 days
  (`playerInfluenceLookbackDays`). The log merges a day's trades into one entry (`logEvent`), so a day's buying and
  selling of a mineral net out. An entry counts as its kilograms (bought positive, sold negative) times the base price
  over 2,000,000,000 (`playerInfluenceSaleDividor`), clamped to ±5, weighted by its age: nothing when new, the most at
  90 days, nothing again at 180 (1 − √|2 × age / 180 days − 1|). Their sum moves the adjustment, clamped from −1 to
  +0.1: buying raises the price months later, by up to a tenth of the base price, and selling lowers it. The sum of
  their sizes enlarges every sine (`playerMeddlingInfluenceFactor`), up to 81 times, those under an hour the most and
  those over 10 hours the least: the more ore traded, the jumpier the price for months.
- **The chart** (`enceladus/MineralPriceChart.gd`, as the slider row sets it): a point a day (`time`, 24 h), 672 points
  (`steps`), the last 4,608 hours of them (192 days, `lookAhead`) a forecast, the rest the past 480 days. A forecast
  point is the true price blended into the price at the mirrored time (−t, where every sine has the opposite sign) by
  the prediction error, `(Δt / 40 days)² / accuracy` (`CurrentGame.getMineralPricePredictionError`), where accuracy is
  the crew's Price prediction accuracy (see *Crew stats*): 0.1 without a geologist, up to 0.9 at the highest talent.
  Where the error reaches 1 (about 13 days ahead without a geologist, 38 at 0.9), the forecast shows the mirrored price
  alone, which says nothing about the true one; the band drawn around it (`spread`) grows with the error.
- **Time at the station**: the clock runs while the player is there, an in-game second per second
  (`enceladus/Enceladus.gd` `_physics_process`), and jumps with the services that take hours (see *Services*: a night
  at a hotel). Repairs and new equipment don't move it: they keep the ship in maintenance until a time
  (`CurrentGame.addShipMaintanenceTime`), before which it can't dive (see *Repairs*).

## Morale

The crew line-up at the station (`enceladus/CrewFaceOnEnceladus.gd`) shows a happy icon above `moraleLimit` (0.3) and a
sad one below minus that. The dive HUD's crew faces (`hud/CrewFaceOnDive.tscn`) hide both icons.

- Effect: the crew stats use the exponent `1 - morale` on the member's talent and experience (`getCrewStats`). At
  0.5 a talent of 0.5 counts as about 0.71, and at -0.5 as about 0.35. The Hire screen's comparison leaves morale
  out (`CrewBio.gd`). Some crew conversations need it inside a range (`maxAgendaMorale` / `minAgendaMorale`,
  `comms/ConversationPlayer.gd`). A crew member asks for a raise (`DIALOG_NEED_RAISE`) only when their morale is 0
  or less and their salary is below the market's (`getExpectedSalaryFrom`). If the player refuses and their morale
  is -0.4 or less, they quit and are fired on the spot (`DIALOG_RAISE_I_QUIT`).
- Drift: every in-game day, morale closes 5 % of the gap to a target (`erodeCrewMorale`, `moraleErodePerDay`), so it
  halves in about two weeks. For the dive crew, from launch to return (transits included), the target is the ship's
  `crewMoraleBonus`: the Eagle-Prospector-VP -0.3, the Eagle-Prospector-Lux 0.4, the OCP-209 0.3, other ships 0.
  Everywhere else the target is 0, except during a hotel stay.
- Changes: the station's Services screen (`Services.tscn`). A hotel stay sets the target to its `moraleStay` for the
  hours it lasts. Some services also add their `moraleChange` at the end to the crew not on leave: The Twins (a bar,
  4 h, once a day) adds 0.1. Moonview Capsule Hotel (24 h) sets the target to 0.2. The Underside Inn (168 h) sets it to
  0.2, then adds 0.1. SkyDome Resort (72 h) sets it to 0.3, then adds 0.15. Conversations also change morale
  (`adjustGlobalMorale` for the crew aboard, `adjustAgendaMorale` for one member). A round of drinks at a space bar
  (`DIALOG_SPACE_BAR_ROUND_OF_DRINKS`) gives everyone 0.2. Agenda events (see *Crew agendas* under *EVA*) give or take
  up to 0.5 from that member, and a refused raise takes 0.2. When the player can't pay a member's wages, which are due
  every 30 days, that member loses 0.05 every in-game hour at the station (`payWages`, called from `Enceladus.gd`).
  At 45 days past due (`baseCrewPatience`) they are fired.

## Nanodrones

- Picking (`scanForTarget`, every `scanEvery`: 1 s for tug, 2 s for haul, `weapons/WeaponSlot.tscn`): first the
  priority queue of the Obonto USV-GOT recon drone (`SYSTEM_RD_GUIDING`, the ship's `droneQueue`), then the
  pickable objects within the plant's reach (`DronePickupArea`, 400 m around it, and the Tuning range
  `TUNE_RANGE_MIN` / `TUNE_RANGE_MAX`) that pass the plant's own row of the Geologist tab (its `mineralConfig`,
  `weaponSlot.<slot>.config`; `ship-ctrl.gd` `isValidMineralTarget`) and that no other system of the ship has taken
  (the ship's target bus, `addSystemTarget` / `isValidSystemTarget`). Tug takes the one with the most
  `mass × speed²`, speed relative to the rings; haul the most `mass × |desired − velocity|² / distance`; both only
  above `minEnergyToTarget`. The bias meant to keep a plant on its target (`currentTargetBias`) never applies:
  `scanForTarget` clears `target` before reading it.
- Work (`_on_DroneLaunchManager_droneHit`): tug drones push the target against its velocity, to a stop relative to
  the rings. Haul drones push it towards the velocity `desiredVelicityFor` wants: towards a gathering spot ahead of
  the excavator (`haulGatherSpot`), slower inside the slow zone (`TUNE_SLOW_ZONE`), away from the hull inside the
  keep-away distance (`TUNE_RANGE_KEEP_AWAY`, from the ship's `haulMinDistance`), and into the excavator once lined
  up with it while it is open (`haulAccurancy`, `getPower() > 0.5`); a ship without an excavator (no "x" system)
  gets them pushing to a stop, as tug drones do. The push per second is `dronesPerSecond × droneTugPower`, so a
  light chunk changes speed faster.
- Flight (`weapons/drones/DroneLaunchManager.gd`): the drones reach the target about 2 × √(distance /
  `acceleration`) after launch, 1.4 s at 100 m and 2.8 s at 400 m, and a plant that changes target throws away the
  drones in flight (`_setTargetNode`).
- Maintenance drones fix the most damaged system of the ship, or of a friendly ship within reach, up to
  `repairLimit`.

## Notification panel

- Each notice is a 4 s animation of the panel's `AnimationPlayer` (`achievement/Notifications.tscn`: `acquired`,
  `lost`, `inTransit`, `level`, `gone`, `achieved`, `achieved-rare`, `poi`, `establish`, `updated`, `money`), played in
  real time whatever the time scale (`Notifications.gd` `_process`: `playback_speed = 1 / Engine.time_scale`).
- Its handlers, connected in `_ready`, fill in the notice's labels and play it, first waiting for the one playing to
  end (`yield(animation, "animation_finished")`): `_newShip` (`CurrentGame.newShip`, *Acquired*), `_lostShip`
  (`lostShip`, *Catastrophic Craft Failure*), `_transit` (`transit`, *Interlunar Transit Confirmed*), `_levelUp`
  (`levelUp`), `_gone` (`crewGone` and `crewInactive`) and `_achieve` (`Achivements.achivedOffline`, *Achievement
  Unlocked*; none in a game's first `staleAchievementTime` seconds). `_onPoiFound` (`poiDiscovered`) and the money's
  (`moneyChangedBy`, summed up while it shows) queue theirs on the player instead.
- In *Acquired*, the title fades in over the first 0.6 s, and the ship's name from 0.7 s, brightest at 1.3 s.
- The ring scene's panel is in `BulletTimer.tscn` (`NotificationsLayer`). The station's, in `enceladus/Enceladus.tscn`
  (`NotificationLayer`), shows no money notice (`suppresMoney`): the station shows the money itself.
- Leaving the ring brings notices. `ship-ctrl.gd` `escapeTheRing` (the exit) and `Game.gd` `sendHelp` (the rescue)
  let every ship and drone take its leave (`handleExitToEnceladus`): the player's drones send their cargo on
  (`claimCargo` emits `transit`), and the player's ship, unless helpless, salvages the ship the arm holds
  (`CurrentGame.addShip` emits `newShip`; see *Salvage*). Both cutscenes end in `Game.gd` `goToEnceladus`, which loads
  the station and drops the ring scene's panel with whatever it still had to show.

## Physics rate

With Dynamic Temporal Simulation Simplification on, `Settings.gd` `_process` moves the rate once a second towards the
real frame rate, never below 30. What counts physics frames changes with it: a mass driver pushes its slug frame by
frame for `timeFire` (`weapons/massdriver.gd`), so at 30 its slugs carry more energy; a pulse laser fires at most one
pulse a step; the per-hit floors of roids (`asteroid.gd` `applyKineticDamage`, `hardness`) and reactors (`Reactor.gd`
`_on_impact`, `damageLeakThreshold`) scale with the step. Godot 3 seems to work the step's length out in 32 bits,
which puts 1/60 s a hair over (CombatSimulator's wiki page relies on it for a few figures; not measured).

## Point Defence Turret

Each targets hostile ships in its `DefendArea` and roids in its `RockArea`, but nothing of `massLimit` or less, so never
a chunk (`_on_DefendArea_body_entered`), taking the one with the lowest score of angle, distance and threat (the
NDPT-4205's weights are Tuning settings, `TUNE_WEIGHT_*`), turning at `rotationPerSecond`. Tuning: the ONMWG-650's
Power (`TUNE_EMP_POWER`, more damage and a wider beam) and Water resonance (`TUNE_EMP_RESONANCE`, the share of its
output that heats roids); the NDPT-4205's mass driver power (`TUNE_MASSDRIVER_POWER`, faster and harder bullets). A hit
that carries a roid well past its threshold makes it skip a size class (`asteroid.gd` `obliterating`), so its chunks
come straight from a heavier roid and fly faster: the ONMWG-650's beam never overshoots, the NDPT-4205's bullets do
from just above its lowest power (measured by the drone bench, `_bench\README.md`). On the Antonoff-Titan K225's middle
hardpoints the ONMWG-650s are turned 60° outward (`weapons/WeaponSlot.tscn` `SYSTEM_PDMWG-L` / `-R`), and their rock
areas leave a strip straight ahead that neither covers.

## Random event

The playlist is every child of `story/TheRing.tscn` that has both a `makeAt` and a `canBeAt`, shuffled at the start of
each round and gone through in order (`TheRing.gd` `getNextOnPlaylist`). `AsteroidSpawner.gd` `spawnProperThings` asks
`getOddityAt` about one spot ahead of the ship at a time, and fills the spot with roids when it gets nothing. It
returns, in this order:

1. nothing, for a second after something spawned (`respawnCounter`);
2. a spawn something asked for (`requestOdditySpawn`);
3. the event of a point of interest the ship has come to (`CurrentGame.getEventNear`), whatever its `canBeAt`;
4. another try at an event that didn't spawn;
5. once `oddityCounter` is past `odditiesEvery` (450 in `Game.tscn`; 600 is the script's own) and the spot is deeper
   than the edge limit, the first event of the playlist whose `canBeAt` holds there and which isn't already near;
6. else, short of the edge limit, a digger (a K37 TNTRL, or one time in ten an Eagle Prospector) every `diggerEvery`
   (45 in `Game.tscn`).

`oddityCounter` counts in-game seconds while the tutorial's basics are done and the ship isn't in a cutscene or
astrogating away, and starts again at a time jump and whenever an event or a digger enters the scene: it runs for the
whole ring, not per spot. The edge limit is 4 km deep at the start of a game and shrinks to nothing over 300 days.
Most events need chaos above their `chaosLimit` at the spot (see *Chaos*), and some also a story, a point of interest
not yet known, no other of the same nearby, money, combat capacity or a difficulty (see *Difficulty*). The frozen
bodies and two Halloween events (`story/TimedEvent.gd`) are always eligible on a few dates of the real-world calendar
around Halloween (`times`, read with `OS.get_date()`). A test meant to keep events away while two ships are near
(`suppressEventIfShips`) compares `testSpecificStoryElement` with `""`, but `Game.tscn` leaves it null, so it never
passes (read in the code, not tried in the game).
## Reactor

The reactor engages and disengages by itself to hold its target temperature, a Tuning setting
(`TUNE_TARGET_TEMPERATURE`). Its damage is listed in the Mechanic tab (`hud/SystemList.gd`): Fuel rods jammed
(`DAMAGE_RODS`, from hard accelerations: slower to engage and disengage, and the temperature swings), Reactor leak
(`DAMAGE_LEAK`) and Turbine Galling (`DAMAGE_TURBINE`, from overheating: the turbine needs more heat to make power). If
the reactor stays above its meltdown temperature for a few seconds (`telegraphTimeLimit`, with a growing glow as
warning), it explodes and the ship is lost. For the player's ship, that is game over. The EIME's fusion reactor has
other kinds of damage (coils, coolant, lasers) and no leak.

## Reactor leak

The leak comes from the impact's power divided by the distance squared, counted above a threshold (`Reactor.gd`
`_on_impact`). The spot that was hit becomes a leak point. Used ships start with some leak damage (`ageIfNeeded`). Past
a quarter of its capacity (`damageLeakOffset`), the leak vents remass at random moments. It vents more often the worse
the leak, and more remass the hotter the reactor; it doesn't vent while the reactor is below `leakTemperature`. Each
vent wastes remass, cools the reactor and pushes the ship from the leak point. The leak also lowers the meltdown
temperature (`meltdownTemperature - jamTemperatureAdj * leak`), so an overheating reactor explodes sooner. Leaks matter
most in combat: they are the only way to disable an enemy ship so it can be captured, because a ship that runs out of
remass stops working.

## Repairs

Replace costs the piece's `repairReplacementPrice` less what it is still worth, in `repairReplacementTime` hours; Fix
costs `repairFixPrice` per step, in `repairFixTime` hours shortened by the crew's mechanics. The hours are the ship's
maintenance, a time stored in that ship's own config (`maintaineceUntil`, `CurrentGame.isShipMaintained`); fitting
equipment adds to it only when the piece replaced was damaged (`ship-ctrl.gd` `getSlotTime`). A ship in maintenance
can't dive (`Enceladus.gd` `shipPassesInspection`; the pre-flight inspection offers a hotel stay until it is done) or be
sold, but the player can switch to another ship of the fleet, while the first one's maintenance runs on.

- **A piece's value** is its `repairReplacementPrice` × (condition / 100)², × 0.8 below 100 % (`ship-ctrl.gd`
  `getSystemPrice`), and its condition is 100 less its worst damage, as a share of that damage's capacity (each
  system's `getStatus`). Replace costs that price less the value (`SystemShipRepairUI.gd` `replacementPrice`), so it
  adds to the ship's value exactly what it costs.
- **Fix** halves every damage of the piece (`doFixSystem`, `repairStepAmount`): each click takes half of what is left,
  at the full `repairFixPrice` again, paid from the insurance first (`changeMoney(-price, true)`, see *Insurance*). A
  click adds the most value when the worst damage is near 2/3 of its capacity. Its hours are `repairFixTime` ×
  2 / (1 + N), N being the mechanics in the dive crew (`getMechanicMultiplier`): one mechanic leaves them as they are,
  none doubles them.
- **Fix is enabled** only while the piece is under the crew's Repair limit (`isFixable`, `getRepairLimit(true)`, see
  *Crew stats*), none of its damages is past 1.5 times its capacity (`isFubar`, `maxDamageThatCanBeFixed`: then it can
  only be replaced), and replacing would cost more than one click (`shouldBeFixed`).
- **Each Fix or Replace** gives the mechanics a quarter of its `repairFixTime` or `repairReplacementTime` as XP
  (`giveXp`), two Logs entries (`LOG_EVENT_REPAIR`, the second with the piece's name and price) and an achievement
  (`FIX_PART`, `REPLACE_PART`).

## Rescue

The ship is helpless when it is out of remass (or with no capacitor, `ship-ctrl.gd` `isHelpless`) for longer than
`helplessTimeLimit`, outside a cutscene (`Game.gd` `_process`). The game switches the reactor off, claims the cargo and
plays the `helpless` cutscene: `sendHelp` advances the clock by a random stranded time (up to `strandedTIme`, two weeks)
and spawns a MAD-CERF of the `helper` faction near the ship (the ship counts as `helpless`, so the MAD-CERF goes for it
as it does for a derelict, see *Salvage claim*; this changes nothing), and `goToEnceladus` ends the dive at the
station. The transit back isn't charged.

## Roid

Five size classes, from 4096 t down to 16 t, each a quarter of the one above, every roid spawned at 0.75 to 1.25 times
its class's mass (`AsteroidSpawner.gd`). Its damage adds up for good (`totalEnergy`): kinetic hits less a floor per hit
(`hardness`, scaled with the physics step, see *Physics rate*), heat at `energyDamageScale`; EMP does nothing to it.
Once past `splitEnergyThreshold` (`baseEnergyThreshold` times its mass) it splits into two roids of the next class, the
smallest class into chunks; for each further doubling the damage went past, it skips a class (`obliterating`), so its
pieces hold half the ore each time (see *Density*).

## Salvage

Derelicts come from:

- **Random events of the rings** (`story/TheRing.tscn`, `TheRing.gd` `getOddityAt`, asked by the asteroid field for
  a spot near the ship). The ring scene spawns one only after 600 in-game seconds of flight since the last
  (`odditiesEvery`; astrogation restarts the count, cutscenes don't count), once the basic tutorial is done, while
  no other ship is around (`suppressEventIfShips`), and deeper than the edge limit (4 km at the start of a game,
  shrinking to 0 over 300 in-game days; shallower, only miners come). The events, about a hundred, are walked in a
  shuffled order, each tested once per pass, and the first that passes spawns. A derelict's event passes with a
  chance of base × (1 − cash / ceiling), at least 10 %, where cash is the E$ in hand (`CurrentGame.getMoney()`,
  without insurance), and only where the chaos (see *Chaos*) is at least its limit (`story/RescueOperation.gd`
  `canBeAt`). Base, ceiling and chaos limit, by series, with the names the game shows:
  - TNTRL: K37 TNTRL (80 %, 5 million E$, 0.2); KX37 TNTRL, Runasimi KR37 TNTRL, KTA24 TNTRL and K44 MHFTR
    Prototype (40 %, 5 million E$, 0.2 each). Two more K37 TNTRLs come with a rescue ship (see *Salvage claim*):
    one beside it (`RescueOperation`: 100 %, 10 million E$, any chaos), and one on a lone rescue ship's path
    3 minutes after it spawns, if it is still there (`story/FlightForRescue.gd`, always). The rescue ship is often
    in sight when the derelict talks, and then only the arm can take it.
  - Eagle Prospector: Eagle Prospector (100 %, 10 million E$, 0.4); Peacock Prospector, Vulture Prospector (the
    VP, `ships/Eagle-Prospector-VP.tscn`) and Pelican Prospector (50 %, 10 million E$, 0.4 each).
  - Cothon: Cothon-212 (80 %, 10 million E$, 0.3); Cothon-211 "Chonker", Cothon-213 "Triplet" and Cothon-217
    "Bender" (40 %, 10 million E$, 0.3 each).
  - Antonoff-Titan K225 and Eon Interstellar Model E, the EIME (50 %, 2 million E$, 0.5 each); Antonoff-Titan
    K225-BB, ND-LIS Kitsune and OCP-209 (30 %, 2 million E$, 0.5 each).

  The derelict is a random used build of its model (`ships/Shipyard.gd` `createShipBuildByName`), so its equipment
  varies, with its reactor off, no remass and, from these events, a random kinetic and EMP hit
  (`applyExtraDamage`).
- **Scrapwright Recovery Operations** (`SERVICE_SALVAGE_LICENCE`, SRO): a subscription on the station's Services
  screen, 300,000 E$ for 30 days (`enceladus/Services.tscn`). While it lasts, three more random events (`SalvageCall`,
  wherever the chaos is above 0) spawn a beacon whose broadcast (`comms/conversation/SalvageBanter.tscn`) lists two
  derelicts, sometimes three, as destinations (see *Astrogation*) 100 to 1,600 km away, for 24 h. Each listing is one
  of 50 lines of equal weight, three per model above (two for the K225-BB, none for the K44 MHFTR), offered only if
  that model's event passes its test at one of three random spots. At the spot, the derelict then spawns without a
  further roll.
- **Conversations** that reveal a destination, where the derelict spawns without a roll: crew chatter
  (`DIALOG_POI_RANDOM_2`: a K37 TNTRL 10 to 100 km away); a rescue ship asked "Seen anything worth salvaging?"
  (`DIALOG_HELPER_SALVAGE_ANY`, one of its four answers: a K37 TNTRL 25 km away, offered only if its event passes
  there); the same answer to a member looking for their child who asks a rescue ship for clues (see *EVA*); and
  pirates friendly enough to talk business (`DIALOG_PIRATE_BUSINESS_SHIP_*`: a K37 TNTRL, a Cothon-212 or an Eagle
  Prospector about 500 km deeper, for 200,000 E$, kept for 7 days). The sibling's ship (see *EVA*), an
  Antonoff-Titan K225 (modified) with full remass and no extra damage, comes only that way
  (`story/AgendaSpecificDerelict.gd`).

## Salvage claim

What decides who gets a derelict:

- **The rescue ship**: a MAD-CERF of the `helper` faction, spawned with the derelict (`story/RescueOperation.gd`) or
  before it, the derelict then appearing on its path after `time` (`story/FlightForRescue.gd`). It goes for
  `helpless` ships. A powerless one (`powerBalance` at or below 0, as a derelict is with its reactor off and no
  remass) it docks with its clamps (`SYSTEM_DOCKING_CLAMPS`; `ship-ctrl.gd` `AI.dock`), and after
  `aiDockingSecureTime` it leaves (`AI.exit`). Nothing passes to it: the derelict doesn't become its cargo.
- **The derelict's conversation**: if the derelict sees a rescue ship when the conversation opens
  (`mustSeeFaction = "helper"`, tested on the derelict's `getObjectsAIisAwareOf`), a random crew member says one of
  the four `DIALOG_DERELICT_TAKEN_*` lines and the conversation ends, without the offer to send them over. Every
  other branch needs no rescue ship in sight (`cantSeeFaction`). A derelict talks once, so for that one the chance
  is gone.
- **The arm**: a ship the arm holds (`addTemporaryCargo`, which sets its `docked`) counts as taken for the AI
  (`aiIsTaken`), so a rescue ship no longer goes for it. If the arm still holds it when the dive ends at the
  station, it joins the fleet for free when `CurrentGame.isShipSalvageable` says so: abandoned (every derelict),
  of the `pirate` faction, or without a transponder (`ship-ctrl.gd` `handleExitToEnceladus`,
  `CurrentGame.addShip`; the arm's manual says so too, `SYSTEM_SALVAGE_ARM_MANUAL`). A rescue ship nearby doesn't
  prevent it. A `helpless` ship that isn't salvageable pays 10 % of its value instead (`getShipValue`). Nothing
  held is taken when the player's own ship ends the dive helpless (see *Rescue*).

## Services

One row per service (`enceladus/ServiceUI.gd`, nested in `enceladus/Services.tscn`), each with its price (`getPrice`:
`flatPrice`, plus `activeMemberPrice` per active crew member and `totalMemberPrice` per crew member not on leave), the
hours it takes (`serviceHours`, which pass at once when it is bought: `advanceTimeBySeconds`), the morale it gives
(`moraleChange`, and `moraleStay` while those hours pass; see *Morale*) and a cooldown (`cooldownHours`, kept per save
in the UI store as `cooldown.<serviceName>`). A row's Buy button is enabled (`checkPrice`, run on every hour, money
change and crew change) when the row costs something, isn't in its cooldown, the money covers its price (or the row
allows debt, `allowDebt`: the capsule hotel) and its story condition holds (`storyLine` between `storyMin` and
`storyMax`); a row whose condition fails is greyed out, or hidden with `storyHide`. Three cost a monthly fee (a
720-hour cooldown, an hour each): Jameson's Insurance (`SERVICE_JAMESON`, 50,000 E$; see *Insurance*), Scrapwright
Recovery Operations (`SERVICE_SALVAGE_LICENCE`, 300,000 E$: derelicts brought to the rings; see *Salvage*) and the
simulator's Premium subscription, Minding Premium Virtual Flight Service (`SERVICE_SIMULATOR`, 4,000 E$). The bar The
Twins (`SERVICE_BAR_TWINS`, 300 E$ plus 300 E$ per crew member not on leave, 4 hours, morale +0.1) has a 24-hour
cooldown; the hotels have none, and can be bought again at once.

Three rows are compensations (`enceladus/ServiceUIFactionChange.gd`, at the end of the list): Local Vilcy Branch
(`SERVICE_VILCY`, faction `vilcy`), The Miner's Guild (`SERVICE_MINERS`, `civilian`) and Obonto Habitats
(`SERVICE_OBONTO`, `obonto`), an hour each and no cooldown. Their price (`getPrice`) is the faction's hostility towards
the player times `hostilityPrice` plus its fear times `fearPrice` (each counted only above 0; Vilcy 100,000 and
30,000 E$, the miners 20,000 and 50,000 E$, Obonto 60,000 and 100,000 E$), on top of the row's own price, which is
none. Buying one (`buy`) takes both back to 0 (`Factions.adjustFactionDisposition`, see *Faction*), so the row costs
nothing, and can't be bought, until the faction is hostile or afraid again. Local Vilcy Branch can be bought only
until the Big Bad Wolf is destroyed (`storyLine` `vilcy.bbw.destroyed`, `storyMax` 0); then it is greyed out.

## Transit

Each way covers the ΔV for trajectory (`MAP_DV`) of the Dive entry point picked (`DiveTarget.gd` `getPrices`, kept in
`CurrentGame.dvToEnceladus`). The main drives, the ship's thrusters, cover the ΔV in
`CurrentGame.timeDistanceToEnceladus` (12 h), burning the remass the rocket equation gives for the ship's whole mass
and its best thruster's exhaust velocity (`ship-ctrl.gd` `getRemassRequiredForDv`, `getBestThrusterVe`); the xenon
drive covers it in `xenonBurnToEnceladus` (96 h) and burns none.

- Out, at the start of a dive: charged once the ship is set up (`Game.gd` `_ready`: `getInterlunarTransitRemass`,
  `getInterlunarTransitTime`), then the arrival cutscene plays. The xenon drive's Tuning setting splits the ΔV
  between the two drives, and the time between their two times, in the same shares; the remass doesn't follow the
  shares, because the rocket equation isn't linear. The dive entry point screen shows that remass as Interlunar
  propellant usage (`HUD_RETURN_FUEL_XENON`) and won't launch without it (`HUD_WARN_PROPELLANT`).
- Back, at the end: charged during the exit cutscene (`Game.gd` `interlunarToEnceladus`), whatever the setting. The
  main drives burn all the remass aboard, up to the Transit reserve (`HUD_RETURN_FUEL`: the remass for the whole ΔV
  at the ship's mass then, cargo included), and the xenon drive does the rest. The time is split between the two
  drives' times by the share of the reserve burned (`getTimeRequiredToBurnToEnceladus`, the HUD's Transit time,
  `HUD_RETURN_TIME`), so a ship out of remass comes back in the xenon drive's time, never stranded.
- The K37 TNTRL's HUD also shows Estimated interlunar transit time and Interlunar propellant usage
  (`HUD_RETURN_*_XENON`, `hud/trtl/ShipParams.tscn`): the outbound figures at the ship's current mass, not the trip
  back.

## Transponder

- The game's codes: one of five prefixes, a dash and four digits (`CurrentGame.gd` `getNewTransponder`: `SE1`,
  `JG4`, `ETH`, `MRS`, `BLT`), from a seed. The prefixes read as a place of registry: a crew member reads `SRA-01`
  as "Saturn, Ring A, station 01" (`AGENDA_LOOKING_FOR_SIBLING_TAXI_JOB_HABITATS`). A ship the Shipyard builds gets
  its code through `getTransponder`, which keeps it in the save against the ship's build (`state.transponders`), so
  a ship met again has its old code; the player's first ship gets one on a new game.
- A ship keeps its code for good (its config's `transponder`). The game makes the ship's name from it
  (`generateShipNameFromTransponder`, kept in `state.shipNames`) and its captain's and crew's names in comms
  (`getCrewMember`), picks some lines by it, and keeps what it remembers about the ship by it (dispositions,
  encountered ships).
- Codes made from a ship's: its lifepod's is the ship's; a drone's is `<ship>-CC42` (`ClaimOwner.gd`); frozen
  bodies take their group's plus initials. Fixed codes: the stations (`IRRS-*`, the habitats `SRA-01`–`SRA-07`)
  and beacons (`SE1`, `SE1-SG`).
- Pirates broadcast none (`ship-ctrl.gd` `getTransponder` returns ""; the LIDAR's tutorial sticker,
  `TUTORIAL_STICKER_LIDAR`, says "NO TRANSPONDER - pirate RUN!").

## Tsukuyomi

Its seven turrets are `ships/modules/PDT.tscn` on no hardpoint: two CL-150, two CL-600P and three MWG; its laser
turrets also aim at reactors. The Big Bad Wolf (faction `vilcy`) comes at a point of interest, as its event
(`BigBadWolf` in `story/TheRing.tscn`, on `story/MinerMining.gd`; its `chaosLimit` of 3 is beyond any chaos, so it is
never picked at random): the Drop Point (`POI_BBW`), 1,000 km away, which Vilcy's conversation lines give
(`DIALOG_VILCY_HAVE_DROP_POINT`, with a Vilcy licence, `DIALOG_VILCY_PROVEN_1`, `DIALOG_VILCY_I_HAVE_PRISONERS_DROP`,
`DIALOG_VILCY_ANARCHY_HQ`), or a Radar Anomaly (`POI_ANOMALY`) 10 to 100 km away, which one of the crew's random lines
may mark (`DIALOG_POI_RANDOM_4`, in `comms/conversation/InterCrewBanter.tscn`). Only its patrol is a random event of
the rings (`BigBadWolfPatrol`: chaos above 0.45, until the Drop Point is known). Neither comes while it is in the
rings (its code, `SE1-BBW1`, active) or once the story says it was destroyed (`vilcy.bbw.destroyed`, which each of its
reactors sets as it explodes, their `storyFlag`; the achievement `ACHIEVEMENT_STORY_BBW_DESTROYED`, "Blow up the Big
Bad Wolf"). It has no lifepod.

## Vilcy

Vilcy's events in the rings (`story/Vilcy.gd`: `VilcyPatrol`, `VilcyLone`, `VilcyStrike`, `VilcyDisabler`,
`VilcyCombat`, `VilcyAmbush`, and on the same script the pirates `PirateG4A` and the abductors) come between 30 and
2,970 km deep, until the G4A pirate is destroyed (`g4a.destroyed`); the revengers (`PirateRevenger`, `VilcyRevenger`,
`PirateRevengerTeam`) only once it or the Big Bad Wolf is (see *Tsukuyomi*). The faction's defaults (`Factions.gd`):
curious towards the player, cautious towards the military, hostile towards pirates, supportive towards the helpless.
Its compensation row, Local Vilcy Branch: see *Services*.
## Weapons

By family, as CombatSimulator's wiki page explains them:

- mass drivers (`weapons/massdriver.gd`): the EMD-14 (`SYSTEM_EMD14`), ERFMD-17 (`SYSTEM_EMD17RF`), MPI Railgun MkI
  (`SYSTEM_RAILTOR`), AEMD-14 (`SYSTEM_ACTEMD14`, on a mount of `ships/modules/PDT.gd` that aims it within its
  `gimbalLimit`, `ships/modules/act-massdriver.tscn`) and the NDPT-4205's (see *Point Defence Turret*). A shot
  pushes its slug frame by frame for `timeFire`, takes ammunition (`SLOT_AMMO`) and recoils on the ship; slugs
  (`weapons/projectiles/projectile.gd`) have no lifetime, and the AI aims within the boresight's range;
- lasers (`weapons/laser.gd`): the CL-150 (`SYSTEM_CL150`, a steady beam), the pulse lasers CL-600P
  (`SYSTEM_CL600P`) and CL-200AP (`SYSTEM_ACL200P`, aimed as the AEMD-14, `act-laser.tscn`), whose pulses split into
  heat and a kinetic part (`kineticPart`), and a laser turret no ship carries and the station never sells
  (`SYSTEM_PDTL`, `ships/modules/PDT-laser.tscn`, no name text);
- microwave emitters (`weapons/emp.gd`): the MWG (`SYSTEM_MWG`) and the ONMWG-650 turret (`SYSTEM_PDMWG`), their
  output split into heat and EMP by Water Resonance (`TUNE_EMP_RESONANCE`; see *EMP*);
- the SPC Gungnir (`SYSTEM_SYNCHRO`, `weapons/synchrotron.gd`), charged while the trigger is held, on side mounts
  only;
- exhaust weapons, thrusters pointed forward (`sfx/thruster.gd`): the EINAT Kzinti Lesson MkII (`SYSTEM_EINAT`), the
  NANI (`SYSTEM_NANI`) and the Tetsuo HMX-2000I (`SYSTEM_IROH`, which also throws iron taken from the cargo,
  `iron-blob.tscn`); their heat ray is fed by the reactor's heat (`drawThermal`).

A hit does kinetic damage (`applyKineticDamage`: it leaks reactors, see *Reactor leak*, and chokes and bends
thrusters), heat (`applyEnergyDamage`: it heats reactors towards a meltdown, see *Reactor*) or EMP (`applyEmpDamage`,
see *EMP*); roids take kinetic damage and heat (see *Roid*).

## Xenon drive

Its Tuning setting, Interplanetary Xenon transit drive usage (0–100 %, default 100 %, kept per ship with the rest of
its tuning), is the share of the outbound ΔV it covers (`ship-ctrl.gd` `getXenonBurnRatio`); the main drives cover
the rest. It covers its share in `xenonBurnToEnceladus` and burns no remass. The trip back ignores the setting (see
*Transit*).
