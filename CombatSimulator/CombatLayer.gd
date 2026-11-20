extends CanvasLayer

# CombatSimulator's arena: a hostile encounter in a stretch of ring, run as an overlay at the station, the way the
# simulator runs (enceladus/Simulator/SimulationLayer.gd) but without its hex look. The station root's child right
# after SimulationLayer (Code.gd), on its layer. Inside a viewport with a world of its own, what the ring scene
# (Game.tscn) holds around a ship: the asteroid field (with the ships as its children), BulletTimer, the music and
# WESpace. The field's map is CombatMap.gd. The player's ship is built as the simulator builds it (zone "sim", `test`);
# the enemies, all pirates, by the game's own builders.
# - The layer processes while the game is paused (to take input and show the end confirmation); the viewport's
#   container stops, so the arena stops with the game.
# - Its _input runs before the screens' (later in the tree; Godot 3 calls _input in reverse tree order): it forwards
#   events into the viewport as the simulator's container does (enceladus/MarginViewportUpscale.gd, Viewport.input),
#   and marks each handled, so nothing at the station reacts. Esc closes the OMS when it is open, as in a dive
#   (ships/camera.gd _input); otherwise pause (Esc, the gamepad's Start) asks whether to end the run, pausing the game
#   as the dive's pause menu does (PauseLayer.gd pauseGame), where a dive would open that menu.
# - What the arena's ships write into the save is kept out: CurrentGame.gd drops what has no table to restore, the
#   ships are cleaned up as they enter (_onNodeAdded), and the tables they write are copied at Start and restored at
#   the end (SAVE_TABLES).

const CombatSimulator = preload("res://CombatSimulator/Settings.gd")
const CombatMap = preload("res://CombatSimulator/CombatMap.gd")

# The ring scene, read for what it sets on its nodes (GAME_FIELD_MASKS, the cursor's fade, the arrival's length), and
# the parts of it the arena instances.
const GAME_RING_SCENE = "res://Game.tscn"
const GAME_FIELD = "res://AsteroidField.tscn"
const GAME_BULLET_TIMER = "res://BulletTimer.tscn"
const GAME_MUSIC = "res://music/Music.tscn"
const GAME_ENVIRONMENT = "res://WESpace.tscn"
# The field's node in the ring scene, and the intersection masks the ring scene gives it.
const GAME_RING_FIELD = "AsteroidField"
const GAME_FIELD_MASKS = ["oddityIntersectionTest", "asteroidIntersectionTest"]
# The ring scene's cursor layer, whose fadeTime the station's cursor takes during a run.
const GAME_RING_MOUSE = "MouseLayer"
# The ring scene's root value for the arrival cutscene's length (Game.gd totalCutsceneTime), for the prefill; the
# fallback, for when the scene doesn't set it, is the value Game.tscn sets (GAME.md, Cutscene).
const GAME_ARRIVAL_SECONDS = "totalCutsceneTime"
const ARRIVAL_SECONDS_FALLBACK = 16.0
# The simulator's container and viewport scripts.
const GAME_UPSCALE = "res://enceladus/MarginViewportUpscale.gd"
const GAME_VIEWPORT = "res://enceladus/Simulator/ViewportWithProxy.gd"
# BulletTimer's own notifications layer: the station has one (NotificationLayer), and each notification would show
# twice.
const GAME_BULLET_TIMER_NOTIFICATIONS = "NotificationsLayer"
# The theme of the simulator's button, for the end confirmation when the Tuning screen is missing.
const GAME_THEME = "res://menu/MenuTheme.tres"
# The random events of the rings (story/TheRing.tscn), where the Big Bad Wolf's builder has its values.
const GAME_EVENTS = "res://story/TheRing.tscn"
# The Music bus, whose first effect (a low-pass filter) the dive's pause menu switches on.
const MUSIC_BUS = "Music"

# The station's nodes (enceladus/Enceladus.tscn).
const STATION_SIMULATION = "SimulationLayer"
const STATION_SIMULATION_UPSCALE = "SimulationLayer/MarginContainer"
const STATION_RING = "EnceladusMenu/DiveTarget/TheRing"
const STATION_NO_BULLET_TIME = "NoBulletTime"
const STATION_MUSIC = ["Intro", "Loop"]
const STATION_MOUSE = "MouseLayer/Mouse"
const STATION_UI = ["Background", "EnceladusMenu"]
const STATION_TUNING = "Tuning"

# How the game builds a model when it attacks the player: the event's script, its builder, the builder's arguments,
# values set on the script's fresh instance first, and the node of story/TheRing.tscn whose values it takes (the Big
# Bad Wolf's). The pirate comes alone, without the civilian it hunts and without loot (lootMax above lootMin:
# PirateCombat.gd takes a modulo of their difference).
const BUILDERS = {
	"TRTL": {
		"script": "res://story/PirateCombat.gd",
		"method": "makeAt",
		"args": [Vector2(0, 0)],
		"set": {"hasCivilian": false, "lootMin": 0, "lootMax": 1},
		"node": "",
	},
	"MADCERF": {
		"script": "res://story/RescueOperation.gd",
		"method": "makeAbductor",
		"args": [],
		"set": {},
		"node": "",
	},
	"HYBRID": {
		"script": "res://story/HybridHunter.gd",
		"method": "makeAt",
		"args": [Vector2(0, 0)],
		"set": {},
		"node": "",
	},
	"TSUKUYOMI": {
		"script": "res://story/MinerMining.gd",
		"method": "makeAt",
		"args": [Vector2(0, 0)],
		"set": {},
		"node": "BigBadWolf",
	},
}
# Models the game builds new, as story/RingRace.gd builds its racers (Shipyard.createShipByName, age 0). Any other
# model gets the used build or default config the game gives it as a derelict or miner (createShipBuildByName).
const NEW_BUILDS = ["ATLAS", "DRONE", "PROSPECTOR-BALD"]
const ENEMY_FACTION = "pirate"

# The spot of the ring the run takes its size bias, veins and HUD readings from (CombatMap.gd pickSpot): random pixels
# tried, and the least distance in pixels (km) from the ring's edges, where the HUD's leaving-the-rings warning
# (hud/Leaving Rings.gd) would show.
const SPOT_SAMPLES = 400
const SPOT_EDGE_MARGIN = 5
# Where the enemies spawn, in m: from the Distance setting to that plus SPAWN_SPREAD; grouped ones side by side,
# GROUP_SPACING apart. With the largest Distance and three grouped enemies, the farthest stays inside the AI's
# awareness (ships/AI.tscn ShipArea, 6.4 km), so they come for the player.
const SPAWN_SPREAD = 1000
const GROUP_SPACING = 300
# How far the field may move a spot taken by a rock (AsteroidSpawner.gd spawnByBlueprint's spawnPointRandomness), in
# m, and how many spots are drawn before an enemy is given up.
const PLACEMENT_RANDOMNESS = 100
const PLACEMENT_TRIES = 8
# The fade in and out, in seconds.
const FADE_SECONDS = 1.0

# The save's tables the arena's ships write whatever their zone: copied at Start, restored in place at the end.
# dispositions: every AI ship's entry, made as it is set up (ships/ship-ctrl.gd setDummy) and written by hits;
# encounteredShips: conversations; shipNames: written on read (getShipName); transponders: every new ship's
# (Shipyard.gd createShipByConfig); factions: hits seen (applyHostility) and plain reads (Factions.gd).
const SAVE_TABLES = ["dispositions", "encounteredShips", "shipNames", "transponders", "factions"]

var _settings = CombatSimulator.shared()
var _station = null
var _upscale = null
var _viewport = null
var _picture = null
var _texture = null
var _tween = null
var _confirm = null
var _running = false
var _ending = false
var _field = null
var _map = null
var _ship = null
var _realPlayerShip = null
var _lastFocus = null
var _inventoryMode = false
var _frozePirate = false
var _mouseFade = null
var _copies = {}

func setup(station):
	_station = station
	name = "CombatSimulatorArena"
	pause_mode = PAUSE_MODE_PROCESS
	var simulation = station.get_node_or_null(STATION_SIMULATION)
	if simulation is CanvasLayer:
		layer = simulation.layer
	visible = false
	_upscale = MarginContainer.new()
	_upscale.set_script(load(GAME_UPSCALE))
	_upscale.name = "Upscale"
	_upscale.pause_mode = PAUSE_MODE_STOP
	_upscale.passEvents = false
	var gameUpscale = station.get_node_or_null(STATION_SIMULATION_UPSCALE)
	if gameUpscale != null and "scale" in gameUpscale:
		_upscale.scale = gameUpscale.scale
	_fullRect(_upscale)
	add_child(_upscale)
	_viewport = Viewport.new()
	_viewport.set_script(load(GAME_VIEWPORT))
	_viewport.name = "Viewport"
	_viewport.own_world = true
	_viewport.render_target_update_mode = Viewport.UPDATE_DISABLED
	_viewport.mouseProxy = NodePath("../../Picture/TextureRect")
	_upscale.add_child(_viewport)
	_picture = MarginContainer.new()
	_picture.name = "Picture"
	_fullRect(_picture)
	add_child(_picture)
	_texture = TextureRect.new()
	_texture.name = "TextureRect"
	_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture.expand = true
	_texture.stretch_mode = TextureRect.STRETCH_SCALE
	_texture.flip_v = true
	_texture.texture = _viewport.get_texture()
	_texture.modulate.a = 0.0
	_picture.add_child(_texture)
	_tween = Tween.new()
	_tween.name = "Fade"
	add_child(_tween)
	_buildConfirmation(station)

func _fullRect(control: Control):
	control.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.rect_clip_content = true
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL

# The end confirmation: the question and Yes / No, in the game's theme (the Tuning screen's, as SettingsUI.gd uses),
# as ShipCopyPaste's dialog is built. Exclusive: clicks outside it do nothing.
func _buildConfirmation(station):
	_confirm = ConfirmationDialog.new()
	_confirm.name = "EndConfirmation"
	_confirm.window_title = ""
	_confirm.popup_exclusive = true
	_confirm.dialog_hide_on_ok = false
	_confirm.dialog_text = "COMBATSIMULATOR_END_QUESTION"
	_confirm.get_ok().text = "COMBATSIMULATOR_END_YES"
	_confirm.get_cancel().text = "COMBATSIMULATOR_END_NO"
	var screens = station.get("menusContainer")
	var tuning = screens.get_node_or_null(STATION_TUNING) if screens != null else null
	_confirm.theme = tuning.theme if tuning is Control and tuning.theme != null else load(GAME_THEME)
	add_child(_confirm)
	_confirm.connect("confirmed", self, "_onConfirmed")
	_confirm.connect("popup_hide", self, "_onConfirmHidden")

func isRunning() -> bool:
	return _running

# Starts a run with the ship `sim` (what the screen's simulator would have flown); `lastFocus` gets the focus back at
# the end. Nothing happens without the station's ring map to build the stretch of ring from.
func start(sim, lastFocus):
	if _running or not sim is Dictionary or not sim.has("config"):
		return
	var ring = _station.get_node_or_null(STATION_RING)
	if ring == null or ring.get("image") == null:
		return
	_running = true
	_ending = false
	_lastFocus = lastFocus
	_snapshot()
	CurrentGame.set("_csArena", self)
	_frozePirate = not Factions.frozenFactions.has(ENEMY_FACTION)
	if _frozePirate:
		Factions.frozenFactions.append(ENEMY_FACTION)
	_inventoryMode = CurrentGame.inventoryMode
	_map = CombatMap.new()
	_map.shareImagesOf(ring)
	_map.chaos = _settings.getValue("chaos")
	_map.density = _settings.getValue("density")
	CurrentGame.setGlobalOffset(_map.pickSpot(SPOT_SAMPLES, SPOT_EDGE_MARGIN))
	get_tree().connect("node_added", self, "_onNodeAdded")
	var ringScene = load(GAME_RING_SCENE)
	var state = ringScene.get_state() if ringScene is PackedScene else null
	_pauseStation(true, state)
	_buildArena(state)
	if not _buildShip(sim):
		_cleanup()
		return
	_prefill(state)
	_spawnEnemies()
	_fadeIn()

# Copies of the save's tables the ships write (SAVE_TABLES); a table the save lacks is remembered as null.
func _snapshot():
	_copies = {}
	for key in SAVE_TABLES:
		var table = CurrentGame.state.get(key)
		_copies[key] = table.duplicate(true) if table is Dictionary else null

# Each table back as it was, in place: Factions.gd and the game hold these dictionaries. One the save lacked at Start
# goes again.
func _restore():
	for key in _copies:
		var copy = _copies[key]
		var table = CurrentGame.state.get(key)
		if copy == null:
			CurrentGame.state.erase(key)
		elif table is Dictionary:
			table.clear()
			for entry in copy:
				table[entry] = copy[entry]
		else:
			CurrentGame.state[key] = copy
	_copies = {}

# For the whole run, the station stops what would change the arena, and starts it again at the end:
# - NoBulletTime forces Engine.time_scale to 1 and the Master bus's effect off every physics frame, which would undo
#   bullet time (BulletTimer.gd);
# - the station's music (pause_mode PROCESS) pauses;
# - the cursor fades as fast as the ring scene's (menu/Mouse.gd reads its layer's fadeTime once, in _ready);
# - the focus leaves the screen, and comes back at the end.
func _pauseStation(pause: bool, state = null):
	var noBulletTime = _station.get_node_or_null(STATION_NO_BULLET_TIME)
	if noBulletTime != null:
		noBulletTime.set_physics_process(not pause)
	for music in STATION_MUSIC:
		var player = _station.get_node_or_null(music)
		if player is AudioStreamPlayer:
			player.stream_paused = pause
	var mouse = _station.get_node_or_null(STATION_MOUSE)
	if mouse != null and "fadeTime" in mouse:
		if pause:
			var fade = _ringValue(state, GAME_RING_MOUSE, "fadeTime")
			_mouseFade = mouse.fadeTime
			if fade != null:
				mouse.fadeTime = fade
		elif _mouseFade != null:
			mouse.fadeTime = _mouseFade
			_mouseFade = null
	if _lastFocus != null and is_instance_valid(_lastFocus):
		if pause:
			_lastFocus.release_focus()
		else:
			_lastFocus.grab_focus()

# The value the ring scene (its SceneState) gives its node `nodeName`'s `property` ("." for its root), or null.
func _ringValue(state, nodeName: String, property: String):
	if state == null:
		return null
	for i in state.get_node_count():
		if str(state.get_node_path(i)) != _statePath(nodeName):
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == property:
				return state.get_node_property_value(i, p)
	return null

# How a SceneState names the node at `nodeName` (a path from its scene's root, "." for the root itself): it puts "./"
# before every path but the root's (SceneState.get_node_path).
func _statePath(nodeName: String) -> String:
	return nodeName if nodeName == "." else "./" + nodeName

# The ring scene's parts, as Game.tscn holds them. The field: nothing traced into the save's density map, its event
# ships in the "sim" zone, the ring scene's masks, the arena's map; its _process (in-game time, which the station
# already advances, and the mood) stops, and _process here sends the mood. The field's _ready reseeds the random
# numbers with a fixed word: randomize() after it. BulletTimer: without its own notifications, and deaf to gameOver,
# which Reactor.gd emits for any player-controlled ship and which would slow time to 0.1 for good.
func _buildArena(state):
	_field = load(GAME_FIELD).instance()
	_field.traceSpawns = false
	_field.zone = "sim"
	_field.map = NodePath()
	for mask in GAME_FIELD_MASKS:
		var value = _ringValue(state, GAME_RING_FIELD, mask)
		if value != null:
			_field.set(mask, value)
	_field.mapInstance = _map
	_map.field = _field
	_viewport.add_child(_field)
	_field.set_process(false)
	randomize()
	var timer = load(GAME_BULLET_TIMER).instance()
	var notifications = timer.get_node_or_null(GAME_BULLET_TIMER_NOTIFICATIONS)
	if notifications != null:
		timer.remove_child(notifications)
		notifications.free()
	_viewport.add_child(timer)
	if CurrentGame.is_connected("gameOver", timer, "_on_gameOver"):
		CurrentGame.disconnect("gameOver", timer, "_on_gameOver")
	_viewport.add_child(load(GAME_MUSIC).instance())
	_viewport.add_child(load(GAME_ENVIRONMENT).instance())
	_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS

# The player's ship, as SimulationLayer.gd startSimulation builds it, with the remass set (CurrentGame.gd
# resupplyThisCfg fills the tanks the same way). CurrentGame.playerShip is swapped before the ship is added: the OMS's
# Astrogator tab takes it in its _ready (hud/AstrogatorPanel.gd). The ship sets itself as the field's focus once set
# up (ships/ship-ctrl.gd handlePlayerControl); the prefill needs it at once.
func _buildShip(sim) -> bool:
	sim = sim.duplicate(true)
	sim.config = CurrentGame.resupplyThisCfg(sim.config)
	var fuel = sim.config.get("fuel")
	if fuel is Dictionary:
		fuel.initial = fuel.get("capacity", 0) * _settings.getValue("remass")
	_ship = Shipyard.createShipByConfig(sim)
	if _ship == null:
		return false
	_ship.test = true
	_ship.zone = "sim"
	_ship.playerControlled = true
	_ship.preheat = true
	_ship.set_meta(CombatSimulator.SHIP_META, true)
	_realPlayerShip = CurrentGame.playerShip
	CurrentGame.playerShip = _ship
	_field.add_child(_ship)
	_field.focusObject = _ship
	_ship.connect("removal", self, "_onShipRemoved")
	return true

# As the field fills around the ship during a dive's arrival cutscene: as many spawns as it makes in that time (the
# ring scene's arrival length over the field's spawnEvery), with the cutscene's spawn radius.
func _prefill(state):
	var seconds = _ringValue(state, ".", GAME_ARRIVAL_SECONDS)
	if not (seconds is float or seconds is int):
		seconds = ARRIVAL_SECONDS_FALLBACK
	var spawns = int(seconds / _field.spawnEvery)
	var radius = _field.minSpawnRadius
	_field.minSpawnRadius = _field.cutsceneSpawnRadius
	for i in spawns:
		_field.spawnProperThings(0)
	_field.minSpawnRadius = radius

# The enemies, placed by the field as it places event ships (spawnByBlueprint: the zone set, the spot clear of rocks),
# at rest. Grouped: one bearing and distance, side by side across it; else each on its own.
func _spawnEnemies():
	var model = _settings.getValue("ship")
	var number = int(_settings.getValue("number"))
	var grouped = _settings.getValue("grouped")
	var minimum = _settings.getValue("distance")
	var origin = _ship.global_position
	var bearing = randf() * TAU
	var distance = minimum + randf() * SPAWN_SPREAD
	for i in number:
		var enemy = _buildEnemy(model)
		if enemy == null:
			continue
		enemy.faction = ENEMY_FACTION
		enemy.ai = true
		enemy.preheat = true
		if _settings.getValue("disabledWeapons"):
			enemy.set_meta(CombatSimulator.DISARMED_META, true)
		var placed = false
		for t in PLACEMENT_TRIES:
			if not grouped:
				bearing = randf() * TAU
			if t > 0 or not grouped:
				distance = minimum + randf() * SPAWN_SPREAD
			var across = (i - (number - 1) / 2.0) * GROUP_SPACING if grouped else 0.0
			var spot = origin + Vector2(distance, across).rotated(bearing) * CombatSimulator.UNITS_PER_METRE
			if _field.spawnByBlueprint(enemy, spot, _map.chaos,
					PLACEMENT_RANDOMNESS * CombatSimulator.UNITS_PER_METRE):
				placed = true
				break
		if not placed:
			enemy.free()

# One enemy of `model`, built as the game builds it when it attacks (BUILDERS), new (NEW_BUILDS) or as a derelict or
# miner; the faction is passed where the Shipyard takes one, since without it createShipByName fails and
# createShipBuildByName leaves it null. The Big Bad Wolf's builder gives nothing once the save's story says it was
# destroyed: then its model's build.
func _buildEnemy(model):
	if BUILDERS.has(model):
		var entry = BUILDERS[model]
		var builder = load(entry.script).new()
		if entry.node != "":
			_copySceneValues(builder, GAME_EVENTS, entry.node)
		for property in entry.set:
			builder.set(property, entry.set[property])
		var made = builder.callv(entry.method, entry.args)
		builder.free()
		var ship = _firstShip(made)
		if ship != null:
			return ship
		var config = Shipyard.getBuildConfigByName(model)
		config.faction = ENEMY_FACTION
		return Shipyard.createShipByConfig(config)
	if model in NEW_BUILDS:
		return Shipyard.createShipByName(model, ENEMY_FACTION, true, 0)
	return Shipyard.createShipBuildByName(model, ENEMY_FACTION)

# A builder gives one ship or an array (PirateCombat.gd: the pirate first); the ship is kept, anything else freed.
func _firstShip(made):
	var items = made if made is Array else [made]
	var ship = null
	for item in items:
		if not item is Node:
			continue
		if ship == null and "faction" in item:
			ship = item
		else:
			item.free()
	return ship

# The values a scene gives its node `nodeName` (the event's exports in story/TheRing.tscn), set on `target`; its script
# stays.
func _copySceneValues(target, scenePath: String, nodeName: String):
	var scene = load(scenePath)
	if not scene is PackedScene:
		return
	var state = scene.get_state()
	for i in state.get_node_count():
		if str(state.get_node_path(i)) != _statePath(nodeName):
			continue
		for p in state.get_node_property_count(i):
			var property = state.get_node_property_name(i, p)
			if property != "script":
				target.set(property, state.get_node_property_value(i, p))

# Every ship entering the arena (enemies, the player's, lifepods, the AI core, drones), before its _ready and after its
# _enter_tree (which resets exitedToEnceladus):
# - the "sim" zone (no fleet, logs or dive bonus: ships/ship-ctrl.gd isRealShip);
# - no conversations: not hailable, no dialog trees (an empty path, the game's default: ship-ctrl.gd passes the path on
#   as a String, getNodeOrPlaceholderOrNull, which null isn't), no talking when docked or held;
# - its removal doesn't run handleExitToEnceladus, which would put what the arm holds into the fleet, cargo into the
#   real ship's cargo and drones' ore into the remote cargo, and add log entries.
# Every node entering with a story flag (the Tsukuyomi's reactors, ships/Reactor.gd explode) has it cleared.
func _onNodeAdded(node):
	if not _running or _viewport == null or not _viewport.is_a_parent_of(node):
		return
	if node is RigidBody2D and "exitedToEnceladus" in node:
		if "zone" in node:
			node.zone = "sim"
		if "hailable" in node:
			node.hailable = false
		for property in ["dialogTree", "farewellDialogTree"]:
			if property in node:
				node.set(property, NodePath())
		for property in ["talkWhenDocksToPlayer", "talkWhenInCargoHold"]:
			if property in node:
				node.set(property, false)
		node.exitedToEnceladus = true
	if "storyFlag" in node:
		node.storyFlag = ""

func _fadeIn():
	visible = true
	_texture.modulate.a = 0.0
	_tween.interpolate_property(_texture, "modulate:a", 0.0, 1.0, FADE_SECONDS)
	_tween.start()
	yield(_tween, "tween_all_completed")
	if _running and not _ending:
		_setStationVisible(false)

# The station's background and menu, hidden behind the arena once it covers them (CanvasHidding.gd setVisibility), as
# the simulator's simulationFullyVisible does.
func _setStationVisible(how: bool):
	for path in STATION_UI:
		var node = _station.get_node_or_null(path)
		if node != null and node.has_method("setVisibility"):
			node.setVisibility(how)

# The mood the field would send from its _process (the western music with chaos), not while paused.
func _process(delta):
	if _running and not _ending and not get_tree().paused and _field != null and is_instance_valid(_field):
		_field.handleMood(delta)

func _input(event):
	if not _running:
		return
	if _confirm.visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			get_tree().set_input_as_handled()
			_confirm.hide()
		return
	if not _ending:
		if event.is_action_pressed("jury_rig_cancel") and CurrentGame.inventoryMode:
			_viewport.input(event)
		elif event.is_action_pressed("pause"):
			confirmEnd()
		else:
			_viewport.input(event)
	get_tree().set_input_as_handled()

# Asks whether to end the run, pausing the game as the dive's pause menu does: the tree paused (the arena, the
# station's time and wages), the Music bus's low-pass filter on. Also what the station's pause menu does during a run
# (PauseMenu.gd).
func confirmEnd():
	if not _running or _ending or _confirm.visible:
		return
	_pause(true)
	_confirm.popup_centered_minsize()
	_confirm.get_ok().grab_focus()

func _pause(pause: bool):
	get_tree().paused = pause
	var bus = AudioServer.get_bus_index(MUSIC_BUS)
	if bus >= 0 and AudioServer.get_bus_effect_count(bus) > 0:
		AudioServer.set_bus_effect_enabled(bus, 0, pause)

func _onConfirmed():
	_confirm.hide()
	end()

func _onConfirmHidden():
	_pause(false)

func _onShipRemoved():
	end()

# Ends the run: by Yes on the confirmation, or by the ship's removal 16 s after it explodes (Tool.remove), as the
# simulator ends. It runs once, however it is reached.
func end():
	if not _running or _ending:
		return
	_ending = true
	if _confirm.visible:
		_confirm.hide()
	if get_tree().paused:
		_pause(false)
	if _ship != null and is_instance_valid(_ship) and _ship.is_connected("removal", self, "_onShipRemoved"):
		_ship.disconnect("removal", self, "_onShipRemoved")
	_setStationVisible(true)
	_tween.interpolate_property(_texture, "modulate:a", _texture.modulate.a, 0.0, FADE_SECONDS)
	_tween.start()
	yield(_tween, "tween_all_completed")
	_cleanup()

# Everything in the viewport goes (Tool.remove, as SimulationLayer.gd endSimulation does), and once it is gone, a
# frame later, the station gets back what the run changed, and the save its tables. CurrentGame.playerShip comes back
# only now: the field's backgrounds and lights read the camera through it (CurrentGame.getCurrentCamera) until then.
func _cleanup():
	_viewport.render_target_update_mode = Viewport.UPDATE_DISABLED
	for child in _viewport.get_children():
		Tool.remove(child)
	_field = null
	_ship = null
	yield(get_tree(), "idle_frame")
	if _realPlayerShip != null:
		CurrentGame.playerShip = _realPlayerShip
		_realPlayerShip = null
	CurrentGame.inventoryMode = _inventoryMode
	CurrentGame.emit_signal("inventoryModeChange", _inventoryMode)
	CurrentGame.targetTimeScale = 1.0
	if _frozePirate:
		Factions.frozenFactions.erase(ENEMY_FACTION)
		_frozePirate = false
	CurrentGame.setGlobalOffset(Vector2(0, 0))
	_restore()
	if _map != null:
		_map.free()
		_map = null
	if get_tree().is_connected("node_added", self, "_onNodeAdded"):
		get_tree().disconnect("node_added", self, "_onNodeAdded")
	CurrentGame.set("_csArena", null)
	visible = false
	_running = false
	_ending = false
	_pauseStation(false)
	_lastFocus = null
