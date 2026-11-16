extends "res://harness/suite.gd"

# DiveSkipTransit: a dive starts in the ring at once and the return goes straight to the station, each skip by its own
# setting. The station (the game's enceladus/Enceladus.gd) cuts its launch sequence as soon as it starts, as the game
# does on Esc. The ring scene (run.ps1's Game.tscn: the game's Game.gd with the scene's root values and the "intro" and
# "exit" title cards) starts with the ship where the arrival cutscene leaves it, the game's own _process ends the
# cutscene on its first frame, and once the ship is set up the cutscene's braking, turbine remass and in-game time are
# charged. On the way out, the "exit" cutscene's method keys run at once, in order, each after the departure's burn,
# the turbines and the time of the stretch before it. The settings model is game-wide, in a file the suite points into
# its own project; Shift+Click on the station menu's dive entry (the game's EnceladusMenu.gd) opens its screen. The ship
# is harness/skip_ship.gd, holding nodes of the game's reactor scripts and harness/skip_thruster.gd thrusters. The
# control checks run on the game's own scripts: with the mod loaded, the bases of the extensions.

const GAME_SCENE = "res://Game.tscn"
const STATION_SCENE = "res://enceladus/Enceladus.tscn" # where Game.gd goToEnceladus goes
const SHIP = preload("res://harness/skip_ship.gd")
const THRUSTER = preload("res://harness/skip_thruster.gd")
const FISSION = "res://ships/Reactor.gd"
const FUSION = "res://ships/modules/FusionReactor.gd"
const TOLERANCE = 0.001
const SETTINGS_FILE = "res://skip_settings.cfg" # the mod's settings file during the suite, in its own project
# ships/ship-ctrl.gd escapeTheRing: the autopilot's desired velocity on the way out, in world units/s.
const ESCAPE_VELOCITY = Vector2(-5000, 0)
const DIVE_KEY = "ENCELADUS_RETURN_TO_RING" # the dive entry's text (enceladus/EnceladusMenu.tscn)
const CREW_KEY = "ENCELADUS_CREW"

var recorded = [] # what _record was given, in order
var settings = null # the mod's shared settings, with the mod loaded

func _record(what):
	recorded.append(what)

func run():
	var mod = hasMod("DiveSkipTransit")
	bindGameKeys()
	if mod:
		settings = load("res://DiveSkipTransit/Settings.gd").shared()
		settings.filePath = SETTINGS_FILE
		removeSettingsFile()
		settings.loadFromFile()
	launch(mod)
	var state = arrival(mod)
	if state is GDScriptFunctionState:
		yield(state, "completed")
	state = exits(mod)
	if state is GDScriptFunctionState:
		yield(state, "completed")
	if not mod:
		return
	model()
	state = switchesOff()
	if state is GDScriptFunctionState:
		yield(state, "completed")
	state = settingsScreen()
	if state is GDScriptFunctionState:
		yield(state, "completed")
	removeSettingsFile()

# With the mods' zips mounted as resource packs, a Directory opened on res:// sees the packs, read-only: it neither
# finds nor removes the file, which ConfigFile writes to the project folder. Opened on that folder's own path, it does.
func removeSettingsFile():
	var dir = Directory.new()
	if dir.open(ProjectSettings.globalize_path(SETTINGS_FILE.get_base_dir())) == OK and dir.file_exists(SETTINGS_FILE.get_file()):
		dir.remove(SETTINGS_FILE.get_file())

# The game's bindings (its project.godot): cutscene_ff is Space, the left mouse button and buttons 0 and 1; pause is
# Esc and Start; ui_cancel is Esc, B (button 1) and Start. Game.gd _process reads cutscene_ff every frame.
func bindGameKeys():
	var space = InputEventKey.new()
	space.scancode = KEY_SPACE
	var click = InputEventMouseButton.new()
	click.button_index = BUTTON_LEFT
	var bindings = [["cutscene_ff", space], ["cutscene_ff", click], ["pause", escKey()], ["ui_cancel", escKey()]]
	for button in [JOY_BUTTON_0, JOY_BUTTON_1]:
		bindings.append(["cutscene_ff", joyButton(button)])
	bindings += [["pause", joyButton(JOY_START)], ["ui_cancel", joyButton(JOY_BUTTON_1)], ["ui_cancel", joyButton(JOY_START)]]
	for binding in bindings:
		if not InputMap.has_action(binding[0]):
			InputMap.add_action(binding[0])
		if not InputMap.action_has_event(binding[0], binding[1]):
			InputMap.action_add_event(binding[0], binding[1])

func escKey():
	var event = InputEventKey.new()
	event.scancode = KEY_ESCAPE
	return event

func joyButton(index):
	var event = InputEventJoypadButton.new()
	event.button_index = index
	return event

# ---- The launch ----

# A station with `script` (the game's Enceladus.gd), given after the node is in the tree: its _ready needs the whole
# station, and without it nothing processes. It gets what _on_DiveTarget_launch uses: the three players, the ring
# scene's path (what Loader.prepare returns) and the ship.
func makeStation(script):
	var station = Node.new()
	station.name = "Enceladus"
	for playerName in ["ExitPlayer", "Autopilot", "AnimationPlayer"]:
		var player = AnimationPlayer.new()
		player.name = playerName
		station.add_child(player)
	station.get_node("ExitPlayer").add_animation("LaunchSequence", Animation.new())
	station.get_node("Autopilot").add_animation("GoToRing", Animation.new())
	add_child(station)
	station.set_script(script)
	station.nodeExitPlayer = station.get_node("ExitPlayer")
	station.nodeAutopilot = station.get_node("Autopilot")
	station.game = GAME_SCENE
	station.ship = SHIP.new()
	station.connect("launch", self, "_record", ["launch"])
	station.ship.connect("instance", self, "_record", ["instance"])
	return station

func freeStation(station):
	station.ship.free()
	station.free()

# Whether a launch from a new station with `script` goes to the ring at once (the station is freed after).
func launchesAtOnce(script) -> bool:
	Loader.calls.clear()
	var station = makeStation(script)
	station._on_DiveTarget_launch()
	var atOnce = Loader.calls.count("go " + GAME_SCENE) == 1 and not station.nodeExitPlayer.is_playing()
	freeStation(station)
	return atOnce

func launch(mod):
	var script = load("res://enceladus/Enceladus.gd")
	var game = script.get_base_script() if mod else script
	Loader.calls.clear()
	recorded.clear()
	var control = makeStation(game)
	control._on_DiveTarget_launch()
	check("control: the game alone plays the launch sequence", control.nodeExitPlayer.is_playing() and control.nodeExitPlayer.current_animation == "LaunchSequence")
	check("control: the game alone doesn't go to the ring yet", not ("go " + GAME_SCENE) in Loader.calls, Loader.calls)
	freeStation(control)
	if not mod:
		return
	Loader.calls.clear()
	recorded.clear()
	var station = makeStation(script)
	station._on_DiveTarget_launch()
	check("launch: the game's own launch runs first (the ship's instance signal, the launch signal, the ring scene loading)", recorded == ["instance", "launch"] and Loader.calls.size() > 0 and Loader.calls[0] == "prepare " + GAME_SCENE, [recorded, Loader.calls])
	check("launch: the game goes to the ring scene at once", Loader.calls.count("go " + GAME_SCENE) == 1, Loader.calls)
	check("launch: the launch sequence and the autopilot's sequence are stopped", not station.nodeExitPlayer.is_playing() and not station.nodeAutopilot.is_playing())
	check("launch: the ship still gets the station's power handler, as the game connects it", station.ship.is_connected("shipPowerToggle", station, "shipPower"))
	freeStation(station)

# ---- The ring scene ----

# A node of the game's reactor script at `path`, with the turbine state given.
func reactor(path, consumption, enabled):
	var script = load(path)
	var node = ClassDB.instance(script.get_instance_base_type())
	node.set_script(script)
	node.turbineConsumption = consumption
	node.enabled = enabled
	return node

# A thruster of `ship`, as the game keys its own (ship-ctrl.gd setupShip): `vector` is its push in the ship's frame.
func addThruster(ship, thrusterName, vector, thrust, exhaust, choke = 1.0):
	var node = THRUSTER.new()
	node.name = thrusterName
	node.thrust = thrust
	node.specificImpulse = exhaust
	node.choke = choke
	ship.add_child(node)
	ship.thrusters[thrusterName] = {"node": node, "vector": vector}

# The ship the ring scene gets (CurrentGame.recreatePlayerShip): a running fission reactor, one switched off but still
# at its coldLimit, one switched off and below it, one exploding, and a fusion reactor; each with its own consumption,
# so the sum tells which ones were charged. Four thrusters: ahead, angled, sideways and behind, `strength` scaling the
# thrust. Its transits cost remass and time, which Game.gd charges.
func makeShip(strength = 1.0):
	var ship = SHIP.new()
	var running = reactor(FISSION, 0.25, true)
	var hot = reactor(FISSION, 0.5, false)
	hot.temperature = hot.coldLimit
	var cold = reactor(FISSION, 2.0, false)
	cold.temperature = cold.coldLimit - 1
	var exploding = reactor(FISSION, 4.0, true)
	exploding.exploding = true
	var fusion = reactor(FUSION, 8.0, true)
	ship.reactors = [running, hot, cold, exploding, fusion]
	ship.interlunarRemass = 1000.0
	ship.interlunarTime = 3600.0
	ship.transitRemass = 5000.0
	ship.transitTime = 7200.0
	addThruster(ship, "Main", Vector2(0, -1), 90000.0 * strength, 30.0)
	addThruster(ship, "Angled", Vector2(0.6, -0.8), 20000.0 * strength, 20.0, 0.5)
	addThruster(ship, "Side", Vector2(1, 0), 50000.0 * strength, 10.0)
	addThruster(ship, "Retro", Vector2(0, 1), 70000.0 * strength, 10.0)
	return ship

# The ring scene with a new ship; with `script`, the scene's root gets it instead, keeping the scene's values.
func makeRing(script = null, strength = 1.0):
	CurrentGame.state["time"] = 0.0
	CurrentGame.advanced.clear()
	var ship = makeShip(strength)
	CurrentGame.nextShip = ship
	CurrentGame.playerShip = ship
	var scene = load(GAME_SCENE).instance()
	if script != null:
		var values = {}
		for property in scene.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				values[property.name] = scene.get(property.name)
		scene.set_script(script)
		for key in values:
			scene.set(key, values[key])
	add_child(scene)
	scene.get_node("AsteroidField").events = ship.events
	return [scene, ship]

func freeRing(ring):
	for r in ring[1].reactors:
		r.free()
	ring[0].queue_free()

func introHidden(scene):
	return not scene.get_node("TitleAnimPlayer/SubtitleLayer/IntroContainer").visible

# The turbines the mod should charge per second: the running and the still-hot fission reactors (makeShip's first two).
func turbinesPerSecond(ship):
	return ship.reactors[0].turbineConsumption + ship.reactors[1].turbineConsumption

func arrival(mod):
	var script = load("res://Game.gd")
	var game = script.get_base_script() if mod else null
	var control = makeRing(game)
	var cScene = control[0]
	var cShip = control[1]
	check("control: the game alone spawns the ship for the cutscene", cShip.position == cScene.initialPosition and cShip.linear_velocity == cScene.initialSpeed and cShip.cutscene and cScene.cutscene, [cShip.position, cShip.linear_velocity])
	yield(frames(3), "completed")
	check("control: the game alone keeps the cutscene going", cShip.cutscene and cScene.cutscene)
	check("control: the game alone shows the title card", not introHidden(cScene))
	var cBefore = cShip.reactiveMass
	cShip.emit_signal("setup")
	check("control: the game alone charges the transit only", is_equal_approx(cBefore - cShip.reactiveMass, cShip.interlunarRemass) and is_equal_approx(CurrentGame.state.time, cShip.interlunarTime), [cBefore - cShip.reactiveMass, CurrentGame.state.time])
	freeRing(control)
	yield(frames(1), "completed")
	if not mod:
		return

	var ring = makeRing()
	var scene = ring[0]
	var ship = ring[1]
	check("arrival: the ring scene gets the extension", scene.get_script() == script and script.get_base_script() != null)
	var seconds = scene.totalCutsceneTime
	var braking = Vector2(1, 0) * scene.desiredAcceleration
	var position = scene.initialPosition + scene.initialSpeed * seconds - braking * seconds * seconds / 2
	var velocity = scene.initialSpeed - braking * seconds
	check("arrival: the ship starts where the cutscene's braking leaves it", ship.position.distance_to(position) < TOLERANCE, [ship.position, position])
	check("arrival: the ship starts at the speed the braking leaves it", ship.linear_velocity.distance_to(velocity) < TOLERANCE, [ship.linear_velocity, velocity])
	check("arrival: the title card is at its end, hidden", introHidden(scene))
	yield(frames(3), "completed")
	check("arrival: the game's _process ends the cutscene on its first frame", not ship.cutscene and not scene.cutscene and ship.fastTravelDirection == 0)
	check("arrival: the ship already faces where the game turns it", is_equal_approx(ship.rotation, ship.autopilotDesiredRotation), [ship.rotation, ship.autopilotDesiredRotation])
	var before = ship.reactiveMass
	# The extension's constants, from the installed script (it took over Game.gd's path; loading its own path again
	# would compile a second copy that extends the first).
	var dv = braking.length() * seconds / script.get_script_constant_map()["_DST_UNITS_PER_METRE"]
	var expected = ship.interlunarRemass + ship.getRemassRequiredForDv(dv) + turbinesPerSecond(ship) * seconds
	ship.emit_signal("setup")
	check("arrival: after setup, the transit, the braking and the running or still-hot fission turbines are charged", abs(before - ship.reactiveMass - expected) < TOLERANCE, [before - ship.reactiveMass, expected])
	check("arrival: after setup, the transit's time and the cutscene's are charged", is_equal_approx(CurrentGame.state.time, ship.interlunarTime + seconds), CurrentGame.advanced)
	freeRing(ring)
	yield(frames(1), "completed")

# ---- The exit ----

# The method keys of the scene's "exit" animation, in time order: [time, method].
func exitKeys(scene) -> Array:
	var exit = scene.get_node("TitleAnimPlayer").get_animation("exit")
	var keys = []
	for track in exit.get_track_count():
		if exit.track_get_type(track) == Animation.TYPE_METHOD:
			for key in exit.track_get_key_count(track):
				keys.append([exit.track_get_key_time(track, key), exit.method_track_get_name(track, key)])
	keys.sort_custom(self, "_earlier")
	return keys

func _earlier(a, b):
	return a[0] < b[0]

# What the exit should leave, worked out here from the game's formulas: the full-throttle push and flow of the
# thrusters along the ship's forward axis, each fired at its alignment (ship-ctrl.gd fireVector) with a push of
# realThrust * cf and a flow of cf * realThrust * power / (specificImpulse * 10) kg/s (sfx/thruster.gd); the rocket
# equation at push / flow (a push of 1 is 1 t speeding up 1 world unit/s every second: 100 N) up to the change of speed
# still needed; the turbines; and the transit at its key. [the remass at the transit, the remass at the end, the burn's
# remass, the remass full throttle would burn over the whole cutscene].
func expectedExit(ship, keys) -> Array:
	var push = 0.0
	var flow = 0.0
	for thrusterName in ship.thrusters:
		var t = ship.thrusters[thrusterName]
		var alignment = t.vector.normalized().dot(Vector2(0, -1))
		if alignment > 0:
			var power = min(1.0, alignment)
			var thrust = t.node.thrust * t.node.choke
			push += thrust * power * alignment
			flow += thrust * power / (t.node.specificImpulse * 10)
	var exhaust = push * 100.0 / flow
	var mass0 = ship.currentMass * 1000 + ship.cargoMass
	var remass0 = ship.reactiveMass
	var remass = remass0
	var dv = (ship.autopilotDesiredVelocity - ship.linear_velocity).length() / 10.0
	var burned = 0.0
	var elapsed = 0.0
	var atTransit = null
	for key in keys:
		var gap = key[0] - elapsed
		if gap > 0:
			var mass = mass0 - (remass0 - remass)
			var reach = INF
			if flow * gap < mass:
				reach = exhaust * log(mass / (mass - flow * gap))
			var step = min(dv, reach)
			dv -= step
			var burn = min(remass, mass * (1 - exp(- step / exhaust)))
			burned += burn
			remass -= burn
			remass -= min(remass, turbinesPerSecond(ship) * gap)
		elapsed = max(elapsed, key[0])
		if key[1] == "interlunarToEnceladus":
			atTransit = remass
			remass -= min(remass, ship.transitRemass)
	return [atTransit, remass, burned, flow * elapsed]

# A ring two frames in, its ship set up, then leaving as escapeTheRing leaves (the escape velocity, the cutscene) from
# `velocity`: [scene, ship, the remass and in-game time just before, whether the arrival cutscene was over].
func leave(script, strength, velocity):
	var ring = makeRing(script, strength)
	yield(frames(2), "completed")
	ring[1].emit_signal("setup")
	yield(frames(1), "completed")
	var ship = ring[1]
	var arrived = not ship.cutscene and not ring[0].cutscene
	ship.linear_velocity = velocity
	ship.autopilotDesiredVelocity = ESCAPE_VELOCITY
	ship.cutscene = true
	ship.events.clear()
	Loader.calls.clear()
	CurrentGame.saves = 0
	return ring + [ship.reactiveMass, CurrentGame.state.time, arrived]

func exits(mod):
	var script = load("res://Game.gd")
	var game = script.get_base_script() if mod else null
	var state = leave(game, 1.0, Vector2(0, 0))
	var control = yield(state, "completed")
	var cShip = control[1]
	cShip.emit_signal("exitingRing")
	check("control: the game alone plays the exit cutscene", control[0].get_node("TitleAnimPlayer").current_animation == "exit")
	check("control: the game alone charges nothing yet and stays in the ring", cShip.events.empty() and Loader.calls.empty() and CurrentGame.saves == 0 and is_equal_approx(cShip.reactiveMass, control[2]), [cShip.events, Loader.calls, CurrentGame.saves])
	freeRing(control)
	yield(frames(1), "completed")
	if not mod:
		return
	# Diving back: from a full stop, on a ship that reaches the escape speed within the cutscene. Overspeed: heading into
	# the rings, on a ship too weak to turn round in time, which burns throughout.
	for case in [["dive back", 1.0, Vector2(0, 0), true], ["overspeed", 0.1, Vector2(2500, 0), false]]:
		state = leave(null, case[1], case[2])
		var ring = yield(state, "completed")
		var scene = ring[0]
		var ship = ring[1]
		var keys = exitKeys(scene)
		var last = keys[keys.size() - 1][0]
		var expected = expectedExit(ship, keys)
		ship.emit_signal("exitingRing")
		var transit = []
		for e in ship.events:
			if e is Array and e[0] == "transit":
				transit = e
		check("exit, %s: the cutscene's calls run at once, in order: the transit, the asteroids, the station" % case[0], ship.events.size() == 2 and transit.size() == 3 and ship.events[1] == "despawnAllAsteroids" and Loader.calls.count("go " + STATION_SCENE) == 1 and CurrentGame.saves == 1, [ship.events, Loader.calls, CurrentGame.saves])
		if transit.size() == 3:
			check("exit, %s: the transit is charged from what the departure's first stretch leaves" % case[0], abs(transit[1] - expected[0]) < TOLERANCE, [transit[1], expected[0]])
		check("exit, %s: the departure, the turbines and the transit are charged" % case[0], abs(ship.reactiveMass - expected[1]) < TOLERANCE, [ship.reactiveMass, expected[1]])
		check("exit, %s: %s" % [case[0], "the burn stops at the escape speed, short of full throttle all along" if case[3] else "the burn lasts the whole cutscene"], (expected[2] < expected[3] - 1.0) == case[3], [expected[2], expected[3]])
		check("exit, %s: the cutscene's in-game time and the transit's are charged" % case[0], is_equal_approx(CurrentGame.state.time, ring[3] + last + ship.transitTime), [CurrentGame.state.time - ring[3]])
		check("exit, %s: the title card is at its last frame, black" % case[0], is_equal_approx(scene.get_node("TitleAnimPlayer/SubtitleLayer/IntroContainer/CoverOfDark").color.a, 1.0))
		freeRing(ring)
		yield(frames(1), "completed")

# ---- The settings ----

func model():
	var script = load("res://DiveSkipTransit/Settings.gd")
	var keys = script.SETTINGS.keys()
	var defaults = true
	for key in keys:
		defaults = defaults and settings.getValue(key) == script.SETTINGS[key].default
	check("settings: every skip starts at its default", defaults and keys == ["skipLaunch", "skipArrival", "skipExit"], keys)
	recorded.clear()
	settings.connect("settingsChanged", self, "_record", ["changed"])
	settings.setValue("skipExit", not script.SETTINGS.skipExit.default)
	settings.setValue("skipExit", not script.SETTINGS.skipExit.default)
	check("settings: a change is stored and signalled once", settings.getValue("skipExit") != script.SETTINGS.skipExit.default and recorded == ["changed"], recorded)
	var file = ConfigFile.new()
	var loaded = file.load(SETTINGS_FILE) == OK
	var id = settings.modId()
	check("settings: written at once, in a section named by the mod's id, with the format and mod versions", loaded and file.get_value(id, "skipExit", null) == settings.getValue("skipExit") and file.get_value(id, "formatVersion", null) == script.FORMAT_VERSION and file.get_value(id, "modVersion", null) == settings.modVersion(), [loaded, id])
	var other = script.new()
	other.filePath = SETTINGS_FILE
	other.loadFromFile()
	check("settings: a new instance reads them back from the file", other.getValue("skipExit") == settings.getValue("skipExit"))
	settings.setValue("skipExit", "off")
	check("settings: a value that isn't a switch's gives the default", settings.getValue("skipExit") == script.SETTINGS.skipExit.default)
	file.set_value(id, "skipLaunch", 7)
	file.set_value(id, "skipArrival", false)
	file.save(SETTINGS_FILE)
	other.loadFromFile()
	check("settings: a hand-edited file loads its switches and keeps the default for anything else", other.getValue("skipLaunch") == script.SETTINGS.skipLaunch.default and other.getValue("skipArrival") == false)
	settings.disconnect("settingsChanged", self, "_record")
	removeSettingsFile()
	settings.loadFromFile()

# Each switch off: that sequence plays as in the game, while the others are still skipped.
func switchesOff():
	settings.setValue("skipLaunch", false)
	check("launch switch off: the launch sequence plays", not launchesAtOnce(load("res://enceladus/Enceladus.gd")))
	settings.setValue("skipLaunch", true)

	settings.setValue("skipArrival", false)
	check("arrival switch off: the launch is still cut", launchesAtOnce(load("res://enceladus/Enceladus.gd")))
	var ring = makeRing()
	check("arrival switch off: the ship is spawned for the cutscene", ring[1].position == ring[0].initialPosition and ring[1].cutscene)
	yield(frames(3), "completed")
	check("arrival switch off: the cutscene goes on under the title card", ring[1].cutscene and not introHidden(ring[0]))
	var before = ring[1].reactiveMass
	ring[1].emit_signal("setup")
	check("arrival switch off: only the transit is charged", is_equal_approx(before - ring[1].reactiveMass, ring[1].interlunarRemass))
	ring[1].autopilotDesiredVelocity = ESCAPE_VELOCITY
	ring[1].events.clear()
	Loader.calls.clear()
	ring[1].emit_signal("exitingRing")
	check("arrival switch off: the exit is still skipped", Loader.calls.count("go " + STATION_SCENE) == 1, Loader.calls)
	freeRing(ring)
	yield(frames(1), "completed")
	settings.setValue("skipArrival", true)

	settings.setValue("skipExit", false)
	var state = leave(null, 1.0, Vector2(0, 0))
	ring = yield(state, "completed")
	check("exit switch off: the arrival is still skipped", ring[4])
	ring[1].emit_signal("exitingRing")
	check("exit switch off: the exit cutscene plays and nothing is charged yet", ring[0].get_node("TitleAnimPlayer").current_animation == "exit" and ring[1].events.empty() and Loader.calls.empty() and is_equal_approx(ring[1].reactiveMass, ring[2]))
	freeRing(ring)
	yield(frames(1), "completed")
	settings.setValue("skipExit", true)

# The station as enceladus/Enceladus.tscn nests the menu and the right-hand screens (as the crew suite builds it):
# MarginContainer > HBoxContainer > Options (the menu, the game's EnceladusMenu.gd, with the dive entry and, when
# CrewCheapHireNotifier is loaded too, the Crew entry and its screen), and MarginContainer > CanvasLayer >
# MarginContainer (HidingMarginContainer.gd) > the Tuning screen, hidden, with a frame of its own to copy.
func menuStation(withCrew):
	var root = MarginContainer.new()
	root.name = "MarginContainer"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	var hbox = HBoxContainer.new(); hbox.name = "HBoxContainer"
	root.add_child(hbox)
	var menu = VBoxContainer.new(); menu.name = "Options"
	menu.set_script(load("res://enceladus/EnceladusMenu.gd"))
	var dive = Button.new(); dive.name = "RingDive"; dive.text = DIVE_KEY
	menu.add_child(dive)
	dive.connect("pressed", self, "_record", ["dive"])
	var crew = null
	if withCrew:
		crew = Button.new(); crew.name = "Crew"; crew.text = CREW_KEY
		menu.add_child(crew)
	var logs = Button.new(); logs.name = "Logs"; logs.text = "ENCELADUS_LOGS"
	menu.add_child(logs)
	hbox.add_child(menu)
	var layer = CanvasLayer.new(); layer.name = "CanvasLayer"
	root.add_child(layer)
	var screens = MarginContainer.new(); screens.name = "MarginContainer"
	screens.set_script(load("res://enceladus/HidingMarginContainer.gd"))
	screens.hideOnFocusOf = NodePath("../../HBoxContainer/Options")
	screens.anchor_right = 1.0
	screens.anchor_bottom = 1.0
	screens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screens)
	if withCrew:
		var crewScreen = Control.new(); crewScreen.name = "Crew"; crewScreen.visible = false
		crewScreen.set_script(load("res://harness/crew_screen.gd"))
		screens.add_child(crewScreen)
		crew.connect("pressed", crewScreen, "_on_Crew_pressed")
	var tuning = PanelContainer.new(); tuning.name = "Tuning"; tuning.visible = false
	tuning.theme = Theme.new()
	tuning.add_stylebox_override("panel", StyleBoxFlat.new())
	tuning.rect_min_size = Vector2(600, 0)
	tuning.size_flags_horizontal = Control.SIZE_SHRINK_END
	screens.add_child(tuning)
	add_child(root)
	return {"root": root, "menu": menu, "dive": dive, "crew": crew, "logs": logs, "screens": screens}

# A left click on `button` through the scene tree's input, as the mouse makes it: the press, then the release.
func click(button, shift):
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = BUTTON_LEFT
		event.pressed = pressed
		event.shift = shift
		event.position = button.rect_global_position + button.rect_size / 2
		event.global_position = event.position
		get_tree().input_event(event)

# A press and release of a key, as Input delivers a player's, in the idle part of a frame (crew suite's tap).
func tap(event):
	yield(get_tree(), "idle_frame")
	for pressed in [true, false]:
		var e = event.duplicate()
		e.pressed = pressed
		Input.parse_input_event(e)

func screenOf(s):
	return s.screens.get_node_or_null("DiveSkipTransitSettings")

# The settings screen's switches (the game's TuningBoolValue), in order, and its groups.
func switches(screen) -> Array:
	var out = []
	for group in screenGroups(screen):
		for row in group.get_children():
			if "tune" in row:
				out.append(row)
	return out

func screenGroups(screen) -> Array:
	var out = []
	for items in screen.get_node("VB/ScrollContainer").get_children():
		if items.is_queued_for_deletion() or items.name != "Items":
			continue
		for group in items.get_children():
			if "tuning" in group and not group.is_queued_for_deletion():
				out.append(group)
	return out

func settingsScreen():
	var script = load("res://DiveSkipTransit/Settings.gd")
	Input.set_use_accumulated_input(false)
	var withCrew = hasMod("CrewCheapHireNotifier")
	recorded.clear()
	var s = menuStation(withCrew)
	yield(frames(2), "completed")
	var tip = tr("DIVESKIPTRANSIT_SETTINGS_TOOLTIP")
	check("screen: the mod's texts are loaded (i18n/en.po)", tip != "DIVESKIPTRANSIT_SETTINGS_TOOLTIP" and tr("DIVESKIPTRANSIT_SKIP_EXIT") != "DIVESKIPTRANSIT_SKIP_EXIT")
	check("screen: the dive entry's tooltip tells about Shift+Click", s.dive.hint_tooltip == tip % [OS.get_scancode_string(KEY_SHIFT), settings.modName()], s.dive.hint_tooltip)
	click(s.dive, false)
	yield(frames(2), "completed")
	check("screen: a plain click on the dive entry launches and opens no settings", recorded == ["dive"] and screenOf(s) == null, recorded)
	s.dive.disabled = true
	click(s.dive, true)
	yield(frames(2), "completed")
	check("screen: Shift+Click on a disabled dive entry does nothing", recorded == ["dive"] and screenOf(s) == null, recorded)
	s.dive.disabled = false
	click(s.dive, true)
	yield(frames(5), "completed")
	var screen = screenOf(s)
	check("screen: Shift+Click on the dive entry opens the settings and doesn't launch", screen != null and screen.visible and recorded == ["dive"], recorded)
	if screen == null:
		freeMenuStation(s)
		return
	var groups = screenGroups(screen)
	var rows = switches(screen)
	var names = []
	var shown = true
	for i in rows.size():
		names.append(rows[i].tuningItem)
		var key = script.SETTINGS.keys()[i] if i < script.SETTINGS.size() else ""
		shown = shown and rows[i].get_node("HBoxContainer/Value").pressed == settings.getValue(key)
	var labels = []
	for key in script.SETTINGS:
		labels.append(script.SETTINGS[key].label)
	var groupLabel = load("res://DiveSkipTransit/SettingsUI.gd").get_script_constant_map()["GROUP_LABEL"]
	check("screen: one group, titled by the mod's group key, with one switch per setting named by its label, in order", groups.size() == 1 and groups[0].system == groupLabel and names == labels, [groups.size(), names])
	check("screen: each switch shows its setting", shown)
	check("screen: its header is the dive entry's text", screen.get_node("VB/HeaderWithMoney/MarketLabel").text == DIVE_KEY)
	var exitSwitch = rows[2].get_node("HBoxContainer/Value")
	exitSwitch.pressed = false
	check("screen: switching one off stores it at once", settings.getValue("skipExit") == false and ConfigFile.new().load(SETTINGS_FILE) == OK)
	rows[0].get_node("HBoxContainer/Value").grab_focus()
	exitSwitch.grab_focus()
	yield(frames(1), "completed")
	check("screen: focusing it again doesn't switch it back", settings.getValue("skipExit") == false and not exitSwitch.pressed)
	rows[2].get_node("HBoxContainer/Reset").emit_signal("pressed")
	check("screen: its reset button puts it back to the default", settings.getValue("skipExit") == script.SETTINGS.skipExit.default and exitSwitch.pressed == script.SETTINGS.skipExit.default)
	yield(tap(escKey()), "completed")
	yield(frames(40), "completed")
	check("screen: Esc closes it after the game's fade", not screen.visible)
	if withCrew:
		click(s.crew, true)
		yield(frames(40), "completed")
		var crewSettings = s.screens.get_node_or_null("CrewCheapHireNotifierSettings")
		check("with CrewCheapHireNotifier: Shift+Click on Crew opens its settings, not these", crewSettings != null and crewSettings.visible and not screen.visible)
		click(s.dive, true)
		yield(frames(40), "completed")
		check("with CrewCheapHireNotifier: Shift+Click on the dive entry opens these and hides its", screen.visible and not crewSettings.visible)
		check("with CrewCheapHireNotifier: both entries keep their own tooltip", s.dive.hint_tooltip.find(settings.modName()) >= 0 and s.crew.hint_tooltip.find("CrewCheapHireNotifier") >= 0, [s.dive.hint_tooltip, s.crew.hint_tooltip])
	freeMenuStation(s)

func freeMenuStation(s):
	s.root.queue_free()
	yield(frames(1), "completed")
