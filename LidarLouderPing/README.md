# LidarLouderPing - ΔV: Rings of Saturn

The lidar's ping for sensor contacts plays louder.

## What it does and why
- **What:** the ping the lidar plays for each contact it finds is louder, by `LOUDER_PING_DB` decibels. This is the
  sound that the Tuning setting "Audible feedback for sensor contacts" switches on and off, and that switch still
  works. The ping in the lidar preview of the Tuning and Upgrades screens is louder too, so the change can be heard
  there.
- **What not:** the game's own way of playing it is kept. Contacts that are far away ping louder and lower, and
  contacts that are close ping quieter and higher (the game plays the ping at −10 dB for a far contact and −40 dB for
  a close one); the mod adds the same gain to both. The game's volume settings still apply: Ambient for most ships,
  Sound effects for the K225 and the Kitsune.
- **Why:** the ping is easy to miss over the rest of the ship's sound.
- What pings is up to the game: anything a lidar ray hits whose lidar response is above 1, such as mineral chunks
  with any purity, ships, equipment and projectiles. Plain rock does not.
- To change the gain, edit `LOUDER_PING_DB` at the top of `LidarLouderPing/Code.gd` inside the zip. 0 leaves the game's
  volume. The sound already peaks at full scale, so with a large gain the game's compressor on the main bus squashes
  the pings and briefly lowers other sounds along with them.

## For modders
- Script extension of `res://hud/LIDAR.gd` (`installScriptExtension` in `ModMain.gd`), the lidar display of every
  ship's HUD (`hud/Display-*.tscn`) and of the Tuning and Upgrades previews (`hud/components/LIDAR.tscn`). The tag
  `group = LIDAR` in `Mod.manifest` names that game script.
- The ping is the lidar's `Bleep` child, an `AudioStreamPlayer` with `sfx/PitchAdjustedAudio.gd` and
  `hud/LIDAR_beep.wav`, held in `soundBleep` (`onready`). `_physics_process` sets its `pitch_scale` and `volume_db`
  before every ping, from how far away the contact is (`volume_db = w * -30 - 10`, with `w` 1 at the lidar and 0 at
  its range), and plays it only while `doBleep` is true. `onSetup` reads `doBleep` from the ship's tuning
  (`getBleepSound`, `TUNE_AUDIO_LIDAR`) and runs again on the ship's `tuningChanged`.
- Because `volume_db` is set anew for every ping, a gain on the player would be lost. The mod moves the player to a
  bus of its own instead, named `<the player's bus> (LidarLouderPing)`, that sends to the player's bus with a volume
  of `LOUDER_PING_DB`. From there the sound goes the way it went before (`default_bus_layout.tres`): `ShipBowels`
  (or `SFX` on the K225 and the Kitsune) → `SFX` → `Sounds` → `Master`, whose volumes `Settings.gd` sets from the
  game's settings. The ping's code, its pitch and the switch are not touched.
- Overrides `_ready` only, which does not call the parent's: the mod loader runs the base first, so `soundBleep` is
  set when the override runs. A lidar without a `Bleep` is left alone.
- The bus is added on first use, last in the list (a bus can only send to one before it), and every lidar on the
  same bus shares it. A player already on a bus of the mod's is left there, so two installed copies of the mod do
  not add the gain twice.
- Members: `LOUDER_PING_DB` (the gain, a constant a user may edit), `_LOUDER_PING_BUS_SUFFIX` and
  `_louderPingBus()`.
- Tested only outside the game, in a headless Godot 3.6 with the game's `LIDAR.gd`, `PitchAdjustedAudio.gd` and audio
  buses, and stubs of the HUD and the ship (the `lidar` suite of the repository's test harness). It has not been
  checked in a real game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put the mod's zip in it, and remove any other version of the mod from there: they would all load. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).
