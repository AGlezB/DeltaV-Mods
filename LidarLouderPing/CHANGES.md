# LidarLouderPing - Changes

## 1.2.4
- The README and the description in `Mod.manifest` write LIDAR and the Equipment screen as the game does.
- A comment in `Code.gd` names `i18n/en.po`, where the slider's texts are.

## 1.2.3
- The README's *Disclaimer* no longer names the author.

## 1.2.2
- The README has a new *Disclaimer*: the game belongs to Kodera Software, the author has no tie to it or to the
  company, and the mod is provided as is, for free, without warranty.

## 1.2.1
- The mod's id is now `AGlezB.LidarLouderPing`, and its author is capitalized the same way (both were lowercase).

## 1.2.0
- The slider goes higher (`LOUDER_PING_DB_MAX`), and its default is larger (`LOUDER_PING_DB_DEFAULT`). The default
  applies to ships whose slider was never selected (the game stores a Tuning value once its row gets the focus) and
  to the slider's Reset button.

## 1.1.0
- The boost is a slider in the ship's Tuning screen, "Audible feedback boost", right below the switch "Audible
  feedback for sensor contacts" and shown wherever it is. Each ship keeps its own value with its tuning, saved with
  the game. It only applies while the switch is on, which its description says.
- While the slider is selected, the Tuning screen's preview plays pings from a far, a halfway and a close contact
  every `LOUDER_PING_DEMO_INTERVAL` seconds, and silences its other pings.
- `LOUDER_PING_DB` is renamed `LOUDER_PING_DB_DEFAULT`, the slider's default. New constants a user may edit:
  `LOUDER_PING_DB_MIN`, `LOUDER_PING_DB_MAX`, `LOUDER_PING_DB_STEP`, `LOUDER_PING_DEMO_RANGES`, `LOUDER_PING_DEMO_GAP`
  and `LOUDER_PING_DEMO_INTERVAL`.
- For modders: overrides `onSetup` and `_process` instead of `_ready`. New members `_LOUDER_PING_TUNE` (the Tuning key,
  stored in save games), `_louderPingSwitchOn`, `_louderPingDemoNext`, `_louderPingDemoWait`, `_louderPingPlayAt()`,
  `_louderPingSelected()`, `_louderPingDb()` and `_routeLouderPing()`; `_louderPingBus()` takes the gain as a parameter.
- Adds `i18n/en.po`, the slider's name and description, loaded by `ModMain.gd`.
- The README describes the slider and the demo, and talks about loudness rather than amplitude.
- The script extension is now `LidarLouderPing/Code.gd` (was `LidarLouderPing.gd`): edit the constants there.
- Adds this CHANGES.md.
- The README no longer states the version (it is in `Mod.manifest` and here), and its Install step says to remove
  any other version of the mod from the `mods` folder.
