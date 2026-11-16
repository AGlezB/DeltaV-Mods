# DiveSkipTransit - ΔV: Rings of Saturn

Every dive starts in the ring at once, with you in control, and diving back takes you straight to the station: no
launch sequence, no arrival cutscene, no departure and transit cutscene. What those cutscenes would have cost in
remass and in-game time is charged all the same. Each skip has its own switch: Shift+Click Launch Ring Dive.

## Warning
This mod changes how the game plays, though it tries not to. Compared to vanilla:
- the launch sequence is cut as soon as it starts, the way the game cuts it when you press Esc, so the station
  seconds it would take don't pass;
- the arrival cutscene is skipped. Your ship starts where the cutscene would leave it, and the mod charges what the
  cutscene would have cost, from the game's own formulas: the remass to brake, the remass the reactor's turbine burns
  and the in-game time. It doesn't charge the remass the ship spends turning, or what a damaged reactor might vent in
  those seconds. A ship too weak to brake as fast as the cutscene asks starts as if it had;
- the exit cutscene (diving back, or leaving at overspeed) is skipped: you go straight to the station, and the mod
  charges what the cutscene would have cost: the remass of the burn away from the ring, the turbine's and the
  in-game time, with the transit charged in between, as the cutscene does. The burn is an estimate at full throttle
  from the first moment: it doesn't count the time a ship needs to turn round first (at overspeed), how its thrust
  builds up, or the power and heat its thrusters might lack, so it can charge a little more remass than the cutscene
  would burn;
- your real-time playtime (the game's statistics) counts only the time you actually play.

Each of the three can be switched off (see *Settings*). Before reporting a bug with the start or the end of a dive to
the game's developers, check that it also happens without the mod.

## What it does and why
- **The launch:** after you press Launch Ring Dive and pick the dive target, the game goes straight to the ring.
- **The arrival:** in the ring, the arrival cutscene (the ship braking in under the title card and the transit tip)
  doesn't play: the ship starts where the cutscene leaves it, slowed down and facing into the rings, and you are in
  control from the first frame.
- **The return:** when you dive back, or leave the ring at overspeed, the exit cutscene (the ship burning away from
  the ring, then the title card of the trip to Enceladus) doesn't play: the screen goes black at once, and the station
  loads. Running out of remass (the rescue) and a reactor meltdown still play their cutscenes.
- **Why:** to save time on every dive. The game lets you skip only the launch sequence (Esc), and only speed up the
  ring's cutscenes (Space, 3x, with VHS stripes).
- **No gameplay effects, as far as possible:** in the ring's cutscenes the ship really flies. It brakes or burns away,
  its reactor's turbine burns remass, and in-game time passes. The remass left after a dive carries over to the next
  one, and the resupply before a dive tops it up for E$, so the mod charges that remass and that time.
- **Settings:**
  - **Shift+Click** Launch Ring Dive to open them, as the entry's tooltip says. A plain click still launches a dive.
    The settings open where the Tuning screen does, with the same frame and the game's own Tuning switches, and close
    the way the game's screens do: Esc, the controller's B or Start button, or picking another entry of the menu.
  - One group, *Skip*, with a switch for each: *Launch sequence*, *Arrival in the ring*, *Return to the station*. Each
    has a button that resets it to its default. A change applies to the next sequence of that kind.
  - They are game-wide, the same for every save, and written at once to a file of the mod's own in the game's user
    folder. Every skip starts switched on.
  - Opening them needs a mouse and a keyboard; a controller can use and close them.
  - Each switch's default is in `SETTINGS` at the top of `DiveSkipTransit/Settings.gd`, inside the zip. The mod's texts
    (the tooltip, the group's and the switches' names) are in `DiveSkipTransit/i18n/en.po`.

## For modders
- Five scripts: `Code.gd` (the ring scene's script extension: the arrival and the exit), `Station.gd` (the station's:
  the launch), `StationMenu.gd` (the station menu's: Shift+Click on the dive entry), `SettingsUI.gd` (the settings
  screen) and `Settings.gd` (the settings model, which the other four share). The texts are in `i18n/en.po`. The tag
  `group = Game` in `Mod.manifest` names the main game script, `res://Game.gd`.
- **The launch.** `Station.gd` extends `res://enceladus/Enceladus.gd`. It overrides `_on_DiveTarget_launch` and calls
  the parent's, which starts loading the ring scene (`Loader.prepare(game, true)`) and plays the launch sequence:
  `ExitPlayer`'s `LaunchSequence`, then, once the ship has power (`shipPowerToggle`), `Autopilot`'s `GoToRing`, which
  ends in `goToRing()`. Then, while `skipLaunch` is on, it does what the game's `_physics_process` does on
  `cutscene_ff` or `pause`: it stops both players and calls `goToRing()`. If the ring scene isn't loaded yet, the
  loader shows its bar and switches when it is (`Loader.gd` `goNow`). The station's ship is thrown away with the scene,
  so there is nothing to charge.
- **The arrival.** `Code.gd` extends `res://Game.gd` and overrides `_ready`, which does not call the parent's: Godot
  runs the base first, so the ship (`si`) is already spawned for the cutscene (`_respawn_ship`, which adds it to the
  tree deferred), and the base waits for its `setup`. While `skipArrival` is on, `_dstSkipArrival`:
  - puts the ship where the cutscene's braking leaves it, worked out from the game's own values: `initialPosition` and
    `initialSpeed`, which `_ready` computes from `desiredAcceleration` and `initialCutsceneTime`, and
    `totalCutsceneTime` (`Game.tscn` sets the two times). `_process` brakes along
    `initialSpeed - Vector2(1, 0) * desiredAcceleration * eclapsedTime`. Its heading is `_DST_RING_HEADING`, where
    `_process` turns it;
  - sets `eclapsedTime` to `totalCutsceneTime`, so the game's `_process` ends the cutscene on its next frame with its
    own code (the ship's `cutscene` off, the autopilot's end values, the time scale);
  - seeks the title card, `TitleAnimPlayer`'s `intro`, to its end;
  - once the ship is set up, charges the braking with `_dstChargeDv`: the game's rocket equation (`ship-ctrl.gd`
    `getRemassRequiredForDv`) for the change of speed in m/s (`_DST_UNITS_PER_METRE`). It charges the turbines and
    the in-game time with `_dstChargeSeconds`. The fission reactor (`_DST_REACTOR_SCRIPT`, `ships/Reactor.gd`
    `_physics_process`) draws `turbineConsumption` per second while it is enabled or not yet below its `coldLimit`;
    the fusion reactor's turbine burns nothing. The time goes through `CurrentGame.advanceTimeBySeconds`, which the
    ring's asteroid field calls every frame (`AsteroidSpawner.gd` `_process`).
- **The exit.** Diving back (the Astrogator's course to Enceladus, from a full stop) and overspeed both end in
  `ship-ctrl.gd` `escapeTheRing`: it turns the ship to the escape heading, sets the autopilot's desired velocity far
  out of the rings, with comfort and collisions off, claims the cargo and emits `exitingRing`. `Game.gd`
  `_on_exitingRing` plays `TitleAnimPlayer`'s `exit` and lets every ship take its leave (`handleExitToEnceladus`).
  `Code.gd` overrides `_on_exitingRing` and calls the parent's; then, while `skipExit` is on, `_dstSkipExit` reads the
  method keys of `exit` from the animation (`interlunarToEnceladus`, which charges the transit from the remass left;
  the asteroid field's `despawnAllAsteroids`; `goToEnceladus`, which saves and loads the station) and calls them at
  once, in time order. Before each, it charges the stretch of the cutscene since the previous one: the burn, the
  turbines and the in-game time. Nothing is charged after the last key, where the scene switches. A seek to the end
  (which calls no method keys) leaves the title card's last frame, black, until the station is loaded.
  - **The burn** (`_dstEscapeBurn`, `_dstChargeEscape`): from the ship's velocity to the desired velocity, at full
    throttle on the thrusters that push along the ship's forward axis (`_DST_FORWARD`, where the escape heading
    points). The autopilot fires each thruster at its alignment with the push (`ship-ctrl.gd` `fireVector`, which fires
    switched-off thrusters too during a cutscene). A thruster pushes with `realThrust * cf` and burns
    `cf * realThrust * power / (specificImpulse * 10)` kg/s (`sfx/thruster.gd` `_physics_process`, `realThrust =
    getThrust() * 10`, `cf = getChoke()`), so the exhaust velocity is the push over the flow (a push of 1 is 1 t,
    `_DST_KG_PER_TONNE`, speeding up 1 world unit/s every second). Each stretch charges the rocket equation's remass
    for the change of speed still needed or what the thrusters reach in that stretch, whichever is smaller, from the
    mass at the start (`currentMass`, which the game recomputes every physics frame) less the remass drawn since.
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
    (`Shower.tscn`, `HeaderWithMoney.tscn` titled with the entry's key, and an `Items` box with one
    `Tuning/TuningItems.tscn` group, `GROUP_LABEL`), and closed by `ui_cancel`, `pause` or the container's `hidefoka`.
    The group holds one switch (`"type": "bool"`, `Tuning/TuningBoolValue.tscn`) per setting, named by its `label`.
    A switch emits `tuningChanged` when toggled and again when it gets the focus, with the `current` of its
    description (`TuningBoolValue.gd` `_focus`), which it never updates; that description is the screen's own
    dictionary, so the screen sets `current` on every change, or focusing a switch again would turn it back.
  - **The model** (`Settings.gd`, a `Reference`): `shared()` returns the one instance, kept as metadata of the script,
    loaded from the file when first made. `SETTINGS` describes each switch (`label`, `default`, `type`), in display
    order. `getValue(key)`; `setValue(key, value)` keeps anything that isn't a bool at the default and, on a change
    only, saves and emits `settingsChanged`. `loadFromFile()` overlays the defaults with the file's values;
    `saveToFile()` writes them. The file, `filePath` (`user://<the mod's id>.cfg`), holds one section named by the
    mod's id, with `formatVersion` (`FORMAT_VERSION`), `modVersion` and each setting. The skips read the model when
    their sequence starts, so a change applies to the next one. Scripts reach it through the preload constant
    `DiveSkipTransit`, never `Settings`, which would hide the game's autoload.
  - **The texts:** `i18n/en.po`, loaded in `ModMain.gd` with `load()` and `TranslationServer.add_translation`, as the
    game loads its own `.po` files. English is Godot's fallback language, so every language shows it until it gets its
    own file.
- Members of `Code.gd`: `DiveSkipTransit` (preload), `_DST_REACTOR_SCRIPT`, `_DST_RING_HEADING`,
  `_DST_UNITS_PER_METRE`, `_DST_FORWARD`, `_DST_KG_PER_TONNE`, `_dstSkipArrival()`, `_dstSkipExit()`,
  `_dstIsKeyBefore()`, `_dstEscapeBurn()`, `_dstChargeEscape()`, `_dstChargeDv()` and `_dstChargeSeconds()`. Of
  `Station.gd`: `DiveSkipTransit` (preload). Of `StationMenu.gd`: `DiveSkipTransit` and `_DST_SETTINGS_UI` (preloads),
  `_DST_SETTINGS_TOOLTIP`, `_dstDiveButton`, `_dstDiveKey`, `_dstSettingsScreen`, `_dstScreens`, `_dstTuning`,
  `_dstUpdateTooltip()`, `_dstOnDiveInput()` and `_dstOpenSettings()`. No tunables.
- Tested only outside the game, in a headless Godot 3.6 (the harness's `skip` suite): the game's `Game.gd` on a stub
  of the ring scene with the game's own `intro` and `exit` title cards and values, the game's `Enceladus.gd`, and the
  game's `EnceladusMenu.gd`, `HidingMarginContainer.gd`, `TuningItems.gd` and `TuningBoolValue.gd` in a station built
  as its scene nests them, with a stub ship holding the game's reactor scripts and stub thrusters; alone and with
  CrewCheapHireNotifier. It has not been checked in a real game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).
