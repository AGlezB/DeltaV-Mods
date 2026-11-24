# Test harness - ΔV: Rings of Saturn mods

The repository's own test harness (it ships in no zip). The folder names and conventions it uses are in
[MODDING.md](../MODDING.md).

`_tests\run.ps1` (PowerShell 7) tests the mods listed below in a headless Godot 3.6, in a few seconds. It assembles
a Godot project in `TempDir\tests\project` from `_tests\`; the game's own `DockingArm.gd`, `Arm.gd`,
`CabinLight.gd`, `Boot.gd`, `LIDAR.gd`, `PitchAdjustedAudio.gd`, `HardwareLabel.gd`, `EnceladusMenu.gd`,
`HidingMarginContainer.gd`, `AnalogControlSlider.gd`, `TuningFloatValue.gd`, `TuningBoolValue.gd`, `TuningItems.gd`,
`Hud.gd`, `OMS.gd`,
`TabsWithGamepadControl.gd`, `PriceLabel.gd`, `RepeatingHSlider.gd`, `MineralLabel.gd`, `MineralSystemToggle.gd`,
`SystemMineralList.gd`, `HireableCrew.gd`, `CrewBio.gd`, `CurrentCrewManagement.gd`, `PlaySoundsOnTheseButtons.gd`, `SystemBuyUI.gd`,
`SystemShipUpgradeUI.gd`, `Dealer.gd`, `Game.gd`, `Enceladus.gd`, `TransponderOnIntro.gd`, `ship-ctrl.gd`, `Reactor.gd`,
`FusionReactor.gd`, `CurrentGame.gd`, `body.gd`, `ClaimOwner.gd`, `ClaimBeacon-1.gd`, `ClaimBeaconForeign.gd`,
`NewGamePlus.gd`, `WeaponSlot.gd`, `PauseLayer.gd`, `PDT.gd`, `Video.gd`, `GravimetricReadout.gd`, `massdriver.gd`,
`TheRing.gd`, `MarginViewportUpscale.gd`, `ViewportWithProxy.gd`, `NoBulletTime.gd`, `CanvasHidding.gd`, `MouseLayer.gd`,
`drone-plant.gd`, `MineralMarket.gd`, `MineralSellSlider.gd`, `MineralPriceChart.gd`, `MarketChartPrice.gd`,
`InGameMoney.gd`, `ServiceUI.gd`, `ServiceUIInsurance.gd`, `ServiceUIFactionChange.gd`, `Repairs.gd`,
`SystemShipRepairUI.gd`, `SpecificDamageLabel.gd`, `ScrollWithAnalog.gd`, `Tool.gd`, `gdunzip.gd`, `MessageLine.gd`,
`Player.gd`, `ConversationPlayer.gd`, `Display-K37.gd`, `ShipOnOMSLabel.gd`, `ShipOnOMSBearingDistance.gd`,
`Shower.tscn`, audio buses (`default_bus_layout.tres`), the skill
icons `CrewBio.gd` preloads and a Fleet entry's Use icon (`enceladus/Upgrades/switch.png`; their `.png.import` and
imported `.stex`, so they load without an import step), copied from the decompiled source on every run and never
committed, since they are the game's; a stub mineral scene with the chunk radius read from the game's; bare stubs of
the two scenes `LIDAR.gd` preloads; and stubs of the Tuning scenes (`TuningFloatValue.tscn`, `TuningItems.tscn`,
`TuningBoolValue.tscn`, with the game's scripts, node paths and connections, and `HeaderWithMoney.tscn`, with your
cash, `Money.tscn`, and the hidden insurance row, both on the game's `InGameMoney.gd`), of a Hire
screen entry (`CrewBio.tscn`, with a portrait stub,
`harness/crew_video.gd`, and the game's tooltip node, `PlaySoundsOnTheseButtons`), of the Geologist tab's parts
(`MineralSystemToggle.tscn`, `MineralLabel.tscn`, `PriceLabel.tscn`, `MineralSystemLabel.tscn`, `PercentLabel.tscn`),
of a Fleet entry (`SystemBuyUI.tscn`, with the
Use and OK icons, the confirmation's frame and margins, the confirmation animations read from the game's scene, the
game's themes for the entry, its labels' grid and its thumbnail margin (`menu/MenuTheme.tres`, `hud/TNTRL-theme.tres`,
`enceladus/Subwindow.theme`, and every font, stylebox and image they load, found by following their `res://` paths),
so its sizes and looks are the game's, its picture's sprite placement and its Buy button's margins read from the
game's scene, and a
flicker stub, `harness/fleet_flicker.gd`) and of an Equipment item (`SystemShipUpgradeUI.tscn`) with the game's node
paths and scripts but no theme, textures or sounds (beyond those named); a stub of the Dealer screen (`Dealer.tscn`)
built from the game's: its root with `Dealer.gd`, its theme, anchors and the node paths the scene sets, the Shower,
and a node at every path `Dealer.gd` reads and at their parents (the game's type, or the root type of the scene
instanced there), with the game's sizes, margins, themes and frames where its scene sets them; its entries are
`harness/dealer_entry.tscn`, the Fleet entry stub with the game's tooltip node. Fleet (`Owned.tscn`) is that stub
with the game's values for it, and `harness/station_dealer.tscn` and `station_owned.tscn` are the two with the
station's (`Enceladus.tscn`: size, size flags, frame, lists); a stub of a ship's hardpoint (`weapons/WeaponSlot.tscn`),
the game's root with `WeaponSlot.gd` and the values it sets, without the systems' placeholders; and a stub of the ring
scene (`Game.tscn`)
built from the game's: its root node with `Game.gd` and the scene's values, the title card player with the game's
autoplay, process mode and `intro`, `exit`, `helpless`, `gameover` and `fasttravel` animations, a node at every path
those drive (the game's type where the scene declares one, the transponder label with `TransponderOnIntro.gd`) and an
asteroid field that records the `despawnAllAsteroids` calls of `exit` and the rescue ship's spawn
(`harness/skip_field.gd`), the masks the scene gives that field, and the cursor's layer with the game's `MouseLayer.gd`
and the scene's fade time (CombatSimulator reads both from the scene's state); the method keys on the root call
`Game.gd`'s own. For CombatSimulator: the simulator's button (`enceladus/Simulator/LaunchVRButton.tscn`, the game's
root with its theme and shortcut, without the key hint), stubs of what its arena instances (`AsteroidField.tscn` on
`harness/combat_field.gd`, `BulletTimer.tscn` on `harness/combat_bullet_timer.gd` with its notifications layer,
`music/Music.tscn` with the game's pause mode, a bare `WESpace.tscn`), a ship scene under `ships/`
(`ships/CombatTestShip.tscn`, `harness/combat_ship.gd`, in the ships group and without gravity, with what the ship list
asks of a ship whose picture it draws, as the Dealer screen stub's ship has), the pirate event at
its game path (`story/PirateCombat.gd`, a copy of `harness/combat_pirate.gd`: the game's preloads its loot), the game's
tooltip node (`menu/sfx/PlaySoundsOnTheseButtons.tscn`: its script, paths and nodes, without the sounds and theme), a
bare stub of the projectile `massdriver.gd` preloads, and stand-ins of the two maps `TheRing.gd` preloads
(`ring/ring-map.png`, `ring-veins.png`): small ImageTextures in text resources that the PNGs' `.import` files point to,
so they load without an import step (the game's map is a 4 MB lossy texture), the map's red growing across it, its blue
down it and its green changing from pixel to pixel. Also bare stubs of the two scenes
`ship-ctrl.gd` preloads (`sfx/WeldingSparks.tscn`, `ships/modules/EVAflight.tscn`) and of the three the story claim
beacons preload (`ships/drone/ClaimBeacon.tscn`, `ClaimBeaconForeign.tscn`, `story/DummyBeacon.tscn`), the game's
ship models (`harness/transponder_models.gd`, written from the keys of `ships` in `ships/Shipyard.gd`), and the
station's fade-in (`Enceladus.tscn`'s `FadeInCRT`) as an Animation resource of its own (`harness/station_fadein.tres`).
For MarketAdvisor: stubs of the Mineral Market (`MineralMarket.tscn`, with the menu theme), its slider rows
(`MineralSellSlider.tscn`), their price charts (`Minerals/MineralPriceChart.tscn`) and the charts' labels
(`MarketChartPrice.tscn`), with the game's node paths, scripts, values and connections. For MarketAdvisor and
ServiceNotifier: stubs of a row of the Services screen, its insurance row and its compensation row (`ServiceUI.tscn`,
`ServiceUIInsurance.tscn`, `ServiceUIFactionChange.tscn`), likewise. For ShipRepairAdvisor: the game's Repairs screen (`Repairs.tscn`,
without its insurance row's sound, which would need an import step), its rows (`SystemShipRepairUI.tscn`) and their
damage labels (`SpecificDamageLabel.tscn`), copied, and bare stubs of the four scenes they instance (`SmoothScrollTo.tscn`,
with the `focusAt` the rows set on it and the `scrollWhenEntering` the comms line sets, `Flicker.tscn`,
`MoveScrollerToMatchThese.tscn`, and `MaintainenceLabel.tscn`, with the game's key). For LidarContactCallout: the
game's comms line (`comms/MessageLine.tscn`), copied, with its theme (`hud/TNTRL-theme-inventory.tres`, followed as the
Fleet entry's themes are) and its light, control hint icon and incoming sound (their `.import` files and imported
resources), and bare stubs of the three scenes it instances: the reply line (`comms/PlayerReply.tscn`, never made), the
speaker's face (`faces/FaceSprite.tscn`, with the `fullName` and `gender` `MessageLine.gd` sets and the nodes the line's
scene edits) and the control hint (`hud/components/ContextSensitiveControlDisplay.tscn`, with the members and nodes the
line's scene sets); the hang-up icon `ConversationPlayer.gd` preloads; and the Pilot tab's label and its bearing and
distance (`hud/components/ShipOnOMSLabel.tscn`, `ShipOnOMSBearingOrDistance.tscn`, `ShipOnOMSBearingDistance.tscn`),
copied. The `CurrentGame` stub holds
the game's market code: the prices drawn from a save's seed and moved by the trades in its log (`state.logs`, which
`logEvent` keeps as the game keeps it where a suite gives the state one), the stored minerals, and the price chart's
prediction error; and the game's crew levels (`translateLevel`), who is in the dive crew (`isCrewMemberActive`) and
the one derived stat a mod reads, the geologist's Price prediction accuracy (`deriveStats`); and the
game's `getMoney`, with the insurance where asked (the Repairs screen's Replace); and, for ShipSaleAdvisor and
ShipRepairAdvisor, the game's `changeMoney` with the insurance paying first where asked, the stored ships' instances
(`ownedShipInstances`, `removeOwnedShipByHash`) and their lock (`shipMutex`), a repair limit a suite sets
(`getRepairLimit`), and the XP given (`giveXp`, recorded); the game's count of the crew by occupation
(`getCrewNumberWithRole`), plus mechanics a suite sets without hiring anyone; and, for LidarContactCallout, the game's
`getCrew` and `isOddity`.
The game's `Shipyard` (which makes the rescue ship, recorded; for the `dealer` suite, the ship models' scenes, aliases
and default configs (`getDefaultConfigByName`, falling back to the base model's, as the game's), and a
`createShipByConfig` that records each config, keeps it and its `config` by reference and, as the game's, registers a
transponder for a config without one; and, as the game's, the build `stripEmpheralsFromConfig` keys codes by,
`getBuildConfigByName`, `createShipBuildByName`, and a `createShipByName` that makes a model with a scene from its
default config), `K2RGB`, `Factions` (with the game's `frozenFactions`, and the dispositions a suite sets, read and
adjusted with the game's `getDispositionTowards` and `adjustFactionDisposition`, for the Services screen's compensation
rows), `Namer` (fixed names: "Ann Bell", a ship name from its seed), `Agenda` (which the game's `CurrentGame.gd` names),
`Achivements` and `Debug` (whose logging the game's scripts call) autoloads are stubs (`harness/stubs/`), with the
`Settings`, `Loader` and `CurrentGame` stubs named above, in the game's order, so the game's scripts that name them
compile. The drone bench (`_bench\README.md`) reuses these stubs and the mod loader, so they also hold what its game
scripts read and what the mods' badges read (`Settings` particle settings, its `control` enum and a `controlScheme` that
emits `controlSchemeChaged` on a change, as the game's, `Factions.noFaction`, `CurrentGame.isInSimulatiorRange`).
`CurrentGame` and `Achivements` also declare the signals the game's notification panel connects, with the game's
arguments, since DiveSkipTransit connects each by its count of arguments. A
script compiled once the autoloads exist has its calls on them checked against the stubs' scripts, arguments included,
so the stubs take the game's arguments (`Shipyard.createShipByName`); one compiled while they are being created, from a
`ModMain`'s `_init`, isn't checked (found with the game's `CurrentGame.gd`). It packages each mod as a release zip is
laid out (MODDING.md *Packaging and releasing*, without the `LICENSE` copy) and loads the zips as `ModLoader.gd` does,
at the same moment (`_tests\harness\loader.gd` is the `ModLoader` autoload, and loads in its `_init`; the autoloads keep
the game's order), so the zip layout is tested too. Logs: `TempDir\tests\logs`. Godot and these folders come from
`paths.local.psd1` (MODDING.md *Folders outside the repo*), or from the parameters `-GodotPath`, `-DecompiledRoot`,
`-GameSource` and `-WorkDir`.

```powershell
.\_tests\run.ps1                                               # every suite, its own mods, the game's order
.\_tests\run.ps1 -Suite moving -AllOrders                      # one suite, every load order
.\_tests\run.ps1 -Matrix                                       # moving: 109.29/330 t ships x 2.8/5 t chunks
.\_tests\run.ps1 -ModZip <a release zip>                       # a release zip in place of the mod's folder
.\_tests\run.ps1 -Suite units -Mods ArmAltPullBehavior         # other mods than the suite's own (@() = none)
```

Call it from a pwsh prompt or `pwsh -Command`: under `pwsh -File`, list arguments such as `-Suite still,moving` are
not parsed as arrays. Exit code 0 = every run passed; a script error fails its run even if every check passed.

The suites are ported from the claude.ai harness (DVModTestHarness 1.0.0; the original was deleted once ported), except
`hold`, `boot`, `lidar`, `hud`, `crew`, `geology`, `fleet`, `skip`, `dealer`, `transponder`, `combat`, `drones`,
`market`, `services`, `sale`, `repairs` and `callout`. `units`, `still`, `moving` and `hold` load the two arm mods by
default, `dive` loads DiveDisableAdrenalineBooster, `boot` loads BootSkipLogos, `lidar` loads LidarLouderPing, `hud`
loads HudHideLabels, `crew` loads CrewCheapHireNotifier, `geology` loads GeologyByMass, `fleet` loads ShipCopyPaste,
`skip` loads DiveSkipTransit, `dealer` loads DealerNotifier, `transponder` loads TransponderAltCodes, `combat` loads
CombatSimulator, `drones` loads DroneAltPriorities and GeologyByMass, `market` loads MarketAdvisor, `services` loads
ServiceNotifier, `sale` loads ShipCopyPaste and ShipSaleAdvisor, `repairs` loads ShipRepairAdvisor, `callout` loads
LidarContactCallout.

- `units` (`suites/units.gd`): the claude.ai unit tests (its `arm/main.gd`) nearly verbatim, on synthetic arms around
  the game's `DockingArm.gd`. TargetSelection: area geometry on turned, scaled and offset arms, reach, the strip, the
  weighted pick, keeping the current target, switch off/on, intake and entry point. PullBehavior: where the pull goes
  (20 cases: feeding or not, grinder or excavator, a block of hull; since 1.6.0 held at the dock slot by the mod while
  not feeding, and while feeding pulled along its path, kept off the hull, or straight in, never outwards, once in line
  with the opening), the EIME's claws, the corridor's edge (pulled straight in exactly while in line with the opening),
  closed beak, switching ship types, cost, a target held at the dock slot while the ship accelerates (pushed along with
  it, never ahead of it, the ship taking the opposite push: the 1.3.0 bug flung it away). Plus 4 checks on the real
  Eagle-Prospector-VP rig, including the hull inertia `moving` uses. A group whose mod is not loaded runs "control"
  checks of the game alone.
- `still` (9 cases, `suites/still.gd`, the claude.ai `arm/real.gd`) and `moving` (16 cases, `suites/moving.gd`, its
  `arm/real_move.gd`): ArmAltPullBehavior bringing a chunk in on a simulated Eagle-Prospector-VP, standing still, held
  in place, cruising at 10–40 m/s or turning, feeding or not; two start points are where the author's in-game logs
  started. Each case expects the chunk in between the rotors, its first touch of one on the inner side (facing the gap)
  and never on a rotor's outer half (the harness's rotors don't collide, so the case ends at that touch), held at the
  dock slot, or moved straight forward first and then held there, the mod never handing it back to the game's pull, and
  prints how long it took. The feeding cases behind the red line beside the hull also have a time limit (1.5.0's times +
  25 %, below 1.4.0's), so a slow-down fails.
- `hold` (`suites/hold.gd`): ArmAltPullBehavior holding a chunk, and feeding it, while the simulated
  Eagle-Prospector-VP turns and accelerates, flown by a strong autopilot (the commanded turn rate ramps up at a set
  rate). The arm's limits are worked out from its own values (its strength, the fastest turn it can hold a target
  through at the dock slot and held closest, the most linear and turning acceleration) and printed; each case is a
  share of them. Holding: turning at up to 100 % of the limit (130 % held closest), spinning up faster than the arm can
  follow, turning back and forth, accelerating forwards, backwards and sideways, turning while braking: the chunk
  settles within a chunk's radius of where it is held (closer in while the ship turns or brakes) and is back at the
  dock slot after, or, where the ship's motion outruns the arm for a while (spinning up too fast, turning back and
  forth, turning while braking, 120 % of the linear limit), is kept and back at the dock slot after; an 11 t target
  (over the mod's mass limit) is held at the dock slot, never closer. A
  chunk grabbed ahead-left or off to the side, then the ship turning, comes to where it is held and stays there.
  Feeding, from five starts with the ship still, turning, braking, accelerating, and turning while braking: in on a
  rotor's inner side. Distances allow for the harness's one-frame offset (the ship is moved before the physics step,
  the chunk during it, so the mod sees the ship a frame ahead): the ship's speed at the point times a frame; feeding
  while turning and braking starts at 20 m/s forward to keep that offset small. Combinations beyond the arm's strength
  even held closest, and a 15 t target turning while braking, are notes, not checks. And while the mod pulls, the arm's
  power (its OMS entry) shows what the pull draws, by the game's formula.
- `dive` (`suites/dive.gd`, the claude.ai `dive/main.gd`): the player's Adrenaline booster (the game's `CabinLight.gd`)
  starts disabled; another ship's booster, other cabin-light systems and a light with no ship are untouched; switching
  it on sticks; it gives adrenaline only when enabled. The control check (the game alone starts it enabled) runs on the
  game's own script, the base of the extension, so it needs no separate run.
- `boot` (`suites/boot.gd`): runs with `_tests\harness\boot.tscn` as the main scene (a scene path on Godot's
  command line), whose root has the game's `Boot.gd`, so the engine loads it after the autoloads, as the game loads
  `Boot.tscn`. Checks that this startup scene got the extension, runs the game's own start-up and then asks for the
  title screen; that the first launch (`Settings.firstBoot`) keeps the logos; and, as control, that the game's
  script alone does not leave them. A `Loader` stub records the calls instead of switching scenes.
- `lidar` (`suites/lidar.gd`): hidden LIDARs built in code around the game's `LIDAR.gd`, with a `Bleep` on the
  game's `PitchAdjustedAudio.gd` that records each `play()` (`harness/recording_bleep.gd`), under stubs of the HUD and
  the ship (`harness/lidar_reader.gd`, `lidar_ship.gd`). Checks that the slider is registered right below the Tuning
  switch, in its group, with the mod's range, and stays there; that its value (clamped, the default for a non-number)
  moves the ping to the mod's bus, which sends to its own bus (`ShipBowels`, or `SFX`) with the gain, and a gain of 0
  back to its own bus; that the bus is shared, not added twice, and that a LIDAR without a ping is left alone; that
  the switch still sets `doBleep`. The demo, on a preview's LIDAR (`dynamicConnect`) with a synthetic sound, driven
  frame by frame with the game's `TuningFloatValue` row focused: the game's volume and pitch for each distance, the
  spacing and the interval, the preview's own pings muted, nothing with another row, no focus, the switch off or a
  LIDAR that isn't a preview's. And the texts of `i18n/en.po`, also in a language without them. The control checks (the
  ping stays on its bus) run on the game's own script.
- `hud` (`suites/hud.gd`): trees built in code with the node paths and types of the OCP-209's HUD
  (`hud/Display-OCP209.tscn`), the station's Equipment screen and the OMS (`hud/OMS.tscn`), each scene root
  marked by its `filename`; the HUD is added in one go under stubs of the ship and its Hud (the `lidar` suite's),
  as `Hud.gd` `instance()` does. Checks that each title on the HUD (and the feed sub-scene's) is hidden from the
  first frame when its key is in the mod's `HIDDEN_KEYS` and drawn when not, also the LIDAR's, which the game's
  `HardwareLabel.gd` renames in its `_ready`; that hidden titles keep their space; that other labels, a button with
  a title's text and the same titles outside a `Display-*.tscn` are drawn; and that a title added later follows
  `HIDDEN_KEYS` too. The control checks (with `-Mods @()`): every title is drawn.
- `crew` (`suites/crew.gd`): station menus built in code around the game's `EnceladusMenu.gd`, nested as
  `enceladus/EnceladusMenu.tscn` nests them (a `Crew` and a `Logs` Button), with the hire list and the crew set in the
  `CurrentGame` stub and a test translation in two languages. Salaries and slider values are built from the
  descriptions in the mod's `Settings.gd` (`SETTINGS`) and the jobs from `CurrentGame.occupations`; expected texts
  with `tr()` from the mod's keys. Checks that the Crew entry is marked from the first frame; the
  rule's edges (at and above the threshold, which the tolerance never moves either way, also within the tolerance
  above it; at, within the tolerance of, at the end of and above the best-paid member's salary in that job; the
  threshold above a best-paid below it even after the tolerance; the tolerance clamped to its minimum, and there a
  hire at the best-paid salary times it, above it and, when negative, at the best-paid salary itself; another job);
  the crew limit (a job below it judged as usual; a limit lowered to the crew hired fills the job at once; in a full
  job a hire at the best-paid salary not marked and one below it marked, the threshold and the tolerance at its
  minimum ignored; another job judged as usual; benched and on-leave crew counted; a limit of 0 with nobody in the job
  and with someone; firing frees the job and hiring fills it);
  that `dayPassed` and `employmentChanged` refresh it both ways and an unmarked entry gets its key back; that a marked entry follows a language change; and
  that the other entries, a menu without `Crew` and the game's `disable()` are untouched. The settings model: one
  shared instance; the crew limit per job, for each of `CurrentGame.occupations`, and the salary settings not;
  defaults for a save without the mod's entry, every crew limit at its maximum; a save from before the crew limit;
  a tolerance saved as a dictionary by job read as the default; clamping and snapping of what is loaded or set, also per job,
  and a job missing or not a number in a saved dictionary, or a crew limit that is not one; saving into
  `CurrentGame.state.ui` under the manifest's id, with the format and mod versions and every job, a job's change
  stored for that job only and as a copy, and a signal only on a change; the % conversion. The texts of
  `i18n/en.po`, also in a language without them. The Hire screen: the Hire tab built as `enceladus/Crew.tscn` nests it, around the game's
  `HireableCrew.gd` and `CrewBio.gd`, with a theme holding a Button font color and a flat frame with an overbright
  border, and the menu beside it. Each qualifying person's entry, at and below the limit, has a visible badge:
  above the details grid's values, right-aligned with them, one grid row gap above, at its minimum size and inside
  the entry; the capitals of the manifest's name, then how many of that job are hired out of its crew limit, as the
  mod's text formats them, in the Hire button's font color times `colorBetter`; a copy of the
  Hire button's frame with a `colorBetter` border, the theme's frame unchanged; letting the mouse through; a mouse
  moved onto it through the scene tree's input (after `NOTIFICATION_WM_MOUSE_ENTER`: without it, a window-less Godot
  3.6 sends no control the mouse's enter) shows the limit for the job in the game's tooltip (the entry's
  `PlaySoundsOnTheseButtons`), which took over its `hint_tooltip`, and moving away hides it; the Hire button untouched
  and the entry's height unchanged. Above the limit, no badge; the menu is marked exactly when an entry has one. A new
  day judges kept entries again, one badge each; firing (`employmentChanged`) hides it; hiring there gives another
  pilot one with the new limit; a setting shows and hides it; in a full job the tooltip tells so, with the best-paid
  salary, and gives the limit again once there is room; every badge reads, and every tooltip has a second line with,
  how many of that job are hired (benched and on-leave crew too) out of its crew limit; a shorter text (the lower
  crew limit) shrinks the badge to its minimum size, still right-aligned, a frame later (the controls' deferred size
  updates); the tooltip follows a language change. A new entry is
  hovered a frame after it is made, once its containers have laid it out. With CrewPerfectSort loaded too (`-Mods
  CrewCheapHireNotifier,CrewPerfectSort`), the list is sorted and the badges stay; and the derelict conversation's
  EVA choice, from the game's `CurrentGame.gd` with the extension, instanced out of the tree (its `state` set from
  `initialState`, as entering the tree would): `getSpecificMemberNr` gives the crew aboard by job, then salary, then
  name, from crew hired in another order, without the benched and on-leave crew, and nobody past the last, while
  `getActiveMembers` keeps the hire order. Then a station built as
  `enceladus/Enceladus.tscn` nests it (the menu, and the game's `HidingMarginContainer.gd` with stubs of the Crew and
  Tuning screens, `harness/crew_screen.gd`), clicked through the scene tree's input: the tooltip, on the entry's Shift
  badge (the entry has none of its own), also after a language change; Shift+Click opens the settings and not the Crew
  screen, a plain click the Crew screen, a disabled entry nothing; the screen copies Tuning's frame and place; it has
  two groups in an `Items` box right below the header (the settings that are not per job, then the crew limit, one row
  per job named by its key, in alphabetical order of the jobs' names whatever the case, and in a second language that
  language's order; test names for all four jobs in both), each row with its range, step and value (each job's own);
  each crew limit row's value shows how many of its job are hired before its limit, as the mod's text puts them (more
  pilots hired than their limit, as many mechanics as theirs, nobody else), also once its slider is moved, in the game's
  `CrewBio.gd` worse-stat colour over the limit, its better-stat colour at it and the game's own under it, on opening
  and as the mechanics' slider moves through all three, and the other rows show theirs as the game does; opening it
  stores nothing; moving a slider (the threshold, the tolerance, the pilots' crew limit) flips the mark at once and
  stores the value (the pilots' only); reset; Esc (handled, so `harness/unhandled_probe.gd`, standing in for the pause
  menu, doesn't get it), the controller's B and Start, and focusing another entry close it; after a JSON round trip of
  the state a new station has the saved values; and without a Tuning screen there is no tooltip and Shift+Click is a
  plain click. Keys and buttons are sent as real input events in the idle part of a frame, with the game's bindings: a
  bare `InputEventAction`, or one sent during physics, doesn't make `Input.is_action_just_pressed` true. With a gamepad
  (the `Settings` stub's `controlScheme` set as the game sets it): the Shift badge reads the gamepad twin and its
  tooltip tells about it, and both go back with keyboard and mouse; `PAD_BUTTON` alone, and the twin (`PAD_BUTTON` while
  `PAD_MODIFIER` is held) on a disabled entry or with another entry highlighted, do nothing; the twin on the highlighted
  entry opens the settings and not the Crew screen, and B closes them, the entry highlighted again; the Shift badge's
  tooltip shows on hover with keyboard and mouse, and moving away hides it, and not when the entry gets the focus (a
  click, the keyboard), and with a gamepad while the entry has the focus, in its gamepad wording, hidden once the focus
  moves on (`suite.gd` `shiftBadgeTipChecks`); a Hire screen entry's badge shows its tooltip while the entry's Hire
  button has the focus, only with a gamepad, and hides it when the button loses it. The settings screen: the
  description's window under the header, a description in `i18n/en.po` for every setting (its label and
  `DESCRIPTION_SUFFIX`), the first row's on opening and the crew limit's on its rows. Also a tolerance below its minimum
  clamped, every job's crew limit at its default, also from a save without the mod's settings, a menu without a Crew
  entry left alone, and one shared settings instance. The control checks (the entry keeps its key; a Hire screen entry
  gets no badge) run on the game's own scripts.

- `geology` (`suites/geology.gd`): the tab on HUDs from `harness/geology_hud.tscn` (the game's `Hud.gd`, with an
  `Inventory` placeholder of `harness/geology_oms.tscn`: the game's `OMS.gd` and `TabsWithGamepadControl.gd` over the
  OMS's four role tabs) on `harness/geology_ship.gd`, a ship stub whose `isValidMineralTarget` records each call in
  place of the game's rule; the OMS is built on the ship's `instance` signal, as the game builds it. The rule on ships
  of the game's `ship-ctrl.gd` (with the mod, its extension), given their script out of the tree (their `_ready` never
  runs), with the HUD's row as their `hud.config`; where the game decides, each answer is compared with the same ship
  on the game's own script (the bottom of the script chain, whatever extends it). The Geologist tab: a list of the
  game's `SystemMineralList.gd` (with the mod, its extension) added to that OMS's Geologist tab, where the game nests
  it, building its rows on the stub ship's `systemsChanged` (`getSystems`): the HUD itself, and stubs
  (`harness/geology_system.gd`) of an arm and of a cargo container's dock (`onlyMinerals`). The line on the geologist
  reads the crew from the `CurrentGame` stub's `state.crew`, with the game's `isCrewMemberActive`, `translateLevel` and
  the geologist's line of `deriveStats`. The mod's settings descriptions come from its `Settings.gd`. Checks that the
  tab comes right after the Geologist tab, titled by its key, once however often the OMS is built, and that opening it
  stores nothing; its switch, with its label at the mod's spacing (once laid out); a grid of four columns, one row per
  mineral of the market, H2O too, in the Geologist tab's order: the mineral's switch (the Geologist tab's, showing the
  stored state, at first the game's own for a new row: every trace mineral on, H2O off), its name, its least mass
  slider (the Geologist tab's parts, the mod's range, step, unit, format, tooltip and bar width, also once laid out)
  and what that mass is worth at the day's price; the switches and the sliders store what they show, the worth follows
  its slider, and the day's price each time the tab shows; the switch dims the rows; choosing the tab focuses the
  switch. The line under the grid: the warning with nobody aboard, and with only a Pilot, a Geologist not in the dive
  crew or one on leave; a Geologist's Education level and the most error the game's estimates have at that level, for
  every level (found by trying talents across it); the best Geologist in the dive crew among several; brought up to
  date each time the tab shows. A HUD without mineral targeting gets no tab. The HUD hands every chunk to its ship with
  its own row, the switch on. The rule, with the HUD's row: off, the game decides; on, below, at and above a mineral's
  least mass; H2O, switched off on the tab at first, refused however much, even in a row with it; switched on, passing
  the HUD's row, which can't switch it on; the row's own switches ignored both ways (a mineral switched on on the tab
  passes a row without it, one switched off doesn't count in a row with it); one of two minerals enough; the value and
  Minimum value ignored both ways (a cheap chunk the game refuses passes); each mineral's own mass; every mass at its
  minimum; every switch off. With an arm's or drone plant's row (H2O switched on, its own Minimum value and albedo):
  H2O still only once switched on on the tab; an identified chunk the game refuses for its value and albedo passes; the
  game decides a chunk not yet identified (by the row's albedo, both ways), a row without mineral targeting, another
  ship (its AI target, both ways) and the switch off again. The Geologist tab: off, as the game shows it (the HUD's and
  the arm's Minimum value, not the dock's; each row's mineral switches), and that column's title as the game's, taking
  focus; on, once the tab shows, the HUD's and the arm's mineral switches disabled and dimmed with the list's
  `modulateDisabled`, still showing their state, their Minimum values still shown with their values, dimmed, the
  value's button disabled and the bar not draggable; the dock's row, the Minimum Albedo controls, the title and the
  list's width as the game set them; A (`ui_accept`) changes nothing on a disabled switch and doesn't open a disabled
  Minimum value's bar; nothing stored; off again, every control back as the game set it, with its value, and A opening
  the arm's bar again; rows built anew while on, disabled at once; another ship's tab as the game. The settings model:
  defaults for a ship without the entry (the switches the game's own for a new row); reading and unchanged sets store
  nothing; the mineral list, every mineral of the market whatever the HUD's `onlyMinerals`; clamping and snapping of
  what is set or hand-edited, a switch that isn't a bool and masses or switches that aren't a dictionary giving the
  defaults; the entry in the HUD's `mineralConfig` (the ship's `hud.config`) under the manifest's id, with the format
  and mod versions and every mineral's mass and switch, the game's keys untouched; a JSON round trip; a format-1 entry
  (`minMass`, read as the least masses) and a format-2 entry (`baseMass` plus each `extraMass`, the base alone without
  one, capped at the slider's most), reading storing nothing, and the rewrite on the first change. A preheated ship
  (its HUD builds the OMS before loading `mineralConfig`) gets the tab with its stored values. And the texts of
  `i18n/en.po`, also in a language without them. With DiveSkipTransit too, in either order (both extend
  `ship-ctrl.gd`), the same checks pass. The control checks (the OMS keeps its four tabs; the HUD asks its ship with its
  own row; the ship judges by value against the Minimum value; the Geologist tab shows the HUD's and the arm's Minimum
  value, not the dock's) run on the game's own scripts. With a gamepad: each mineral's switch carries its description,
  taken in by a game's tooltip node of its own, which shows it when the switch gets the focus, and each slider's value
  its own; up, left and right stay on the switch at the top; down goes from it through each mineral's switch and stays
  on the last; right goes from a switch to its row's value and stays there, left back and stays there; down goes
  through the values and stays on the last; up goes back through either column, and from the first row to the switch
  at the top; and walking the tab changes nothing.
- `fleet` (`suites/fleet.gd`): Fleet entries built from the stub `SystemBuyUI.tscn` (the game's `SystemBuyUI.gd`) as
  `Dealer.gd` `doAddShips` makes them, under a Fleet screen stub (`harness/fleet_screen.gd`, which records
  `shipChanged` and `addShips`, and the Esc presses that reach its `_input`, once per frame, as `Dealer.gd` closes the
  screen on them) and beside a market entry and an Equipment screen stub (`harness/fleet_equipment.gd`:
  `getItems`, and a count of `updatePricesAndAvailability`) holding the game's `SystemShipUpgradeUI.gd` items, whose
  prices the suite sets as the game does (`setValuesDiscount`); the ships are `harness/fleet_ship.gd` (the game's
  config accessors, a recording `clearDamageInSlot`, and `getSystems`), the current one with equipment that has Tuning
  settings (`harness/fleet_system.gd`, and `harness/fleet_slot_system.gd` for a piece on a slot, with its
  `slotName`), the game's state the `CurrentGame` stub's (`state.ship`, `state.garage`, money, log, maintenance; a
  `validateEmployment` that records the crew list it would put aboard).
  Checks that the market's entry gets nothing; every Fleet entry gets Copy, then a spacer, right before Use, Copy a copy
  of Use; Copy shows on the other ships' entries, the spacer on the current ship's (Copy's size, the mouse and the
  focus passing by), so the details and Use sit at the same x on every entry; Copy enabled on another ship of the
  current ship's model, disabled on another model with the tooltip saying why; Copy's icon has the Use icon's size,
  flags and colours (light strokes, dark edge), and differs from it; switching ships swaps Copy and the spacer. The
  comparisons: no crew list is no crew; values by what they hold (arrays in any order, ints as floats); a piece kept
  keeps its own Tuning entries, and loses the copied ship's where it has none. The dialog: a disabled or hidden Copy
  opens nothing; Copy reprices the Equipment screen first, then opens a `ConfirmationDialog` without a title, a child
  of the copied ship's entry, its Buy confirmation untouched, without switching ships; in the menu theme's window
  frame, with the game's OK and CANCEL, Cancel focused; the question naming both ships in the menu font; then the rows
  (the game's Tuning switch, named by the mod's texts, without its reset button, never clipped), a switch on each when
  every part differs; under Equipment, each piece bought by its Equipment name with its price (a missing LIDAR read as
  the ship's default and a missing number as none), the total and the repair time, costs in the Fleet screen's colour
  for a cost, right-aligned with the switches, in the prose font (the entry's `HBox/Margin`, `Subwindow.theme`); the
  dialog on the screen, centered, at its least size; the rows and the list only as wide as they need (`COLUMN_GAP`
  between names and values), centered under a one-line question; the entry's width kept. Cancel closes it, the focus
  back on Copy, nothing changed; Esc (a real key press, with the game's bindings) closes the dialog only, the Fleet
  screen not getting it, and with the dialog closed reaches the screen. With the equipment on and too little money, OK
  reads Insufficient funds, disabled, and pressing it does nothing; the equipment off, OK again. Reopened, every switch
  is on; the D-pad goes up from Cancel through the switches and back, changing none; a switch turned off stays off when
  it gets the focus again. A price changed while it showed makes OK show the new plan without pasting. Pasting every
  part: the money, each piece fitted (damage cleared, value set) at `getNetPrice()`, pieces already the same left, the
  repair time from now and not the copied ship's, the log as the Equipment screen logs it; the tuning, mineral
  targeting, slot configs and crew list copied, the crew put aboard at once (`validateEmployment` after the list is
  written); identity, damage, cargo and consumables kept; the copied ship untouched; then `shipChanged` and
  `addShips`, the dialog closed and the focus on Copy. A refund (positive, in the colour for a gain, no repair time when
  the piece replaced isn't damaged), with the settings reading Same where the Tuning screen shows the same (a value
  stored on one ship only, at its default snapped to its step). Settings that differ only in the bought piece's Tuning
  entries read Same with the equipment off (the list stays, OK disabled with nothing on). The equipment off and the
  settings on: nothing bought, logged or added; the tuning copied with the ship's own entries for the piece kept, whose
  slot keeps its config; the same crew not put aboard again. Pieces not sold or not available: Incompatible equipment
  in place of the switch, and only those pieces listed with the reason (a system by its name, a number by its slot).
  The crew: a copied list naming someone fired since puts aboard only those still employed; a copied ship without a
  list has no crew, and OK leaves an empty list, put aboard, after which the crew reads Same; the same crew in another
  order reads Same. A long question wraps at `MAX_WIDTH_SHARE` of the screen, the rows as narrow as before; the same
  ship reads Same on every row, with no list and OK disabled; an empty slot and its default item (None) count as the
  same, either way round; the copied ship sold, or the Fleet screen closed, closes the dialog (Copy disabled). The texts
  of `i18n/en.po`, also in a language without them; the entries' script keeps the game's path. With a gamepad: the
  entry's tooltip node takes Copy in, a disabled Copy shows why when it gets the focus, and the D-pad goes from Use to
  Copy and back. The control checks (no Copy or dialog) run on the game's own script.
- `skip` (`suites/skip.gd`): a dive's cutscenes, the station's fade-in, and the settings, with the game's bindings for
  `cutscene_ff`, `pause` and `ui_cancel`. The mod's settings file is pointed into the suite's own project
  (`filePath`) and removed at the start and the end; a Directory opened on `res://` sees the mounted zips, read-only,
  so it is opened on the project folder's own path. The launch:
  stations built in code around the game's `Enceladus.gd` (given its script once in the tree, so neither its `_ready`
  nor its processing runs), with the three players, the ring scene's path and a ship stub; the Loader stub records the
  calls. Checks that the game's own launch runs first (the ship's `instance` signal, the `launch` signal, the ring
  scene prepared, the ship's power handler connected), that the station then goes to the ring scene at once, and that
  both sequences are stopped. The arrival: the ring scene stub instanced as the station loads it, with
  `harness/skip_ship.gd` as the player's ship (`CurrentGame.recreatePlayerShip`; the game's `drawReactiveMass` and
  `getRemassRequiredForDv`, a transit to the rings that costs remass and time), holding nodes of the game's reactor
  scripts: a running fission reactor, one switched off but still at its `coldLimit`, one switched off below it, one
  exploding and a fusion reactor, each with its own turbine consumption. Checks that the scene gets the extension;
  that the ship starts at the position and speed the cutscene's braking leaves it (from the scene's own values) and
  the title card is at its end, hidden; that the game's `_process` ends the cutscene on its first frame, with the ship
  already facing where the game turns it; and that after the ship's `setup` the remass charged is the transit's plus
  the braking (`getRemassRequiredForDv`, the mod's `UNITS_PER_METRE`) plus the turbines of the running and
  still-hot fission reactors only, and the time charged is the transit's plus `totalCutsceneTime`. The exit: the ship
  set up, then leaving as `escapeTheRing` leaves (its escape velocity, the cutscene), with four
  `harness/skip_thruster.gd` thrusters (ahead, angled, sideways, behind; the game's `getThrust` and `getChoke`), the
  ship being `CurrentGame.getPlayerShip`, which `interlunarToEnceladus` charges. Diving back from a full stop on a ship
  that reaches the escape speed within the cutscene, and overspeed heading into the rings on one too weak to: checks
  that `exit`'s calls run at once, in order (the transit, the asteroids, then the station once, saved once); that the
  transit is charged from what the departure's first stretch leaves, and the end remass is the departure's burn, the
  turbines and the transit, both against the suite's own working of the game's formulas (the thrusters' push and flow
  at full throttle along the ship's forward axis, each at its alignment; the rocket equation; the stretches between
  `exit`'s method keys, read from the animation); that the first burn stops at the escape speed and the second lasts
  the whole cutscene; that the time charged is the cutscene's plus the transit's; and that the title card is left at
  its last frame, black. The rescue: a ring whose ship goes helpless one frame short of `helplessTimeLimit`, so the
  game's `_process` sets the rescue up (the cutscene on, the reactor off, the cargo claimed) and plays `helpless`:
  checks that the rescue ship is made (`MADCERF`, `helper`) and spawned and the station loaded at once, saved once;
  that the in-game time is charged stretch by stretch (the stretches between `helpless`'s method keys) around the
  game's stranded time; and that the title card is left black. The game over (`CurrentGame.gameOver`): the title screen
  at once, a second signal changes nothing. The notices: stand-ins for the game's notification panel
  (`harness/skip_notices.gd`: an `AnimationPlayer` that plays a notice in real time whatever the time scale, as the
  game's does, and handlers of the game's names that record their calls) where the ring scene and the station hold it
  (the mod's `_DST_NOTICES` and `_DST_STATION_NOTICES`), each notice signalled as the game signals it (by default
  `CurrentGame.newShip`, the salvage). The exit with a notice showing: the cutscene's calls run, the station at once,
  once, saved once; the notice handed to the station's panel, its handler and what the game signalled; the ring's panel
  hidden and stopped; the costs as without it. After a notice shown in full, nothing handed on and the panel left
  alone. With every notice of `NOTICES` signalled: each handed on, in order, with its handler and the signal's
  arguments. The rescue with a notice showing calls the rescue ship and hands it on; the game over hands nothing on
  (the title screen has no panel). The station, its fade-in skipped and played: each notice handed on goes to its
  panel's handler, in order and once; with nothing handed on, the panel gets nothing. The control check: the game alone
  hands nothing on, even with a notice showing. Astrogation: ships of the game's `ship-ctrl.gd` (with the extension),
  given their script once in the tree and static, so neither processing nor physics runs, with a running fission
  reactor, a stub thruster, mass, remass and speed, and a body beside them; checks that `fastTravelTo` doesn't yield,
  lands the ship at the game's arrival point plus the drift after the jump (the mod's wait constants), folds space as
  the game does (the body moves by the jump, the ship doesn't), leaves the game's end state, signals `fastTraveling`
  but never `cutscene`, and charges the travel time and the waits, the turbine over the waits and the change to the
  travel velocity (`getRemassRequiredForDv`); that another ship's is the game's (it yields); and that the ring's
  `fasttravel` card is jumped to its end. The station's fade-in: a station with the menu where `Enceladus.tscn` nests
  it (the game's `EnceladusMenu.gd`, its entries disabled) and the game's `FadeInCRT` (the tracks whose nodes it lacks
  removed), whose extension `_ready` is called as the engine calls it after the base's: the menu enabled at once, the
  animation at its end. The settings model: defaults, in a dive's order, the transit's two in a group of their own; a
  change stored and signalled once; the file written at once, its section named by the manifest's id, with the format
  and mod versions; read back by a new instance; a value that isn't a switch's gives the default, also in a
  hand-edited file; the speed snapped to its step, kept in its range, its default for anything not a number; a
  format-2 file's arrival and exit switches becoming the transit's (skipped only if both were). Each switch off: that
  sequence plays (the launch; the transit both ways, the arrival under its title card at the game's speed, only the
  transit to the rings charged, the exit with nothing charged yet; astrogation with its waits and its card; the rescue
  and the game over, nothing called yet; the fade-in, the menu disabled) while the others are still skipped. The
  transit's speed, with its switch off: at a speed up to the game's Space speed (`_DST_SPACE_SPEED`, read from the
  mod), the arrival's time scale follows the speed tapered to 1x, the physics rate stays the game's, the sound on, and
  holding Space gives the game's own (higher) speed; when the arrival ends (idle frames: at a raised rate several
  physics frames fit in one), the game's rate, sound and normal time. At the most (`transitSpeed`'s `max`), the rate
  raised to keep the Space speed's step size, the master bus muted, a reset of the rate (as `Settings.gd`'s) undone
  before the next frame's physics, the exit at the full speed, and leaving the scene putting everything back. At the
  most, with the salvage's notice showing as the exit starts: one three times what the exit leaves the panel (its
  length over the speed) hides and stops the ring's panel at once, and the station loads as soon as the exit is over,
  once, the notice handed on; one a third of it plays to its end in the ring, and nothing is handed on; with one of 0.6
  of it, a second (`lostShip`) halfway through the exit no longer fits, hides the panel then, and both are handed on.
  The screen: a station built as `enceladus/Enceladus.tscn` nests the menu (the game's
  `EnceladusMenu.gd`, with a `RingDive` entry whose `pressed` the suite records) and the right-hand screens (the game's
  `HidingMarginContainer.gd` with a Tuning stub), clicked through the scene tree's input: the texts of `i18n/en.po`
  loaded; the tooltip, on the entry's Shift badge (the entry has none of its own); a plain click launches, Shift+Click
  on a disabled entry does nothing, Shift+Click opens the screen without launching; a group per `GROUPS` entry, in
  order, titled by it, with a game's row per setting of that group named by its label in the game's language, each
  switch showing its setting, under the entry's text; the switches of the settings with `remass`, and only those, end
  with `REMASS_MARK`; under the header, in this order, the description's window, the note that explains the mark
  (`REMASS_NOTE`) and the groups; the window copies the Tuning screen's (the stub has one nested as
  `enceladus/Tuning.tscn` nests it: theme, margins around and inside, panel); every setting has a description in
  `i18n/en.po` (its label and `DESCRIPTION_SUFFIX`), the window shows the first row's on opening, that of each row
  focused in turn (switch or slider) and that of a row changed, and keeps its height whatever the description; the
  transit's speed is a game's slider with the setting's range, step, unit and format, dimmed (`DIMMED`) while the
  transit is skipped and not otherwise, storing what it is moved to, its reset button restoring the default; switching a
  switch off stores it at once, focusing it again doesn't switch it back, its reset button restores the default; Esc
  closes it after the fade. With CrewCheapHireNotifier loaded too (`-Mods CrewCheapHireNotifier,DiveSkipTransit`), the
  menu also has its Crew entry: Shift+Click on each opens its own screen and hides the other, and each entry's Shift
  badge keeps its own tooltip. The control checks (the launch keeps playing and doesn't go to the ring; the ship spawned
  for the cutscene, which goes on under the title card; only the transit charged; the exit, rescue and game over
  cutscenes play and call nothing yet; astrogation yields; the station's menu stays disabled) run on the game's own
  scripts. With a gamepad (the `Settings` stub's `controlScheme` set as the game sets it): the Shift badge reads the
  gamepad twin and its tooltip tells about it, and both go back with keyboard and mouse; `PAD_BUTTON` alone, and the
  twin (`PAD_BUTTON` while `PAD_MODIFIER` is held) on a disabled entry or with another entry highlighted, do nothing;
  the twin on the highlighted entry opens the settings and doesn't launch, and B closes them, the entry highlighted
  again; the Shift badge's tooltip shows with a gamepad while the entry has the focus, in its gamepad wording, hidden
  once the focus moves on, and not when the entry gets the focus with keyboard and mouse (`suite.gd`
  `shiftBadgeTipChecks`; the hover is checked in `crew`).

- `dealer` (`suites/dealer.gd`): stations built in code as `enceladus/Enceladus.tscn` nests the menu (the game's
  `EnceladusMenu.gd`, with its `ShipMarket`, `OwnedShips` and `Logs` entries, and the Crew, dive, Mineral Market and
  Services entries of CrewCheapHireNotifier, DiveSkipTransit, MarketAdvisor and ServiceNotifier when they are loaded
  too, with the Mineral Market stub for MarketAdvisor's and a Services screen with The Twins' row for ServiceNotifier's)
  and the right-hand screens (the game's
  `HidingMarginContainer.gd` with the station's Dealer and Fleet, from `harness/station_dealer.tscn` and
  `station_owned.tscn`, on the game's `Dealer.gd`, wired to their entries as the scene wires them, and a Tuning stub
  with its description window). The dealer's stock is the `CurrentGame` stub's (`forSale`, `harness/fleet_ship.gd`
  ships), refreshed as the game refreshes it (`hourPassed`); the ship models are the suite's own scenes
  (`harness/dealer/*.tscn` on `harness/dealer_ship.gd`) under the game's model keys, two of them variants (one
  inheriting its base's scene), with test names in two languages, in a different order in each. Their hardpoints are
  the game's `WeaponSlot.gd`, inline (one nested) or as placeholders of the hardpoint stub, one leaving its slot to the
  scene, beside a placeholder of another scene that stores a slot. `dealer_ship.gd` counts its instances; keeps its
  config by reference and reads and writes it as `ship-ctrl.gd` does, with what the game's hardpoints ask of their ship;
  is set up two physics frames after it enters the tree; and records the config it enters the tree with and its
  viewport.
  Clicks go through the scene tree's input, keys as real input events with the game's bindings. The settings model:
  one shared instance; the models (the mod's `NEW_STOCK`, then the pool, each once, only those with a scene); a
  variant's series; each model's names, read from its scene, the scene it inherits from, or (made once) an instance,
  and no ship made for the others; every ship's switch off by default, New and Used on; a value that isn't a switch's
  giving the default and storing nothing; storing under the manifest's id with the format and mod versions, the ships
  seen, New and Used, signalling once, a copy; switching Used off stored; a JSON round trip; a hand-edited entry
  (switches, ships seen) read safely, and one without New or Used, or with a value that isn't a switch's, giving their
  defaults. The rule: the stock reaches the
  model at the game's refresh; switching a model on with a ship of it for sale doesn't mark the entry; a new ship of a
  model switched off, or one the player sold, doesn't; a new ship of a model switched on does, also in a second
  language, with the tooltip; switching the model off unmarks it, and on again doesn't mark it; a later ship does;
  Fleet's refreshes and opening change nothing and its entries get no badge; a plain click opens the Dealer screen,
  which clears the mark at once and sees every ship; the ship that marked gets a badge and no other, also after the
  refresh the opening makes; the badge (the manifest name's capitals in the Buy button's font colour times the Owned
  label's, in the font a Label gets in the entry's picture, smaller than the name's, a copy of the Buy button's frame
  with its border in that colour, letting the mouse through to the entry's name, at the right end of the name inside
  the right margin around its text, centred from top to bottom, at its least size, its tooltip registered with the
  entry's `PlaySoundsOnTheseButtons`);
  ships no longer for sale forgotten; badges kept through hourly refreshes and reopening; after a JSON round trip, a new
  station with the saved switches and ships seen, no mark for the same stock, and no badges. New and Used: the stock
  tells a ship younger than the mod's `_DN_GAME_NEW_AGE` (new) from one that old (used); with Used off a later new ship
  marks and a later used one doesn't; with both off nothing does; switching Used, then New, on doesn't mark the ships
  of that condition already for sale, and a later used ship marks. The screen: Shift+Click on
  a disabled entry does nothing, on the entry opens the settings and not the Dealer; opening stores nothing; the Dealer
  screen's theme, frame, size and size flags; the entry's title; under the header the window, the groups and the
  buttons, with no note; the window copies the Dealer's (theme, margins around and inside, panel, least height, the
  texts' spacing), its texts wrapping in a ScrollContainer with no horizontal scroll that fills the window at the
  Dealer's least height; first New and Used in a group titled by their `group`, then one group per series titled
  by its name, the series and their rows in alphabetical order of the names whatever the case, the models alone in their
  series last under `OTHERS_LABEL`, in an `Items` box, the titles and names in `i18n/en.po`; New's switch focused; each
  switch showing its setting; each ship's row dressed as a Dealer entry (the picture first, of the entry's picture's
  size, its sprite placed as the entry's; no reset; the switch at the row's right end, at least as wide as the entry's
  Buy button; its tooltip the setting's label); New's and Used's switches lined up with them, with no picture and no
  tooltip; focusing a row shows its ship's description after its series' where that differs, and focusing New or Used
  empties the window; a long description keeps the window's height and scrolls, the right stick scrolls it down, stops
  when let go and scrolls it back up, and another ship's description starts at the top; switching a model on stores
  it, describes it, and doesn't mark for a ship of it for sale, and
  focusing it again doesn't switch it back; a later ship marks; switching Used off on the screen stores it; Select all
  and Select none under the groups, in `i18n/en.po`: Select all switches every switch on (New's and Used's too) on the
  screen and in the settings, marking nothing already for sale and leaving the window as it was, Select none every
  switch off, saved, unmarking the entry; the pictures drawn
  all at once, a viewport for each model; one ship of each model made to draw, in the screen's order, from the dealer's
  config, with a transponder, a name and a making time, nothing written to `state.transponders`, each in a viewport of
  its own; each entering the tree with every hardpoint empty (`PICTURED`: the dealer's, its other settings kept; the
  scene's inline ones, nested too; its placeholders', one with its slot left to the scene and a gun as its default;
  not the other scene's placeholder; the thrusters and propellant kept); every row's picture (frames drawn with
  `VisualServer.force_draw`, the render loop being off); the drawn ships gone; Esc closes it and gives the focus back;
  reopened in the second language, its order and the pictures kept (no ship made again); focusing another entry hides
  it; without a Dealer screen no tooltip and no settings. With CrewCheapHireNotifier and DiveSkipTransit
  (`-Mods CrewCheapHireNotifier,DealerNotifier,DiveSkipTransit`), and with MarketAdvisor and ServiceNotifier as well
  (`-Mods CrewCheapHireNotifier,DealerNotifier,DiveSkipTransit,MarketAdvisor,ServiceNotifier`),
  Shift+Click on each of their entries (MarketAdvisor's: on the Trade button of the Mineral Market its entry opens,
  the entry having no badge) opens their screen, then on Dealer opens this one and hides theirs, and every Shift badge
  keeps its own tooltip. The control checks (the entry keeps its key; the Dealer lists the stock and
  no entry gets a badge) run on the game's own scripts. With ShipSortByTypeAndPrice or ShipHighlightTypeAndPrice loaded,
  with or without DealerNotifier (`-Mods ShipHighlightTypeAndPrice,ShipSortByTypeAndPrice`), each waiting its mod's
  `SETTLE_TIME`: the sort puts the Dealer's offers in order of their type as shown, then of price, moves the highlight
  the Dealer put on its first entry to the new first one, and leaves Fleet's entries in the game's order; the highlight,
  on every entry of the Dealer and Fleet, shows the type in `TYPE_COLOR` and in a bold copy of the game's font, one copy
  for every entry (also after the Dealer adds its entries again), with the game's font as its file has it; the
  registration and year in `DIM_COLOR`, the name and price as they were, the picture behind the row transparent. The
  stock ships for these have their model's name and a price each (`harness/fleet_ship.gd` `value`). With a gamepad (the
  `Settings` stub's `controlScheme` set as the game sets it): the Shift badge reads the gamepad twin and its tooltip
  tells about it, and both go back with keyboard and mouse; `PAD_BUTTON` alone, and the twin (`PAD_BUTTON` while
  `PAD_MODIFIER` is held) on a disabled entry or with another entry highlighted, do nothing; the twin on the highlighted
  entry opens the settings and not the Dealer screen, and closing them highlights the entry again; the Shift badge's
  tooltip shows with a gamepad while the entry has the focus, in its gamepad wording, hidden once the focus moves on,
  and not when the entry gets the focus with keyboard and mouse (`suite.gd` `shiftBadgeTipChecks`; the hover is checked
  in `crew`); a Dealer entry's badge shows its tooltip while the entry's name has the focus, only with a gamepad, and
  hides it when the name loses it.

- `transponder` (`suites/transponder.gd`): the game's `CurrentGame.gd`, copied to `res://CurrentGame.gd` (where the
  mod's `Code.gd` extends it), instanced under the suite with a player's ship in its state; the `CurrentGame` autoload
  stays the stub, which hands this instance `menu/NewGamePlus.gd`'s transponder calls and the members it lacks
  (`_get`, `_set`). Checks that the script has the extension; that every model of the game's Shipyard
  (`harness/transponder_models.gd`) has a code in `MODEL_CODES`, all different, of one length, without a dash; that a
  model's code is followed by a dash and a serial of `SERIAL_LENGTH` characters of `SERIAL_CHARS`, the same for a
  seed, and the same serial for a seed whatever the model; a model not in the table (its key's letters and digits, a
  short key padded with `MODEL_CODE_PAD`); with no model given, a ship of the game's `usedShipsPool`, the same for a
  seed, several for several seeds; across those seeds, every character of `SERIAL_CHARS` in the serials.
  `getTransponder`: a config's own code kept; a new build coded by its model, stored in
  `state.transponders`; met again (not new, a frame later), its stored code back; a code stored before the mod reused
  as it is; no model left set. The player's ship: `createPlayerShip` and `validateState` code a ship without one by
  its model, a save's code is kept. The game's New Game Options screen, built on the node paths its script reads: the
  extension, a code of the new game's ship model and the name the game makes from it. `_tacNodeAdded` on ships of the
  game's `ship-ctrl.gd` out of the tree: a ship's lifepod (the suffix, the name of the ship's code kept, the forgotten
  code not stored back; a ship's stored name kept; added again, unchanged), a lone lifepod (a `usedShipsPool` ship's
  code and the suffix, a model set around it kept), the AI core (with and without a code), another ship untouched, the
  bodies' beacon and the destroyed habitat's (no code yet, untouched). Through the tree's `node_added`: frozen bodies
  of the game's `body.gd` (the group's code, the crew suffix, the initials; at the habitat; without a code, the
  initials only; added again, unchanged); docks of the game's `ClaimOwner.gd` under a ship given its script once in
  the tree, one per `DRONE_CODES` type (the format and the code it makes), another format and a dock under something
  that isn't a ship untouched; the story claim beacons' format. The control checks (a vanilla prefix; a body's code
  and a dock's format unchanged) run on the game's own scripts.
- `combat` (`suites/combat.gd`): a station built in code around the game's `Enceladus.gd` (given its script once in
  the tree, as in `skip`; the extension's `_ready` called and its input processing switched on, as the engine would),
  with the nodes of `Enceladus.tscn` the mod reads: `Background` and `EnceladusMenu` (the game's `CanvasHidding.gd`),
  the music players, the right-hand screens with a Tuning screen (its description window nested as `Tuning.tscn` nests
  it) and a Fleet screen, each with the simulator's button where the game's has it and a stand-in of its script
  (`harness/combat_station.gd`: `previewedConfig` or `currentConfig`, `_on_LaunchVR_pressed`, Esc closing it from its
  `_input`), wired to a stand-in of the simulator's layer that records `startSimulation`, as the scene wires them; the
  dive entry point's ring (the game's `TheRing.gd`, with the stand-in maps); the cursor's layer (the game's
  `MouseLayer.gd`); the station's pause menu (the game's `PauseLayer.gd`, with the nodes it reaches); `NoBulletTime`
  (the game's script). The game's `CurrentGame.gd`, with the extension, is instanced under the suite, and the
  `CurrentGame` stub hands it `_csArena`, as in `transponder`. The arena runs on stub ships, a stub field (which records
  its spawns, with the frame of each, moods and placements, can refuse a spot, and can make its spawns fewer and slower)
  and a stub BulletTimer; its TRTLs come from the stub pirate event. Keys and buttons are real input events with the
  game's bindings, pressed in one idle frame and released in the next; clicks go through the scene tree's input. Checks:
  - The settings model: one shared instance; the models offered (a scene under `ships/`, so not the habitat; each
    series together, in the game's order); a model's name (its scene's `shipName`, or the mod's text for one the game
    leaves unnamed) and description; defaults for a save without the entry; nothing stored or signalled for an
    unchanged value; each slider kept in its range and snapped to its step; a change stored in `state.ui` under the
    manifest's id with the format and mod versions and every setting, signalled once; the ship one of the models
    offered, a switch a bool; a JSON round trip; a hand-edited entry, and one that isn't a dictionary. The texts of
    `i18n/en.po` (the tooltip with its two `%s` and its gamepad form with three, the title, groups and buttons, every
    setting's name and description, the unnamed models' names and descriptions).
  - The HUD: the ring map (the game's `hud/Video.gd`) and the gravimetric readout (`hud/GravimetricReadout.gd`), under
    a HUD stand-in, show on the arena's ship outside the rings, stay hidden on another ship there and show in the rings;
    the readout stays hidden without the scanner. Disabled weapons: on a disarmed ship a hardpoint (the game's
    `WeaponSlot.gd`) passes 0 to its weapon and a turret (`PDT.gd`) fires with 0 and keeps 0 as its power, their
    switches on; another ship's fire as the game's.
  - The map (`CombatMap.gd` on the station ring's images): a pixel's red and blue are the dialog's, its green the ring's;
    `getChaosAt` and `getRawDensityAt` read them; the density is the game's `getTargetDensityAt` for those values (the
    game's `TheRing.gd` on a ring of that pixel, in floats); no oddity, no event; no ships counted without a field; the
    spot is the closest of its `SPOT_SAMPLES` samples (the sampling replayed with the same seed), at a pixel's centre
    away from the edges.
  - The dialog: the arena's layer right after the simulator's, on its layer, and the dialog's last; both buttons found;
    the tooltip, on the button's Shift badge (the button has none), held and shown by the game's tooltip node on the
    dialog's layer, a hidden button's badge's once it shows, after the key is rebound and after a language change; a
    plain click and J start the simulator and open nothing; Shift+Click and Shift+J open the dialog and start nothing; J
    and Shift+J with it open start nothing; it pops up over the screen, at least as big as its parts need; Esc, Cancel
    and the controller's Start close it, the screen staying open, the station's pause menu shut and the focus back on
    the button; a disabled button, or the simulator showing, opens nothing; from the Fleet screen it takes
    `currentConfig`. Its screen: opening it stores nothing; two tabs, the settings then the ship, the second titled by
    the Ship setting's label, opening on the first (a plain `TabContainer`: the harness has neither the Crew screen's
    tab hints nor its theme); the first holding the window, the groups and the buttons, the second the window, the ship
    list and the buttons; Tuning's theme on both and its window frame copied; a group per `GROUPS` entry with a game's
    row per setting but the ship, named by its label; a row with `namedBy` (Number) showing the name of the ship picked,
    as the ship list names it, and another ship's at once when that is picked, its key still its label; each slider's
    range, step, unit and value in the units shown, each switch's state; the first row focused and its description
    shown, then each row's on focus; the window keeping its height with a long text, which scrolls, and with none; a
    slider and a switch stored when changed, the switch not switched back on focus. The ship list (its pictures drawn
    from the combat ship stub): a row per model offered, only the current one on; the models alone in their series
    under Others, last; the tab focusing the current ship and showing its description; another ship switched on picked,
    the previous one switched off, the tab's title kept, the value stored; the current one switched off back on;
    focusing another row changing nothing; Esc cancelling from the ship tab; reopened on the first tab with the last
    choices, the ship's row switched on.
  - A run from Start (TRTL, `number` at its most, grouped): the layer running, known to `CurrentGame`, processing while
    paused, its viewport's container stopping and not forwarding, the simulator's scale, the viewport's own world and
    mouse proxy; the field, BulletTimer (without its notifications layer, deaf to `gameOver`), the music and WESpace in
    the viewport; the field tracing nothing, in the `sim` zone, with the ring scene's masks (from its state) and the
    arena's map (the dialog's chaos and density), not processing; until the field is full the arena hidden, no rocks
    spawned in Start's frame and no enemies, then the arena shown; the prefill (the ring scene's arrival over
    `spawnEvery`, at the cutscene's radius, then restored); the player's ship built as the simulator builds it, marked,
    the field's focus and `CurrentGame`'s player ship, its remass at the share set and its other tanks full, the
    screen's config untouched; `number` enemies, pirates with the AI on, preheated, armed, from the pirate event without
    the civilian or loot, placed by the field (`spawnByBlueprint`, `PLACEMENT_RANDOMNESS`) at Distance or more, side by
    side `GROUP_SPACING` apart across one bearing; every ship cleaned up (`exitedToEnceladus`, the zone, not hailable,
    empty dialog trees, no talking); the map counting the arena's ships; the pirates frozen; the global offset a pixel's
    centre away from the edges; at the station `NoBulletTime` stopped, the music paused, the cursor's fade the ring
    scene's, the focus let go; once faded in, the background and menu hidden, and the layer sending the mood; a ship
    entering later cleaned up and a story flag cleared, a ship outside the arena left alone; `giveXp` keeping talent and
    dropping experience, story flags and fleet ships dropped; the Shipyard's new transponders written. Input: J and
    Shift+J go into the viewport (a probe there) and start nothing at the station; with the OMS open, Esc goes in too;
    with it closed, Esc asks, pausing the game and filtering the music, the station's pause menu shut, the arena
    standing still; Esc, No and the controller's Start answer No; the pause menu's `pauseGame(true)`, `CurrentGame`'s
    `pauseGame` and losing the window's focus ask instead of opening the menu, and `pauseGame(false)` changes nothing;
    the arena's time scale left alone; Yes ends it, unpaused, the background and menu shown at once. Then: the layer
    hidden, `_csArena` cleared; the player ship, `inventoryMode` (signalled once) and `targetTimeScale` back;
    `NoBulletTime` running and the time scale 1 again; the music, the cursor's fade, the pirates' faction, the global
    offset and the focus back; the five save tables as at Start (the same dictionaries; one missing at Start missing
    again); `giveXp` giving experience again; the viewport emptied, `node_added` no longer watched. A second run (a
    model the game builds new, two ungrouped at the least Distance, Disabled weapons, all the remass, and a field with
    fewer spawns, each taking a third of `PREFILL_FRAME_MS` and a bit): the prefill spread over frames from the one
    after Start, at most three spawns in each; Esc while the field fills asking nothing until the arena shows, and then
    the end confirmation; a refused spot drawn again; each enemy from Distance to Distance + `SPAWN_SPREAD`, marked
    disarmed, made by `createShipByName` with the pirate faction; full tanks; the enemy's hardpoint and turret firing
    nothing; losing the ship (`removal`) ends it without asking.

  Not run here, since they need the game: its asteroid field, AI and HUD, the camera's OMS, BulletTimer's bullet time,
  the other builders (MAD-CERF, Hybrid, the Tsukuyomi with the Big Bad Wolf's values from `story/TheRing.tscn`), the
  mass driver's reload sound (`MassDriver.gd` is installed, not run) and the station's own processing (its time and
  wages while paused). With another extension of `Enceladus.gd` loaded too (DiveSkipTransit), the extension `_ready`
  the suite calls is the last one's only, so the suite runs with CombatSimulator alone or with TransponderAltCodes. The
  control checks (with `-Mods @()`): a click starts the simulator, Shift held or not; Shift+J starts nothing and J does
  (a button's shortcut matches its key exactly); the ring map and the readout hide outside the rings; a hardpoint and a
  turret fire with the power given; the station's pause menu pauses; `PAD_BUTTON` on the highlighted button while
  `PAD_MODIFIER` is held does nothing, and Back while it is held starts the simulator. With a gamepad (the game's
  bindings: Back is `jury_rig`, LB and RB `ui_page_up` and `ui_page_down`, the right stick `ui_scroll_up2` and
  `ui_scroll_down2`): the Shift badge reads the gamepad twin and its tooltip tells about it; with the dialog closed RB
  switches the screen's own tabs; `PAD_BUTTON` alone does nothing, Back alone still starts the simulator, and with the
  button disabled neither twin opens the dialog; the twin of Shift+Click (`PAD_BUTTON` while `PAD_MODIFIER` is held)
  opens it only on the highlighted button, without starting the simulator, and B closes it with the focus back on the
  button; the twin of Shift+J (Back while `PAD_MODIFIER` is held) opens it with the button not highlighted; the Shift
  badge's tooltip shows with a gamepad while the button has the focus, in its gamepad wording, hidden once the focus
  moves on, and not when the button gets the focus with keyboard and mouse (`shiftBadgeTipChecks`); RB and LB switch the
  dialog's tabs, and at its last or first tab the screen behind keeps its own; the right stick scrolls a long
  description down, stops when let go and scrolls it back up; Start with no ring map runs nothing and gives the focus
  back to the button. On opening, the first row is focused and the window shows its description; the arena's end
  confirmation opens with Cancel focused, as the game's own confirmations do.
- `drones` (`suites/drones.gd`): drone plants from `harness/drones_plant.tscn` (the game's `drone-plant.gd`, with a
  stub launch manager, `harness/drones_launcher.gd`, and bare pickup area and sound nodes) in hardpoints
  (`harness/weapon_slot.gd`) of `harness/drones_ship.gd`, the geology suite's ship stub plus what a plant reaches (its
  Tuning, the USV-GOT's queue, a target bus and a Geologist-tab filter that refuse what the suite lists, the excavator,
  `harness/drones_excavator.gd`, and damaged systems for the maintenance drones); chunks are rigid bodies in the
  plants' space, identified by the ship's `identifiedObjects` as the geology suite's are; the suite calls
  `scanForTarget` itself. HUDs as in `geology`. The mod's settings descriptions and `Code.gd`'s constants (through a
  plant) come from the mod. Checks the ranking on three identified chunks the same distance from the gathering spot,
  beyond the slow zone (a light, slow Be one worth the most; a heavy, fast Fe one, the game's pick; a Pt one): the
  switch off, another ship's plants and every weight at 0 pick as the game; value and mass alike pick the chunk worth
  the most, each alone its own best, haul and tug; only ore counts as mass; a chunk not yet identified comes after;
  intake alone picks the chunk nearest the gathering spot, and tug plants ignore it; the current target kept up to
  `KEEP_TARGET_MARGIN` and given up past it; the USV-GOT's queue first; a chunk the filter or the target bus refuses,
  beyond reach, in the hold or outside the space never picked, nor a still one by tug plants; the target kept between
  scans and dropped there once in the hold; the maintenance drones and a ship without `hud.config` as the game. The
  tab: right after the Geologist tab (with GeologyByMass, both tabs there), titled by its key, added once, opening it
  storing nothing; the switch; one row per weight in `WEIGHTS` order with the Geologist tab's parts, the range, step,
  unit, tooltip and bar width in the units shown, and the stored weight; the switch and a slider store what they show
  and the switch dims the rows; the reset button puts the switch and every weight back to their defaults, on the tab
  too, and leaves no entry; choosing the tab focuses the switch; a plant follows the tab's switch at once; a HUD
  without mineral targeting gets no tab; a preheated ship's tab shows the stored values. The settings model: defaults
  without the entry; reading, unchanged sets and a reset store nothing; clamping and snapping, an unknown weight
  ignored, the units shown; the entry in `hud.config` under the manifest's id with the format and mod versions, the
  switch and every weight, the game's keys untouched; a JSON round trip; hand-edited entries. And the texts of
  `i18n/en.po`, also in a language without them. With a gamepad: a reset button, its text and tooltip translated and
  taken in by the game's tooltip node; each slider's value carries its weight's description; down goes from the switch
  through each slider's value to Reset and stays there, Reset shows its description on focus, left and right stay
  where they are, up goes back to the switch and stays there, and walking the tab changes nothing. The control checks
  (both plants pick by the game's rule; the OMS keeps its four tabs) run on the game's own scripts.
- `market` (`suites/market.gd`): stations built in code as `enceladus/Enceladus.tscn` nests them: the menu (the game's
  `EnceladusMenu.gd`, with its `MineralMarket`, `Services` and `Logs` entries) and the right-hand screens (the game's
  `HidingMarginContainer.gd` with the Mineral Market from its stub, wired to its entry as the scene wires it; a Services
  screen with the rows given, by default the game's rows for Jameson's Insurance, Scrapwright Recovery Operations and
  the simulator's subscription, at the game's prices and cooldowns; a Tuning stub with its description window). Each
  save is loaded into the `CurrentGame` stub with the game's seed, so its prices are the game's; in-game time passes
  with the game's day and hour signals; the Trade button is pressed as a click presses it. The settings model: one
  shared instance; defaults and no parked tonnes for a save without the entry; the cash reserve, the amount times ten to
  the power; every amount at every power, written plain and in scientific notation, reading back as itself; an
  unchanged value storing and signalling nothing; a change stored under the manifest's id with the format and mod
  versions and every setting, signalled once; ranges, steps, and the defaults for what isn't a number or a bool; the
  parking minerals with Trade all ores off and on; the parked tonnes stored as a copy, without a signal; a JSON round
  trip; hand-edited entries. The tolerance: any amount written by `formatCash` (the largest suffix that fits, no
  trailing zeros, or scientific notation); the range, the reserve less and plus the tolerance's share in whole E$, shown
  as `RANGE` writes it, in both notations; none at a tolerance of 0 (the reserve as `formatFloor` writes it) or with a
  reserve of 0; the tolerance kept in its range and snapped to its step; `toShown` and `fromShown`. The advice alone
  (`Advisor.gd` `plan`, around a reserve of 500,000 E$ with a 10 % range): nothing to trade inside the range, above or
  below the reserve; above it, buying down to the reserve; below it, selling up to it; short only when everything sold
  can't reach the range; with no tolerance, the rule as before (less than a tonne above the reserve is nothing, a tonne
  above is bought, a shortfall sold). The market: the row at the bottom inside the list's side margins, its Trade
  button disabled with nothing to trade, the advice when the cash reserve is out of reach, a new save's holdings taken
  as parked, the line comparing
  today's prices with the chart's average, both lines in the Label font of `Badge.gd`'s `SMALL_FONT_THEME`, smaller
  than the Trade button's; the parked row right under your cash, a copy of the game's insurance row
  without its script and sound, captioned by the mod's text, the game's row still hidden, worth nothing at first. With
  cash above the reserve: the advice to buy and what it leaves, the alert mark on the entry; Trade buys the main
  mineral through its slider (its holdings and trade log as the slider makes them), leaves what the advice said, within
  a tonne's price above the reserve, and parks it in the save; then no alert mark, the button disabled, the advice at
  the reserve, the parked row worth the parked tonnes today, and a day later at that day's prices. Ore brought back
  with the ship ready: sold now, the cash parked again. A save without a record takes its holdings as parked, once;
  parked tonnes sold by hand leave the record. A plain click opens the market, its sliders' focus chain going on down
  to the Trade button. Trade all ores: the cash spread over more than one ore, within the cheapest tonne's price above
  the reserve, each parked as bought; ore brought back during a two-day stay sold without ever selling parked tonnes,
  the stay ending at the reserve with nothing left beyond the parked tonnes; a higher reserve selling parked ore down to
  within a tonne of the cheapest ore sold that has tonnes left, the record and the parked row following. Every tonne
  the market allows held: nothing to trade, the advice says so, no alert mark. The menu and the badge: the texts of
  `i18n/en.po`; the market entry with no Shift badge and no tooltip; the Trade button's Shift badge inside it, at its left as
  far in as the button keeps its text and centred top to bottom, the button making room for it with its text at the
  right, letting the mouse through to the button, with the tooltip (the button has none of its own), in the button's
  frame and font colour, the row's tooltip node taking the button in (its hover and focus sounds); the entry's alert mark while a trade is due, following a
  language change; the alert mark's switch on by default, switching it off unmarking the entry at once though a trade
  is due, and on marking it again; the Services entry left alone while Jameson's Insurance can be bought
  (ServiceNotifier's, in `services`); without the market screen, no tooltip and no settings. The screen: Shift+Click on
  the market's entry opens the market and no settings; Shift+Click on the disabled Trade button opens the settings in
  the market's place, storing nothing; the market's frame; the header, then the description's window (copying the
  Tuning screen's), then the groups, one per `GROUPS` entry with a row per setting named by its label, the notation
  switch first, the alert mark's switch last, in the Trading group, each showing its setting, a slider with its range,
  step and value as the screen shows them (`toShown`); the power of ten's row showing the power; the cash reserve's row
  under the cash group, named by the mod's text, its name and reset button out of reach, its value the reserve's range,
  right-aligned under the values of the two sliders without a unit once laid out; the tolerance's row between the power
  of ten's and the cash reserve's, in its unit; each row's description on focus, with the mineral it names, storing
  nothing; the sliders and the notation switch stored and shown as they change (the tolerance stored as a fraction, the
  range following it, the reserve alone at its lowest), a switch not switched back on focus, resets; Esc closes it and
  brings the market back with the Trade button focused, and Esc again closes the market, back to its entry; another
  entry closes it, and the market stays hidden; with cash above the reserve, Shift+Click on the enabled Trade button
  opens it and trades nothing, and a plain click still trades, leaving the button disabled. A year of stays from
  100,000 E$, with Trade all ores off and on (ore brought back, 1 to 3 days of maintenance, Trade pressed every day of
  the stay, money spent between stays): every stay ends inside the reserve's range with the ore sold. The control checks (the entry keeps its key and gets no tooltip; no row of the mod's in the
  market; Shift+Click opens the market; `PAD_BUTTON` on the highlighted entry while `PAD_MODIFIER` is held opens
  nothing) run on the game's own scripts. With a gamepad (the `Settings` stub's `controlScheme` set as the game sets
  it): the Shift badge reads the gamepad twin and its tooltip tells about it, and both go back with keyboard and mouse;
  the Shift badge's tooltip shows with a gamepad while the Trade button has the focus, in its gamepad wording, hidden
  once the focus moves on (to the last slider), and not when the button gets the focus with keyboard and mouse
  (`suite.gd` `shiftBadgeTipChecks`; the hover is checked in `crew`); down from the last slider highlights the Trade
  button, though disabled; `PAD_BUTTON` alone on it, and the twin (`PAD_BUTTON` while `PAD_MODIFIER` is held) with a
  slider highlighted, do nothing; the twin on the highlighted, disabled Trade button opens the settings and trades
  nothing, and closing them brings the market back with the button highlighted; on the enabled button it opens them
  and trades nothing.

- `services` (`suites/services.gd`, which extends `market.gd` for its station, saves, time, clicks and translations):
  the same station without the Mineral Market, its Services screen with the game's rows (`enceladus/Services.tscn`'s
  values) for The Twins, a hotel, the three that cost a monthly fee and The Miner's Guild, a compensation row whose
  price follows the miners' disposition towards the player in the `Factions` stub. The settings model: one shared
  instance; every service's switch at its default with nothing stored; the services watched (those with a cooldown and
  the compensations, not the hotel); an unchanged value storing and signalling nothing; a change stored under the
  manifest's id with the format and mod versions and the service's value, signalled once, as a copy; a value that
  isn't a bool giving the default; a JSON round trip; a hand-edited entry (only bool values kept) and one that isn't a
  dictionary. The mark: the texts of `i18n/en.po`; the Services entry's tooltip, on its Shift badge (the entry has none
  of its own); none with no money, for the hotel, or for The Twins during their cooldown; the mark once it is over,
  following a language change; none with The Twins' switch off; the mark for Jameson's Insurance and the simulator, none
  with their switches off though both can be bought; the mark for Scrapwright Recovery Operations, none during its
  cooldown; the mark while the miners hold a grudge, none once that is paid (the row costs nothing); back with a switch
  on; none with the money below every price; a menu without the station's screens, no tooltip and no mark. The screen:
  Shift+Click on a disabled entry does nothing, on the entry opens the settings and not the Services screen, storing
  nothing; the Services screen's frame; the header, then the description's window (copying the Tuning screen's), then a
  group per kind in `KINDS` order with a row per watched service in the screen's order, no hotel; each switch showing
  its service's setting, with the setting's label as its tooltip; the first row's description, its kind's with its name
  and cooldown as the game writes a time, another row's with its own, a compensation's; focusing stores nothing; a
  switch stored, and not switched back on focus; Esc and another entry close it. With a gamepad (the `Settings` stub's
  `controlScheme` set as the game sets it): the Shift badge reads the gamepad twin and its tooltip tells about it, and
  both go back with keyboard and mouse; `PAD_BUTTON` alone, and the twin (`PAD_BUTTON` while `PAD_MODIFIER` is held) on
  a disabled entry or with another entry highlighted, do nothing; the twin on the highlighted entry opens the settings
  and not the Services screen, and closing them highlights the entry again; the Shift badge's tooltip shows with a
  gamepad while the entry has the focus, in its gamepad wording, hidden once the focus moves on, and not when the entry
  gets the focus with keyboard and mouse (`suite.gd` `shiftBadgeTipChecks`; the hover is checked in `crew`). The control
  checks (the entry keeps its key and gets no tooltip; Shift+Click and its gamepad twin open no settings) run on the
  game's own scripts.
- `sale` (`suites/sale.gd`), with ShipCopyPaste loaded too, since both extend the Fleet entries' script: first the
  advice alone (`Advisor.gd` from plain data), on a worked K37 derelict (every damaged system at 65 %, a repair limit
  of 71 %, so one Fix click each): the clicks that add more than they cost, the thrusters' never, even paid by the
  insurance; the slots taken down, in the data's order; the insurance paying first, then the cash; the maintenance
  time, refunds and gain; the same with full insurance, fewer clicks with none (a click's cash gain below the minimum),
  only what 2,000 E$ cover, every step with a minimum gain of 0, nothing with a high one; a piece at 0 % fixed in one
  run of clicks, a run ending at the click with the most per E$, two clicks taken together where the first alone loses
  money; a click adding less than its price dropped even when the insurance pays, one adding more taken; an undamaged
  hardpoint piece, a damaged piece worth less than the cheapest item. Then Fleet entries built from the stub
  `SystemBuyUI.tscn` as `fleet` builds them, under a Fleet screen stub (`harness/sale_fleet.gd`: `fleet_screen.gd`'s,
  its list in a column and hidden on `hidefoka` as `Dealer.gd`) among the station's screens (the game's
  `HidingMarginContainer.gd`), beside the Equipment screen stub with that derelict's items; the ships are
  `harness/sale_ship.gd` (a fleet ship whose systems come from its config, with the Repairs screen's figures, damage
  entries and the game's price formulas, set up a frame after entering the tree as the game's ships are, so what waits
  for a ship's setup waits here too), also the trial ship's scene in the `Shipyard` stub, stored in the
  `CurrentGame` stub's state (its `changeMoney` takes the insurance first where asked, as the game's). Checks: the
  save's minimum gain loaded with the Fleet screen, a change stored; the note, once, at the bottom of the Fleet
  screen, in the texts of `i18n/en.po`, following the control scheme. Sell disabled while the offer is worked out; the
  dialog instead of the game's confirmation; the trial ship gone; the sale now, the sale after (the trial ship's) and
  the gain; the line at the top, the rows (money signed, coloured as the Fleet screen's `colorPlus` and
  `colorMinus`, none uncoloured) and the warning; Prepare, Sell and Cancel in that order, Cancel focused; the layout
  in a 1920x1080 window (the line at the top on two lines, the warning on one, each value a column gap after its name,
  the rows centred, the contents narrower than before they followed their texts, the dialog centred); the D-pad along
  the buttons, stopping at the ends; B, Esc and Cancel closing it alone (the Fleet screen sees neither), Sell focused
  again; closing with the Fleet screen; Prepare on an offer that changed meanwhile showing the new one, applying
  nothing. The settings: Shift+Click on Sell opening the screen in the Fleet screen's place, its row and the
  highlighted row's description, a change stored; B and Esc bringing the Fleet screen back with that Sell button
  highlighted; `PAD_BUTTON` alone doing nothing, the twin on the highlighted Sell opening the settings, nothing sold or
  offered; a disabled Sell opening nothing. Prepare: the slots taken down and those kept, a click halving the damage,
  a slot taken down clearing its pieces', the maintenance, the refunds paid and the clicks paid by the insurance, the
  logs and the mechanics' XP, the old instance dropped and the Fleet screen listing its ships again; the prepared ship
  in maintenance with Sell disabled, and after it the game's confirmation. The dialog's Sell selling the ship as it is;
  too little cash; below the minimum gain, the game's confirmation; an offer with no maintenance and no warning; the
  entries' script keeping the game's path. The control checks (Sell shows the game's confirmation; no note) run on
  the game's own script.
- `repairs` (`suites/repairs.gd`): first the settings screen's estimates (`Settings.gd` `failureRate`,
  `performanceLoss`) at every condition the target can take, against the suite's own working of their formulas from the
  constants (the worst damage's square; the middle of the average loss and the worst case, each rounded half up), the
  degradation between those two, neighbouring conditions with different failure rates, none at 100 %. Then the plans
  alone (`Advisor.gd`, from plain data, each system's steps built by the Repairs screen's rules as `Code.gd` predicts
  them: a Fix click halving the damage, Fix while under the repair limit and cheaper than Replace, Replace below the
  game's highest repair limit). Repair's: Fix alone and its hours, Fixes then Replace where that costs less, Replace
  where the repair limit stops Fix, beyond repair (Replace without money, the cash below zero), nothing to do where the
  repair limit is below the target and Replace can't be paid, Fixes as far as they go, damage no repair clears, money
  for one of two Replaces (the cheaper kept) and cash and insurance together for both, the insurance paying first (all,
  part, none, below zero), Fixes needing no money, nothing to do; the presses (a paid Replace's Fixes, then its Replace,
  then those beyond repair, then the Fixes alone); Replace at 100 %, which Fix can't reach, and once Fix costs no less.
  Park's: one Fix before a trade-in where it pays, the refund growing by its gain, the hours; none where it costs more;
  the number of Fixes with the most gained; the refunds first, in the screen's order, then the costs, cheapest first;
  what is missing when the dearest cost's turn comes; an out-and-back's second purchase a refund right after the first,
  which still needs the first's cash; a repair to Park's target replacing, a system no way brings there left alone and
  listed with those given; a paid Replace kept without the money, what is missing at it, the insurance covering it, a
  refund first paying for it; Fixes from the insurance first and purchases from the cash; nothing to do, also with only
  systems no way brings there; Repair's own plan still dropping a Replace it can't pay. Then the game's Repairs screen
  (`Repairs.tscn` with `Repairs.gd`, its rows `SystemShipRepairUI.tscn` with `SystemShipRepairUI.gd`) as the station
  has it (its least width, size flags and frame, `menu/PanelWithHugeShadow.tres`), among the station's screens (the
  game's `HidingMarginContainer.gd`), the `CurrentGame` stub's repair limit at the game's highest and one mechanic.
  Repair, on `harness/repairs_ship.gd` (five systems: a thruster at 40 %, a HUD at 70 %, a reactor beyond repair, a
  laser above the target, an arm held below it by what no repair clears; `harness/repairs_part.gd` their nodes): the
  extension, the script keeping the game's path; a row per system; the table's first line the target named as the
  setting, at its default for a save without the mod's entry, then following it; what the insurance pays, what the
  cash pays, both and the maintenance time, the names in order, in `Badge.gd`'s small font, aligned right, the cash in
  the normal colour; Repair enabled and named by the mod's text, Park disabled without the Equipment screen. The
  layout: the row at the bottom of the panel, as wide as the header, the list of rows ending where it begins; Park,
  which ends the row, as far from the panel's frame at the bottom as at the right; the Shift badge inside Repair, at its
  left as far in as the button keeps its text, centred top to bottom, Repair making room for it with its text at the
  right, the badge letting the mouse through and wearing Repair's frame and font colour; the table right before Repair,
  at its own width; the D-pad down from the last row's buttons to Repair and up to the last row's Fix. The badge's
  tooltip from the row's own tooltip node (Repair has none), placed above the badge inside the screen, the placing
  stopping once it hides; and as `shiftBadgeTipChecks` checks it with a gamepad. A run: both buttons disabled while it
  works; the thruster and the HUD fixed past the target, the reactor replaced, the laser and the arm untouched; the cash,
  insurance and maintenance as the table said; the mechanics' XP for each press; the table at zero, Repair disabled.
  Shift+Click on the badge of the disabled Repair, through the scene tree's input, opens the settings in the screen's
  place, titled as it, its group without a title, the estimates' rows right under the slider (named by the mod's texts,
  in the setting's unit, taking no focus, their reset buttons unseen) showing the estimates at the target and following
  the slider, which stores the target, the slider's description; Esc brings the screen back; the table at a higher
  target, kept in the save under the manifest's id; the cash in the rows' colour for a failed inspection while it would
  end below zero, and back; a second run reaching the higher target. With a gamepad: the twin (`PAD_BUTTON` while
  `PAD_MODIFIER` is held, from `Badge.gd`) on the highlighted Repair opens the settings, and B closes them with Repair
  highlighted again. Park, on `harness/repairs_park_ship.gd` (a ship built from its config, as the game's, its
  hardpoint's and thrusters' members with a `type` (`harness/repairs_slot_part.gd`, as the game's), and systems on
  slots without members; its damage kept in the config by system key; also the trial ship's scene in the `Shipyard`
  stub; RCS_B's systems worth less than its price), beside a stub of the Equipment screen (`harness/repairs_equipment.gd`:
  the game's `updatePricesAndAvailability` and `buy`, building the ship again as the station does and recording each
  purchase, its groups `harness/repairs_group.gd` holding the game's `SystemShipUpgradeUI.gd` items, one group not
  shown) and of the Fleet screen (`harness/repairs_fleet.gd`, colours for money of its own): a row per system; Park
  named by the mod's text, enabled, right of Repair at its height, the badge in Repair, Park as far from the panel's
  frame at the bottom as at the right; the D-pad up from Park to the last row's Replace, right from Repair to Park and
  left back. The confirmation (a laser at 60 % on the hardpoint, RCS_A thrusters with one at 99.7 %, the dearer
  reactor at 70 %, a HUD at 99.7 % on a slot without members, the cabin at 80 % on no slot, an ammo capacity bought):
  no title, the game's OK and CANCEL, Cancel highlighted; the question with Park's target; the lines' names without
  "cost"; the insurance going out with - and the cash and the total coming in with +, in the Fleet screen's colours;
  the maintenance time in the normal colour; the trial ship given the pieces bought (the other thrusters for the
  out-and-back) and the members without damage, the rest kept, then gone, the ship and the state untouched; the HUD
  named, at its condition rounded down to the mod's decimals; OK enabled; the dialog on the screen. Esc (a real key
  press, with the game's bindings) closes the confirmation only, Park highlighted again, nothing changed; B closes it
  too. OK: both buttons disabled while it works; the hardpoint emptied, the cheapest reactor and ammo capacity, the
  thrusters out and back (the second purchase refunding what the other thrusters' systems are worth), the refunds
  first, the laser fixed once before its trade-in, the slot not shown left alone; every other system at Park's
  target, the HUD as it was; the cash, the insurance and the maintenance as the confirmation said; the rows made for the
  new ship; Park disabled with nothing left to do, and highlighted. Again with a gun at 50 % and the cash below zero: the
  note of the money missing and OK disabled; Cancel changing nothing; with the money, no insurance spent shown without
  a sign or colour, the cash and time, then the cash and maintenance as it said, the gun traded in after two Fixes, the
  cabin at Park's target. The screen hiding closes the confirmation; without the Equipment screen, Park disabled. The
  control checks (the game's rows, nothing of the mod at the bottom of the screen, the list's margin as the scene sets
  it) run on the game's own script.
- `callout` (`suites/callout.gd`): HUDs from `harness/callout_hud.tscn` (the game's `Hud.gd`, its `dialogLineNode` the
  game's comms line, `comms/MessageLine.tscn`; a display of the game's `Display-K37.gd`, `harness/callout_display.tscn`,
  whose `Dialog` is the HUD's comms line; the geology suite's OMS, whose `Comms` is the Comms log) on
  `harness/callout_ship.gd`, a ship stub with the zone, the Pilot tab's rows (`identifiedShips`, added and removed with
  the game's `addIdentifiedShip` and `removeIdentifiedShip`), its transponder, `temporaryCargo`, `cutscene`,
  `talkingWith` and a LIDAR whose `hasSeen` gives the objects the suite marks seen (`harness/callout_lidar.gd`), alone
  in a field with objects (`harness/callout_object.gd`: a reward of its own, `inCargoHold`, `dead`, no transponder;
  `callout_contact.gd`, the same with one, which a pirate's leaves empty); the crew is the `CurrentGame` stub's
  `state.crew`. The OMS is built on the ship's `instance` signal; once the set-up is checked, the mod's timer is stopped
  and the suite calls its ticks, so time passes as the mod counts it. Exact figures are the Pilot tab's (the game's
  `ShipOnOMSBearingDistance.tscn` and its `compute`), approximate ones are read back from the text and checked against
  their circle; the mod's constants are read from the script at the game's `Hud.gd` path and down its chain. Checks: the
  texts of `i18n/en.po`, also in a language without them, each holding the parts the mod fills in. The set-up: in a dive
  (zone `rings`) once the frame is idle after the OMS is built, a timer on the HUD in physics time, every
  `_CALLOUT_TICK`, running; the rows and the game's comms lines followed; the game's `ConversationPlayer.gd`,
  crew-spoken (`agendaNPC`), for its lines; all of it once, however often the OMS is built; the UIO text the placeholder
  of the game's `ShipOnOMSLabel.tscn` (with a stand-in scene at that path, another label's placeholder read as it is,
  none or an empty one giving `CALLOUT_UIO_FALLBACK`; the game's scene put back after); with the timer running, a new
  row said in game time by `CALLOUT_SETTLE` (nothing two ticks before, said two ticks after); in the simulator (zone
  `sim`) set up and saying a new row; nothing set up, followed or said for the zones "", null and "enceladus", or for a
  ship that isn't the player's (a preview's). When: a new row said after `CALLOUT_SETTLE` and not a tick before, once,
  on the HUD and in the Comms log: New, identified by its transponder, approximate, in the speaking astrogator's circle;
  once marked, Updated with the Pilot tab's figures, once; a row marked before it is said, one exact New and no Updated;
  a marked row with no transponder, New with the game's UIO, exact; several rows together, one numbered list
  (`_CALLOUT_LIST` of `_CALLOUT_LIST_ITEM`s) in the order they came, the marked one exact, the oddity in none of
  `CALLOUT_MARKABLE_GROUPS` Anomalous, which never gets an Updated when marked; an oddity in one of those groups, or one
  of `CALLOUT_IGNORED_ODDITIES`, New; a steady trickle (a new row every `CALLOUT_SETTLE` less a tick) said once the
  first has waited `CALLOUT_MAX_WAIT`, all in one report. Anomalous: with only a pilot aboard, an oddity with a row said
  as New by the pilot (in the largest circle) and one with no row not sighted, so once an astrogator is aboard that one
  is, Anomalous with the game's UIO, by the astrogator, once; one sighted while an astrogator was aboard but said by
  someone else dropped, the rest of the report said, the list cleared. Objects with no row: a ship with no transponder
  the LIDAR hasn't seen, nothing; seen, New with the game's UIO, approximate, once; given a marked row later, Updated,
  exact; one without `getTransponder`, the same; seen together, only the oddities with no transponder in no markable
  group (Anomalous), nothing for a chunk, a bullet, a ship with a transponder and no row yet, or something gone (being
  freed, held by the arm, in a hold, dead); sighted, then given a row before it is said, said once as its row stands;
  sighted, given a row and the row gone before it is said, dropped. Never said: the ship's own drones (its transponder
  and a dash) and what the arm holds, while a transponder that only starts like the ship's is; a row gone before it is
  said dropped, the others said; found again later, New; said, gone and found again, New again; nothing while the ship
  is out of the zones or isn't the player's, said at the next tick once it is again. Near the ship (at the origin, so
  the edge is exact): a new row a metre inside `CALLOUT_MIN_RANGE` not said, one at it said, New; the first not said
  once beyond it while its row stays, and New once its row is gone and found again beyond it; a ship the arm lets go of
  inside it, its row gone while it was held, not said; a contact said from beyond it, marked inside it, Updated, exact;
  an object with no row the LIDAR sees inside it not said, nor later beyond it; one seen at it, New. Who speaks (the
  line's "[Name,
  Occupation]"), over several reports: an astrogator aboard, with others aboard; one of two astrogators at random, each
  speaking, nobody else; with no astrogator, a pilot or a mechanic at random, each speaking, never the passenger; an
  astrogator not in the dive crew or on leave, never; with nobody to speak (a passenger, someone not in the dive crew
  and someone on leave; no crew), nothing said and the list cleared, nothing later either. The figures, drawn many times
  for each experience (`_calloutValues`): in the circle of `CALLOUT_ERROR_RADIUS` times (1 - experience) of the distance
  around the contact (the bearing within its angle and a degree's rounding, the distance within the circle and half a
  step), the distance a multiple of `CALLOUT_DISTANCE_STEP`, spread over the circle; at experience 1, the Pilot tab's
  bearing and the distance rounded to a step; a contact nearer than half a step, one step; a marked row's figures the
  Pilot tab's all around the ship (the bearing in three digits), with no precision text, whatever the experience; said
  by an astrogator of experience 1, approximate at the centre, an experience above 1 counting as 1; by a pilot of
  experience 1, the largest circle, not at the centre. The holds: during a cutscene and while the ship talks with
  another (`talkingWith`), said at the next tick after; after the game's comms line to the ship (a broadcast of a
  `ConversationPlayer.gd`, which the game's `Hud.gd` shows), held for `CALLOUT_AFTER_COMMS` and said at the tick it has
  passed, the game's line on the HUD freed and kept in the Comms log; not held by a comms line to another ship, nor by a
  broadcast to the ship with no message (the game clearing its line). The line: one on the HUD and one more in the Comms
  log, both the HUD's `dialogLineNode` with the same text; the HUD's fading (playing the game's `incoming-fade` a frame
  later, once the engine tells it it is visible), the Comms log's not, and stale until the OMS shows; both from the ship
  to itself through the mod's conversation, whose member is the speaker; the speaker's "[Name, Occupation]" and face
  (`MessageLine.gd` `_ready`: name, gender, `crewTalkingColor`); with the OMS open, the Comms log's line playing the
  game's `incoming` and the HUD's stale, hiding itself once the HUD shows again. With DroneAltPriorities and
  GeologyByMass too (both extend `Hud.gd`), in every load order, the same checks pass. The control checks (with `-Mods
  @()`): the HUD gets nothing of its own; the game says nothing of a new row or of an object the LIDAR has seen; the
  game's own comms line to the ship shows on the HUD and in the Comms log.
- `_tests\harness\rig.gd` builds the arm's node tree as the game nests it, with the values in
  `_tests\harness\vp_data.gd`; each cites its scene file and line, so re-check them after a game update. The ship
  is a stub moved by hand (it takes the arm's impulses and torque; inertia from the hull); the rotors don't collide.
  `harness\grinder.gd` and `spotlight.gd` are stubs of the grinder (its two rotors, which the arm mods read) and of
  the arm's spotlight (which `DockingArm.gd` switches).
- `_tests\harness\suite.gd` is the base of every suite: the results, the loaded mods and the masses given on the command
  line, and helpers several suites share: `frames`; `addMenuTooltips`, the game's tooltip node added to a station menu
  built in code, as `enceladus/EnceladusMenu.tscn` has its own; `shiftBadge` and `badgeTip`, a Shift badge (a child of
  its entry or button, beside or inside it) and its tooltip; `shiftBadgeTipChecks`, the checks of a Shift
  badge's tooltip as that node shows it, on hover with keyboard and mouse and on the entry's focus with a gamepad. In
  most suites' stations a mouse moved through the scene tree's input shows no hover on any control, not even a plain
  button added to the root (cause not found); in `crew` it does, so the hover is checked there only (`Badge.gd` is the
  same file in every mod). `harness\dive_ship.gd` is the ship `dive` gives the game's `CabinLight.gd`: what it and
  DiveDisableAdrenalineBooster read.
- **Baseline** (both arm load orders give the same results): `units` 114 checks with both arm mods (64 with PullBehavior
  alone, 61 with TargetSelection alone), `still` 9, `moving` 16, `hold` 63, `dive` 8 (1 control check with `-Mods @()`),
  `boot` 5 (3 control checks with `-Mods @()`), `lidar` 40 (3 control checks with `-Mods @()`), `hud` 13 (the same with
  LidarContactCallout too; 3 control checks with `-Mods @()`), `crew` 167 (171 with CrewPerfectSort too, in both load
  orders; the same 167 with DealerNotifier too; 3 control checks with `-Mods @()`), `geology` 95 (the same with
  DiveSkipTransit too, in both load orders, and with LidarContactCallout too; 5 control checks with `-Mods @()`),
  `fleet` 95 (the same with ShipHighlightTypeAndPrice and ShipSortByTypeAndPrice too, and with ShipSaleAdvisor too, in
  both load orders; 3 control checks with `-Mods @()`), `skip` 135 (138 with CrewCheapHireNotifier too, the same with
  DealerNotifier as well; the same 135 with CombatSimulator too; 13 control checks with `-Mods @()`), `dealer` 130 (133
  with CrewCheapHireNotifier and DiveSkipTransit too, in every load order, 136 with MarketAdvisor and ServiceNotifier as
  well; 136 with ShipCopyPaste, ShipHighlightTypeAndPrice and ShipSortByTypeAndPrice too; 8 with the two ship-list mods
  alone; 2 control checks with `-Mods @()`), `transponder` 48 (3 control checks with `-Mods @()`; the same 48 with
  CombatSimulator too), `combat` 153 (the same with TransponderAltCodes too; 8 control checks with `-Mods @()`),
  `drones` 69 (the same in both load orders, with DroneAltPriorities alone and with LidarContactCallout too; 3 control
  checks with `-Mods @()`), `market` 124 (4 control checks with `-Mods @()`), `services` 52 (3 control checks with
  `-Mods @()`), `sale` 75 with ShipCopyPaste (in both load orders; 2 control checks with `-Mods ShipCopyPaste` and with
  `-Mods @()`), `repairs` 156 (2 control checks with `-Mods @()`), `callout` 89 (the same with DroneAltPriorities and
  GeologyByMass too, in every load order; 3 control checks with `-Mods @()`), all passing; `units` gives 11 control
  checks with `-Mods @()`; `-Matrix` gives 16 of 16 in every combination.
  Feeding, a chunk beside the hull is in after 3.0–3.7 s.
  For comparison with `-ModZip` and older release zips: PullBehavior 1.5.4 (the same pull as 1.5.0) takes 4.2–4.8 s
  there, and fails the 3 cases that move a chunk straight forward and then expect it held at the dock slot (it hands
  the chunk back to the game's pull); 1.4.0 (the claude.ai results, case for case)
  took 5.9–6.3 s there, now fails 17 of the 25 cases (every feeding case, since it hands the chunk to the game's feed
  in the corridor, and those 3), and `-Matrix` gave 16, 15, 16, 16 (feeding while turning with a 5 t
  chunk touched a rotor: the game's pull measures speed against the swinging dock slot); 1.3.1, which broke in the
  game, gives 0, 0, 12, 4 of 16. This ship also takes the arm's torque reaction, as the game's does (the claude.ai
  stub dropped it), which shifts some numbers in the third decimal.

The harness doesn't replace the game. CrewHighlightJobAndSalary has no tests at all, and CrewPerfectSort runs only
beside CrewCheapHireNotifier in `crew` (its Hire screen sort and its EVA choice; its Your Crew screen isn't tested).
The ship-list mods have their checks in `dealer`, and load beside ShipCopyPaste in `fleet` without checks of their
own. The real check is playing the game with the mods.
