extends "res://harness/suite.gd"

# DiveSkipTransit: a dive starts in the ring at once. The station (the game's enceladus/Enceladus.gd) cuts its launch
# sequence as soon as it starts, as the game does on Esc. The ring scene (run.ps1's Game.tscn: the game's Game.gd with
# the scene's root values and title card) starts with the ship where the arrival cutscene leaves it, the game's own
# _process ends the cutscene on its first frame, and once the ship is set up the cutscene's braking, turbine remass
# and in-game time are charged. The ship is harness/skip_ship.gd, holding nodes of the game's reactor scripts. The
# control checks run on the game's own scripts: with the mod loaded, the bases of the extensions.

const GAME_SCENE = "res://Game.tscn"
const SHIP = preload("res://harness/skip_ship.gd")
const FISSION = "res://ships/Reactor.gd"
const FUSION = "res://ships/modules/FusionReactor.gd"
const TOLERANCE = 0.001

var recorded = [] # what _record was given, in order

func _record(what):
	recorded.append(what)

func run():
	var mod = hasMod("DiveSkipTransit")
	bindGameKeys()
	launch(mod)
	var state = arrival(mod)
	if state is GDScriptFunctionState:
		yield(state, "completed")

# The game's bindings (its project.godot): cutscene_ff is Space, the left mouse button and buttons 0 and 1; pause is
# Esc and Start. Game.gd _process reads cutscene_ff every frame.
func bindGameKeys():
	var space = InputEventKey.new()
	space.scancode = KEY_SPACE
	var click = InputEventMouseButton.new()
	click.button_index = BUTTON_LEFT
	var esc = InputEventKey.new()
	esc.scancode = KEY_ESCAPE
	var bindings = [["cutscene_ff", space], ["cutscene_ff", click], ["pause", esc]]
	for button in [JOY_BUTTON_0, JOY_BUTTON_1, JOY_START]:
		var event = InputEventJoypadButton.new()
		event.button_index = button
		bindings.append(["pause" if button == JOY_START else "cutscene_ff", event])
	for binding in bindings:
		if not InputMap.has_action(binding[0]):
			InputMap.add_action(binding[0])
		if not InputMap.action_has_event(binding[0], binding[1]):
			InputMap.action_add_event(binding[0], binding[1])

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

# A node of the game's reactor script at `path`, with the turbine state given.
func reactor(path, consumption, enabled):
	var script = load(path)
	var node = ClassDB.instance(script.get_instance_base_type())
	node.set_script(script)
	node.turbineConsumption = consumption
	node.enabled = enabled
	return node

# The ship the ring scene gets (CurrentGame.recreatePlayerShip): a running fission reactor, one switched off but still
# at its coldLimit, one switched off and below it, one exploding, and a fusion reactor; each with its own consumption,
# so the sum tells which ones were charged. Its transit to the rings costs remass and time, which Game.gd _ready charges
# after setup.
func makeShip():
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
	return ship

# The ring scene with a new ship; with `script`, the scene's root gets it instead, keeping the scene's values.
func makeRing(script = null):
	CurrentGame.state["time"] = 0.0
	CurrentGame.advanced.clear()
	var ship = makeShip()
	CurrentGame.nextShip = ship
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
	return [scene, ship]

func freeRing(ring):
	for r in ring[1].reactors:
		r.free()
	ring[0].queue_free()

func introHidden(scene):
	return not scene.get_node("TitleAnimPlayer/SubtitleLayer/IntroContainer").visible

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
	var turbines = (ship.reactors[0].turbineConsumption + ship.reactors[1].turbineConsumption) * seconds
	var expected = ship.interlunarRemass + ship.getRemassRequiredForDv(dv) + turbines
	ship.emit_signal("setup")
	check("arrival: after setup, the transit, the braking and the running or still-hot fission turbines are charged", abs(before - ship.reactiveMass - expected) < TOLERANCE, [before - ship.reactiveMass, expected])
	check("arrival: after setup, the transit's time and the cutscene's are charged", is_equal_approx(CurrentGame.state.time, ship.interlunarTime + seconds), CurrentGame.advanced)
	freeRing(ring)
	yield(frames(1), "completed")
