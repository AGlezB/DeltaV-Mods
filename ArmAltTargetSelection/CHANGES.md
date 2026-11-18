# ArmAltTargetSelection - Changes

## 1.2.3
- The README's image moved out of the mod into the repository's users' wiki
  (`_wiki/images/ArmAltTargetSelection-area.png`, was `TargetSelection.png`), which the README now links: the zip
  no longer carries it.
- The README has a new *Disclaimer*: the game belongs to Kodera Software, the author has no tie to it or to the
  company, and the mod is provided as is, for free, without warranty.

## 1.2.2
- The script extension is now `ArmAltTargetSelection/Code.gd` (was `DockingArmTargetSelection.gd`): edit the
  constants there. No change in behaviour.
- Adds this CHANGES.md.
- The README no longer states the version (it is in `Mod.manifest` and here), and its Install step says to remove
  any other version of the mod from the `mods` folder.
- The README starts with a *Warning*: what the mod changes compared to vanilla, and to check a bug without the mod
  before reporting it to the game's developers.
- The mod's id is now `AGlezB.ArmAltTargetSelection` and its author `AGlezB` (were lowercase).

## 1.2.1
- When the arm is switched off, the mod drops the target itself again, as up to 1.1.2. Keeping the queue empty
  while the arm is off now comes on top of that instead of replacing it. Both wait for the game to release its hold
  on the target, which it does in the same frame.
- The README names the constants without quoting their values.

## 1.2.0
- While the arm is off, its queue is kept empty, from the frame after it is switched off.
- The mod's own release of the target on switch-off was removed, leaving the drop to the game (restored in 1.2.1).
- The number of segments of the area's shape is a constant, `AREA_SEGMENTS`, raised so the shape follows the circle
  more closely.
- The README and the image are updated.

## 1.1.2
- Fix: the buffer area points the way the arm faces, not towards the ship's front. Only turned mounts change: on the
  OCP-209 it now points out of the side opening instead of towards the nose.

## 1.1.1
- The constant `FRONT_EXTENSION` is renamed `BUFFER_AREA_FACTOR`: what the code and the README called the front
  extension is now the buffer area, and the README explains it in its own item. No change in behaviour.
- The image shows the buffer area in orange; the strip is now purple.

## 1.1.0
- New target area: instead of shrinking the game's rectangle, the mod gives the area a new shape, the arm's reach
  circle moved forward by `FRONT_EXTENSION` of the reach and cut at the arm base.
- The strip next to the arm base, outside the game's own area, is now inside it, and a target there is taken only
  when no other valid target exists. Its edge is read from the game's own area.
- The mod no longer checks the reach itself: the game's checks follow the new area, so targets out of reach never
  enter the queue, and a held target that drifts out of reach is dropped.
- A chunk counts as in reach once its edge touches the area, about 1 m more at the edge. If the arm grabs a target
  in the strip because nothing else was there, it doesn't switch when a better one appears.
- The README and the image are updated.

## 1.0.5
- README only: it no longer says ArmAltPullBehavior uses the same entry point on every ship, which stopped being
  true when that mod left ships without a grinder or excavator to the game.

## 1.0.4
- All logging is removed (the area-resize line and the "left shape alone" line), and so are the log notes in the
  README. No change in behaviour.

## 1.0.3
- Renamed from ArmAlternativeTargeting: the folder, the mod ID (`aglezb.ArmAltTargetSelection`), the manifest, the
  README and the log prefixes. The script is now `DockingArmTargetSelection.gd` and the image `TargetSelection.png`.
  The game sees a new mod, so remove the old zip. No change in behaviour.

## 1.0.1
- The intake centerline follows the direction the arm faces, instead of the arm's tilted `feedVelocity`.
- On ships with no grinder or excavator (the OCP-209), the entry point is the ship's centre instead of the dock
  slot, as in ArmAltPullBehavior (then ArmAlternativePhysics). Ships with a grinder or excavator score targets as
  before.
