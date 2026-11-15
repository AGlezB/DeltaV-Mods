extends "res://harness/suite.gd"

# LidarLouderPing: the lidar's contact ping (the `Bleep` child of the game's hud/LIDAR.gd) plays through a bus of the
# mod's, which sends to the ping's own bus with the gain set on the ship's Tuning slider; the slider is registered
# right below the ping's switch, and while it is selected the Tuning screen's preview plays a demo. The buses are the
# game's (its default_bus_layout.tres, copied by run.ps1). The mod's constants (gain range, demo, key, bus suffix) are
# read from the mod, so any value of them passes. The control checks run on the game's own script: with the mod
# loaded, that is the base of the extension.

const SWITCH = "TUNE_AUDIO_LIDAR"
const SPEED = "TUNE_LIDAR_SPEED"
const ROW = "res://enceladus/Tuning/TuningFloatValue.tscn"
const PING_LENGTH = 0.4 # seconds, the synthetic ping's length (the game's sound is about as long)
const STEP = 1.0 / 60.0 # the frame time the demo is driven with

# A lidar as the game's HUD scenes nest it: the reader (HUD) above it, its `Bleep` below on `bus` (the game's
# PitchAdjustedAudio.gd, recording its pings: harness/recording_bleep.gd). Hidden, so it
# neither draws, renders nor scans, which the ping does not need. `reader`: an existing one to share; `preview`: a
# lidar of the Tuning and Upgrades screens (dynamicConnect); `stream`: the Bleep's sound.
func make(bus, script = null, withBleep = true, reader = null, preview = false, stream = null):
	if reader == null:
		var ship = Node2D.new(); ship.set_script(load("res://harness/lidar_ship.gd"))
		add_child(ship)
		reader = Control.new(); reader.set_script(load("res://harness/lidar_reader.gd")); reader.ship = ship
		add_child(reader)
	var lidar = TextureRect.new(); lidar.set_script(script if script != null else load("res://hud/LIDAR.gd"))
	lidar.visible = false
	lidar.dynamicConnect = preview
	if withBleep:
		var bleep = AudioStreamPlayer.new(); bleep.set_script(load("res://harness/recording_bleep.gd"))
		bleep.name = "Bleep"
		bleep.bus = bus
		bleep.stream = stream
		lidar.add_child(bleep)
	reader.add_child(lidar)
	return lidar

func busSends(busName, to) -> bool:
	var index = AudioServer.get_bus_index(busName)
	return index != -1 and AudioServer.get_bus_send(index) == to

func busVolume(busName):
	var index = AudioServer.get_bus_index(busName)
	return AudioServer.get_bus_volume_db(index) if index != -1 else null

# A silent sound of PING_LENGTH seconds (8-bit mono: one byte per frame).
func pingStream() -> AudioStreamSample:
	var sample = AudioStreamSample.new()
	sample.format = AudioStreamSample.FORMAT_8_BITS
	sample.mix_rate = 8000
	var data = PoolByteArray()
	data.resize(int(PING_LENGTH * sample.mix_rate))
	sample.data = data
	return sample

# A Tuning row (the game's TuningFloatValue.gd) for the entry `key` as `reader` holds it.
func makeRow(reader, key):
	var row = load(ROW).instance()
	row.tuningItem = key
	row.tune = reader.subsystems[key].duplicate()
	add_child(row)
	return row

# Drives the lidar's _process for `seconds` in frames of STEP and returns each ping it played: [time, volume_db,
# pitch] (harness/recording_bleep.gd).
func demo(lidar, seconds) -> Array:
	var pings = []
	var t = 0.0
	while t < seconds:
		var before = lidar.soundBleep.played.size()
		lidar._process(STEP)
		for i in range(before, lidar.soundBleep.played.size()):
			pings.append([t] + lidar.soundBleep.played[i])
		t += STEP
	return pings

# The game's ping for a contact at `fraction` of the lidar's range (hud/LIDAR.gd _physics_process).
func gameVolume(fraction):
	return (1 - clamp(fraction, 0, 1)) * - 30 - 10

func gamePitch(fraction):
	return max(1 + 0.5 * (1 - clamp(fraction, 0, 1)), 0.1)

func run():
	var mod = hasMod("LidarLouderPing")
	var game = load("res://hud/LIDAR.gd")
	if mod:
		game = game.get_base_script()
	if AudioServer.get_bus_index("ShipBowels") == -1 or AudioServer.get_bus_index("SFX") == -1:
		printerr("HARNESS ERROR: the game's buses are missing (default_bus_layout.tres)")
		return
	var buses = AudioServer.bus_count
	var control = make("ShipBowels", game)
	yield(get_tree(), "physics_frame")
	check("control: the game's ping is its Bleep child", control.soundBleep == control.get_node("Bleep"))
	check("control: without the mod the ping stays on ShipBowels", control.soundBleep.bus == "ShipBowels", control.soundBleep.bus)
	check("control: without the mod no bus is added", AudioServer.bus_count == buses)
	if not mod:
		return

	var ping = make("ShipBowels")
	var k225 = make("SFX")
	yield(get_tree(), "physics_frame")
	var key = ping._LOUDER_PING_TUNE
	var suffix = ping._LOUDER_PING_BUS_SUFFIX
	var gainDefault = ping.LOUDER_PING_DB_DEFAULT
	var gainMin = ping.LOUDER_PING_DB_MIN
	var gainMax = ping.LOUDER_PING_DB_MAX
	var louder = "ShipBowels" + suffix
	var ship = ping.ship
	var subsystems = ping.reader.subsystems

	# The Tuning entry
	var keys = subsystems.keys()
	var at = keys.find(SWITCH)
	check("the Tuning screen still lists the switch, with the game's entry", at != -1 and subsystems[SWITCH].get("type") == "bool", subsystems.get(SWITCH))
	check("the slider comes right below the switch, the lidar's other entries after it", at != -1 and keys.slice(at, at + 2) == [SWITCH, key, SPEED], keys)
	var entry = subsystems.get(key, {})
	var switchEntry = subsystems.get(SWITCH, {})
	check("the slider is in the switch's group and preview", entry.get("subsystem") == switchEntry.get("subsystem") and entry.get("testProtocol") == switchEntry.get("testProtocol"), entry)
	check("the slider is a float with the mod's default, range and step, in dB", entry.get("type") == "float" and entry.get("default") == gainDefault and entry.get("min") == gainMin and entry.get("max") == gainMax and entry.get("step") == ping.LOUDER_PING_DB_STEP and entry.get("unit") == "dB", entry)
	check("a new ship's slider shows the default", entry.get("current") == gainDefault, entry.get("current"))
	ship.setTunedValue("Hud", SWITCH, true)
	var second = make("ShipBowels", null, true, ping.reader)
	yield(get_tree(), "physics_frame")
	check("onSetup again, and a second lidar on the same HUD, keep the entries in place", subsystems.keys() == keys, subsystems.keys())

	# The gain
	if gainDefault == 0:
		check("a default of 0 leaves the ping on its own bus (ShipBowels, SFX)", ping.soundBleep.bus == "ShipBowels" and k225.soundBleep.bus == "SFX", "%s, %s" % [ping.soundBleep.bus, k225.soundBleep.bus])
		check("a default of 0 adds no bus", AudioServer.bus_count == buses, "%d, was %d" % [AudioServer.bus_count, buses])
	else:
		check("by default the ping plays on the mod's bus, with the default gain", ping.soundBleep.bus == louder and busVolume(louder) == gainDefault, "%s, %s" % [ping.soundBleep.bus, busVolume(louder)])
	ship.setTunedValue("Hud", key, gainMax)
	k225.ship.setTunedValue("Hud", key, gainMax)
	check("the slider's value sets the gain", ping.soundBleep.bus == louder and busVolume(louder) == gainMax and subsystems[key].current == gainMax, "%s, %s, current %s" % [ping.soundBleep.bus, busVolume(louder), subsystems[key].current])
	var own = AudioServer.get_bus_index("ShipBowels")
	var louderIndex = AudioServer.get_bus_index(louder)
	check("the mod's bus sends to the ping's own bus, which comes before it", busSends(louder, "ShipBowels") and louderIndex > own, "%d, %d" % [louderIndex, own])
	check("the mod's bus has no effects", louderIndex != -1 and AudioServer.get_bus_effect_count(louderIndex) == 0)
	check("a ping on SFX (K225, Kitsune) gets a bus sending to SFX", k225.soundBleep.bus == "SFX" + suffix and busSends("SFX" + suffix, "SFX"), k225.soundBleep.bus)
	buses = AudioServer.bus_count
	if gainMin <= 0:
		ship.setTunedValue("Hud", key, 0.0)
		check("a gain of 0 puts the ping back on its own bus", ping.soundBleep.bus == "ShipBowels", ping.soundBleep.bus)
		ship.setTunedValue("Hud", key, gainMax)
		check("a gain above 0 puts it on the mod's bus again", ping.soundBleep.bus == louder, ping.soundBleep.bus)
	ship.setTunedValue("Hud", key, gainMax + 100)
	check("a saved gain above the range is kept at the top", busVolume(louder) == gainMax and subsystems[key].current == gainMax, subsystems[key].current)
	ship.setTunedValue("Hud", key, gainMin - 100)
	check("a saved gain below the range is kept at the bottom", subsystems[key].current == gainMin, subsystems[key].current)
	ship.setTunedValue("Hud", key, "loud")
	check("a saved gain that is not a number gives the default", subsystems[key].current == gainDefault, subsystems[key].current)
	ship.setTunedValue("Hud", key, gainMax)
	var twice = make(louder)
	var silent = make("", null, false)
	yield(get_tree(), "physics_frame")
	twice.ship.setTunedValue("Hud", key, gainMax)
	check("a ping already on the mod's bus is left there (no double gain)", twice.soundBleep.bus == louder, twice.soundBleep.bus)
	if gainMin <= 0:
		twice.ship.setTunedValue("Hud", key, 0.0)
		check("at 0 it goes to the bus the mod's sends to", twice.soundBleep.bus == "ShipBowels", twice.soundBleep.bus)
	check("a lidar without a ping does not fail", silent.soundBleep == null)
	check("none of these adds a bus", AudioServer.bus_count == buses, "%d, was %d" % [AudioServer.bus_count, buses])

	check("the switch is on by default", ping.doBleep == true)
	ship.setTunedValue("Hud", SWITCH, false)
	check("switching the audible feedback off still stops the ping", ping.doBleep == false)
	ship.setTunedValue("Hud", SWITCH, true)
	check("switching it on again brings it back", ping.doBleep == true)

	# The demo, on a preview's lidar (dynamicConnect) with a sound of known length, and the Tuning rows of the slider
	# and of the sweep speed built from what its HUD holds.
	var preview = make("ShipBowels", null, true, null, true, pingStream())
	yield(get_tree(), "physics_frame")
	var row = makeRow(preview.reader, key)
	var other = makeRow(preview.reader, SPEED)
	yield(get_tree(), "idle_frame")
	var ranges = preview.LOUDER_PING_DEMO_RANGES
	var count = ranges.size()
	var spacing = PING_LENGTH + preview.LOUDER_PING_DEMO_GAP
	var period = max(preview.LOUDER_PING_DEMO_INTERVAL, count * spacing)
	check("no demo while the slider is not selected", demo(preview, period * 2).empty())
	row.get_node("HSlider").grab_focus()
	preview.onSetup()
	check("while the slider is selected the preview's own pings are muted", preview.doBleep == false)
	var pings = demo(preview, period + (count - 1) * spacing + 2 * count * STEP)
	check("two sequences of one ping per demo distance", pings.size() == 2 * count, pings)
	if pings.size() == 2 * count:
		var sounds = true
		var apart = true
		for i in pings.size():
			var fraction = ranges[i % count]
			sounds = sounds and is_equal_approx(pings[i][1], gameVolume(fraction)) and is_equal_approx(pings[i][2], gamePitch(fraction))
			if i > 0:
				apart = apart and pings[i][0] - pings[i - 1][0] >= spacing - 0.001
		check("each demo ping sounds like the game's for its distance", sounds, pings)
		check("each ping waits for the previous one to end, plus the gap", apart, pings)
		var start = pings[count][0] - pings[0][0]
		check("a sequence starts every LOUDER_PING_DEMO_INTERVAL (or once the last ended)", abs(start - period) <= 2 * count * STEP, "%s, expected %s" % [start, period])
	row.get_node("HSlider").release_focus()
	preview.onSetup()
	check("once the slider loses the focus the preview pings again", preview.doBleep == true)
	demo(preview, STEP)
	row.get_node("HBoxContainer/Reset").grab_focus()
	pings = demo(preview, STEP * 2)
	check("the row's Reset button counts as the slider, and the demo starts at once", pings.size() == 1, pings)
	other.get_node("HSlider").grab_focus()
	preview.onSetup()
	check("another row selected: no demo, no muting", demo(preview, period * 2).empty() and preview.doBleep == true)
	row.get_node("HSlider").grab_focus()
	preview.ship.setTunedValue("Hud", SWITCH, false)
	check("with the switch off there is no demo", demo(preview, period * 2).empty())
	preview.ship.setTunedValue("Hud", SWITCH, true)
	ping.soundBleep.stream = pingStream()
	ping.onSetup()
	check("a lidar that is not a preview's is neither muted nor demoed", ping.doBleep == true and demo(ping, period * 2).empty())
	row.get_node("HSlider").release_focus()

	# The slider's texts (i18n/en.po), also in a language without them (Godot's fallback, en)
	var locale = TranslationServer.get_locale()
	var desc = key + "_DESC"
	check("the slider's name and description are translated", tr(key) != key and tr(desc) != desc, "%s / %s" % [tr(key), tr(desc)])
	check("the description's quotes come out single", not ("\"\"" in tr(desc)) and "\"" in tr(desc), tr(desc))
	TranslationServer.set_locale("de")
	check("a language without them shows the English texts", tr(key) != key and tr(desc) != desc)
	TranslationServer.set_locale(locale)
