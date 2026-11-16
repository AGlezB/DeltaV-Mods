# DiveSkipTransit - ΔV: Rings of Saturn

Every dive starts in the ring at once, with you in control: no launch sequence at the station and no arrival cutscene
in the ring. What the arrival would have cost in remass and in-game time is charged all the same.

## Warning
This mod changes how the game plays, though it tries not to. Compared to vanilla:
- the launch sequence is cut as soon as it starts, the way the game cuts it when you press Esc, so the station
  seconds it would take don't pass;
- the arrival cutscene is skipped. Your ship starts where the cutscene would leave it, and the mod charges what the
  cutscene would have cost, from the game's own formulas: the remass to brake, the remass the reactor's turbine burns
  and the in-game time. It doesn't charge the remass the ship spends turning, or what a damaged reactor might vent in
  those seconds. A ship too weak to brake as fast as the cutscene asks starts as if it had.

Before reporting a bug with the start of a dive to the game's developers, check that it also happens without the mod.

## What it does and why
- **What:** after you press Launch Ring Dive and pick the dive target, the game goes straight to the ring. There, the
  arrival cutscene (the ship braking in under the title card and the transit tip) doesn't play: the ship starts where
  the cutscene leaves it, slowed down and facing into the rings, and you are in control from the first frame.
- **Why:** to save time on every dive. The game lets you skip only the launch sequence (Esc), and only speed up the
  arrival (Space, 3x, with VHS stripes).
- **No gameplay effects, as far as possible:** in the cutscene the ship really flies. It brakes, its reactor's turbine
  burns remass, and in-game time passes. The remass left after a dive carries over to the next one, and the resupply
  before a dive tops it up for E$, so the mod charges that remass and that time once your ship is ready.
- Only the start of a dive changes. Leaving the ring (diving back, overspeed, running out of remass, a reactor
  meltdown) and fast travel inside the ring are as in the game.

## For modders
- Two script extensions (`installScriptExtension` in `ModMain.gd`): `Code.gd` of `res://Game.gd`, the ring scene
  (`Game.tscn`), and `Station.gd` of `res://enceladus/Enceladus.gd`, the station. The tag `group = Game` in
  `Mod.manifest` names the main one.
- **The launch.** `Station.gd` overrides `_on_DiveTarget_launch` and calls the parent's, which starts loading the ring
  scene (`Loader.prepare(game, true)`) and plays the launch sequence: `ExitPlayer`'s `LaunchSequence`, then, once the
  ship has power (`shipPowerToggle`), `Autopilot`'s `GoToRing`, which ends in `goToRing()`. Then it does what the
  game's `_physics_process` does on `cutscene_ff` or `pause`: it stops both players and calls `goToRing()`. If the ring
  scene isn't loaded yet, the loader shows its bar and switches when it is (`Loader.gd` `goNow`). The station's ship
  is thrown away with the scene, so there is nothing to charge.
- **The arrival.** `Code.gd` overrides `_ready`, which does not call the parent's: Godot runs the base first, so the
  ship (`si`) is already spawned for the cutscene (`_respawn_ship`, which adds it to the tree deferred), and the base
  waits for its `setup`. The override, `_dstSkipArrival`:
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
- The remass matters because what is left carries over to the next dive (`ship-ctrl.gd` `_exit_tree`,
  `storeCurrentSuppliesInConfig`).
- New members: `_dstSkipArrival`, `_dstChargeDv`, `_dstChargeSeconds`, and the constants `_DST_REACTOR_SCRIPT`,
  `_DST_RING_HEADING` and `_DST_UNITS_PER_METRE`. No tunables.
- Tested only outside the game, in a headless Godot 3.6 (the harness's `skip` suite). It ran the game's `Game.gd` on a
  stub of the ring scene with the game's own title card and values, and the game's `Enceladus.gd`, with a stub ship
  holding the game's reactor scripts. It has not been checked in a real game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).
