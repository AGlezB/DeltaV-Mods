# DiveSkipTransit - ΔV: Rings of Saturn

Skips the cutscenes of a dive: the transit both ways (the arrival in the ring and the return to the station), the
launch sequence, astrogation, the rescue when you run out of remass, the game over after a meltdown, and the station's
fade-in when you're back. Whatever a skipped cutscene would have cost in remass and in-game time is charged all the
same. Each skip has its own switch, and the transit, when you'd rather watch it, can play faster without holding
Space: Shift+Click Launch Ring Dive.

## Warning
This mod changes how the game plays, though it tries not to. Compared to vanilla:
- the skips whose cutscene burns remass charge it, worked out from the game's own formulas: the transit (the arrival
  and the return) and astrogation (see *Settings* for what each charges). The return's burn is an estimate at full
  throttle from the first moment: it doesn't count the time a ship needs to turn round first (at overspeed), how its
  thrust builds up, or the power and heat its thrusters might lack, so it can charge a little more remass than the
  cutscene would burn. The arrival doesn't charge the remass the ship spends turning, and a ship too weak to brake as
  fast as the cutscene asks starts as if it had;
- none of the skips charges what a damaged reactor might vent during the skipped seconds;
- the launch sequence is cut the way the game cuts it when you press Esc, so the station seconds it would take don't
  pass;
- you don't see the rescue ship fly in, or your ship explode;
- the transit played (not skipped) runs at the speed you set without holding Space, as the game's own fast-forward
  does, and the ship flies it for real, costing what the game makes it cost. Above the game's Space speed it plays
  without sound, and the game's physics runs more steps per frame, each the size the game's own fast-forward uses, so a
  slower machine reaches less than the speed set;
- your real-time playtime (the game's statistics) counts only the time you actually play.

Any skip can be switched off (see *Settings*). Before reporting a bug with a dive's cutscenes, or with the remass or
the in-game time around them, to the game's developers, check that it also happens without the mod.

## What it does and why
- **The transit**, both ways, the two cutscenes the game speeds up while you hold Space:
  - the arrival: in the ring, the arrival cutscene (the ship braking in under the title card and the transit tip)
    doesn't play: the ship starts where the cutscene leaves it, slowed down and facing into the rings, and you are in
    control from the first frame;
  - the return: when you dive back, or leave the ring at overspeed, the exit cutscene (the ship burning away from the
    ring, then the title card of the trip to Enceladus) doesn't play: the screen goes black at once, and the station
    loads.
- **The transit's speed:** with the transit not skipped, both cutscenes play at the speed you set, without holding
  Space: at 1x as in the game, at the game's own Space speed, or faster. The arrival slows back to 1x by its end, as the
  game's own fast-forward does, so you take the controls in normal time. Holding Space still gives at least the game's
  Space speed. Above it there is no sound (sounds follow the game's speed, and get shrill).
- **The launch:** after you press Launch Ring Dive and pick the dive target, the game goes straight to the ring.
- **Astrogation:** once a plotted course is complete, the ship is at once where the game's astrogation would leave it,
  short of the destination and still moving at the travel velocity, with the trip's time on the clock, and you are in
  control. The course to Enceladus is the return.
- **The rescue:** when you run out of remass, the rescue cutscene (the rescue ship flying in) doesn't play: the time
  you spend stranded passes as in the game, and the station loads.
- **The game over:** after a meltdown, the game goes straight to the title screen.
- **The station's fade-in:** back at the station, the menu is usable at once instead of after the fade-in.
- **Why:** to save time on every dive. The game lets you skip only the launch sequence (Esc), and only speed up the
  ring's cutscenes (Space, 3x, with VHS stripes).
- **No gameplay effects, as far as possible:** in some of the ring's cutscenes the ship really flies. It brakes or
  burns away, its reactor's turbine burns remass, and in-game time passes. The remass left after a dive carries over
  to the next one, and the resupply before a dive tops it up for E$, so the mod charges that remass and that time.
- **Settings:**
  - **Shift+Click** Launch Ring Dive to open them, as the entry's tooltip says. A plain click still launches a dive.
    The settings open where the Tuning screen does, with the same frame and the game's own Tuning switches, and close
    the way the game's screens do: Esc, the controller's B or Start button, or picking another entry of the menu.
  - At the top, under the title, a window describes the selected setting, as the game's Tuning screen does. Under it,
    a note says that the switches with a mark after their name affect remass; the others don't. Then two groups.
  - *Transit*:
    - *Skip both ways* (marked): the arrival charges the remass to brake (the game's rocket equation, for the cutscene's
      change of speed), the remass the reactor's turbine burns during the cutscene, and its in-game time. The return
      charges the remass of the burn away from the ring (estimated), the turbine's, and the cutscene's in-game time,
      with the transit back charged in between, from what is left, as the cutscene does.
    - *Speed when played*: a slider for the speed the transit plays at while it isn't skipped. It is dimmed while the
      transit is skipped, since it doesn't apply then. Its range, step and default are `transitSpeed`'s in `SETTINGS`;
      the most is the game's Space speed times the physics steps the game's engine runs in one frame.
  - *Skip*:
    - *Launch sequence*: no remass. The ship flown there is the station's.
    - *Astrogation* (marked): the remass the turbine burns during the cutscene's waits, the remass for any change of
      speed to the travel velocity, and the waits' in-game time, besides the trip's time the game adds.
    - *Rescue*: no remass (the tank is empty). The cutscene's in-game time, besides the stranded time the game adds.
    - *Game over*: nothing; the game is over.
    - *Arrival at the station*: nothing; the station's clock runs either way.
  - Each row has a button that resets it to its default. A change applies to the next cutscene of that kind.
  - They are game-wide, the same for every save, and written at once to a file of the mod's own in the game's user
    folder. Every skip starts switched on. Settings from before the transit had one switch carry over: it is skipped if
    both the arrival and the return were.
  - Opening them needs a mouse and a keyboard; a controller can use and close them.
  - Each setting's default, the speed's range, and whether a switch affects remass are in `SETTINGS` at the top of
    `DiveSkipTransit/Settings.gd`, inside the zip. The mod's texts (the tooltip, the groups' and the rows' names, the
    rows' descriptions, the note) are in `DiveSkipTransit/i18n/en.po`.

## For modders
- Six scripts: `Code.gd` (the ring scene's script extension: the arrival, the return, the rescue, the game over and
  astrogation's title card), `Ship.gd` (every ship's: astrogation), `Station.gd` (the station's: the fade-in and the
  launch), `StationMenu.gd` (the station menu's: Shift+Click on the dive entry), `SettingsUI.gd` (the settings screen)
  and `Settings.gd` (the settings model and the code the skips share). The texts are in `i18n/en.po`. The tag
  `group = Game` in `Mod.manifest` names the main game script, `res://Game.gd`.
- **Playing a cutscene through** (`Settings.gd` `playThrough(player, animName, charge)`): most cutscenes are an
  animation whose method keys do the work (charge the transit, call the rescue ship, load the station or the title
  screen, enable the menu). The mod calls those keys at once, in time order (keys at the same time in track order),
  reading them from the animation, and before each calls `charge` (a FuncRef, or none) with the seconds since the
  previous key: the stretch of the cutscene that key ends. Nothing is charged after the last key, where the scene
  switches. A seek to the end, which calls no method keys, leaves the animation's last frame on screen.
- **The costs** (`Settings.gd`): `chargeDv(ship, dv)` is the game's rocket equation (`ship-ctrl.gd`
  `getRemassRequiredForDv`) for a change of speed in m/s (`UNITS_PER_METRE`). `chargeSeconds(ship, seconds)` is the
  in-game time (`CurrentGame.advanceTimeBySeconds`, which the ring's asteroid field calls every frame,
  `AsteroidSpawner.gd` `_process`) and the turbines: each fission reactor (`REACTOR_SCRIPT`, `ships/Reactor.gd`
  `_physics_process`) draws `turbineConsumption` per second while it is enabled or not yet below its `coldLimit`; the
  fusion reactor's turbine burns nothing. Remass matters because what is left carries over to the next dive
  (`ship-ctrl.gd` `_exit_tree`, `storeCurrentSuppliesInConfig`).
- **The launch.** `Station.gd` extends `res://enceladus/Enceladus.gd`. It overrides `_on_DiveTarget_launch` and calls
  the parent's, which starts loading the ring scene (`Loader.prepare(game, true)`) and plays the launch sequence:
  `ExitPlayer`'s `LaunchSequence`, then, once the ship has power (`shipPowerToggle`), `Autopilot`'s `GoToRing`, which
  ends in `goToRing()`. Then, while `skipLaunch` is on, it does what the game's `_physics_process` does on
  `cutscene_ff` or `pause`: it stops both players and calls `goToRing()`. If the ring scene isn't loaded yet, the
  loader shows its bar and switches when it is (`Loader.gd` `goNow`).
- **The station's fade-in.** `Station.gd` also overrides `_ready`, which does not call the parent's (Godot runs the
  base first). The station's `AnimationPlayer` autoplays `FadeInCRT`, whose method key `Options.disable(false)` enables
  the menu at 3 s; while `skipStationFadeIn` is on, the override plays it through.
- **The arrival.** `Code.gd` extends `res://Game.gd` and overrides `_ready`, which does not call the parent's: the ship
  (`si`) is already spawned for the cutscene (`_respawn_ship`, which adds it to the tree deferred), and the base waits
  for its `setup`. While `skipTransit` is on, `_dstSkipArrival`:
  - puts the ship where the cutscene's braking leaves it, worked out from the game's own values: `initialPosition` and
    `initialSpeed`, which `_ready` computes from `desiredAcceleration` and `initialCutsceneTime`, and
    `totalCutsceneTime` (`Game.tscn` sets the two times). `_process` brakes along
    `initialSpeed - Vector2(1, 0) * desiredAcceleration * eclapsedTime`. Its heading is `_DST_RING_HEADING`, where
    `_process` turns it;
  - sets `eclapsedTime` to `totalCutsceneTime`, so the game's `_process` ends the cutscene on its next frame with its
    own code (the ship's `cutscene` off, the autopilot's end values, the time scale);
  - seeks the title card, `TitleAnimPlayer`'s `intro`, to its end;
  - once the ship is set up, charges `chargeDv` for the braking and `chargeSeconds` for the cutscene's length.
- **The return.** Diving back (the Astrogator's course to Enceladus, from a full stop) and overspeed both end in
  `ship-ctrl.gd` `escapeTheRing`: it turns the ship to the escape heading, sets the autopilot's desired velocity far
  out of the rings, with comfort and collisions off, claims the cargo and emits `exitingRing`. `Game.gd`
  `_on_exitingRing` plays `TitleAnimPlayer`'s `exit` and lets every ship take its leave (`handleExitToEnceladus`).
  `Code.gd` overrides `_on_exitingRing` and calls the parent's; then, while `skipTransit` is on, it plays `exit` through
  (`interlunarToEnceladus`, which charges the transit from the remass left; the asteroid field's `despawnAllAsteroids`;
  `goToEnceladus`, which saves and loads the station), charging each stretch with the burn (`_dstChargeEscape`) and
  `chargeSeconds`. Before the first key, the transit is charged from what the departure leaves, as in the cutscene.
  - **The burn** (`_dstEscapeBurn`, `_dstChargeEscape`): from the ship's velocity to the desired velocity, at full
    throttle on the thrusters that push along the ship's forward axis (`_DST_FORWARD`, where the escape heading
    points). The autopilot fires each thruster at its alignment with the push (`ship-ctrl.gd` `fireVector`, which fires
    switched-off thrusters too during a cutscene). A thruster pushes with `realThrust * cf` and burns
    `cf * realThrust * power / (specificImpulse * 10)` kg/s (`sfx/thruster.gd` `_physics_process`, `realThrust =
    getThrust() * 10`, `cf = getChoke()`), so the exhaust velocity is the push over the flow (a push of 1 is 1 t,
    `KG_PER_TONNE`, speeding up 1 world unit/s every second). Each stretch charges the rocket equation's remass for the
    change of speed still needed or what the thrusters reach in that stretch, whichever is smaller, from the mass at
    the start (`currentMass`, which the game recomputes every physics frame) less the remass drawn since.
- **The transit's speed** (`Code.gd`, the pacing), while `skipTransit` is off and the arrival (`cutscene`) or the exit
  (`exit` playing) runs:
  - The game's own fast-forward: during a cutscene, `Game.gd` `_process` sets `CurrentGame.targetTimeScale` every frame
    (the Space speed, `_DST_SPACE_SPEED`, while `cutscene_ff` is held, tapered on the arrival by `lerp(…, 1.0,
    eclapsedTime / totalCutsceneTime)`; else 1). `BulletTimer.gd` `_physics_process` eases `Engine.time_scale` towards
    it at `timeSlowPerSecond` per real second, then sets it back to 1.
  - The mod's speed (`_dstTransitPace`) is `transitSpeed`, tapered the same way on the arrival, and never below the
    target the game set, so holding Space still works. `_dstApplyPace` sets both the target and `Engine.time_scale`,
    from the mod's `_physics_process`: that runs after the previous frame's `Game.gd` `_process` and before
    BulletTimer's (a child of the scene), which then finds nothing to ease, so the speed holds from the first frame.
  - Physics steps by `time_scale / iterations_per_second`, so above the Space speed the mod raises
    `Engine.iterations_per_second` with the speed (from the rate when it started, times the speed over
    `_DST_SPACE_SPEED`): every step keeps the size the game's own fast-forward gives it, and the frame takes more of
    them. Godot 3 takes at most 8 physics steps a frame, which is where `transitSpeed`'s maximum comes from; a frame
    that can't keep up slows the game down instead of taking bigger steps. `Settings.gd` `_process` puts the rate
    back to the player's once a second, before the scene's `_process`; the mod's `_process` re-applies its own, so a
    frame never counts its steps from the player's rate at the mod's speed. The rate is otherwise read only for
    `applyKineticDamage`'s default delta, and a ship takes no collision damage during a cutscene.
  - Above the Space speed the master bus (`_DST_MASTER_BUS`) is muted. When the pacing stops (the arrival ends, `exit`
    is over, or the scene leaves the tree), `_dstStopPace` puts back the rate, normal time and the mute as the game
    sets it (`_dstRestoreMute`: muted while the window is out of focus, unless streaming, `Settings.gd`
    `_notification`).
- **The rescue.** `Game.gd` `_process` starts it once the ship has been helpless (out of remass) for
  `helplessTimeLimit`: the ship's cutscene on, its reactor off, its cargo claimed, then `TitleAnimPlayer`'s `helpless`,
  whose method keys are `sendHelp` (the stranded time, and the MAD-CERF rescue ship, which goes for the helpless
  ship but changes nothing) and `goToEnceladus`. That happens inside `_process`, so `Code.gd` connects the title card
  player's `animation_started` in `_ready`; on `helpless`, while `skipRescue` is on, it plays it through, deferred so
  the frame's processing ends first, charging `chargeSeconds`.
- **The game over.** A meltdown emits `CurrentGame.gameOver`; `Game.gd` `_on_gameOver` plays `gameover` the first time
  (`gamerunning`), whose method key `gameOverScreen` loads the title screen. `Code.gd` overrides `_on_gameOver`, calls
  the parent's, and only when that call started the game over, while `skipGameOver` is on, plays it through.
- **Astrogation.** `Ship.gd` extends `res://ships/ship-ctrl.gd`, the script of every ship scene (`ModLoader` comes
  before `Shipyard` in the game's autoloads, so even the scenes `Shipyard` preloads get it; `ship-ctrl.gd` has no
  `_init` and calls no autoload in its member initializers, so the loader's throwaway instance is safe). It overrides
  `fastTravelTo(target)`, which the game calls once a plotted course is complete (`handleTrajectoryProgress`): the game
  emits `fastTraveling` (`Game.gd` `_onFastTravel` plays the `fasttravel` title card) and, with the autopilot holding
  the travel velocity, waits, adds the travel time, waits, folds space (`teleportTo`: the world moves, not the ship)
  to put the ship short of the destination, waits again and stops. While `skipAstrogation` is on, for the player's
  ship (`isPlayerControlled()`) and any destination but `DESTINATION_ENCELADUS` (the return), the override takes the
  same steps without the waits: one `teleportTo` lands the ship at the game's arrival point plus the drift of the wait
  after the jump (`_DST_ASTROGATION_AFTER_JUMP`), at the travel velocity, and it charges `chargeDv` for the change to
  the travel velocity and `chargeSeconds` for the waits (`_DST_ASTROGATION_BEFORE_JUMP` and the after-jump wait).
  It never touches the ship's `cutscene` flag, whose setter would signal it on and off in the same frame. Otherwise it
  calls the parent's. `Code.gd` overrides `_onFastTravel`, calls the parent's, and while `skipAstrogation` is on plays
  the title card through.
- **The settings** follow CrewCheapHireNotifier's pattern, with the game-wide storage of the game's own settings:
  - **Shift+Click:** `StationMenu.gd` extends `res://enceladus/EnceladusMenu.gd`, the station menu. Its `_ready` finds
    the dive entry (`RingDive`, a plain Button with the key `ENCELADUS_RETURN_TO_RING`) and the right-hand screens
    container (`../../CanvasLayer/MarginContainer`, `enceladus/HidingMarginContainer.gd`) with its `Tuning` screen.
    Godot 3 emits a Control's `gui_input` signal before it calls the Control's own `_gui_input`, and `accept_event()`
    there stops the event: a left press with Shift on the enabled entry is accepted, so the entry never presses, and
    the settings open instead. The tooltip (`hint_tooltip`, `tr(_DST_SETTINGS_TOOLTIP)`) names the key with
    `OS.get_scancode_string(KEY_SHIFT)` and the mod's name from `Mod.manifest`; the menu's tooltip node
    (`PlaySoundsOnTheseButtons`) reads it again on every hover, and `_notification` sets it again after a language
    change. Without the container or its Tuning screen there are no settings, and Shift+Click is a plain click.
  - **With CrewCheapHireNotifier**, which extends the same menu script for its Crew entry: mods load by path, so the
    chain is game ← CrewCheapHireNotifier ← DiveSkipTransit. Both override `_ready` and `_notification`, which the
    game's script doesn't have, and don't call the parent's: Godot runs every level by itself. Each hooks its own entry,
    and their member names differ.
  - **The screen** (`SettingsUI.gd`) is CrewCheapHireNotifier's: one more of the right-hand screens, copying the live
    Tuning screen's theme, frame, size and place, built from the game's parts as `enceladus/Tuning.tscn` nests them
    (`Shower.tscn`; `HeaderWithMoney.tscn` titled with the entry's key; the description's window; and an `Items` box
    with one `Tuning/TuningItems.tscn` group per `GROUPS` entry, titled by it), and closed by `ui_cancel`, `pause` or
    the container's `hidefoka`. A group holds a row per setting of its `group`: a switch (`"type": "bool"`,
    `Tuning/TuningBoolValue.tscn`) or a slider (`"float"`, `Tuning/TuningFloatValue.tscn`, with the setting's `min`,
    `max`, `step`, `unit` and `format`), named by its `label` in the game's language, with ` ` and `REMASS_MARK` after
    it for a `remass` setting; a row whose `dimmedWhen` switch is on is dimmed (`DIMMED`). A row emits `tuningChanged`
    when it changes and again when it gets the focus (`TuningBoolValue.gd` / `TuningFloatValue.gd` `_focus`).
  - **The description's window** (`VB/WindowMargin/Window/MarginContainer/Description`, an autowrapping Label) is
    nested as `Tuning.tscn` nests the game's (`VB/WindowMargin/Window/…/Description`, without the simulator's parts),
    with the live Tuning screen's theme and margins around it, its panel and the margins inside it, copied when they
    are there. On every `tuningChanged`, the screen sets its text to the row's `label` followed by
    `DESCRIPTION_SUFFIX`, a key of `i18n/en.po` the Label translates, as `Tuning.gd` `tuningChanged` does for the
    game's rows; so it follows the selection, by mouse or controller, and shows the first row's when the screen opens
    (`Tool.deferCallWhenIdle(first, "focus")`). Its height is kept for `DESCRIPTION_LINES` lines, from its font's
    height and line spacing, so the groups don't move as it changes.
  - **The note** (`RemassNote`, a Label between the window and the groups) explains the mark (`tr(REMASS_NOTE)`, whose
    `%s` is the mark). The screen is filled each time it opens, so names, descriptions and note follow a language
    change.
  - **A switch's value**: the switch sends the `current` of its row's dictionary (`tune`) when it gets the focus, and
    never updates it; that dictionary is the screen's own, so the screen sets `current` on every change, or focusing a
    switch again would turn it back (a slider keeps its own, `TuningFloatValue.gd` `changed`).
  - **The model** (`Settings.gd`, a `Reference`): `shared()` returns the one instance, kept as metadata of the script,
    loaded from the file when first made. `SETTINGS` describes each setting (`label`, which with `DESCRIPTION_SUFFIX`
    also names its description, `default`, `type`, `group`; for a slider its range, step, unit and format; `remass`
    where skipping charges remass; `dimmedWhen`), in display order within its group. `getValue(key)`;
    `setValue(key, value)` takes only a bool for a switch and only a number for a slider, snapped to its step and range
    (anything else gives the default), and, on a change only, saves and emits `settingsChanged`. `loadFromFile()`
    overlays the defaults with the file's values (a key missing from an older file keeps its default, or what the file
    held under the key's old names: format 2's `skipArrival` and `skipExit` give `skipTransit`, on only if both were);
    `saveToFile()` writes them. The file, `filePath` (`user://<the mod's id>.cfg`), holds one section named by the
    mod's id, with `formatVersion` (`FORMAT_VERSION`), `modVersion` and each setting. The skips read the model when
    their cutscene starts, so a change applies to the next one. Scripts reach it through the preload constant
    `DiveSkipTransit`, never `Settings`, which would hide the game's autoload.
  - **The texts:** `i18n/en.po`, loaded in `ModMain.gd` with `load()` and `TranslationServer.add_translation`, as the
    game loads its own `.po` files. English is Godot's fallback language, so every language shows it until it gets its
    own file.
- Members of `Code.gd`: `DiveSkipTransit` (preload), `_DST_RING_HEADING`, `_DST_FORWARD`, `_DST_SPACE_SPEED`,
  `_DST_MASTER_BUS`, `_dstBurn`, `_dstPace`, `_dstBaseRate`, `_dstSkipArrival()`, `_dstChargeExitStretch()`,
  `_dstOnTitleCard()`, `_dstSkipRescue()`, `_dstChargeStretch()`, `_dstEscapeBurn()`, `_dstChargeEscape()`,
  `_dstTransitPace()`, `_dstApplyPace()`, `_dstStopPace()` and `_dstRestoreMute()`; it overrides `_ready`,
  `_on_exitingRing`, `_on_gameOver` and `_onFastTravel`, and adds `_physics_process`, `_process` and `_exit_tree`
  (`Game.gd`'s own `_process` still runs: Godot runs every level of it). Of `Ship.gd`: `DiveSkipTransit` (preload),
  `_DST_ASTROGATION_BEFORE_JUMP`, `_DST_ASTROGATION_AFTER_JUMP`; it overrides `fastTravelTo`. Of `Station.gd`:
  `DiveSkipTransit` (preload); it overrides `_ready` and `_on_DiveTarget_launch`. Of `StationMenu.gd`:
  `DiveSkipTransit` and `_DST_SETTINGS_UI` (preloads), `_DST_SETTINGS_TOOLTIP`, `_dstDiveButton`, `_dstDiveKey`,
  `_dstSettingsScreen`, `_dstScreens`, `_dstTuning`, `_dstUpdateTooltip()`, `_dstOnDiveInput()` and
  `_dstOpenSettings()`; it adds `_ready` and `_notification`, which the game's script doesn't have. No tunables.
- Tested only outside the game, in a headless Godot 3.6 (the harness's `skip` suite): the game's `Game.gd` on a stub
  of the ring scene with the game's own title cards and values, the game's `Enceladus.gd` with the game's `FadeInCRT`,
  the game's `ship-ctrl.gd` (with the extension) for astrogation, and the game's `EnceladusMenu.gd`,
  `HidingMarginContainer.gd`, `Shower.tscn`, `TuningItems.gd`, `TuningBoolValue.gd`, `TuningFloatValue.gd` and
  `AnalogControlSlider.gd` in a station built as its scene nests them, with stub ships holding the game's reactor
  scripts and stub thrusters; alone and with CrewCheapHireNotifier. It has not been checked in a real game.

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
