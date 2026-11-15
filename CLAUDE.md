# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Mods for **ΔV: Rings of Saturn** (Godot 3 engine, GDScript). Each top-level folder not starting with `_` is one
independent mod and ships as one zip. There is no build system; `_tests\` is a test harness for most mods (see
*Testing*). The source has been in git since 14 Nov 2026; `.gitignore` keeps out every zip, so the
versions released before that exist only as release zips.

The root `README.md` is the repository's own (it ships in no zip): a table of every mod with its README's summary,
and, in a section of their own, the mods that change how the game plays (those with a *Warning* in their README).
Update it when a mod is added or removed, when a mod's summary changes, or when a mod gains or loses its *Warning*.

Later changes are in the git history and, from 1.0.0 on, in each mod's `CHANGES.md`.

## Glossary

The game's terms as requests use them: a term listed here means what it says, with no further
explanation. The key after a term is its translation key in the game's `i18n/en.po` (what a Label's `text` holds
before translation, and what mods match on); check a term's English text there, not from memory. When a request
uses a game term that isn't here, find it in the decompiled game and add it; an entry explains every game term it
uses, or that term has its own entry.

- **Adrenaline**: the game's bullet time. A level from 0 to 1 (`adrenaline` in `BulletTimer.gd`, changed through
  `CurrentGame.adrenaline(delta)`) that slows game time (`CurrentGame.targetTimeScale` → `Engine.time_scale`),
  blurs the view around the ship and muffles the sound, and drains by itself. Three things raise it: the Adrenaline
  Booster; the smart camera (a display setting, `Settings.cfg.display.smartCamera`; `ships/camera.gd`) when
  objects close in fast; and the pilot, when their Course anticipation (`CREW_STATS_PILOT_ANTICIPATION`) foresees
  a collision (`ship-ctrl.gd` `handlePilotAdrenaline`). How slow time gets at full adrenaline is the pilot's
  Adrenal slowdown (`CREW_STATS_PILOT_ADRENALINE`, `CurrentGame.getAdrenalSlowdown`), set by their talent.
- **Adrenaline Booster** (`SYSTEM_ADRENALINE_BOOSTER`, `ships/CabinLight.gd`): equipment the player fires with
  the `bullet_time` action (`CONTROLS_GAMEPAD_ADRENALINE`) for a burst of adrenaline, followed by a cooldown
  (`adrenalineBoost`, `adrenalineCooldown`); fired again during the cooldown, it cuts the burst short. Switched off
  in the OMS's Mechanic tab, it pushes adrenaline down every frame instead, which also damps bullet time from the
  other sources. DiveDisableAdrenalineBooster starts the player's booster switched off at every dive.
- **Arm**: the AR-1500 Manipulator (`SYSTEM_SALVAGE_ARM`, `ships/modules/DockingArm.gd`), the ship's arm that grabs
  chunks and brings them to the intake (see *Salvage arm facts*).
- **Astrogator**: the crew occupation for navigation, and the OMS tab with the map: points of interest, distances,
  plotting a course (`HUD_PLOT_COURSE`).
- **Chunk** (mineral chunk, ore chunk): a loose piece of ore floating in the rings; what the arm grabs, the MPU
  processes and the HUD's mineral targeting marks. A `RigidBody2D` with `asteroids/mineral.gd`, one scene per
  mineral and size (`asteroids/mineral-<mineral>-<n>.tscn`); `mineral` names its mineral, `composition` its
  content. Weight: see *Salvage arm facts*.
- **Crew** (`ENCELADUS_CREW`): the people hired at the station, each with an occupation (`CurrentGame.occupations`:
  Pilot, Mechanic, Geologist, Astrogator, keys `CREW_OCCUPATION_*`) and a salary; the player is the captain. The
  dive crew are those aboard. Passengers (`CREW_OCCUPATION_PASSENGER`, no salary) are listed with the crew. The
  **Crew screen** (`enceladus/Crew.tscn`), opened by the station menu's Crew entry, has two tabs: Your Crew
  (`ENCELADUS_CREW_CURRENT`, `enceladus/CurrentCrewManagement.gd`) and the Hire screen.
- **Dealer** (`ENCELADUS_SHIP_MARKET`, `enceladus/Dealer.tscn`): the station's ship market. Its entries are
  `enceladus/SystemBuyUI.gd` (the ship-list mods change them); its Examine tab can launch the simulator. **Fleet**
  (`ENCELADUS_OWNED_SHIPS`): the ships the player owns.
- **Depth** (`HUD_DEPTH`): how far into the rings the ship is.
- **Dive** (ring dive): one trip from the station into Saturn's rings to mine, until the ship is back. Started with
  Launch Ring Dive (`ENCELADUS_RETURN_TO_RING`), at the dive entry point picked before launch
  (`ENCELADUS_DIVE_TARGET`, `enceladus/DiveTarget.tscn`); fees, licences, insurance and consumables are paid per
  dive, and on return the dive's output is stored or sold.
- **E$**: the game's currency.
- **Enceladus**, **the station**: Enceladus Prime station (`ENCELADUS_*`, `enceladus/`), the home base at Saturn's
  moon Enceladus. Its menu (`enceladus/EnceladusMenu.gd`) opens the station's screens on its right (the children of
  `enceladus/HidingMarginContainer.gd`).
- **Equipment**: the parts fitted to a ship (engine, reactor, LIDAR, MPU, arm, Adrenaline Booster, …), and the
  station screen where they are bought and fitted to its hardpoints (`ENCELADUS_SHIP_UPGRADES`,
  `enceladus/Upgrades.tscn`; also called the Upgrades screen, after its key and scene). The code calls one piece a
  system: each has a `SYSTEM_*` key, which its script holds in `systemName` (`SYSTEM_SALVAGE_ARM`); a few texts say
  "system" too (the OMS's on/off switch, the trade-in tip).
- **EVA** (extravehicular activity): a crew member in a space suit outside the ship. It has no key of its own; the
  word is in conversation lines ("Getting into EVA.", `DIALOG_DERELICT_GO_SURE`). In flight an EVA is only a suited
  sprite with a lamp (`ships/modules/EVAflight.tscn`, `EVAflight.gd`), which flies between the player's ship and the
  ship the player is talking with when a conversation line sets `evaDirection` (`comms/ConversationPlayer.gd`
  `execute`, over the line's `evaTime`; `ship-ctrl.gd` `handleEvaProgress`). -1 flies from the player's ship to the
  other ship, 1 from the other ship to the player's. The sprite is decoration: the line's other fields decide what
  happens. The player can't order an EVA. The base game shows one only in the cases below. The first three are
  conversations during a dive, and in them the one who goes out is a member of the dive crew, so a captain flying
  alone never gets them:
  - **Derelicts**: abandoned ships with their reactor off, in the `helpless` faction (`story/RescueOperation.gd`, a
    random event of the rings in `story/TheRing.tscn`, sometimes with a rescue ship nearby;
    `story/FlightForRescue.gd`, on a rescue ship's path). A derelict can't be hailed. It opens its conversation
    (`comms/conversation/DerelictConversation.tscn`) by itself, once, when the player's ship comes within its
    `aiCuriosityDisance` (150 m; `ship-ctrl.gd` `AI.examine`). Unless a rescue ship (faction `helper`) is in sight
    (then it's taken), a random crew member reports it (`DIALOG_DERELICT_RANDOM.tscn`), and the player can send
    them over to restart it (`DIALOG_DERELICT_GO_AND_BRING_IT`). On board, they may get it running, and it joins
    the player's fleet (`getThisShip`). Or they come back with nothing, or injured (leave days,
    `addAgendaLeaveTime`). What they find varies (the `DIALOG_DERELICT_*` subtrees: brick, junk, solo dead, hole,
    ghost ship).
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
- **Geologist**: the crew occupation for mining, and the OMS tab with the cargo's composition and the mineral
  targeting: which minerals the HUD marks, and their Minimum value (`HUD_MIN_PRICE`), kept in the HUD's
  `mineralConfig`.
- **Hardpoint**: a ship's mount for a piece of equipment: high-stress, low-stress or spinal. Only high-stress ones
  take the arm.
- **Hire screen** (`ENCELADUS_CREW_HIRE`, "Hire"; also the Hire list): the Crew screen's tab of the people for hire
  that day, the `HireableCrew` node of `enceladus/Crew.tscn` (`enceladus/HireableCrew.gd`), filled from
  `CurrentGame.getAvailableCrew()` on the first show and every in-game day. One entry per person
  (`enceladus/CrewBio.tscn`, `CrewBio.gd`): their skills compared with the crew's, name, occupation, education,
  experience, salary, portrait, and a Hire button (`CREW_HIRE`, the entry's `hireButton`), disabled while the
  player can't pay the salary.
- **HUD**: the ship's flight display (`hud/Hud.gd`), laid out per ship model in `hud/Display-<model>.tscn`.
- **Intake**: where the arm feeds chunks into the ship: a grinder, an excavator or a side bay (see *Salvage arm
  facts*).
- **LIDAR** (`HUD_LIDAR`, "Doppler LIDAR"; `hud/LIDAR.gd`): the HUD's scanner of nearby objects. Its sweep plays a
  ping (the `Bleep` node) for each strong return, pitched and set in volume by the distance; a Tuning switch
  (`doBleep`) turns the pings off.
- **Mechanic**: the crew occupation for repairs, and the OMS tab listing the ship's equipment, to switch each piece
  on and off and fix it.
- **Mineral**: what a chunk is made of, named in code by its element symbol (`mineral = "PT"`). Processed ore
  (`HUD_CARGO_LIST_PROCESSED`) is what the MPU has extracted; it is sold or stored at the **Mineral Market**
  (`ENCELADUS_MINERAL_MARKET`).
- **MPU** (`SYSTEM_CARGO_MPU*`, `ships/modules/MineralProcessingUnit.gd`): the Mineral Processing Unit, which turns
  the chunks taken in into processed ore and, in most models, their water into remass.
- **OMS** (`HUD_OMS`, `hud/OMS.gd`, `hud/OMS.tscn`): the Onboard Maintenance System, the console opened with `J` in
  flight. Its tabs are named by the crew occupation keys: Mechanic, Astrogator, Geologist, Pilot.
- **Reactor** (`SYSTEM_REACTOR_*`; `ships/Reactor.gd`): the ship's nuclear reactor, the equipment that makes heat. The
  turbine (`SYSTEM_TURBINE_*`, equipment for fission ships, read as the config `turbine.power`) turns that heat into
  electricity and burns remass to do it (`turbineConsumption`). With no remass left, it makes no power. The reactor
  engages and disengages by itself to hold its target temperature, a Tuning setting (`TUNE_TARGET_TEMPERATURE`). The
  HUD shows the temperature as `HUD_REACTOR_TEMP`, and the `power_reactor_toggle` action switches the reactor on and
  off. Its damage is listed in the Mechanic tab (`hud/SystemList.gd`): Fuel rods jammed (`DAMAGE_RODS`, from hard
  accelerations: slower to engage and disengage, and the temperature swings), Reactor leak (`DAMAGE_LEAK`) and
  Turbine Galling (`DAMAGE_TURBINE`, from overheating: the turbine needs more heat to make power). If the reactor
  stays above its meltdown temperature for a few seconds (`telegraphTimeLimit`, with a growing glow as warning), it
  explodes and the ship is lost. For the player's ship, that is game over. The EIME's StarCAT Stellarator
  (`SYSTEM_REACTOR_EIME`, `ships/modules/FusionReactor.gd`) is a fusion reactor with other kinds of damage (coils,
  coolant, lasers) and no leak.
- **Reactor leak** (`DAMAGE_LEAK`): damage to a nuclear reactor from impacts close to it (`Reactor.gd` `_on_impact`:
  the impact's power divided by the distance squared, counted above a threshold). The spot that was hit becomes a
  leak point. Used ships start with some leak damage (`ageIfNeeded`). Past a quarter of its capacity
  (`damageLeakOffset`), the leak vents remass at random moments. It vents more often the worse the leak, and more
  remass the hotter the reactor; it doesn't vent while the reactor is below `leakTemperature`. Each vent wastes
  remass, cools the reactor and pushes the ship from the leak point. The leak also lowers the meltdown temperature
  (`meltdownTemperature - jamTemperatureAdj * leak`), so an overheating reactor explodes sooner. Leaks matter most in
  combat: they are the only way to disable an enemy ship so it can be captured, because a ship that
  runs out of remass stops working.
- **Remass**: reaction mass, the ship's propellant (`HUD_FUEL`, shown as "propellant").
- **Roid**: an asteroid (`asteroids/asteroid.gd`, a `RigidBody2D`), the rocks that fill the rings; the game's own
  texts say "roids" too.
- **Ship models**: Eagle-Prospector-VP (the VP), EIME, OCP-209, K37 TNTRL, the Cothon series, the Kitsune, …: names
  of ships as the Dealer shows them.
- **Simulator** (MVFS; `ENCELADUS_LAUNCH_VR`, `enceladus/Simulator/`): the Minding Virtual Flight Service, the
  station's flight simulator for trying a ship as fitted; launched from the Tuning and Equipment screens and the
  Dealer's Examine tab. A Premium subscription (`SERVICE_SIMULATOR`) adds a simulated ring scenario.
- **Transit**: the trip back to the station at the end of a dive (`HUD_RETURN_*`); the transit reserve is the
  propellant kept for it.
- **Tuning** (`ENCELADUS_SHIP_TUNING`, `enceladus/Tuning.tscn`): the station screen with the settings of each piece
  of the current ship's equipment, registered by its script with `registerSubsystem` and saved with the game (see
  *Conventions*).

## Local paths

| What | Path |
|---|---|
| Game (GOG) | `<GameDir>` (`Delta-V.exe`, `mods\`) |
| Decompiled game, one folder per game version | `<TempDir>\gdre\Delta-V-<version>\` (1.91.61 so far) |
| Godot 3.6 (the game's engine) and GDRE Tools 2.7.4 | `<GodotDir>\` |
| Generated and temporary files: zips being packaged, test runs, scratch scripts | `<TempDir>\`, never the repo |

Do not read outside these paths and this folder without asking first.

The decompiled game is where the `res://` paths the mods extend resolve (`res://ModLoader.gd`,
`res://ships/modules/DockingArm.gd`, …). **Always read and test against the newest version there.**

After a game update, decompile it again with GDRE Tools
(`gdre_tools.exe --recover=<the game's Delta-V.pck>`) into `<TempDir>\gdre\Delta-V-<version>\` next to
the older versions. The harness takes the newest folder by itself (by version number) and warns when
`_tests\harness\vp_data.gd` was checked against another version (`CHECKED_AGAINST`): then re-check the values it
cites and update that constant.

## Testing

`_tests\run.ps1` (PowerShell 7) tests the mods listed below in a headless Godot 3.6, in a few seconds. It assembles
a Godot project in `<TempDir>\tests\project` from `_tests\`; the game's own `DockingArm.gd`, `Arm.gd`,
`CabinLight.gd`, `Boot.gd`, `LIDAR.gd`, `PitchAdjustedAudio.gd`, `HardwareLabel.gd`, `EnceladusMenu.gd`,
`HidingMarginContainer.gd`, `AnalogControlSlider.gd`, `TuningFloatValue.gd`, `TuningItems.gd`, `Hud.gd`, `OMS.gd`,
`TabsWithGamepadControl.gd`, `PriceLabel.gd`, `RepeatingHSlider.gd`, `MineralLabel.gd`, `MineralSystemToggle.gd`,
`HireableCrew.gd`, `CrewBio.gd`, `CurrentCrewManagement.gd`, `PlaySoundsOnTheseButtons.gd`, `Tool.gd`, `gdunzip.gd`,
`Shower.tscn`, audio buses (`default_bus_layout.tres`) and the skill icons `CrewBio.gd` preloads (their `.png.import`
and imported `.stex`, so they load without an import step), copied from the decompiled source on every run and never
committed, since they are the game's; a stub mineral scene with the chunk radius read from the game's; bare stubs of
the two scenes `LIDAR.gd` preloads; and stubs of the Tuning scenes (`TuningFloatValue.tscn`, `TuningItems.tscn`,
`TuningBoolValue.tscn`, `HeaderWithMoney.tscn`), of a Hire screen entry (`CrewBio.tscn`, with a portrait stub,
`harness/crew_video.gd`, and the game's tooltip node, `PlaySoundsOnTheseButtons`) and of the Geologist tab's parts
(`MineralSystemToggle.tscn`, `MineralLabel.tscn`, `PriceLabel.tscn`) with the game's node paths and scripts but no
theme, textures or sounds. It packages each mod as a release zip and loads the zips as `ModLoader.gd` does, at
the same moment (`_tests\harness\loader.gd` is the `ModLoader` autoload, and loads in its `_init`; the autoloads keep
the game's order), so the zip layout is tested too. Logs: `<TempDir>\tests\logs`.

```powershell
.\_tests\run.ps1                                               # every suite, its own mods, the game's order
.\_tests\run.ps1 -Suite moving -AllOrders                      # one suite, every load order
.\_tests\run.ps1 -Matrix                                       # moving: 109.29/330 t ships x 2.8/5 t chunks
.\_tests\run.ps1 -ModZip <a release zip>                       # a release zip in place of the mod's folder
.\_tests\run.ps1 -Suite units -Mods ArmAltPullBehavior         # other mods than the suite's own (@() = none)
```

Call it from a pwsh prompt or `pwsh -Command`: under `pwsh -File`, list arguments such as `-Suite still,moving` are
not parsed as arrays. Exit code 0 = every run passed; a script error fails its run even if every check passed.

The suites are ported from the claude.ai harness (DVModTestHarness 1.0.0; the original was deleted once ported),
except `boot`, `lidar`, `hud`, `crew` and `geology`. `units`, `still` and `moving` load the two arm mods by default,
`dive` loads DiveDisableAdrenalineBooster, `boot` loads BootSkipLogos, `lidar` loads LidarLouderPing, `hud` loads
HudHideLabels, `crew` loads CrewCheapHireNotifier, `geology` loads GeologyByMass.

- `units`: the claude.ai unit tests (`arm/main.gd`) nearly verbatim, on synthetic arms around the game's
  `DockingArm.gd`. TargetSelection: area geometry on turned, scaled and offset arms, reach, the strip, the weighted
  pick, keeping the current target, switch off/on, intake and entry point. PullBehavior: where the pull goes (20
  cases: feeding or not, grinder or excavator, a block of hull; feeding in the corridor, pulled straight in by the
  mod since 1.5.0), the EIME's claws, the hysteresis at the corridor's edge, closed beak, switching ship types,
  cost, nothing pushed while the game pulls (the 1.3.0 bug). Plus 4 checks on the real
  Eagle-Prospector-VP rig, including the hull inertia `moving` uses. A group whose mod is not loaded runs "control"
  checks of the game alone.
- `still` (9 cases, `arm/real.gd`) and `moving` (16 cases, `arm/real_move.gd`): ArmAltPullBehavior bringing a chunk
  in on a simulated Eagle-Prospector-VP, standing still, held in place, cruising at 10–40 m/s or turning, feeding
  or not; two start points are where the author's in-game logs started. Each case expects the chunk in between the
  rotors without touching them, at the dock slot, or moved straight forward first, and prints how long it took.
  The feeding cases behind the red line beside the hull also have a time limit (1.5.0's times + 25 %, below
  1.4.0's), so a slow-down fails.
- `dive` (`dive/main.gd`): the player's Adrenaline Booster (the game's `CabinLight.gd`) starts disabled; another
  ship's booster, other cabin-light systems and a light with no ship are untouched; switching it on sticks; it gives
  adrenaline only when enabled. The control check (the game alone starts it enabled) runs on the game's own script,
  the base of the extension, so it needs no separate run.
- `boot` (`suites/boot.gd`): runs with `_tests\harness\boot.tscn` as the main scene (a scene path on Godot's
  command line), whose root has the game's `Boot.gd`, so the engine loads it after the autoloads, as the game loads
  `Boot.tscn`. Checks that this startup scene got the extension, runs the game's own start-up and then asks for the
  title screen; that the first launch (`Settings.firstBoot`) keeps the logos; and, as control, that the game's
  script alone does not leave them. A `Loader` stub records the calls instead of switching scenes.
- `lidar` (`suites/lidar.gd`): hidden lidars built in code around the game's `LIDAR.gd`, with a `Bleep` on the
  game's `PitchAdjustedAudio.gd` that records each `play()` (`harness/recording_bleep.gd`), under stubs of the HUD and
  the ship (`harness/lidar_reader.gd`, `lidar_ship.gd`). Checks that the slider is registered right below the Tuning
  switch, in its group, with the mod's range, and stays there; that its value (clamped, the default for a non-number)
  moves the ping to the mod's bus, which sends to its own bus (`ShipBowels`, or `SFX`) with the gain, and a gain of 0
  back to its own bus; that the bus is shared, not added twice, and that a lidar without a ping is left alone; that
  the switch still sets `doBleep`. The demo, on a preview's lidar (`dynamicConnect`) with a synthetic sound, driven
  frame by frame with the game's `TuningFloatValue` row focused: the game's volume and pitch for each distance, the
  spacing and the interval, the preview's own pings muted, nothing with another row, no focus, the switch off or a
  lidar that isn't a preview's. And the texts of `i18n/en.po`, also in a language without them. The control checks (the
  ping stays on its bus) run on the game's own script.
- `hud` (`suites/hud.gd`): trees built in code with the node paths and types of the OCP-209's HUD
  (`hud/Display-OCP209.tscn`), the station's Upgrades screen and the `J` screen (`hud/OMS.tscn`), each scene root
  marked by its `filename`; the HUD is added in one go under stubs of the ship and its Hud (the `lidar` suite's),
  as `Hud.gd` `instance()` does. Checks that each title on the HUD (and the feed sub-scene's) is hidden from the
  first frame when its key is in the mod's `HIDDEN_KEYS` and drawn when not, also the LIDAR's, which the game's
  `HardwareLabel.gd` renames in its `_ready`; that hidden titles keep their space; that other labels, a button with
  a title's text and the same titles outside a `Display-*.tscn` are drawn; and that a title added later follows
  `HIDDEN_KEYS` too. The control checks (with `-Mods @()`): every title is drawn.
- `crew` (`suites/crew.gd`): station menus built in code around the game's `EnceladusMenu.gd`, nested as
  `enceladus/EnceladusMenu.tscn` nests them (a `Crew` and a `Logs` Button), with the hire list and the crew set in the
  `CurrentGame` stub and a test translation in two languages. Salaries and slider values are built from the
  descriptions in the mod's `Settings.gd` (`SETTINGS`). Checks that the Crew entry is marked from the first frame; the
  rule's edges (at and above the threshold, which the tolerance never moves either way, also within the tolerance
  above it; at, within the tolerance of, at the end of and above the best-paid member's salary in that job; the
  threshold above a best-paid below it even after the tolerance; the tolerance clamped to its minimum, and there a
  hire at the best-paid salary times it, above it and, when negative, at the best-paid salary itself; another job);
  that `dayPassed` and `employmentChanged` refresh it both ways and an unmarked entry gets its key back; that a marked entry follows a language change; and
  that the other entries, a menu without `Crew` and the game's `disable()` are untouched. The settings model: one
  shared instance; defaults for a save without the mod's entry; clamping of what is loaded or set; saving into
  `CurrentGame.state.ui` under the manifest's id, with the format and mod versions, and a signal only on a change; the
  % conversion. The Hire screen: the Hire tab built as `enceladus/Crew.tscn` nests it, around the game's
  `HireableCrew.gd` and `CrewBio.gd`, with a theme holding a Button font color and a flat frame with an overbright
  border, and the menu beside it. Each qualifying person's entry, at and below the limit, has a visible badge:
  above the details grid's values, right-aligned with them, one grid row gap above, at its minimum size and inside
  the entry; the capitals of the manifest's name in the Hire button's font color times `colorBetter`; a copy of the
  Hire button's frame with a `colorBetter` border, the theme's frame unchanged; letting the mouse through; a mouse
  moved onto it through the scene tree's input (after `NOTIFICATION_WM_MOUSE_ENTER`: without it, a window-less Godot
  3.6 sends no control the mouse's enter) shows the limit for the job in the game's tooltip (the entry's
  `PlaySoundsOnTheseButtons`), which took over its `hint_tooltip`, and moving away hides it; the Hire button untouched
  and the entry's height unchanged. Above the limit, no badge; the menu is marked exactly when an entry has one. A new
  day judges kept entries again, one badge each; firing (`employmentChanged`) hides it; hiring there gives another
  pilot one with the new limit; a setting shows and hides it; the tooltip follows a language change. A new entry is
  hovered a frame after it is made, once its containers have laid it out. With CrewPerfectSort loaded too (`-Mods
  CrewCheapHireNotifier,CrewPerfectSort`), the list is sorted and the badges stay. Then a station built as
  `enceladus/Enceladus.tscn` nests it (the menu, and the game's `HidingMarginContainer.gd` with stubs of the Crew and Tuning screens, `harness/crew_screen.gd`), clicked through the
  scene tree's input: the tooltip; Shift+Click opens the settings and not the Crew screen, a plain click the Crew
  screen, a disabled entry nothing; the screen copies Tuning's frame and place and lists one row per setting with
  its range, step and value; moving a slider flips the mark at once and stores the value; reset; Esc (handled, so
  `harness/unhandled_probe.gd`, standing in for the pause menu, doesn't get it), the controller's B and Start, and
  focusing another entry close it; after a JSON round trip of the state a new station has the saved value; and
  without a Tuning screen there is no tooltip and Shift+Click is a plain click. Keys and buttons are sent as real
  input events in the idle part of a frame, with the game's bindings: a bare `InputEventAction`, or one sent during
  physics, doesn't make `Input.is_action_just_pressed` true. The control checks (the entry keeps its key; a Hire
  screen entry gets no badge) run on the game's own scripts.
- `geology` (`suites/geology.gd`): HUDs from `harness/geology_hud.tscn` (the game's `Hud.gd`, with an `Inventory`
  placeholder of `harness/geology_oms.tscn`: the game's `OMS.gd` and `TabsWithGamepadControl.gd` over the OMS's four
  role tabs) on `harness/geology_ship.gd`, a ship stub whose `isValidMineralTarget` records each call in place of the
  game's rule; the OMS is built on the ship's `instance` signal, as the game builds it. The mod's settings
  descriptions come from its `Settings.gd`. Checks that the tab comes right after the Geologist tab, titled by its
  key, once however often the OMS is built, and that opening it stores nothing; its switch, with its label at the
  mod's spacing (once laid out), then one row per mineral the HUD can switch on, with the Geologist tab's parts, the
  mod's range, step, unit, tooltip and bar width (also once laid out), and the stored values; the switch and the
  sliders store what they show, and the switch dims the rows; choosing the tab focuses the switch. The rule: off, the
  game decides; on, below, at and above a mineral's mass, a mineral switched off in the Geologist tab, one of two
  minerals enough, the value and Minimum value ignored both ways; the game decides a chunk not yet identified,
  another ship's HUD and a HUD without mineral targeting. The settings model: defaults for a ship without the entry;
  reading and unchanged sets store nothing; the mineral list with and without `onlyMinerals`; clamping and snapping
  of what is set or hand-edited; the entry in the HUD's `mineralConfig` (the ship's `hud.config`) under the
  manifest's id, with the format and mod versions, the game's keys untouched; a JSON round trip. A preheated ship
  (its HUD builds the OMS before loading `mineralConfig`) gets the tab with its stored values. And the texts of
  `i18n/en.po`, also in a language without them. The control checks (the OMS keeps its four tabs; the game decides)
  run on the game's own script.
- `_tests\harness\rig.gd` builds the arm's node tree as the game nests it, with the values in
  `_tests\harness\vp_data.gd`; each cites its scene file and line, so re-check them after a game update. The ship
  is a stub moved by hand (it takes the arm's impulses and torque; inertia from the hull); the rotors don't collide.
- **Baseline** (both arm load orders give the same results): `units` 114 checks with both arm mods (64 with
  PullBehavior alone, 61 with TargetSelection alone), `still` 9, `moving` 16, `dive` 8, `boot` 5 (3 control checks
  with `-Mods @()`), `lidar` 40 (3 control checks with `-Mods @()`), `hud` 13 (3 control checks with `-Mods @()`),
  `crew` 97 (98 with CrewPerfectSort too, in both load orders; 3 control checks with `-Mods @()`), `geology` 50 (3
  control checks with `-Mods @()`), all passing; `-Matrix` gives 16 of 16 in every combination.
  Feeding, a chunk beside the hull is in after 4.4–4.8 s.
  For comparison with `-ModZip` and older release zips: PullBehavior 1.4.0 (the claude.ai results,
  case for case) took 5.9–6.3 s there, fails the 8 time limits, and `-Matrix` gave 16, 15, 16, 16 (feeding while
  turning with a 5 t chunk touched a rotor: the game's pull measures speed against the swinging dock slot);
  1.3.1, which broke in the game, gives 0, 0, 12, 4 of 16. This ship also takes the arm's torque reaction, as the
  game's does (the claude.ai stub dropped it), which shifts some numbers in the third decimal.

The harness doesn't replace the game. CrewHighlightJobAndSalary and the ship-list mods have no tests at all, and
CrewPerfectSort has none of its own: only its Hire screen sort runs, beside CrewCheapHireNotifier in `crew`. The real
check is playing the game with the mods.

## How the game loads a mod (`res://ModLoader.gd`, an autoload)

- Only with `--enable-mods`. **Every file** in `mods\` is mounted with `load_resource_pack(path, true)`, replacing
  game files at the same path. Two versions of one mod both load, and their `ModMain.gd` runs twice.
- Every zip entry whose file name starts with `modmain` and ends in `.gd` (case-insensitive) is loaded as
  `"res://" + <entry path>`. So the mod folder name, the zip root and every `res://<ModName>/…` path in the code
  must match.
- `ModMain` scripts run sorted by an optional `const MOD_PRIORITY` (default 0, ascending), then by path. Each is
  created with `new(modLoader)` and added as a child of the `ModLoader` node, so its `_ready` runs once the tree is up.
- All of this happens in `ModLoader`'s `_init`, while the engine creates the autoloads and before it loads the main
  scene (`Boot.tscn`). An extension installed from a `ModMain`'s `_init` therefore applies even to the boot scene
  (BootSkipLogos relies on it; the `boot` suite checks it). Autoloads after `ModLoader` in the game's
  `project.godot` (`Settings`, `Loader`, `CurrentGame`, …) are still null at that point.
- `modLoader.installScriptExtension(path)` loads the child script, makes **one throwaway instance** of it (its
  `_init` runs with no scene or ship), then `take_over_path`s the parent's path: everything loaded afterwards gets
  the child. A second mod extending the same game script extends the first mod's extension. The throwaway instance
  is never freed, and it is what keeps the child script alive: freed, the script goes too and later loads get the
  game's script back (tried in the harness).
- `Mod.manifest` is not read by the game's loader.
- The loader also has `addTranslationsFromCSV`, `appendNodeInScene` and `saveScene` (unused so far; the harness's
  loader offers `addTranslationsFromCSV` too). **`addTranslationsFromCSV` reads nothing from a mod's zip**: a file in
  a zip reports its end before the first read (`eof_reached()` is true right after `open`, false after one `get_8()`),
  and `get_csv_line` checks for the end before reading (found in the harness's Godot 3.6). A mod's texts go in a
  `i18n/<locale>.po` loaded with `TranslationServer.add_translation(load(...))`, as the game loads its own `.po` files
  (LidarLouderPing).

## The two ways these mods hook in

1. **Script extension**: ArmAltTargetSelection and ArmAltPullBehavior (`ships/modules/DockingArm.gd`),
   DiveDisableAdrenalineBooster (`ships/CabinLight.gd`), BootSkipLogos (`Boot.gd`), LidarLouderPing (`hud/LIDAR.gd`),
   CrewPerfectSort (`enceladus/HireableCrew.gd`, `enceladus/CurrentCrewManagement.gd`), CrewCheapHireNotifier
   (`enceladus/EnceladusMenu.gd`; it also adds its settings screen to the station's right-hand screens, the children
   of `enceladus/HidingMarginContainer.gd`, copying the Tuning screen's frame and behaving like the game's screens;
   and `enceladus/HireableCrew.gd`, the Hire screen), GeologyByMass (`hud/Hud.gd`; it also adds its tab to the OMS,
   right after the Geologist tab, from `instance()`). `ModMain.gd` only calls
   `installScriptExtension("res://<ModName>/Code.gd")` (CrewPerfectSort: once for each of its two extension files;
   CrewCheapHireNotifier: `Code.gd`, then `HireScreen.gd`); `Code.gd` `extends "res://<game script>"`. Rules that let
   mods stack on the same script (header of `ArmAltTargetSelection/Code.gd`):
   - Never call the parent's `_ready`, `_process`, `_physics_process` or `_notification`. Godot 3 runs them at every
     level of the script chain by itself: `_ready` base first (so `ship` etc. are set), `_process`,
     `_physics_process` and `_notification` child first. LidarLouderPing overrides `onSetup` (an ordinary function)
     and `_process`.
   - Ordinary functions are not chained: call the parent with `.name()`, and fall through to it where the mod does
     not apply (`if not _targeting: return .switchTarget()`).
   - Gate the change on a condition (`systemName == "SYSTEM_SALVAGE_ARM" and ship != null`,
     `ship.isPlayerControlled()`), so the script's other users are untouched.
   - New members and helpers start with `_`, have unique names, and are listed in the README's *For modders*.
2. **Scene-tree observer**: CrewHighlightJobAndSalary (`enceladus/CrewBio.gd`), ShipHighlightTypeAndPrice and
   ShipSortByTypeAndPrice (`enceladus/SystemBuyUI.gd`). No game script is changed: `ModMain.gd` adds a node with
   `Code.gd` (`add_child(preload("res://<ModName>/Code.gd").new())` in its `_init`), whose `_ready` connects the
   tree's `node_added`, matches `node.get_script().resource_path`, `yield`s a 0.3 s timer (entries fill their labels
   after entering the tree) and re-checks `is_instance_valid`. Entries get re-added (the dealer does it every hour),
   so handlers must be idempotent (`is_connected` checks, cached copies). Shared resources such as the game's fonts
   are duplicated, never edited; rows are hidden with `self_modulate` alpha 0, not `visible`, which the game toggles.
   HudHideLabels (the titles of the `hud/Display-*.tscn` screens) matches a Label's `text` instead of a script, and
   acts at once without the yield: `node_added` runs before any `_ready` of the new subtree, so the LIDAR's title
   (`hud/HardwareLabel.gd`, renamed in `_ready`) still holds its key.

## Cross-mod dependencies

- ArmAltPullBehavior and ArmAltTargetSelection both extend `DockingArm.gd` and both override `_ready` and
  `_physics_process`. `ModMain` scripts run in path order, so the chain is game ← ArmAltPullBehavior ←
  ArmAltTargetSelection. Their member names must stay distinct, and both find the intake the same way (grinder
  rotors / excavator claws via `ship.hasSystem`): change `_entry` and `_intakePosition` together.
- CrewPerfectSort replaces `CrewSortByJobAndSalary` (the first mod, not in this folder) and must not be installed
  with it: both sort the same lists.
- CrewCheapHireNotifier (`HireScreen.gd`) and CrewPerfectSort (`HireableCrewSorted.gd`) both extend `HireableCrew.gd`
  and both override `fillCrew`, each calling the parent's first: by path the chain is game ← CrewCheapHireNotifier ←
  CrewPerfectSort, and CrewPerfectSort only reorders the entries, so the marks stay (both orders tested in `crew`).
  Their member names must stay distinct.

## Working rules

- Read values from the game (the ship's nodes and collision shapes, scene files, the arm's own properties), never
  from per-ship tables. A constant is only a fallback for when the game data can't be read (`CHUNK_RADIUS_FALLBACK`).
- Find field names and game behaviour in the decompiled source; don't ship a logging-only build to discover them.
- Versions follow [semver](https://semver.org): **major** for a change that breaks what players or modders rely on
  (a feature removed or changed incompatibly, saved settings that no longer load), **minor** for new behaviour or
  settings that keep the old working, **patch** for fixes and for changes with no visible effect (a file renamed,
  code moved between files). Every zip handed over gets a new version, and a released version is never changed.
  A new mod always starts at **0.1.0**. Going to 1.0 means:
  remove all logging, simplify, set 1.0.0, and document the what and why of each feature in the README for other
  modders.
- The wiki's manifest format is outdated; follow [DVTools](https://github.com/rwqfsfasxc100/DVTools).

## Salvage arm facts (for the ArmAlt mods)

- Only ships with high-stress hardpoints can mount the AR-1500 arm (not the Cothon series, not the Kitsune).
- Intakes: a grinder (two toothed rotors, e.g. the Eagle-Prospector-VP), an excavator (a beak that splits in the
  middle, e.g. the EIME), or the OCP-209's side bay (opens front to back, mounts two arms).
- The arm reaches only ahead of its mount; each section turns about 180°, like a human arm.
- Mineral chunks weigh about 5 t. The ship in the author's in-game tests is over 111 t, and can reach about three
  times that with equipment and load. The arm is normally used while moving at 10–40 m/s, rarely standing still.

## Conventions

- **Godot 3 GDScript, not Godot 4**: `.method()` for parent calls, `yield(…, "timeout")`, `connect("signal", self,
  "method")`, `PoolVector2Array`, `xform`, `extents`, `add_color_override`.
- Tabs; UTF-8 without BOM; LF line endings (`.gitattributes` enforces them whatever `core.autocrlf` says). Script
  extensions use the game's camelCase, the observer mods snake_case: match the file.
- **File names in a mod folder**:
  - `ModMain.gd` only hooks the mod in, and keeps its name (the game runs only zip entries named `modmain*.gd`): a
    script extension calls `installScriptExtension("res://<ModName>/Code.gd")`, an observer adds a node with
    `Code.gd` (see *The two ways these mods hook in*).
  - `Code.gd` is the mod's main code.
  - A second script extension next to `Code.gd` is named for the screen it changes: CrewCheapHireNotifier's
    `HireScreen.gd` (the Hire screen, `enceladus/HireableCrew.gd`). Code both use goes in `Settings.gd`, which they
    already share (the rule's `limitFor` / `isCheapHire`).
  - `SettingsUI.gd` is the mod's settings UI, when it has one.
  - `Settings.gd`, only in a mod with a settings UI, is the settings model `Code.gd` and `SettingsUI.gd` share, built
    like the game's own `Settings` autoload (`res://Settings.gd`: a `cfg` dict of defaults, a `ConfigFile` in
    `user://`, `loadFromFile` / `saveToFile`, a `settingsChanged` signal). A `const` can't hold a value the player
    changes and Godot 3 has no static variables, so one shared instance holds, for each setting:
    - its current value;
    - its description (key, default, type, range or choices, label keys), so each default is declared once, there;
    - the conversion between the units shown and the ones the code uses (10 world units = 1 m, a fraction shown
      as %);
    - clamping of what is loaded, so a settings file edited by hand can't break the code;
    - saving, with a format version (renaming a saved key without a migration is a major version);
    - a change signal, so a change applies at once.

    The mod's version is read from the zip's `Mod.manifest`, not repeated. Scripts reach the file through a preload
    constant named for the mod, never `Settings`, which would hide the game's autoload (and stacked extensions break
    on same-named constants). Constants that aren't settings (game paths, fallbacks) stay in `Code.gd`. The first
    mod with settings settles the API.

    The API, as settled by CrewCheapHireNotifier (`extends Reference`):
    - `static func shared()`: the one instance, kept as metadata of the script (`load()` of its own path), which every
      script that preloads the file gets as the same cached resource.
    - `const SETTINGS`: one description per setting, in display order: `label`, `default`, `min`, `max`, `step`,
      `unit`, and `shown`, the factor from the stored value to the one shown (a fraction shown as %). `var cfg`: the
      current values by key, set to the defaults in `_init`. `const FORMAT_VERSION`.
    - `getValue(key)`; `setValue(key, value)` clamps, and only on a change stores (`saveToState()`) and emits
      `settingsChanged`; `toShown(key, value)` / `fromShown(key, shown)`.
    - `loadFromState()` / `saveToState()`: settings kept per save game (CrewCheapHireNotifier's)
      live in `CurrentGame.state.ui` (the game's per-save UI store, `setUiValue` / `getUiValue`, written with the save
      as JSON, so numbers come back as floats) under the mod's id from `Mod.manifest`, so other authors' mods can't
      collide; the entry holds `formatVersion`, `modVersion` and one value per setting. Loading starts from the
      defaults and clamps each saved value. A mod whose settings are game-wide uses the `user://` `ConfigFile` above
      instead, with `loadFromFile` / `saveToFile`.
    - `modId()`, `modName()`, `modVersion()`: read from `Mod.manifest` (path: the script's folder) with `ConfigFile`.

    `SettingsUI.gd` builds the screen from `SETTINGS` through `toShown`, with the game's own UI parts, and writes back
    with `setValue(key, fromShown(key, shown))`; `Code.gd` loads the save's values when its scene is built (the
    station is rebuilt after every load and new game) and listens to `settingsChanged`.
  - A mod without a settings UI has no `Settings.gd`, and no constants file either: that would only add a prefix to
    every use.
  - Settings that belong to a ship system go in the game's Tuning screen instead (`registerSubsystem` from the
    system's `onSetup`; LidarLouderPing). The game draws them, keeps them per ship with its tuning (saved with the
    game) and signals a change (`tuningChanged`), so the mod has no stored value, saving or signal of its own. With
    one or two, their default, range and step are constants in `Code.gd`, read through a clamping helper. With more,
    or spread over several game systems, they split into `Settings.gd` (the descriptions and a clamped read from a
    ship; no shared instance) and `TuningUI.gd` (the registration, called from `Code.gd`'s `onSetup`).
  - Settings that change what a game system's own settings already decide follow that system's pattern
    (GeologyByMass): they live in that system's config, next to the game's, under the mod's id from
    `Mod.manifest`, changed in place as the game changes its own, so the game saves, loads and carries them. Then
    `Settings.gd` has one instance per system, made by `Code.gd` (no `shared()`, no `loadFrom…` / `saveTo…`, no
    signal when the game re-reads by itself): the descriptions as constants, getters that never write and give the
    defaults where nothing is stored (clamped, snapped to the step), setters that write only a change, an entry with
    `formatVersion` and `modVersion`, and `modId()` / `modName()` / `modVersion()`. GeologyByMass: the HUD's
    `mineralConfig` (the ship's `hud.config`), next to the Geologist tab's settings.
  - `i18n/<locale>.po` (`i18n/en.po`, …), in a subfolder named as the game's own `i18n/`: the mod's texts in that
    language, loaded by `ModMain.gd` (see *How the game loads a mod*). English is Godot's fallback language, so
    `en.po` covers every language until it gets its own file.
  - CrewPerfectSort, with two extensions and no single main file, keeps its file names for now.
- Tunables are commented `const`s at the top of `Code.gd`, and the README names them as what a user may edit inside
  the zip. In a mod with a settings UI they are settings in `Settings.gd`, and the README names them as settings; a
  Tuning entry's default, range and step stay constants in `Code.gd` (see above), and the README names the entry.
- **A constant's value exists in one place only: where the constant is declared**, so that
  changing it touches nothing but that file. READMEs, manifests, this file, comments in other files and the tests
  refer to a constant by its name and never repeat its value or a figure computed from it. The tests read constants
  from the mod (`_const` in `units.gd`, the instance in `lidar.gd`, the script's constant map in `hud.gd`) and build
  their layouts from them, so another value of a constant still passes. Base-game values a modder would have trouble
  finding may be quoted (the arm's 45 m reach; the game shows 10 world units as 1 m). Known exception, to fix when
  those mods next change: the legends of `ArmAltTargetSelection/TargetSelection.png` and of the two
  `ArmAltPullBehavior` images still show values of their constants.
- Game behaviour a mod relies on is cited with the game file and function it comes from (`Game.gd`
  `_respawn_ship`, `hud/SystemList.gd`). Check it in the decompiled source, not from memory.
- **The version lives only in `[version]` of `Mod.manifest` and in `CHANGES.md`**. It never
  appears anywhere else in the mod: not in the README (whose *Install* step says "the mod's zip" and names neither
  the mod nor the zip), the code, comments or images. Godot's and the game's own versions may be mentioned. The
  version is bumped only at release.
- **`CHANGES.md`**: a mod at 1.0.0 or later gets one in its folder (so it ships in the zip) as soon
  as it changes after 1.0.0. Changes not yet released accumulate in a `## NEXT` section at the top: every
  change to the mod adds its bullets there, while the manifest keeps the released version. At release the section is
  renamed to the new version, so below it there is one section per released version above 1.0.0,
  newest on top. 1.0.0 is the baseline and gets no section, nor do the versions before it: only changes from 1.0.0
  on matter. Entries are short bullets on what changed for a player or a modder (behaviour, fixes, files, constants
  and members renamed or added, README changes); like everywhere else, they name a constant and never repeat its
  value.

  ```markdown
  # <ModName> - Changes

  ## NEXT
  - …

  ## 1.2.1
  - …
  ```
- `Mod.manifest`: `id = "aglezb.<ModName>"`, `author = "aglezb"`, a one-line `description` that only says what the
  mod does (the details go in the README), the `group` tag naming the game script or the part of the game the mod
  touches (`DockingArm`, `Hud`), `manifest_version = 2.2`.
- README layout: `# <ModName> - ΔV: Rings of Saturn`; the summary (no version), with its images, if any; for a mod
  that changes how the game plays in a dive, *Warning*: in short, what it changes compared to
  vanilla, and to check a bug without the mod before reporting it to the game's developers; *What it does and why*
  (What / Why bullets); *For modders* for script extensions (what is extended, overrides, new members, constants, how
  it was tested); *Install* (three steps; the second, the same in every README, is "Put the mod's zip in it, and
  remove any other version of the mod from there: they would all load. Do not unzip it."; the third,
  `--enable-mods`); the "Mods are unofficial … Keep a backup of your save." line; *About* (made with the help of
  Claude; GPLv3). When the behaviour changes, update the README's text, *Warning* and figures too (and the root
  `README.md`, see *What this is*).
