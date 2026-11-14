extends "res://harness/suite.gd"

# LidarLouderPing: the lidar's contact ping (the `Bleep` child of the game's hud/LIDAR.gd) plays through a bus of the
# mod's, which sends to the ping's own bus with the mod's gain. The buses are the game's (its default_bus_layout.tres,
# copied by run.ps1). The control checks run on the game's own script: with the mod loaded, that is the base of the
# extension.

const SUFFIX = " (LidarLouderPing)"

# A lidar as the game's HUD scenes nest it: the reader (HUD) above it, its `Bleep` below on `bus`. Hidden, so it
# neither draws nor renders, which the ping does not need.
func make(bus, script = null, withBleep = true):
	var ship = Node2D.new(); ship.set_script(load("res://harness/lidar_ship.gd"))
	add_child(ship)
	var reader = Control.new(); reader.set_script(load("res://harness/lidar_reader.gd")); reader.ship = ship
	var lidar = TextureRect.new(); lidar.set_script(script if script != null else load("res://hud/LIDAR.gd"))
	lidar.visible = false
	if withBleep:
		var bleep = AudioStreamPlayer.new(); bleep.set_script(load("res://sfx/PitchAdjustedAudio.gd"))
		bleep.name = "Bleep"
		bleep.bus = bus
		lidar.add_child(bleep)
	reader.add_child(lidar)
	add_child(reader)
	return lidar

func busSends(busName, to) -> bool:
	var index = AudioServer.get_bus_index(busName)
	return index != -1 and AudioServer.get_bus_send(index) == to

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
	var gain = ping.LOUDER_PING_DB
	var own = AudioServer.get_bus_index("ShipBowels")
	var louder = AudioServer.get_bus_index("ShipBowels" + SUFFIX)
	check("the ping is still the game's Bleep", ping.soundBleep == ping.get_node("Bleep"))
	check("the ping plays on the mod's bus", ping.soundBleep.bus == "ShipBowels" + SUFFIX, ping.soundBleep.bus)
	check("the mod's bus sends to the ping's own bus", busSends("ShipBowels" + SUFFIX, "ShipBowels"))
	check("the mod's bus comes after the bus it sends to", louder > own, "%d, %d" % [louder, own])
	check("the gain is positive", gain > 0, gain)
	check("the mod's bus has the gain", louder != -1 and is_equal_approx(AudioServer.get_bus_volume_db(louder), gain), AudioServer.get_bus_volume_db(louder))
	check("the mod's bus has no effects", louder != -1 and AudioServer.get_bus_effect_count(louder) == 0)
	check("a ping on SFX (K225, Kitsune) gets a bus sending to SFX", k225.soundBleep.bus == "SFX" + SUFFIX and busSends("SFX" + SUFFIX, "SFX"), k225.soundBleep.bus)

	buses = AudioServer.bus_count
	var second = make("ShipBowels")
	var twice = make("ShipBowels" + SUFFIX)
	var silent = make("", null, false)
	yield(get_tree(), "physics_frame")
	check("a second lidar on ShipBowels shares the mod's bus", second.soundBleep.bus == "ShipBowels" + SUFFIX)
	check("a ping already on the mod's bus is left there (no double gain)", twice.soundBleep.bus == "ShipBowels" + SUFFIX, twice.soundBleep.bus)
	check("a lidar without a ping does not fail", silent.soundBleep == null)
	check("none of these adds a bus", AudioServer.bus_count == buses, "%d, was %d" % [AudioServer.bus_count, buses])

	check("the Tuning screen still lists the switch", ping.reader.subsystems.has("TUNE_AUDIO_LIDAR"))
	check("the switch is on by default", ping.doBleep == true)
	ping.ship.setTunedValue("Hud", "TUNE_AUDIO_LIDAR", false)
	check("switching the audible feedback off still stops the ping", ping.doBleep == false)
	ping.ship.setTunedValue("Hud", "TUNE_AUDIO_LIDAR", true)
	check("switching it on again brings it back", ping.doBleep == true)
