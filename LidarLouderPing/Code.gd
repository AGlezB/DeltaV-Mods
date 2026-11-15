extends "res://hud/LIDAR.gd"

# How much louder the lidar contact ping plays, in dB, on top of the game's own volume: a slider in the ship's Tuning
# screen, right below the switch "Audible feedback for sensor contacts", kept with each ship's tuning. Its default,
# range and step. About every 10 dB sounds twice as loud; 0 leaves the game's volume. With a large boost the game
# holds the pings back and briefly lowers other sounds along with them.
const LOUDER_PING_DB_DEFAULT = 20.0
const LOUDER_PING_DB_MIN = 0.0
const LOUDER_PING_DB_MAX = 50.0
const LOUDER_PING_DB_STEP = 1.0

# While the slider is selected, the Tuning screen's lidar preview plays a sequence of pings from contacts at these
# distances, as fractions of the lidar's range: at its edge (the game's loudest ping), halfway, and close (the
# quietest). Between two pings there are LOUDER_PING_DEMO_GAP seconds of silence, and a sequence starts every
# LOUDER_PING_DEMO_INTERVAL seconds.
const LOUDER_PING_DEMO_RANGES = [1.0, 0.5, 0.1]
const LOUDER_PING_DEMO_GAP = 0.25
const LOUDER_PING_DEMO_INTERVAL = 3.0

# The slider's key: its name and, with "_DESC", its description in Translations.csv, and where each ship keeps its
# value (tuning.Hud.<key> in the ship's config, saved with the game).
const _LOUDER_PING_TUNE = "TUNE_LIDARLOUDERPING_GAIN"
const _LOUDER_PING_BUS_SUFFIX = " (LidarLouderPing)"

var _louderPingSwitchOn = false # the switch, as the game's onSetup last read it (doBleep, before any muting)
var _louderPingDemoNext = 0 # the demo's next ping, an index into LOUDER_PING_DEMO_RANGES
var _louderPingDemoWait = 0.0 # seconds until it plays

# The game's onSetup registers the lidar's Tuning entries (the switch first) with the HUD, which lists them in the
# order they were first registered (hud/Hud.gd registerSubsystem and getTuneables, enceladus/Tuning.gd
# fillTuneableSystems, enceladus/Tuning/TuningItems.gd addTuneables). Registering the switch with a placeholder and
# then the slider, before the game's onSetup registers the switch for real (which keeps its place), puts the slider
# right below it. Same condition, group (subsystem) and preview (testProtocol) as the switch: the slider shows
# wherever the switch does.
# onSetup runs again on every tuning change (the ship's tuningChanged) and, for the Tuning and Upgrades previews
# (dynamicConnect), every physics frame, before the ping code: that is where the gain is applied and where the
# preview's own pings are muted while the slider is selected, so only the demo plays.
func onSetup():
	var gain = _louderPingDb()
	if reader.has_method("registerSubsystem"):
		reader.registerSubsystem("TUNE_AUDIO_LIDAR", {})
		reader.registerSubsystem(_LOUDER_PING_TUNE, {
			"type": "float",
			"default": LOUDER_PING_DB_DEFAULT,
			"min": LOUDER_PING_DB_MIN,
			"max": LOUDER_PING_DB_MAX,
			"step": LOUDER_PING_DB_STEP,
			"current": gain,
			"unit": "dB",
			"testProtocol": "lidar",
			"subsystem": type,
		})
	.onSetup()
	_louderPingSwitchOn = doBleep
	if dynamicConnect and _louderPingSelected():
		doBleep = false
	_routeLouderPing(gain)

# The demo, on the previews only (the game processes a lidar only while it is visible; selecting the slider shows the
# Tuning screen's lidar preview). It plays while the slider is selected and the switch is on, from the first ping as
# soon as the slider is selected. Each ping waits for the previous one to end (the sound is never longer than the
# stream: a demo ping plays at pitch 1 or higher) plus LOUDER_PING_DEMO_GAP.
func _process(delta):
	if not dynamicConnect:
		return
	var count = LOUDER_PING_DEMO_RANGES.size()
	if count == 0 or not _louderPingSwitchOn or soundBleep == null or soundBleep.stream == null or not _louderPingSelected():
		_louderPingDemoNext = 0
		_louderPingDemoWait = 0.0
		return
	_louderPingDemoWait -= delta
	if _louderPingDemoWait > 0.0:
		return
	var spacing = soundBleep.stream.get_length() + LOUDER_PING_DEMO_GAP
	_louderPingPlayAt(LOUDER_PING_DEMO_RANGES[_louderPingDemoNext])
	_louderPingDemoNext += 1
	if _louderPingDemoNext < count:
		_louderPingDemoWait = spacing
	else:
		_louderPingDemoNext = 0
		_louderPingDemoWait = max(LOUDER_PING_DEMO_INTERVAL - (count - 1) * spacing, spacing)

# Plays the ping as the game's _physics_process does for a contact at `fraction` of the lidar's range (d / distance),
# on the game's own player, so the boost, the volume settings and PitchAdjustedAudio.gd apply as in flight.
func _louderPingPlayAt(fraction: float):
	var w = 1 - clamp(fraction, 0, 1)
	soundBleep.pitch_scale = max(1 + 0.5 * w, 0.1)
	soundBleep.volume_db = w * - 30 - 10
	soundBleep.play()

# Whether the slider's row has the focus: its slider, its Reset button or its name (enceladus/Tuning/TuningFloatValue.gd,
# whose tuningItem is the entry's key). The Upgrades preview has no such row.
func _louderPingSelected() -> bool:
	if not is_inside_tree():
		return false
	var node = get_focus_owner()
	while node != null:
		if "tuningItem" in node:
			return node.tuningItem == _LOUDER_PING_TUNE
		node = node.get_parent()
	return false

# The ship's gain, read as getBleepSound reads the switch. A value that is not a number gives the default, and the
# rest are kept in range, so a save edited by hand can't break anything.
func _louderPingDb() -> float:
	var value = ship.getTunedValue("Hud", _LOUDER_PING_TUNE, LOUDER_PING_DB_DEFAULT) if ship else LOUDER_PING_DB_DEFAULT
	if not (value is int or value is float):
		return LOUDER_PING_DB_DEFAULT
	return clamp(value, LOUDER_PING_DB_MIN, LOUDER_PING_DB_MAX)

# The game sets the ping's volume_db before every ping (_physics_process), so a gain on the player itself would be
# overwritten. The player is moved instead to a bus of the mod's, which sends to the player's own bus with the gain;
# from there on the sound goes the game's way (its effects, the volume settings). A gain of 0 leaves the player on its
# own bus. The own bus is the player's bus without the mod's suffix, so the gain is never added twice.
func _routeLouderPing(gain: float):
	if soundBleep == null:
		return
	var own = soundBleep.bus.trim_suffix(_LOUDER_PING_BUS_SUFFIX)
	var target = own if gain == 0.0 else _louderPingBus(own, gain)
	if soundBleep.bus != target:
		soundBleep.bus = target

# The mod's bus that sends to `original`, added on first use and shared by every lidar on that bus. It goes last: a
# bus can only send to one before it. Sharing it is safe: HUDs, and so lidars, exist only on the player's ship and on
# the Tuning and Upgrades previews, which are built from the player's ship and its tuning (hud/Hud.gd instance,
# enceladus/Tuning.gd addShip, enceladus/Upgrades.gd), so every lidar sets the same gain.
func _louderPingBus(original: String, gain: float) -> String:
	var busName = original + _LOUDER_PING_BUS_SUFFIX
	var index = AudioServer.get_bus_index(busName)
	if index == -1:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, busName)
		AudioServer.set_bus_send(index, original)
	if AudioServer.get_bus_volume_db(index) != gain:
		AudioServer.set_bus_volume_db(index, gain)
	return busName
