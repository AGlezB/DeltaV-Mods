# ArmAltPullBehavior - Changes

## 1.6.3
- The README no longer names other mods: where the mod meets another one, it says what it does there in general
  terms.

## 1.6.2
- Licensed under the MIT License instead of the GNU GPLv3: the LICENSE in the zip and the README's *About* and
  *Disclaimer* say so.

## 1.6.1
- The arm's entry in the OMS's Mechanic tab shows the power the mod's pull draws, as the game's formula would, instead
  of nothing while the mod pulls (`_showPower`, `_drawn`).
- An excavator's claws are found once per excavator instead of on every physics frame (`_clawsOf`, `_claws`).
- The description in `Mod.manifest` only says what the mod does; the details are in the README.
- The README says Godot, not the mod loader, runs `_ready` and `_physics_process` at every level of the script chain.

## 1.6.0
- While feeding, a target no longer stops at the opening: it follows a path into the grinder or excavator. Only the
  outer half of each rotor / claw is kept clear, so a target coming in at an angle aims past the near one's outer side,
  towards the opposite one. From in front it comes straight in; from the side or from behind the red line it curves
  round (`TURN_FACTOR`) to where the steepest straight way in crosses the red line (`JOIN_DISTANCE_FACTOR`), then comes
  straight in. Faster everywhere in the harness, from every start, ship still or moving.
- While not feeding, the mod holds the target at the dock slot itself instead of leaving it to the game's pull,
  straight forward first beside the hull as before.
- Feeding and holding allow for the ship's motion: its acceleration (measured, leaving out the mod's own push), the
  pull outwards of a turn and the sideways throw a turn gives a moving target, up to what the game's formula can give.
  Beyond that the target falls behind until the ship's motion eases. New constants `RESPONSE_RATE`, `ACCEL_SMOOTHING`
  and `BRAKE_SHARE`.
- While the ship turns or accelerates backwards, a target lighter than `CLOSER_MASS_LIMIT` (every chunk, lifepod, AI
  core, drone and frozen body; no ship) is held closer, up to the middle of the opening a chunk's radius past the red
  line, in proportion (`CLOSER_FULL_SHARE`), and goes back out over `CLOSER_RELEASE_TIME`. Heavier targets stay at the
  dock slot, so a held ship is never brought into the ship holding it.
- Overloaded, the arm pulls the target back towards the arm base first while not feeding (the game lets go at two arm
  lengths from it), and keeps it on its path first while feeding.
- `APPROACH_EASE_DISTANCE` is gone. `_gamePull` is replaced by `_parking`; new members `_way`, `_body`, `_parkAt`,
  `_closer`, `_shipSeen`, `_lastShipVelocity`, `_lastImpulse` and `_shipAccel`, and new functions `_pathAt`,
  `_inwardSpeed`, `_roomFor`, `_shorten`, `_parkVelocity`, `_forceFor`, `_measureShip` and `_updateCloser`. `_entry`
  also returns how far ahead of the tip the front of the rotors / claws is; `_hitsHull` takes the circle to sweep.
- The README is rewritten, with new pictures.

## 1.5.4
- The description in `Mod.manifest` is worded for players, as the root README's summary.

## 1.5.3
- The README's *Disclaimer* no longer names the author.

## 1.5.2
- The README's two images moved out of the mod into the repository's users' wiki
  (`_wiki/images/ArmAltPullBehavior-feeding.png` and `-not-feeding.png`, were `PullBehavior-feeding.png` and
  `PullBehavior-not-feeding.png`), which the README now links: the zip no longer carries them.
- The README has a new *Disclaimer*: the game belongs to Kodera Software, the author has no tie to it or to the
  company, and the mod is provided as is, for free, without warranty.

## 1.5.1
- The script extension is now `ArmAltPullBehavior/Code.gd` (was `DockingArmPullBehavior.gd`): edit the constants
  there. No change in behaviour.
- Adds this CHANGES.md.
- The README no longer states the version (it is in `Mod.manifest` and here), and its Install step says to remove
  any other version of the mod from the `mods` folder.
- The README starts with a *Warning*: what the mod changes compared to vanilla, and to check a bug without the mod
  before reporting it to the game's developers.
- The mod's id is now `AGlezB.ArmAltPullBehavior`, and its author is capitalized the same way (both were lowercase).

## 1.5.0
- While feeding, a target in the corridor is no longer handed back to the game: the mod pulls it straight in along
  the corridor's middle line at the feed's speed (`feedVelocity`), or faster where the game's pull would be faster,
  measuring its speed against the hull. This removes 1.4.0's limit, a heavy chunk touching a rotor while feeding
  and turning.
- Moving a target forward to clear the hull goes at the arm's full speed (`maxVelocity`), without braking at the
  point where it turns towards the opening.
- The approach to the opening starts slowing down at the new constant `APPROACH_EASE_DISTANCE` instead of the game's
  `easeDistance`. The force never exceeds what the game's formula gives.
- So while feeding, chunks come in faster. 1.4.0 worked in the game but was slow there: in the test harness, 4.4–4.8 s
  against 5.9–6.3 s with 1.4.0.
- The README names the constants without quoting their values.

## 1.4.0
- Fix: the push that made up for the ship's acceleration is gone. Each push also turned the ship a little, which
  made the next push bigger, until the chunk was flung away and let go, as 1.3.0 did in the game.
- The mod's pull measures the target's speed against the ship's hull at the target's position, not against the dock
  slot, which swings while the ship turns.
- The diagnostic `APB` log lines of 1.3.1 are gone.
- The README drops its "Ship acceleration" section and adds a known limit: while feeding and turning, a heavy chunk
  that the game takes in along the corridor can touch a rotor.

## 1.3.1
- Diagnostic build: behaves exactly like 1.3.0, and writes `APB` lines to the game's log while the arm holds a
  target (six a second, plus one at each grab and release).

## 1.3.0
- Fix for 1.2.0, which in the game pulled chunks towards the corridor and let go of them in the wrong direction.
  Feeding and not feeding are now handled separately, as the game does: its pull always goes to the dock slot, and
  a chunk only goes in between the rotors while feeding.
- While feeding: a target in the corridor is left to the game's feed. Any other target is pulled straight to the
  middle of the opening (forward first if that path is too close to the hull), stopped there, and handed back once
  it is in the corridor and no longer moving sideways.
- While not feeding: the game's pull to the dock slot is used. The mod only moves the target forward first, behind
  the red line, when its path to the dock slot passes too close to the hull.
- The mod's pull aims a moment ahead, so the target stops at the opening instead of overshooting.
- The README's first section is rewritten, with two images (`PullBehavior-feeding.png`,
  `PullBehavior-not-feeding.png`), and says the mod reads the arm's `feed` and dock slot.

## 1.2.0
- Ahead of the red line, the game's own pull is used again; before, the mod pulled sideways towards the opening
  there.
- Behind the red line and outside the corridor, a target goes straight to the nearest point of the opening, and
  forward first only when that path would come too close to the hull. The test sweeps a circle of
  `CHUNK_RADIUS_CLEARENCE_FACTOR` chunk radii along the path against the ship's own collision shapes, so it works
  on any hull.
- No back and forth: the game keeps control until the target is a chunk radius behind the red line and outside the
  corridor.
- Closed beak: the target is no longer held in place. With no corridor, the pull is forward only.
- New image, and the README's sections on the red line, the opening, the hull test, the edge and the closed beak
  are rewritten.

## 1.1.1
- README only: the image is drawn on the Eagle-Prospector-VP, like ArmAltTargetSelection's, and the caption is
  rewritten. Same code as 1.1.0.

## 1.1.0
- The mod's own pulls cost what the game's pull costs, with the game's formula: energy (capped by the arm's power
  limit), wear, and less force from a worn or overheated arm. Both the sideways pull and the push for the ship's
  acceleration were free before. An arm holding nothing still takes no wear.
- The README has a section on the cost and its two known limits: the push and the game's pull together can go over
  the power limit in a frame, and the arm's power reading shows 0 during the sideways pull.
