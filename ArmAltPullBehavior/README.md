# ArmAltPullBehavior - ΔV: Rings of Saturn

Changes how the AR-1500 salvage arm (`SYSTEM_SALVAGE_ARM` on a ship) brings a target in and holds it: while feeding,
along a path into the grinder or excavator that keeps clear of the rotors, claws and hull, without stopping at the
opening; while not feeding, at the dock slot, steady against the ship's thrust and turns. Station dock arms are left
alone. Works together with `ArmAltTargetSelection`, but does not need it (the two do not touch each other's code).

**Only ships with a grinder or an excavator are covered.** On any other ship (the OCP-209, for one) the mod
does nothing at all and the game's own arm handling applies.

![While feeding, shown on the Eagle-Prospector-VP](../_wiki/images/ArmAltPullBehavior-feeding.png)

![While not feeding, shown on the Eagle-Prospector-VP](../_wiki/images/ArmAltPullBehavior-not-feeding.png)

*Eagle-Prospector-VP, facing up, worked out in the test harness with the mod's own code: paths of a 3 t chunk, the ship
still, coloured by speed. Red: the red line. Yellow: the grinder's rotors; grey: the hull; black dot: the arm base;
square: the dock slot; light grey: what the arm can reach. First picture, feeding (excavator key held): crosses, the
gate points; shaded, the straight zone; dark lines, the steepest straight ways in, and circles, where they cross the
red line. Second picture, not feeding: blue, how far in the mod holds a light chunk while the ship turns or brakes.
Close-ups of the grinder on the right. On an excavator (the EIME) the opening is the gap between the claw tips.*

## Warning
This mod changes how the game plays. Compared to vanilla, on ships with a grinder or an excavator, the AR-1500 arm:
- while feeding, brings a chunk in along a curved path that keeps it off the outer side of the rotors / claws, without
  stopping it at the opening, faster than the game does;
- while not feeding, holds the chunk at the dock slot itself, making up for the ship's thrust and turns as far as the
  arm's strength allows, and holds a light one closer to the ship while the ship turns or brakes;
- measures a chunk's speed against the hull, so turning the ship doesn't fling it away or push it into the rotors /
  claws.

On other ships (the OCP-209, for one) nothing changes. Before reporting a bug with the arm to the game's developers,
check that it also happens without the mod.

## What it does and why

### 1. The way in while feeding
- **How the game pulls:** the game always pulls a target towards the arm's dock slot (33.75 m ahead of the arm base on
  the AR-1500), and only while the player holds the excavator key does it also push it straight back, along the
  direction the arm faces (the feed, `feedVelocity`, 28 m/s). A target that is not in line with the opening is pushed
  into the rotors / claws or the hull, and one that is in line is pulled back towards the dock slot as it nears the
  ship, so it comes in slowly.
- **What has to be kept clear (why):** only the outer half of each rotor / claw, the side away from the opening. Between
  them is where chunks go in: touching their inner sides is the grinder or the beak taking the chunk. A chunk keeps off
  the near one's outer half if its centre passes at or inside the **gate point**: a chunk's radius ahead of that
  rotor's / claw's front point. So a chunk coming in at an angle aims past the near one, towards the opposite one,
  but no farther than the opposite one's front point, or it would reach that one's outer half. The paths keep a margin
  inside both (a chunk's radius, or half the opening's half-width if that is less): the arm turns a chunk slowly, and
  a ship turning under its pull moves the opening sideways.
- **The straight zone (what):** where a straight path into the opening passes inside the gate point, at most as steep as
  the steepest one (from inside the gate point to the opposite side's line; about 29° from the centre line on the
  Vulture), the chunk comes straight in: towards the middle, or past the gate point when it comes in steeper.
- **From anywhere else (what):** the chunk heads for the **join point**, where the steepest straight way in crosses the
  red line, turned aside by `TURN_FACTOR` times the angle it still has to come round, seen from there. The path has the
  same shape at every distance, like a logarithmic spiral: nearly straight far away, bending more near the join
  point, and arriving in line with the steepest straight way in, which it then follows. Close to the join point
  (`JOIN_DISTANCE_FACTOR` chunk radii), within the margin of that way in, the chunk goes straight in if it can pass
  inside the gate point.
- **Why curves, and why that one:** a chunk that comes in from the side can't turn instantly, the arm being weak; going
  first to the opening and stopping there (what this mod did up to 1.5.4) wastes the speed it has. A curve that bends
  late keeps it moving, and `TURN_FACTOR` was chosen from a path simulation: lower makes the last bend too tight for
  the arm, and chunks touched a rotor's outer half.
- **The red line:** the front of the rotors / claws moved forward by `CHUNK_RADIUS_CLEARENCE_FACTOR` times the largest
  mineral chunk's radius. Chunks from the side or at a steep angle are on a straight way in from there on. The radius
  (10.4 units, 1.04 m) is read from the game's mineral scene: every mineral chunk has the same collision circle and
  none is scaled above 1.0. If the scene cannot be read (the game changed), `CHUNK_RADIUS_FALLBACK` (the radius in the
  game files when the mod was made) is used.
- **Speed:** the feed's (`feedVelocity` times the feed, or the game's own pull where that is faster, ahead of the dock
  slot), but on a bend and while the ship turns no faster than the arm's spare strength allows (see 3): the bend's
  pull towards its centre is the speed squared times the curvature, and a bend tightens towards its end, so the
  tightest part the chunk reaches in the time the arm takes to slow it counts.
- **Next to the hull:** a circle as big as a chunk, swept along the way the chunk is about to go for the red line's
  clearance, is tested against the ship's own collision shapes. If it touches them, the chunk is pulled straight
  forward instead, in the direction the arm faces, at least to a chunk's radius past the red line.
- **Opening:** measured from tip to tip, between the points of the two rotors / claws that reach farthest ahead (from
  their collision shapes). For the EIME's beak that is the gap between the claws' tips, so it follows the beak as it
  opens and closes. It is measured every time, since the rotors and claws move. If it is narrower than a chunk (a
  closed beak), a fed chunk is pulled straight forward to a chunk's radius past the red line and held there until the
  beak opens.

### 2. Holding while not feeding
- **What:** the mod holds the target at the dock slot itself, where the game's pull would take it. It comes to the dock
  slot quickly and slows down near it without overshooting: `RESPONSE_RATE` sets how quickly. Behind the red line and
  outside the corridor (in line with the opening), where the straight line to the place it is held at would come too
  close to the hull (the room the red line keeps, swept as above), the target is pulled straight forward first, to a
  chunk's radius past the red line, until that line is clear.
- **Why:** the game's pull only acts once the target lags, and overshoots the dock slot by several metres; when the ship
  turns or thrusts, the target swings out, far enough for the arm to let go of it.

### 3. Holding against the ship's motion
- **What:** feeding and holding, the mod works out the force the target needs and has the game's formula give it, by
  choosing the speed difference that makes the formula give that force. The target needs:
  - what the point of the hull under it does: the ship's acceleration (measured from the change in the ship's velocity
    over a frame, leaving out what the mod's own push did to the ship, smoothed over `ACCEL_SMOOTHING`) and the pull
    towards the ship's centre as the ship turns (its turning speed squared times the distance);
  - the sideways throw a turning hull gives a target that moves relative to it (twice the turning speed times its
    speed);
  - and `RESPONSE_RATE` times the difference between the speed it should move at relative to the hull (along its path,
    or towards where it is held) and the speed it moves at.
- **The arm's strength:** the force is never more than the game's own pull could give at the target's speed relative to
  the hull: what its formula gives at a speed difference of that speed plus maxVelocity (plus the feed while feeding).
  At rest relative to the hull, on the Vulture's AR-1500, that holds any chunk over 1.25 t through about 16 m/s² of
  acceleration along the arm and a steady turn of about 35°/s at the dock slot. Beyond that the target falls behind
  until the ship's motion eases; the target's own speed relative to the hull is cut, while the ship turns, so its
  sideways throw stays within `BRAKE_SHARE` of the strength left.
- **Overloaded:** while not feeding, the pull back towards the arm base gets the arm's strength first: the game lets go
  of a target more than two arm lengths (45 m) from the arm base (`DockingArm.gd` `_physics_process`). While feeding,
  the push across the path does, so the chunk slows down on its path instead of drifting off it near the rotors.
- **Left out on purpose:** the ship's turning acceleration, and the way the ship turns when the arm pushes it back at the
  target. The ship's own control holds its heading against the arm, so a measured turning acceleration is mostly that
  tug of war, and allowing for it pushed targets the wrong way in the harness. The turning speed is read as it is.
- **Why measured without its own push:** counting its own push as the ship's acceleration, the mod would push harder
  for every push it gave. 1.3.0 did that, and flung chunks away in the game: on the Vulture the ship's nose gives way
  more easily, sideways at the dock slot, than a chunk does.
- **Speed measured against the hull:** the game measures the target's speed against its dock slot, which moves much
  faster than the ship's nose when the ship turns. The mod measures it against the hull at the target's position.

### 4. Closer while the ship turns or brakes
- **What:** a target lighter than `CLOSER_MASS_LIMIT` (every mineral chunk, lifepod, AI core, drone and frozen body; no
  ship) is held closer to the ship than the dock slot while the ship turns or accelerates backwards: on the way from
  the dock slot to the middle of the opening a chunk's radius past the red line, in proportion to the turning speed
  and to the backward acceleration, all the way in at `CLOSER_FULL_SHARE` of the arm's limits (the turn it can hold the
  target through at the dock slot, the acceleration it can make up for). Once the ship stops, it goes back out over
  `CLOSER_RELEASE_TIME`. A heavier target stays at the dock slot.
- **Why:** held closer, a turn pulls the target outwards less (its turning speed squared times its distance from the
  ship's centre) and its changes swing it less, so the arm keeps it through faster turns; and it has more of the arm's
  reach to spare, two arm lengths from the arm base, before the game lets go of it. Backward acceleration leaves the
  target out in front of the ship, the way the turn pulls it, so the two add up. The point moves in before the arm is
  at its limit, since moving in while the ship turns takes a sideways push; it goes back out slowly, so a ship turning
  back and forth doesn't send the target out and in at every change. A ship brought closer would hit the ship holding
  it, hence the mass limit; accelerating forwards pushes the target towards the ship, where it needs room ahead of the
  intake, so that doesn't bring it in.

### 5. Cost of the mod's pull
- **What:** the mod's pull costs what the game's own pull costs, with the game's own formula: energy, capped by the arm's
  power limit; wear, which grows with the square of the power used (added on the game's random 1% of frames, scaled
  to the same average); and the weakening of a worn or overheated arm. An arm that holds nothing is not worn, as in
  the game.
- **Why:** the game wears the arm only through its own pull, which the mod switches off while it pulls a target.
  Without this, the mod's pull would be free and always at full strength.

### 6. Ships it does not cover
- **What:** a ship without a grinder or excavator (with their two rotors / claws) is left to the game: the arm's
  `maxThrust` is restored and nothing is added. The rotors / claws are looked up on every physics frame and nothing is
  remembered about a ship, so switching ships takes effect at once.
- **Why:** such ships have no rotors or claws to protect and no opening to measure. The OCP-209, for example, takes
  targets in through an opening in its side, not through a grinder or claws.

## For modders
- Script extension of `res://ships/modules/DockingArm.gd` (`installScriptExtension` in `ModMain.gd`). The tag
  `group = DockingArm` in `Mod.manifest` names that game script.
- Overrides `_ready` (reads the chunk radius) and `_physics_process`. Neither calls the parent's: the mod loader runs the
  base first for `_ready`, and the child first for `_physics_process`, which switches the base pull off
  (`maxThrust = 0`) while the mod pulls the target.
- Functions: `_readChunkRadius`; `_entry` (the measurements: the tip, half the opening, the red line and the front of the
  rotors / claws; null where the mod does not apply); `_frontPoint`; `_outside` (where the target must go; null where
  the mod does not apply); `_pathAt` (the path while feeding: the straight zone and the turned aim); `_inwardSpeed`
  (the feed's speed); `_hitsHull` (the sweep test against the ship's collision shapes); `_pullTo` (the force the target
  needs, given through the game's formula); `_roomFor` (the speed a bend and a turn leave room for); `_shorten` (the
  overload priority); `_parkVelocity` (the speed towards a place it is held at); `_forceFor` (the force for an
  acceleration relative to the hull, the ship's give included); `_updateCloser` (how far in a light target is held);
  `_measureShip` (the ship's acceleration without the mod's own push); `_cost` (the game's energy, power limit, wear
  and weakening for an impulse) and `_shipVelocityAt` (the velocity of the ship's hull at a point).
- Members: `_active`, `_radius`, `_clearance`, `_sweep`, `_body`, `_maxThrust`, `_parking` (not feeding: held at the dock
  slot rather than moved forward first), `_feedIn` (feeding, in line with the opening), `_passThrough` (straight forward
  without slowing down), `_way` (the path while feeding), `_lastTarget`, `_shipSeen`, `_lastShipVelocity`,
  `_lastImpulse`, `_shipAccel`, `_closer` and `_parkAt` (the place a target is held at). If you stack another mod on
  `DockingArm.gd`, keep your member names different.
- The mod reads the arm's `feed` (the excavator command), `feedVelocity`, `areaDockSlot` (its dock slot), `maxVelocity`,
  `easeDistance`, `thrust`, `targetMassThrust`, `fullThrust` and `maxVelocityConsidered`, and the ship's `mass`,
  `linear_velocity` and `angular_velocity`.
- Everything is taken from the game: the ship's `grinder1node` / `grinder2node` (grinder) or `Claw Left` / `Claw Right`
  (excavator) found through `ship.hasSystem`, their collision shapes, the ship's own collision shapes (its hull), and
  the arm's own values. No list of ship models is needed.
- The mod only applies where `systemName == "SYSTEM_SALVAGE_ARM"` and the arm has a `ship`.
- Constants at the top of `ArmAltPullBehavior/Code.gd` inside the zip: `ENTRY_SYSTEMS`,
  `CHUNK_RADIUS_CLEARENCE_FACTOR`, `CHUNK_SCENE`, `CHUNK_RADIUS_FALLBACK`, `RESPONSE_RATE`, `ACCEL_SMOOTHING`,
  `BRAKE_SHARE`, `CLOSER_MASS_LIMIT`, `CLOSER_FULL_SHARE`, `CLOSER_RELEASE_TIME`, `TURN_FACTOR`,
  `JOIN_DISTANCE_FACTOR`. The game shows 10 units as 1 m.
- The game unlocks the arm (`locked`, so neither its pull nor the mod's acts) while a target is more than `maxDist`
  (35 m on the AR-1500) from the dock slot, nearer to that the faster it moves relative to it, or more than two arm
  lengths from the arm base (`DockingArm.gd` `_physics_process`; see GAME.md *Arm* in the repository).
- Tested outside the game, in a headless Godot 3.6 with the game's scripts (`DockingArm.gd`, `Tool.gd` ...) and stub
  scenes, including a simulated Eagle-Prospector-VP with the arm's real placement and values, the real rotor positions
  and hull (and the turning inertia Godot works out from it), a 109 t and a 330 t ship, 2.8 t, 3 t and 5 t chunks,
  feeding and not feeding, with the ship still, cruising at 10 to 40 m/s, turning, accelerating and braking: a fed
  chunk first touches the rotors on their inner side in every case within the arm's strength, and a held one stays
  near where it is held and comes back to the dock slot.

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
