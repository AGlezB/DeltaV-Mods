# LidarLouderPing - ΔV: Rings of Saturn

The lidar's ping for sensor contacts plays louder, by as much as you set in the ship's Tuning.

## What it does and why
- **What:** the ping the lidar plays for each contact it finds is louder, by the boost set on the slider "Audible
  feedback boost" in the ship's Tuning screen. The slider sits right below the switch "Audible feedback for sensor
  contacts", which turns this sound on and off and still works, and the boost only applies while that switch is on.
  Each ship keeps its own boost with its tuning, saved with the game; a ship that never had it set uses
  `LOUDER_PING_DB_DEFAULT`. The ping in the lidar preview of the Tuning and Upgrades screens is louder too.
- **Hear it while choosing:** while the slider is selected, the Tuning screen's preview plays a short sequence of
  pings every `LOUDER_PING_DEMO_INTERVAL` seconds: from a contact at the edge of the lidar's range, one halfway and one
  close (`LOUDER_PING_DEMO_RANGES`), with `LOUDER_PING_DEMO_GAP` seconds of silence between them, so the boost sounds as
  it will in flight. The preview's other pings are silenced meanwhile. With the switch off there is no demo.
- **What not:** the game's own way of playing it is kept. Contacts that are far away ping louder and lower, and
  contacts that are close ping quieter and higher (the game plays the ping at −10 dB for a far contact and −40 dB for
  a close one); the mod adds the same boost to both. The game's volume settings still apply: Ambient for most ships,
  Sound effects for the K225 and the Kitsune.
- **Why:** the ping is easy to miss over the rest of the ship's sound.
- About every 10 dB sounds twice as loud; 0 dB leaves the game's volume. With a large boost the game holds the pings
  back and briefly lowers other sounds along with them.
- What pings is up to the game: anything a lidar ray hits whose lidar response is above 1, such as mineral chunks
  with any purity, ships, equipment and projectiles. Plain rock does not.
- The slider's default, range and step (`LOUDER_PING_DB_DEFAULT`, `LOUDER_PING_DB_MIN`, `LOUDER_PING_DB_MAX`,
  `LOUDER_PING_DB_STEP`) and the demo's interval, gap and distances are constants at the top of
  `LidarLouderPing/Code.gd`, which you may edit inside the zip. The slider's name and description are in
  `LidarLouderPing/i18n/en.po`.

## For modders
- Script extension of `res://hud/LIDAR.gd` (`installScriptExtension` in `ModMain.gd`), the lidar display of every
  ship's HUD (`hud/Display-*.tscn`) and of the Tuning and Upgrades previews (`hud/components/LIDAR.tscn`). The tag
  `group = LIDAR` in `Mod.manifest` names that game script.
- The ping is the lidar's `Bleep` child, an `AudioStreamPlayer` with `sfx/PitchAdjustedAudio.gd` and
  `hud/LIDAR_beep.wav`, held in `soundBleep` (`onready`). `_physics_process` sets its `pitch_scale` and `volume_db`
  before every ping, from how far away the contact is (`volume_db = w * -30 - 10`, with `w` 1 at the lidar and 0 at
  its range), and plays it only while `doBleep` is true. `onSetup` reads `doBleep` from the ship's tuning
  (`getBleepSound`, `TUNE_AUDIO_LIDAR`) and registers the lidar's Tuning entries.
- **The slider.** `onSetup` registers the entries with the lidar's reader, the ship's `hud/Hud.gd`
  (`registerSubsystem`). `getTuneables` hands them to `enceladus/Tuning.gd` `fillTuneableSystems`, which groups them by
  `subsystem`, and `enceladus/Tuning/TuningItems.gd` builds one row per entry, in the order they were first
  registered. The mod overrides `onSetup` and calls the parent's. Before that call it registers `TUNE_AUDIO_LIDAR`
  with an empty placeholder and then its own `float` entry, `_LOUDER_PING_TUNE`, with the switch's `subsystem` and
  `testProtocol` (`lidar`). The parent then registers the switch for real, which keeps its place, so the slider lands
  right below it and shows wherever the switch does. The Tuning screen stores the value with `setTunedValue("Hud",
  <key>, value)` (`ships/ship-ctrl.gd`), in the ship's config at `tuning.Hud.<key>`, saved with the game. The mod
  reads it as `getBleepSound` reads the switch; anything that is not a number gives the default, and the rest is
  kept in range. Removing the mod leaves that value in the ship's tuning, where the game ignores it.
- **The boost.** Because `volume_db` is set anew for every ping, a gain on the player would be lost. The mod moves
  the player to a bus of its own instead, named `<the player's bus> (LidarLouderPing)`, that sends to the player's bus
  with the boost as its volume. From there the sound goes the way it went before (`default_bus_layout.tres`):
  `ShipBowels` (or `SFX` on the K225 and the Kitsune) → `SFX` → `Sounds` → `Master`, whose volumes `Settings.gd` sets
  from the game's settings. A boost of 0 leaves the player on its own bus. `onSetup` runs again on every tuning change
  (the ship's `tuningChanged`), so a new value applies at once. The ping's code, its pitch and the switch are not
  touched. "Held back" is the compressor on the `Master` bus: the sound already peaks at full scale.
- The bus is added on first use, last in the list (a bus can only send to one before it), and every lidar on the
  same bus shares it. That is safe because HUDs, and so lidars, only exist on the player's ship and on the Tuning and
  Upgrades previews, which are built from the player's ship and its tuning (`hud/Hud.gd` `instance`,
  `enceladus/Tuning.gd` `addShip`, `enceladus/Upgrades.gd`), so every lidar sets the same boost. The player's own bus
  is its bus without the mod's suffix, so the boost is never added twice. A lidar without a `Bleep` is left alone.
- **The demo.** It runs only on the previews' lidars (`dynamicConnect`), from an override of `_process`, which does
  not call the parent's: Godot runs both, and the game processes a lidar only while it is visible. Selecting the
  slider switches the Tuning preview to its lidar view (`testProtocol` `lidar`). The slider counts as selected while
  the focus is in the `enceladus/Tuning/TuningFloatValue.gd` row whose `tuningItem` is the slider's key: its slider,
  its Reset button or its name. The Upgrades preview has no such row. The demo pings go through the game's own
  player, with the pitch and volume `_physics_process` gives a contact at that distance. Each waits for the previous
  one to end (the stream's length) plus the gap. The preview's own pings are muted by setting `doBleep` to false at
  the end of `onSetup`, which a preview runs every physics frame before its ping code; `doBleep` is the game's again
  as soon as the row loses the focus.
- **The texts.** `i18n/en.po` (the game keeps its own in `i18n/` too) holds the slider's name (its key) and description (`<key>_DESC`, which the Tuning screen
  shows at the top). `ModMain.gd` loads it with `load()` and `TranslationServer.add_translation`, as the game loads
  its own `.po` files. English is Godot's fallback language, so every language shows it until it gets its own file.
  The mod loader's `addTranslationsFromCSV` is not used: it reads nothing from a mod's zip, because a file in a zip
  reports its end before the first read, and `get_csv_line` checks for the end first.
- Overrides `onSetup` (calls the parent's) and `_process` (does not). Members: the constants `LOUDER_PING_DB_DEFAULT`,
  `LOUDER_PING_DB_MIN`, `LOUDER_PING_DB_MAX`, `LOUDER_PING_DB_STEP`, `LOUDER_PING_DEMO_RANGES`, `LOUDER_PING_DEMO_GAP`
  and `LOUDER_PING_DEMO_INTERVAL` (which a user may edit), `_LOUDER_PING_TUNE` and `_LOUDER_PING_BUS_SUFFIX`; the
  variables `_louderPingSwitchOn`, `_louderPingDemoNext` and `_louderPingDemoWait`; the functions
  `_louderPingPlayAt()`, `_louderPingSelected()`, `_louderPingDb()`, `_routeLouderPing()` and `_louderPingBus()`.
- Tested only outside the game, in a headless Godot 3.6 with the game's `LIDAR.gd`, `PitchAdjustedAudio.gd`,
  `TuningFloatValue.gd` and audio buses, and stubs of the HUD and the ship (the `lidar` suite of the repository's test
  harness). It has not been checked in a real game.

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
