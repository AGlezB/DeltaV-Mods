extends "res://harness/suite.gd"

# CombatSimulator: Shift+Click on the station's simulator button, or Shift plus its key, opens a dialog instead of the
# simulator, and its Start runs a hostile encounter as an overlay at the station.
#
# The station is built in code around the game's enceladus/Enceladus.gd (given its script once in the tree, so neither
# its _ready nor its processing runs, as in the skip suite; the extension's _ready is called as the engine calls it after
# the base's, and its input processing switched on as the engine switches it on): the nodes Enceladus.tscn has that the
# mod reads, by the scene's names. Background and EnceladusMenu with the game's CanvasHidding.gd; the music players; the
# right-hand screens with a Tuning screen and a Fleet screen, each with the simulator's button (run.ps1's
# LaunchVRButton.tscn: the game's button, with its shortcut) and a stand-in of the screen's script, wired to a stand-in
# of the simulator's layer as the scene wires them; the dive target's ring with the game's TheRing.gd and run.ps1's
# stand-in maps; the cursor's layer with the game's MouseLayer.gd; the station's pause menu with the game's PauseLayer.gd;
# NoBulletTime with the game's script. The arena runs on stub ships (ships/CombatTestShip.tscn, harness/combat_ship.gd)
# and a stub asteroid field (harness/combat_field.gd), the TRTL built by a stub of the pirate event; the field, the AI,
# the HUD and the game's own builders don't run. The game's CurrentGame.gd, with the extension, is instanced under the
# suite (as in the transponder suite), and the CurrentGame stub hands it what the mod sets on the autoload. Keys and
# buttons are real input events with the game's bindings, pressed in one idle frame and released in the next, as a
# player's are; clicks go through the scene tree's input. The control checks run on the game's own scripts.

const Parts = preload("res://harness/combat_station.gd")
const SHIP_SCENE = "res://ships/CombatTestShip.tscn"
const SHIP_NAME = "SHIP_TEST_COMBAT" # its shipName (run.ps1)
const MANIFEST = "res://CombatSimulator/Mod.manifest"
const SETTINGS_SCRIPT = "res://CombatSimulator/Settings.gd"
const UI_SCRIPT = "res://CombatSimulator/SettingsUI.gd"
const LAYER_SCRIPT = "res://CombatSimulator/CombatLayer.gd"
const MAP_SCRIPT = "res://CombatSimulator/CombatMap.gd"
const STATION_SCRIPT = "res://enceladus/Enceladus.gd"
const PAUSE_SCRIPT = "res://PauseLayer.gd"
const RING_SCRIPT = "res://TheRing.gd"
const SLOT_SCRIPT = "res://ships/WeaponSlot.gd"
const TURRET_SCRIPT = "res://ships/modules/PDT.gd"
const VIDEO_SCRIPT = "res://hud/Video.gd"
const GRAVIMETRIC_SCRIPT = "res://hud/GravimetricReadout.gd"
const FIELD_SCRIPT = "res://harness/combat_field.gd"
const PIRATE_SCRIPT = "res://story/PirateCombat.gd"
const RING_SCENE = "res://Game.tscn"
const MUSIC_BUS = "Music"
# The suite's ship models, in Shipyard.ships order: the game's keys, each with the suite's ship scene but OBONTO (the
# habitat, whose scene isn't under ships/); TRTL-R, a variant of TRTL, comes after another series.
const MODELS = ["TRTL", "PROSPECTOR", "TRTL-R", "ATLAS", "OBONTO", "MADCERF", "DRONE"]
const ALIASES = {"TRTL-R": "TRTL"}
const OFFERED = ["TRTL", "TRTL-R", "PROSPECTOR", "ATLAS", "MADCERF", "DRONE"]
# The models the game leaves without a name and a description of their own (their scenes keep ship-ctrl.gd's shipName),
# which the mod's texts name.
const UNNAMED = ["MADCERF", "TSUKUYOMI", "HYBRID", "ATLAS", "DRONE"]
const TOOLTIP_DE = "%s+Klick: %s"

var settings = null
var cg = null # the game's CurrentGame.gd (with the extension), in the tree
var changes = 0 # settingsChanged signals counted
var inventorySignals = [] # what inventoryModeChange was emitted with
var S = {} # the mod's SETTINGS
# Scripts whose metadata the suite sets or reads, held so they stay loaded (a script nothing references is freed, and
# loaded again without its metadata).
var pirateScript = null
var fieldScript = null

func _countChange():
	changes += 1

func _inventoryChanged(how):
	inventorySignals.append(how)

func manifestValue(section, key):
	var manifest = ConfigFile.new()
	manifest.load(MANIFEST)
	return manifest.get_value(section, key)

func modId() -> String:
	return manifestValue("mod_information", "id")

# What a screen's simulator flies: a model, a transponder and a config with tanks to fill.
func sim(model, transponder) -> Dictionary:
	return {"model": model, "transponder": transponder, "faction": "player", "config": {"fuel": {"capacity": 20000.0, "initial": 2000.0}, "ammo": {"capacity": 100.0, "initial": 3.0}}}

# ---- Input ----

func key(code, shift = false):
	var event = InputEventKey.new()
	event.scancode = code
	event.shift = shift
	return event

func escKey():
	return key(KEY_ESCAPE)

func joyButton(index):
	var event = InputEventJoypadButton.new()
	event.button_index = index
	return event

func joyAxis(axis, value):
	var event = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event

# The game's bindings (its project.godot): jury_rig is J and button 10 (Back); jury_rig_cancel is Esc; pause is Esc and
# Start; ui_cancel is Esc, B (button 1) and Start; ui_page_up and ui_page_down are LB and RB (buttons 4 and 5) too;
# ui_scroll_up2 and ui_scroll_down2 are the right stick's vertical axis, with a dead zone of 0.1.
func bindGameKeys():
	var bindings = [["jury_rig", key(KEY_J)], ["jury_rig", joyButton(JOY_SELECT)], ["jury_rig_cancel", escKey()],
		["pause", escKey()], ["pause", joyButton(JOY_START)], ["ui_cancel", escKey()], ["ui_cancel", joyButton(JOY_BUTTON_1)],
		["ui_cancel", joyButton(JOY_START)], ["ui_page_up", joyButton(JOY_L)], ["ui_page_down", joyButton(JOY_R)],
		["ui_scroll_up2", joyAxis(JOY_AXIS_3, -1.0)], ["ui_scroll_down2", joyAxis(JOY_AXIS_3, 1.0)]]
	for binding in bindings:
		if not InputMap.has_action(binding[0]):
			InputMap.add_action(binding[0], 0.1 if binding[0].begins_with("ui_scroll") else 0.5)
		if not InputMap.action_has_event(binding[0], binding[1]):
			InputMap.action_add_event(binding[0], binding[1])

# A gamepad button pressed, or released, and left so, as Input delivers it (Input.is_joy_button_pressed follows).
func holdJoy(index, pressed):
	yield(get_tree(), "idle_frame")
	var event = joyButton(index)
	event.pressed = pressed
	Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")

# A stick's axis moved to `value` and left there, as Input delivers it (the actions' strength follows).
func holdAxis(axis, value):
	yield(get_tree(), "idle_frame")
	Input.parse_input_event(joyAxis(axis, value))
	yield(get_tree(), "idle_frame")

# A press in one idle frame and the release in the next, as Input delivers a player's.
func tap(event):
	for pressed in [true, false]:
		yield(get_tree(), "idle_frame")
		var e = event.duplicate()
		e.pressed = pressed
		Input.parse_input_event(e)
	yield(get_tree(), "idle_frame")

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

# ---- The station ----

# The station built as enceladus/Enceladus.tscn nests what the mod reads, with `script` (the game's Enceladus.gd: with
# the mod, its extension) given once the station is in the tree. With the mod, the extension's _ready runs and its input
# processing is on, as the engine would have them.
func station(script, mod) -> Dictionary:
	var root = Node2D.new()
	root.name = "Enceladus"
	var background = CanvasLayer.new()
	background.name = "Background"
	background.set_script(load("res://enceladus/CanvasHidding.gd"))
	root.add_child(background)
	var players = []
	for playerName in ["Intro", "Loop"]:
		var player = AudioStreamPlayer.new()
		player.name = playerName
		player.pause_mode = Node.PAUSE_MODE_PROCESS
		root.add_child(player)
		players.append(player)
	var menu = CanvasLayer.new()
	menu.name = "EnceladusMenu"
	menu.layer = 8
	menu.set_script(load("res://enceladus/CanvasHidding.gd"))
	root.add_child(menu)
	var menuContainer = MarginContainer.new()
	menuContainer.name = "MenuContainer"
	menu.add_child(menuContainer)
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	menuContainer.add_child(margin)
	var canvas = CanvasLayer.new()
	canvas.name = "CanvasLayer"
	margin.add_child(canvas)
	var screens = MarginContainer.new()
	screens.name = "MarginContainer"
	screens.anchor_right = 1.0
	screens.anchor_bottom = 1.0
	screens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(screens)
	# Tuning: the button where Tuning.tscn has it, the description window's frame to copy, previewedConfig.
	var tuning = Parts.Tuning.new()
	tuning.name = "Tuning"
	tuning.theme = Theme.new()
	tuning.add_stylebox_override("panel", StyleBoxFlat.new())
	tuning.rect_min_size = Vector2(600, 400)
	tuning.size_flags_horizontal = Control.SIZE_SHRINK_END
	tuning.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tuning.previewedConfig = sim("TRTL", "OWN-1")
	var vb = VBoxContainer.new()
	vb.name = "VB"
	tuning.add_child(vb)
	var windowMargin = MarginContainer.new()
	windowMargin.name = "WindowMargin"
	windowMargin.theme = Theme.new()
	vb.add_child(windowMargin)
	var window = PanelContainer.new()
	window.name = "Window"
	window.add_stylebox_override("panel", StyleBoxFlat.new())
	windowMargin.add_child(window)
	var windowVb = VBoxContainer.new()
	windowVb.name = "VBoxContainer"
	window.add_child(windowVb)
	var inside = MarginContainer.new()
	inside.name = "MarginContainer"
	windowVb.add_child(inside)
	var sides = ["left", "top", "right", "bottom"]
	for i in sides.size():
		windowMargin.add_constant_override("margin_" + sides[i], 11 + i)
		inside.add_constant_override("margin_" + sides[i], 5 + i)
	var vrMargin = MarginContainer.new()
	vrMargin.name = "MarginContainer2"
	windowVb.add_child(vrMargin)
	var vr = load("res://enceladus/Simulator/LaunchVRButton.tscn").instance()
	vrMargin.add_child(vr)
	vr.connect("pressed", tuning, "_on_LaunchVR_pressed")
	screens.add_child(tuning)
	# Fleet: hidden, its button in an Examine tab, currentConfig.
	var fleet = Parts.Dealer.new()
	fleet.name = "Owned"
	fleet.visible = false
	fleet.rect_min_size = Vector2(500, 300)
	fleet.currentConfig = sim("PROSPECTOR", "OWN-2")
	var examine = VBoxContainer.new()
	examine.name = "Examine"
	fleet.add_child(examine)
	var fleetVr = load("res://enceladus/Simulator/LaunchVRButton.tscn").instance()
	examine.add_child(fleetVr)
	fleetVr.connect("pressed", fleet, "_on_LaunchVR_pressed")
	screens.add_child(fleet)
	var diveTarget = Control.new()
	diveTarget.name = "DiveTarget"
	diveTarget.visible = false
	menu.add_child(diveTarget)
	var ring = Node.new()
	ring.name = "TheRing"
	ring.set_script(load(RING_SCRIPT))
	diveTarget.add_child(ring)
	var simulation = Parts.Simulation.new()
	simulation.name = "SimulationLayer"
	simulation.layer = 9
	simulation.visible = false
	var upscale = MarginContainer.new()
	upscale.name = "MarginContainer"
	upscale.set_script(load("res://enceladus/MarginViewportUpscale.gd"))
	upscale.scale = 1.0
	simulation.add_child(upscale)
	root.add_child(simulation)
	for screen in [tuning, fleet]:
		screen.connect("simulateShipConfig", simulation, "startSimulation")
	var mouseLayer = CanvasLayer.new()
	mouseLayer.name = "MouseLayer"
	mouseLayer.layer = 10
	mouseLayer.set_script(load("res://menu/MouseLayer.gd"))
	var mouse = Parts.Mouse.new()
	mouse.name = "Mouse"
	mouseLayer.add_child(mouse)
	root.add_child(mouseLayer)
	var pause = pauseMenu()
	root.add_child(pause)
	var noBulletTime = Node.new()
	noBulletTime.name = "NoBulletTime"
	noBulletTime.set_script(load("res://enceladus/NoBulletTime.gd"))
	root.add_child(noBulletTime)
	add_child(root)
	root.set_script(script)
	if mod:
		root.menusContainer = screens
		root._ready()
		root.set_process_input(true)
	return {"root": root, "background": background, "menu": menu, "players": players, "screens": screens, "tuning": tuning,
		"vr": vr, "fleet": fleet, "fleetVr": fleetVr, "ring": ring, "simulation": simulation, "upscale": upscale,
		"mouse": mouse, "pause": pause, "noBulletTime": noBulletTime}

# The station's pause menu (enceladus/PauseLayerEnceladus.tscn): the game's PauseLayer.gd (with the mod, its extension)
# with the nodes it reaches and the scene's pause mode, given before it enters the tree so its _ready runs.
func pauseMenu():
	var pause = CanvasLayer.new()
	pause.name = "PauseMenuEnceladus"
	pause.pause_mode = Node.PAUSE_MODE_PROCESS
	pause.layer = 10
	var mouseLayer = CanvasLayer.new()
	mouseLayer.name = "MouseLayer"
	mouseLayer.set_script(load("res://menu/MouseLayer.gd"))
	pause.add_child(mouseLayer)
	var mouse = Parts.Mouse.new()
	mouse.name = "Mouse"
	mouseLayer.add_child(mouse)
	var container = Container.new()
	container.name = "PauseContainer"
	container.visible = false
	pause.add_child(container)
	var noMargins = MarginContainer.new()
	noMargins.name = "NoMargins"
	container.add_child(noMargins)
	var popup = Popup.new()
	popup.name = "SettingsPopup"
	noMargins.add_child(popup)
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	container.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	margin.add_child(vbox)
	var resume = Button.new()
	resume.name = "Resume"
	vbox.add_child(resume)
	pause.set_script(load(PAUSE_SCRIPT))
	return pause

func freeStation(s):
	s.root.queue_free()
	yield(frames(3), "completed")

func pauseShown(s) -> bool:
	return s.pause.get_node("PauseContainer").visible

func musicFilter() -> bool:
	var bus = AudioServer.get_bus_index(MUSIC_BUS)
	return bus >= 0 and AudioServer.get_bus_effect_count(bus) > 0 and AudioServer.is_bus_effect_enabled(bus, 0)

func registerModels():
	var scene = load(SHIP_SCENE)
	var habitat = PackedScene.new()
	var node = RigidBody2D.new()
	habitat.pack(node)
	node.free()
	for m in MODELS:
		Shipyard.ships[m] = habitat if m == "OBONTO" else scene
	Shipyard.configAlias = ALIASES.duplicate()

# ---- The suite ----

func run():
	var mod = hasMod("CombatSimulator")
	bindGameKeys()
	Input.set_use_accumulated_input(false)
	registerModels()
	pirateScript = load(PIRATE_SCRIPT)
	fieldScript = load(FIELD_SCRIPT)
	if not mod:
		yield(controls(), "completed")
		return
	var ext = load("res://CurrentGame.gd")
	cg = ext.new()
	cg.name = "CombatGame"
	add_child(cg)
	check("res://CurrentGame.gd has the extension", ext.get_base_script() != null and "_csArena" in cg)
	CurrentGame.game = cg
	settings = load(SETTINGS_SCRIPT).shared()
	S = load(SETTINGS_SCRIPT).SETTINGS
	settings.connect("settingsChanged", self, "_countChange")
	CurrentGame.connect("inventoryModeChange", self, "_inventoryChanged")
	model()
	texts()
	yield(huds(true), "completed")
	weapons(true)
	var s = station(load(STATION_SCRIPT), true)
	yield(frames(3), "completed")
	mapChecks(s)
	yield(dialog(s), "completed")
	yield(screenChecks(s), "completed")
	yield(runOne(s), "completed")
	yield(runTwo(s), "completed")
	yield(freeStation(s), "completed")
	CurrentGame.game = null
	cg.queue_free()
	get_tree().paused = false
	Engine.time_scale = 1.0

# The control checks, on the game's own scripts: the simulator's button starts the simulator on a click, Shift held or
# not, and on its key alone; the ring map and the gravimetric readout hide outside the rings; a hardpoint and a turret
# fire with the power given; the station's pause menu pauses.
func controls():
	var s = station(load(STATION_SCRIPT), false)
	yield(frames(3), "completed")
	click(s.vr, false)
	yield(frames(2), "completed")
	check("control: a click on the simulator's button starts the simulator", s.simulation.started.size() == 1, s.simulation.started.size())
	click(s.vr, true)
	yield(frames(2), "completed")
	check("control: Shift+Click starts it too", s.simulation.started.size() == 2, s.simulation.started.size())
	yield(tap(key(KEY_J, true)), "completed")
	check("control: Shift+J starts nothing (a button's shortcut matches its key exactly), and J does", s.simulation.started.size() == 2, s.simulation.started.size())
	yield(tap(key(KEY_J)), "completed")
	check("control: J fires the button's shortcut, starting it", s.simulation.started.size() == 3, s.simulation.started.size())
	# The gamepad twins (the mod's Badge.gd, not loaded here: LT, and X): a gamepad's buttons carry no modifiers, so
	# LT+Back is Back, the shortcut's button, and LT+X is nothing.
	s.vr.grab_focus()
	yield(holdJoy(JOY_L2, true), "completed")
	yield(tap(joyButton(JOY_XBOX_X)), "completed")
	var afterX = s.simulation.started.size()
	yield(tap(joyButton(JOY_SELECT)), "completed")
	yield(holdJoy(JOY_L2, false), "completed")
	check("control: LT+X on the highlighted button does nothing, and LT+Back starts it", afterX == 3 and s.simulation.started.size() == 4, [afterX, s.simulation.started.size()])
	s.pause.pauseGame(true)
	check("control: the station's pause menu pauses the game and shows itself", get_tree().paused and pauseShown(s))
	s.pause.pauseGame(false)
	yield(freeStation(s), "completed")
	yield(huds(false), "completed")
	weapons(false)

# ---- The settings ----

func model():
	var script = load(SETTINGS_SCRIPT)
	var id = modId()
	check("settings: one shared instance", script.shared() == settings)
	check("settings: the models offered are those with a scene under ships/ (not the habitat), each series together, in the game's order", settings.models() == OFFERED, settings.models())
	check("settings: a model's name is its scene's shipName, or the mod's own text for one the game leaves unnamed; its description that name and DESCRIPTION_SUFFIX", settings.modelName("TRTL") == SHIP_NAME and settings.modelName("MADCERF") == script.MODEL_NAME_PREFIX + "MADCERF" and settings.modelDescription("TRTL") == SHIP_NAME + script.DESCRIPTION_SUFFIX, [settings.modelName("TRTL"), settings.modelName("MADCERF")])
	CurrentGame.state.ui.erase(id)
	settings.loadFromState()
	var defaults = true
	for k in S:
		defaults = defaults and same(settings.getValue(k), S[k].default)
	check("settings: a save without the mod's entry gets the defaults", defaults and not CurrentGame.state.ui.has(id))
	changes = 0
	for k in S:
		settings.setValue(k, S[k].default)
	check("settings: setting the values they have stores and signals nothing", changes == 0 and not CurrentGame.state.ui.has(id), changes)
	# Sliders: above the range, below it, between two steps.
	var clamped = []
	for k in S:
		if S[k].type != "float":
			continue
		var step = S[k].step
		for case in [[S[k].max + 10 * step, S[k].max], [S[k].min - 10 * step, S[k].min], [S[k].min + 1.3 * step, S[k].min + step]]:
			settings.setValue(k, case[0])
			if not is_equal_approx(settings.getValue(k), case[1]):
				clamped.append([k, case[0], settings.getValue(k)])
	check("settings: a slider's value is kept in its range and snapped to its step", clamped.empty(), clamped)
	changes = 0
	settings.setValue("number", S.number.max)
	var entry = CurrentGame.state.ui.get(id, {})
	var stored = entry is Dictionary and entry.get("formatVersion") == script.FORMAT_VERSION and entry.get("modVersion") == "%d.%d.%d" % [manifestValue("version", "version_major"), manifestValue("version", "version_minor"), manifestValue("version", "version_bugfix")]
	for k in S:
		stored = stored and entry is Dictionary and same(entry.get(k), settings.getValue(k))
	check("settings: a change is stored in state.ui under the manifest's id, with the format and mod versions and every setting, and signalled once", stored and changes == 1, [entry, changes])
	settings.setValue("ship", "OBONTO")
	var notOffered = settings.getValue("ship") == S.ship.default
	settings.setValue("ship", "ATLAS")
	var offered = settings.getValue("ship") == "ATLAS"
	settings.setValue("ship", 3)
	check("settings: the ship is one of the models offered (a model not offered, or not a model, gives the default)", notOffered and offered and settings.getValue("ship") == S.ship.default)
	settings.setValue("grouped", not S.grouped.default)
	var switched = settings.getValue("grouped") == (not S.grouped.default)
	settings.setValue("grouped", "no")
	check("settings: a switch takes a bool, anything else gives its default", switched and settings.getValue("grouped") == S.grouped.default)
	# A save's JSON round trip: numbers come back as floats.
	settings.setValue("ship", "PROSPECTOR")
	settings.setValue("distance", S.distance.min + S.distance.step)
	settings.setValue("chaos", S.chaos.max)
	settings.setValue("disabledWeapons", not S.disabledWeapons.default)
	var before = settings.cfg.duplicate()
	var saved = JSON.parse(JSON.print(CurrentGame.state.ui)).result
	CurrentGame.state.ui = {}
	settings.loadFromState()
	var reset = settings.getValue("ship") == S.ship.default
	CurrentGame.state.ui = saved
	settings.loadFromState()
	check("settings: after a JSON round trip of the save, they load back", reset and same(settings.cfg, before), [settings.cfg, before])
	CurrentGame.state.ui[id] = {"number": "three", "distance": 1e9, "grouped": "yes", "ship": "NOPE", "chaos": null, "density": -5, "remass": [1]}
	settings.loadFromState()
	var edited = same(settings.getValue("number"), S.number.default) and same(settings.getValue("distance"), S.distance.max) and settings.getValue("grouped") == S.grouped.default and settings.getValue("ship") == S.ship.default and same(settings.getValue("chaos"), S.chaos.default) and same(settings.getValue("density"), S.density.min) and same(settings.getValue("remass"), S.remass.default)
	CurrentGame.state.ui[id] = 7
	settings.loadFromState()
	defaults = true
	for k in S:
		defaults = defaults and same(settings.getValue(k), S[k].default)
	check("settings: a hand-edited entry loads safely: wrong types give the defaults, numbers are clamped; an entry that isn't one gives the defaults", edited and defaults)
	CurrentGame.state.ui.erase(id)
	settings.loadFromState()

func texts():
	var script = load(SETTINGS_SCRIPT)
	var ui = load(UI_SCRIPT).get_script_constant_map()
	var keys = [load(STATION_SCRIPT).get_script_constant_map()._CS_TOOLTIP, ui.TITLE, ui.START, ui.CANCEL]
	for g in ui.GROUPS:
		keys.append(g[1])
	for k in S:
		keys += [S[k].label, S[k].label + script.DESCRIPTION_SUFFIX]
	for m in UNNAMED:
		keys += [script.MODEL_NAME_PREFIX + m, script.MODEL_NAME_PREFIX + m + script.DESCRIPTION_SUFFIX]
	var missing = []
	for k in keys:
		if tr(k) == k:
			missing.append(k)
	check("texts: i18n/en.po has the tooltip, the dialog's title, groups and buttons, every setting's name and description, and the unnamed models' names and descriptions", missing.empty(), missing)
	check("texts: the tooltip takes the Shift key and the mod's name", tr(keys[0]).count("%s") == 2, tr(keys[0]))

# ---- The HUD and the weapons ----

# The ring map (the game's hud/Video.gd) and the gravimetric readout (hud/GravimetricReadout.gd) under a HUD stand-in on
# ships: the arena's (marked, outside the rings), another ship outside the rings, a ship in the rings, and the arena's
# without the scanner.
func huds(mod):
	var cases = [["sim", true, true], ["sim", false, true], ["rings", false, true], ["sim", true, false]]
	var made = []
	for case in cases:
		var ship = load(SHIP_SCENE).instance()
		ship.zone = case[0]
		if case[1] and mod:
			ship.set_meta(load(SETTINGS_SCRIPT).SHIP_META, true)
		var hud = Parts.Hud.new()
		ship.add_child(hud)
		var video = Node2D.new()
		video.set_script(load(VIDEO_SCRIPT))
		var offset = Node2D.new()
		offset.name = "Offset"
		video.add_child(offset)
		hud.add_child(video)
		var readout = Sprite.new()
		readout.material = ShaderMaterial.new()
		readout.set_script(load(GRAVIMETRIC_SCRIPT))
		ship.shipConfig = {}
		if case[2]:
			var path = readout.slot.split(".")
			ship.shipConfig = {path[0]: {path[1]: readout.system}}
		hud.add_child(readout)
		add_child(ship)
		made.append([ship, video, readout])
	yield(frames(3), "completed")
	if mod:
		check("HUD: the ring map shows on the arena's ship, outside the rings", made[0][1].visible)
		check("HUD: the gravimetric readout shows on the arena's ship, outside the rings", made[0][2].visible)
		check("HUD: on another ship outside the rings both stay hidden, as the game hides them", not made[1][1].visible and not made[1][2].visible)
		check("HUD: in the rings both show, as the game shows them", made[2][1].visible and made[2][2].visible)
		check("HUD: on the arena's ship without the scanner the readout stays hidden (it doesn't run)", not made[3][2].visible and made[3][1].visible)
	else:
		check("control: the ring map and the gravimetric readout hide outside the rings and show in them", not made[0][1].visible and not made[0][2].visible and made[2][1].visible and made[2][2].visible)
	for m in made:
		m[0].free()

# A hardpoint (the game's ships/WeaponSlot.gd) and a turret (ships/modules/PDT.gd) on a ship, each holding a weapon
# that records the power it gets: one ship the arena disarmed, one it didn't.
func fireThrough(ship) -> Dictionary:
	var slot = Node2D.new()
	slot.set_script(load(SLOT_SCRIPT))
	var weapon = Parts.Weapon.new()
	slot.ship = ship
	slot.system = weapon
	slot.fire(1.0)
	var turret = Node2D.new()
	turret.set_script(load(TURRET_SCRIPT))
	var turretWeapon = Parts.Weapon.new()
	turret.ship = ship
	turret.system = turretWeapon
	turret.esp = false
	turret.perhapsFire(1.0)
	turret.fire(1.0)
	var out = {"slot": weapon.fired, "slotEnabled": slot.enabled, "turret": turretWeapon.fired, "firepower": turret.firepower, "turretEnabled": turret.enabled}
	for n in [slot, weapon, turret, turretWeapon]:
		n.free()
	return out

func weapons(mod):
	var ship = load(SHIP_SCENE).instance()
	if mod:
		ship.set_meta(load(SETTINGS_SCRIPT).DISARMED_META, true)
	var disarmed = fireThrough(ship)
	ship.free()
	ship = load(SHIP_SCENE).instance()
	var armed = fireThrough(ship)
	ship.free()
	if mod:
		check("disabled weapons: on a disarmed ship a hardpoint passes 0 to its weapon, its switch still on", same(disarmed.slot, [0]) and disarmed.slotEnabled, disarmed)
		check("disabled weapons: on a disarmed ship a turret fires its weapon with 0 and keeps 0 as its power, its switch still on", same(disarmed.turret, [0]) and disarmed.firepower == 0 and disarmed.turretEnabled, disarmed)
		check("disabled weapons: another ship's hardpoint and turret fire as the game's do", same(armed.slot, [1.0]) and same(armed.turret, [1.0]) and armed.firepower == 1.0, armed)
	else:
		check("control: a hardpoint and a turret fire their weapon with the power given", same(armed.slot, [1.0]) and same(armed.turret, [1.0]) and armed.firepower == 1.0, armed)

# ---- The map ----

func mapChecks(s):
	var ring = s.ring
	check("map: the station's ring (the game's TheRing.gd) has the stand-in map", ring.image != null and ring.size.x > 0)
	var map = load(MAP_SCRIPT).new()
	map.shareImagesOf(ring)
	map.chaos = 0.3
	map.density = 0.6
	# A pixel's corner, where the game's interpolation gives that pixel exactly.
	var pos = Vector2(20, 11) * ring.pixelToKm
	var px = map.getPixelAt(pos)
	var ringPx = ring.getPixelAt(pos)
	check("map: a pixel's chaos (red) and density (blue) are the dialog's, its size bias (green) the ring's", is_equal_approx(px.r, map.chaos) and is_equal_approx(px.b, map.density) and px.g == ringPx.g and not is_equal_approx(ringPx.r, px.r), [px, ringPx])
	check("map: the game's getChaosAt and getRawDensityAt read them", is_equal_approx(map.getChaosAt(pos), map.chaos) and is_equal_approx(map.getRawDensityAt(pos), map.density))
	# The game's TheRing.gd on a ring that is that pixel everywhere (stored as floats, not rounded to bytes).
	var reference = Node.new()
	reference.set_script(load(RING_SCRIPT))
	add_child(reference)
	var uniform = Image.new()
	uniform.create(4, 4, false, Image.FORMAT_RGBAF)
	uniform.fill(Color(map.chaos, ringPx.g, map.density, ringPx.a))
	reference.image = uniform
	reference.size = uniform.get_size()
	var expected = reference.getTargetDensityAt(Vector2(2, 2) * reference.pixelToKm)
	check("map: the density there is the game's (TheRing.gd getTargetDensityAt) for that chaos, density and size bias", same(map.getTargetDensityAt(pos), expected) and not same(expected, [0, 0, 0, 0, 0]), [map.getTargetDensityAt(pos), expected])
	reference.free()
	check("map: no random events or extra ships: no oddity, no event allowed", map.getOddityAt(pos) == null and not map.canEventBeAt("PirateCombat", pos))
	check("map: without a field, no ships counted", map.howManyShips() == 0)
	# pickSpot: the sampling again, with the same seed.
	var c = load(LAYER_SCRIPT).get_script_constant_map()
	seed(4242)
	var spot = map.pickSpot(c.SPOT_SAMPLES, c.SPOT_EDGE_MARGIN)
	seed(4242)
	var image = ring.image
	var width = int(ring.size.x)
	var height = int(ring.size.y)
	var best = null
	var bestDistance = INF
	image.lock()
	for i in c.SPOT_SAMPLES:
		var x = c.SPOT_EDGE_MARGIN + randi() % (width - 2 * c.SPOT_EDGE_MARGIN)
		var y = randi() % height
		var pixel = image.get_pixel(x, y)
		var distance = Vector2(pixel.r - map.chaos, pixel.b - map.density).length()
		if distance < bestDistance:
			bestDistance = distance
			best = Vector2(x + 0.5, y + 0.5)
	image.unlock()
	check("map: the spot is the closest, by chaos and density, of its SPOT_SAMPLES random pixels SPOT_EDGE_MARGIN or more from the edges, at the pixel's centre", best != null and spot == best * ring.pixelToKm, [spot, best])
	randomize()
	map.free()

# ---- The dialog ----

func dialog(s):
	yield(frames(1), "completed")
	var root = s.root
	var layer = root._csLayer
	var ui = root._csDialog
	var tooltips = root._csTooltips
	check("station: the arena's layer comes right after the simulator's, on its layer; the dialog's layer is the station's last child", layer.get_index() == s.simulation.get_index() + 1 and layer.layer == s.simulation.layer and ui.get_index() == root.get_child_count() - 1)
	check("station: both simulator buttons are found by their scene", root._csButtons.size() == 2 and s.vr in root._csButtons and s.fleetVr in root._csButtons)
	# The tooltip, on each button's Shift badge (Badge.gd), shown by the game's tooltip node.
	var tip = tr(root._CS_TOOLTIP) % [OS.get_scancode_string(KEY_SHIFT), settings.modName()]
	var badge = s.vr.get_node_or_null(root._CS_SHIFT_BADGE)
	check("tooltip: the game's tooltip node is on the dialog's layer; the button's Shift badge has the tooltip, which tells about Shift+Click, and the button none", tooltips != null and tooltips.get_parent() == ui and badge != null and badgeTip(tooltips, badge) == tip and tooltips.tooltips.get(s.vr, "") == "", badgeTip(tooltips, badge) if tooltips != null and badge != null else null)
	if tooltips == null or badge == null:
		return
	tooltips.showTooltip(badge)
	yield(frames(1), "completed")
	check("tooltip: shown, it is the badge's", tooltips.tooltipLabel.text == tip and tooltips.tooltipPosition.visible, tooltips.tooltipLabel.text)
	tooltips.hideTooltip(badge)
	check("tooltip: a hidden button has none yet", tooltips.tooltips.get(s.fleetVr) == "")
	s.fleet.show()
	yield(frames(1), "completed")
	check("tooltip: once it shows, its badge has it", badgeTip(tooltips, s.fleetVr.get_node(root._CS_SHIFT_BADGE)) == tip, badgeTip(tooltips, s.fleetVr.get_node(root._CS_SHIFT_BADGE)))
	s.fleet.hide()
	InputMap.action_erase_events("jury_rig")
	InputMap.action_add_event("jury_rig", key(KEY_K))
	s.tuning.hide()
	s.tuning.show()
	yield(frames(1), "completed")
	check("tooltip: with the simulator's key rebound it stays the same, naming only Shift", badgeTip(tooltips, badge) == tip, badgeTip(tooltips, badge))
	InputMap.action_erase_events("jury_rig")
	bindGameKeys()
	var de = Translation.new()
	de.locale = "de"
	de.add_message(root._CS_TOOLTIP, TOOLTIP_DE)
	TranslationServer.add_translation(de)
	TranslationServer.set_locale("de")
	yield(frames(1), "completed")
	check("tooltip: it follows a language change", badgeTip(tooltips, badge) == TOOLTIP_DE % [OS.get_scancode_string(KEY_SHIFT), settings.modName()], badgeTip(tooltips, badge))
	TranslationServer.set_locale("en")
	yield(frames(1), "completed")
	# Opening and closing.
	var started = s.simulation.started
	click(s.vr, false)
	yield(frames(2), "completed")
	check("open: a plain click on the button starts the simulator with the screen's config, and opens no dialog", started.size() == 1 and started[0] == s.tuning.previewedConfig and not ui.isOpen(), started.size())
	yield(tap(key(KEY_J)), "completed")
	check("open: a plain J still fires the button's shortcut, starting the simulator", started.size() == 2 and not ui.isOpen(), started.size())
	click(s.vr, true)
	yield(frames(2), "completed")
	check("open: Shift+Click opens the dialog and doesn't start the simulator", ui.isOpen() and started.size() == 2 and root._csSim == s.tuning.previewedConfig, started.size())
	var popup = ui._popup
	var area = s.tuning.get_global_rect()
	var needed = ui._root.get_combined_minimum_size()
	check("open: it pops up over the screen, as big as the screen or as its parts need", popup.rect_global_position.is_equal_approx(area.position) and popup.rect_size.x >= max(area.size.x, needed.x) - 1 and popup.rect_size.y >= max(area.size.y, needed.y) - 1, [popup.get_global_rect(), area, needed])
	yield(tap(key(KEY_J)), "completed")
	yield(tap(key(KEY_J, true)), "completed")
	check("open: J or Shift+J with the dialog open start nothing (the dialog is modal)", ui.isOpen() and started.size() == 2, started.size())
	yield(tap(escKey()), "completed")
	yield(frames(2), "completed")
	check("close: Esc closes the dialog, the screen stays open, the station's pause menu doesn't open", not ui.isOpen() and s.tuning.visible and not get_tree().paused and not pauseShown(s))
	check("close: the focus is back on the button", s.vr.get_focus_owner() == s.vr, s.vr.get_focus_owner())
	yield(tap(key(KEY_J, true)), "completed")
	check("open: Shift+J opens the dialog and doesn't start the simulator", ui.isOpen() and started.size() == 2, started.size())
	tabButton(ui, 1, "Cancel").emit_signal("pressed")
	yield(frames(2), "completed")
	check("close: Cancel closes it, the screen stays open, the focus back on the button", not ui.isOpen() and s.tuning.visible and s.vr.get_focus_owner() == s.vr)
	yield(tap(key(KEY_J, true)), "completed")
	yield(tap(joyButton(JOY_START)), "completed")
	yield(frames(2), "completed")
	check("close: the controller's Start (pause) closes it too, and pauses nothing", not ui.isOpen() and s.tuning.visible and not get_tree().paused and not pauseShown(s))
	s.vr.disabled = true
	click(s.vr, true)
	yield(tap(key(KEY_J, true)), "completed")
	check("open: with the button disabled, neither Shift+Click nor Shift+J opens it", not ui.isOpen() and started.size() == 2)
	s.vr.disabled = false
	s.simulation.visible = true
	yield(tap(key(KEY_J, true)), "completed")
	check("open: Shift+J does nothing while the simulator shows", not ui.isOpen())
	s.simulation.visible = false
	s.tuning.hide()
	s.fleet.show()
	yield(tap(key(KEY_J, true)), "completed")
	check("open: from the Fleet screen it takes the ship that screen's simulator flies (currentConfig)", ui.isOpen() and root._csSim == s.fleet.currentConfig)
	yield(tap(escKey()), "completed")
	s.fleet.hide()
	s.tuning.show()
	yield(frames(2), "completed")
	yield(gamepad(s), "completed")

# With a gamepad: the Shift badge reads the gamepad twin while the game is played with one; X pressed on the highlighted
# button while LT is held opens the dialog, as Shift+Click does, and Back (the simulator's button) while LT is held, as
# Shift+J does. In the dialog, the right stick scrolls the description, and the shoulder buttons switch only its tabs.
func gamepad(s):
	var root = s.root
	var ui = root._csDialog
	var started = s.simulation.started
	var count = started.size()
	var shiftBadge = s.vr.get_node(root._CS_SHIFT_BADGE)
	var padModifier = shiftBadge.PAD_MODIFIER
	var padButton = shiftBadge.PAD_BUTTON
	var keyText = OS.get_scancode_string(KEY_SHIFT)
	var keyRead = shiftBadge._label.text
	Settings.controlScheme = Settings.control.gamepad
	var padRead = shiftBadge._label.text
	var padTip = shiftBadge.hint_tooltip
	Settings.controlScheme = Settings.control.keyMouse
	var keyTip = shiftBadge.hint_tooltip
	check("gamepad: the Shift badge reads Shift with keyboard and mouse, the gamepad twin with a gamepad, and Shift again", keyRead == keyText and padRead == shiftBadge.PAD_TEXT and shiftBadge._label.text == keyText, [keyRead, padRead, shiftBadge._label.text])
	var padExpected = tr(root._CS_TOOLTIP_PAD) % [shiftBadge.PAD_BUTTON_NAME, shiftBadge.PAD_MODIFIER_NAME, settings.modName()]
	check("gamepad: its tooltip tells about the gamepad twin with a gamepad, and about Shift+Click again with keyboard and mouse", padTip == padExpected and keyTip == tr(root._CS_TOOLTIP) % [keyText, settings.modName()] and tr(root._CS_TOOLTIP_PAD) != root._CS_TOOLTIP_PAD, [padTip, keyTip])
	Settings.controlScheme = Settings.control.gamepad
	# A screen whose tabs use the game's tab script, as the Dealer's and the Equipment screen's do. With the dialog
	# closed, the shoulder buttons are the screen's.
	var behind = TabContainer.new()
	behind.set_script(load("res://menu/TabsWithGamepadControl.gd"))
	for tabName in ["First", "Second"]:
		var page = Control.new()
		page.name = tabName
		behind.add_child(page)
	s.tuning.add_child(behind)
	yield(frames(1), "completed")
	yield(tap(joyButton(JOY_R)), "completed")
	check("gamepad: with the dialog closed, RB switches the screen's own tabs", behind.current_tab == 1 and not ui.isOpen(), [behind.current_tab, ui._tabs.current_tab])
	behind.current_tab = 0
	s.vr.grab_focus()
	yield(tap(joyButton(padButton)), "completed")
	check("gamepad: X alone on the highlighted button does nothing", not ui.isOpen() and started.size() == count, started.size())
	yield(tap(joyButton(JOY_SELECT)), "completed")
	count += 1
	check("gamepad: Back alone still fires the button's shortcut, starting the simulator", not ui.isOpen() and started.size() == count, started.size())
	yield(holdJoy(padModifier, true), "completed")
	s.vr.disabled = true
	yield(tap(joyButton(padButton)), "completed")
	yield(tap(joyButton(JOY_SELECT)), "completed")
	check("gamepad: with the button disabled, neither LT+X nor LT+Back opens it", not ui.isOpen() and started.size() == count, started.size())
	s.vr.disabled = false
	s.vr.release_focus()
	yield(tap(joyButton(padButton)), "completed")
	check("gamepad: LT+X with the button not highlighted opens nothing", not ui.isOpen() and started.size() == count)
	s.vr.grab_focus()
	yield(tap(joyButton(padButton)), "completed")
	check("gamepad: LT+X on the highlighted button opens the dialog and doesn't start the simulator", ui.isOpen() and started.size() == count and root._csSim == s.tuning.previewedConfig, started.size())
	yield(tap(joyButton(JOY_BUTTON_1)), "completed")
	yield(frames(2), "completed")
	check("gamepad: B closes it, the focus back on the button", not ui.isOpen() and s.vr.get_focus_owner() == s.vr, s.vr.get_focus_owner())
	s.vr.release_focus()
	yield(tap(joyButton(JOY_SELECT)), "completed")
	check("gamepad: LT+Back opens the dialog without the button highlighted, and doesn't start the simulator", ui.isOpen() and started.size() == count, started.size())
	yield(holdJoy(padModifier, false), "completed")

	# The shoulder buttons, with the dialog open: at its last tab, RB goes nowhere else.
	yield(tap(joyButton(JOY_R)), "completed")
	var switched = ui._tabs.current_tab == ui.SHIP_TAB_INDEX
	yield(tap(joyButton(JOY_R)), "completed")
	check("gamepad: RB switches the dialog's tab, and at its last tab the screen behind keeps its own", switched and ui._tabs.current_tab == ui.SHIP_TAB_INDEX and behind.current_tab == 0, [ui._tabs.current_tab, behind.current_tab])
	yield(tap(joyButton(JOY_L)), "completed")
	switched = ui._tabs.current_tab == ui.SETTINGS_TAB_INDEX
	yield(tap(joyButton(JOY_L)), "completed")
	check("gamepad: LB switches it back, and at its first tab the screen behind keeps its own", switched and ui._tabs.current_tab == ui.SETTINGS_TAB_INDEX and behind.current_tab == 0, [ui._tabs.current_tab, behind.current_tab])
	behind.queue_free()

	# The right stick on a description longer than its window.
	var lines = PoolStringArray()
	for i in range(ui.DESCRIPTION_LINES * 4):
		lines.append("Line %d" % i)
	ui._showDescription(lines.join("\n"), ui._description)
	yield(frames(2), "completed")
	var scroll = ui._description.get_parent()
	yield(holdAxis(JOY_AXIS_3, 1.0), "completed")
	yield(frames(10), "completed")
	var down = scroll.scroll_vertical
	yield(holdAxis(JOY_AXIS_3, 0.0), "completed")
	yield(frames(5), "completed")
	var still = scroll.scroll_vertical
	yield(holdAxis(JOY_AXIS_3, -1.0), "completed")
	yield(frames(60), "completed")
	var up = scroll.scroll_vertical
	yield(holdAxis(JOY_AXIS_3, 0.0), "completed")
	check("gamepad: the right stick scrolls a long description down, stops when let go, and scrolls it back up", down > 0 and still == down and up == 0, [down, still, up])

	# Start with no ring map to build the arena from: nothing runs, and the focus goes back to the button the dialog was
	# opened from.
	ui.close()
	s.vr.grab_focus()
	click(s.vr, true)
	yield(frames(2), "completed")
	var image = s.ring.image
	s.ring.image = null
	ui._onStart()
	yield(frames(2), "completed")
	check("gamepad: Start with no ring map runs nothing and gives the focus back to the button", not root._csLayer.isRunning() and not ui.isOpen() and s.vr.get_focus_owner() == s.vr, s.vr.get_focus_owner())
	s.ring.image = image
	Settings.controlScheme = Settings.control.keyMouse

# Focuses `button` afresh, so the game's tooltip node shows its tooltip.
# A Shift badge's tooltip: its hint_tooltip, which Badge.gd sets as the control scheme and the language change, or, once
# the game's tooltip node has taken it over (connectSounds, showTooltip: it empties the node's own), the node's copy.
func badgeTip(tooltips, badge) -> String:
	if badge.hint_tooltip != "":
		return badge.hint_tooltip
	return tooltips.tooltips.get(badge, "")

# The dialog's groups (the game's TuningItems) and rows.
func groups(ui) -> Array:
	var out = []
	for items in ui._scroll.get_children():
		if items.is_queued_for_deletion() or items.name != "Items":
			continue
		for group in items.get_children():
			if "tuning" in group and not group.is_queued_for_deletion():
				out.append(group)
	return out

func rows(ui) -> Array:
	var out = []
	for group in groups(ui):
		for row in group.get_children():
			if "tune" in row:
				out.append(row)
	return out

# A tab's Start or Cancel: every tab has both.
func tabButton(ui, tab, button):
	return ui._tabs.get_child(tab).get_node("Buttons/" + button)

# The ship list's groups (the game's TuningItems) and rows (TuningBoolValue), in order.
func shipGroups(ui) -> Array:
	var out = []
	for items in ui._shipList._scroll.get_children():
		if items.is_queued_for_deletion() or items.name != "Items":
			continue
		for group in items.get_children():
			if "tuning" in group and not group.is_queued_for_deletion():
				out.append(group)
	return out

func shipRows(ui) -> Array:
	var out = []
	for group in shipGroups(ui):
		for row in group.get_children():
			if "tune" in row:
				out.append(row)
	return out

func screenChecks(s):
	var root = s.root
	var ui = root._csDialog
	var c = load(UI_SCRIPT).get_script_constant_map()
	var id = modId()
	CurrentGame.state.ui.erase(id)
	settings.loadFromState()
	click(s.vr, true)
	yield(frames(3), "completed")
	check("dialog: opening it stores nothing", not CurrentGame.state.ui.has(id))
	var tabs = ui._tabs
	var tabTitles = [tabs.get_tab_title(0), tabs.get_tab_title(1)]
	check("dialog: two tabs, the settings then the ship, the second titled by the Ship setting's label, opening on the first", tabs.get_tab_count() == 2 and tabTitles[0] == c.TITLE and tabTitles[1] == S.ship.label and tabs.current_tab == 0, tabTitles)
	var order = []
	for child in tabs.get_child(0).get_children():
		order.append(child.name)
	var shipOrder = []
	for child in tabs.get_child(1).get_children():
		shipOrder.append(child.name)
	check("dialog: the first tab holds the description's window, the groups, then Start and Cancel; the second the window, the ship list, then Start and Cancel", order == ["WindowMargin", "ScrollContainer", "Buttons"] and shipOrder == ["WindowMargin", "ShipList", "Buttons"], [order, shipOrder])
	var windowMargin = tabs.get_child(0).get_node("WindowMargin")
	var gameMargin = s.tuning.get_node("VB/WindowMargin")
	var gameInside = s.tuning.get_node("VB/WindowMargin/Window/VBoxContainer/MarginContainer")
	var inside = windowMargin.get_node("Window/MarginContainer")
	var copied = windowMargin.theme == gameMargin.theme and windowMargin.get_node("Window").get_stylebox("panel") == s.tuning.get_node("VB/WindowMargin/Window").get_stylebox("panel") and tabs.get_child(0).theme == s.tuning.theme and tabs.get_child(1).theme == s.tuning.theme
	for side in ["left", "top", "right", "bottom"]:
		copied = copied and windowMargin.get_constant("margin_" + side) == gameMargin.get_constant("margin_" + side) and inside.get_constant("margin_" + side) == gameInside.get_constant("margin_" + side)
	check("dialog: it copies the Tuning screen's theme and its description window's frame", copied)
	# The rows: a group per GROUPS entry, its settings in SETTINGS order, named by their labels.
	var titles = []
	var labels = []
	var keys = []
	for entry in c.GROUPS:
		titles.append(entry[1])
		for k in S:
			if S[k].group == entry[0] and S[k].type != "choice":
				labels.append(tr(S[k].label))
				keys.append(k)
	var shownTitles = []
	for group in groups(ui):
		shownTitles.append(group.system)
	var all = rows(ui)
	var names = []
	for row in all:
		names.append(row.tuningItem)
	check("dialog: a group per GROUPS entry, in order, titled by it, with a game's row per setting of that group, named by its label", shownTitles == titles and names == labels, [shownTitles, names])
	if names != labels:
		ui.close()
		return
	var models = settings.models()
	var list = shipRows(ui)
	var listed = []
	var switchedOn = []
	for row in list:
		var m = ui._shipList._models[row.tuningItem]
		listed.append(m)
		if row.get_node("HBoxContainer/Value").pressed:
			switchedOn.append(m)
	var sortedListed = listed.duplicate()
	sortedListed.sort()
	var sortedModels = models.duplicate()
	sortedModels.sort()
	check("ship list: a row per model offered, named by the model, only the current one switched on", sortedListed == sortedModels and switchedOn == [settings.getValue("ship")], [listed, switchedOn])
	var shipTitles = []
	for group in shipGroups(ui):
		shipTitles.append(group.system)
	var alone = 0
	for m in models:
		var mates = 0
		for o in models:
			if settings.series(o) == settings.series(m):
				mates += 1
		if mates == 1:
			alone += 1
	check("ship list: the models alone in their series are grouped under Others, last", (alone == 0) == (shipTitles.back() != "COMBATSIMULATOR_OTHERS"), shipTitles)
	var ranges = true
	for i in keys.size():
		var k = keys[i]
		if S[k].type == "float":
			var slider = all[i].get_node("HSlider")
			ranges = ranges and is_equal_approx(slider.min_value, settings.toShown(k, S[k].min)) and is_equal_approx(slider.max_value, settings.toShown(k, S[k].max)) and is_equal_approx(slider.step, settings.toShown(k, S[k].step)) and all[i].get_node("HBoxContainer/Unit").text == S[k].unit and all[i].get_node("HBoxContainer/Value").text == S[k].format % settings.toShown(k, settings.getValue(k))
		elif S[k].type == "bool":
			ranges = ranges and all[i].get_node("HBoxContainer/Value").pressed == settings.getValue(k)
	check("dialog: each slider has its setting's range, step, unit and value in the units shown; each switch shows its setting", ranges)
	var description = ui._description
	check("dialog: on opening the first row is focused, and the window shows its description", description.text == tr(S[keys[0]].label + load(SETTINGS_SCRIPT).DESCRIPTION_SUFFIX), description.text)
	var described = true
	for i in keys.size():
		var control = all[i].get_node("HBoxContainer/Value") if S[keys[i]].type == "bool" else all[i].get_node("HSlider")
		control.grab_focus()
		yield(frames(1), "completed")
		described = described and description.text == tr(S[keys[i]].label + load(SETTINGS_SCRIPT).DESCRIPTION_SUFFIX)
	check("dialog: focusing a row shows its description", described)
	# The description's window keeps its height, and a longer text scrolls in it.
	var window = tabs.get_child(0).get_node("WindowMargin")
	var height = window.rect_size.y
	var textScroll = description.get_parent()
	var long = ""
	for m in models:
		long += tr(settings.modelDescription(m)) + "\n\n"
	ui._showDescription(long, description)
	yield(frames(2), "completed")
	check("dialog: the description's window keeps its height (DESCRIPTION_LINES lines) with a long text, which scrolls", is_equal_approx(window.rect_size.y, height) and textScroll is ScrollContainer and textScroll.get_v_scrollbar().max_value > textScroll.rect_size.y, [height, window.rect_size.y])
	ui._showDescription("", description)
	yield(frames(2), "completed")
	check("dialog: and with none", is_equal_approx(window.rect_size.y, height), window.rect_size.y)
	# Changing rows.
	changes = 0
	var numberRow = all[keys.find("number")]
	numberRow.get_node("HSlider").value = settings.toShown("number", S.number.max)
	check("dialog: moving a slider stores its setting", same(settings.getValue("number"), S.number.max) and CurrentGame.state.ui.has(id) and same(CurrentGame.state.ui[id].number, S.number.max) and changes == 1)
	var groupedSwitch = all[keys.find("grouped")].get_node("HBoxContainer/Value")
	groupedSwitch.pressed = not S.grouped.default
	check("dialog: switching a switch stores it", settings.getValue("grouped") == (not S.grouped.default))
	numberRow.get_node("HSlider").grab_focus()
	groupedSwitch.grab_focus()
	yield(frames(1), "completed")
	check("dialog: focusing the switch again doesn't switch it back", settings.getValue("grouped") == (not S.grouped.default) and groupedSwitch.pressed == (not S.grouped.default))
	# The ship tab: it opens on the current ship; picking another switches the previous one off.
	var current = settings.getValue("ship")
	tabs.current_tab = c.SHIP_TAB_INDEX
	yield(frames(3), "completed")
	var currentSwitch = list[listed.find(current)].get_node("HBoxContainer/Value")
	check("ship list: the tab opens with the focus on the current ship, its description in the tab's window", currentSwitch.get_focus_owner() == currentSwitch and ui._shipDescription.text.find(tr(settings.modelDescription(current))) >= 0, currentSwitch.get_focus_owner())
	var other = listed[(listed.find(current) + 1) % listed.size()]
	var otherSwitch = list[listed.find(other)].get_node("HBoxContainer/Value")
	otherSwitch.pressed = true
	yield(frames(1), "completed")
	check("ship list: switching another ship on picks it, switches the previous one off, keeps the tab's title and shows the ship's description", settings.getValue("ship") == other and not currentSwitch.pressed and tabs.get_tab_title(c.SHIP_TAB_INDEX) == S.ship.label and ui._shipDescription.text.find(tr(settings.modelDescription(other))) >= 0 and CurrentGame.state.ui[id].ship == other, [settings.getValue("ship"), currentSwitch.pressed])
	otherSwitch.pressed = false
	yield(frames(2), "completed")
	check("ship list: switching the current ship off puts it back on", settings.getValue("ship") == other and otherSwitch.pressed)
	currentSwitch.grab_focus()
	yield(frames(1), "completed")
	check("ship list: focusing another row changes nothing but the description", settings.getValue("ship") == other and not currentSwitch.pressed and otherSwitch.pressed)
	yield(tap(escKey()), "completed")
	check("dialog: Esc cancels from the ship tab too", not ui.isOpen())
	click(s.vr, true)
	yield(frames(3), "completed")
	all = rows(ui)
	var reopenedOn = []
	for row in shipRows(ui):
		if row.get_node("HBoxContainer/Value").pressed:
			reopenedOn.append(ui._shipList._models[row.tuningItem])
	check("dialog: it reopens on the first tab with the last choices", tabs.current_tab == 0 and all.size() == keys.size() and all[keys.find("number")].get_node("HSlider").value == settings.toShown("number", S.number.max) and all[keys.find("grouped")].get_node("HBoxContainer/Value").pressed == (not S.grouped.default) and reopenedOn == [other], reopenedOn)
	yield(tap(escKey()), "completed")
	CurrentGame.state.ui.erase(id)
	settings.loadFromState()
	yield(frames(2), "completed")

# ---- The arena ----

# The value Game.tscn (its SceneState) gives a node's property, as the arena reads it.
func ringValue(nodePath, property):
	var state = load(RING_SCENE).get_state()
	for i in state.get_node_count():
		if str(state.get_node_path(i)) == nodePath:
			for p in state.get_node_property_count(i):
				if state.get_node_property_name(i, p) == property:
					return state.get_node_property_value(i, p)
	return null

func shipsIn(field) -> Array:
	var out = []
	for child in field.get_children():
		if child.is_in_group("ships") and not child.is_queued_for_deletion():
			out.append(child)
	return out

func waitEnd(layer):
	for i in 400:
		yield(get_tree(), "physics_frame")
		if not layer.isRunning():
			break
	yield(frames(3), "completed")

func runOne(s):
	var root = s.root
	var layer = root._csLayer
	var ui = root._csDialog
	var c = load(LAYER_SCRIPT).get_script_constant_map()
	var units = load(SETTINGS_SCRIPT).UNITS_PER_METRE
	var shipMeta = load(SETTINGS_SCRIPT).SHIP_META
	var disarmedMeta = load(SETTINGS_SCRIPT).DISARMED_META
	settings.setValue("ship", "TRTL")
	settings.setValue("number", S.number.max)
	settings.setValue("grouped", true)
	settings.setValue("disabledWeapons", false)
	settings.setValue("remass", S.remass.min + 2 * S.remass.step)
	var number = int(S.number.max)
	var distance = settings.getValue("distance")
	# The save's tables, one of them missing; the run writes into them.
	CurrentGame.state.dispositions = {"KEEP-1": {"pirate": 0.5}}
	CurrentGame.state.shipNames = {"KEEP-1": "Kept"}
	CurrentGame.state.transponders = {"lookup": {"KEEP-1": ""}, "hashes": {}}
	CurrentGame.state.factions = {"pirate": {"player": 0.1}}
	CurrentGame.state.erase("encounteredShips")
	var tables = {}
	var copies = {}
	for k in ["dispositions", "shipNames", "transponders", "factions"]:
		tables[k] = CurrentGame.state[k]
		copies[k] = CurrentGame.state[k].duplicate(true)
	cg.state.crew = {"Ann Bell": {"occupation": "CREW_OCCUPATION_PILOT", "talent": 0.2, "experience": 0.3}}
	cg.state.story = {}
	var stationShip = Node2D.new()
	CurrentGame.playerShip = stationShip
	CurrentGame.inventoryMode = false
	CurrentGame.globalOffset = Vector2(0, 0)
	var mouseFade = s.mouse.fadeTime
	pirateScript.set_meta("made", [])
	Shipyard.configs.clear()
	click(s.vr, true)
	yield(frames(2), "completed")
	inventorySignals.clear()
	tabButton(ui, 0, "Start").emit_signal("pressed")
	# At once, before anything moves.
	check("run: Start closes the dialog and runs the arena", not ui.isOpen() and layer.isRunning() and layer.visible)
	check("run: the run is known to CurrentGame (the extension's _csArena)", cg._csArena == layer and CurrentGame.get("_csArena") == layer)
	var viewport = layer._viewport
	var upscale = viewport.get_parent()
	check("run: the layer processes while paused, its viewport's container stops; the viewport has its own world, its mouse proxy the picture; the container doesn't forward input and takes the simulator's scale", layer.pause_mode == Node.PAUSE_MODE_PROCESS and upscale.pause_mode == Node.PAUSE_MODE_STOP and viewport.own_world and viewport.mouseProxyNode == layer._texture and not upscale.passEvents and upscale.scale == s.upscale.scale)
	var field = layer._field
	var kinds = []
	for child in viewport.get_children():
		kinds.append(child.name)
	check("run: the viewport holds the asteroid field, BulletTimer, the music and WESpace, as the ring scene does", field != null and field.get_parent() == viewport and viewport.has_node("BulletTimer") and viewport.has_node("Music") and viewport.has_node("WESpace"), kinds)
	var timer = viewport.get_node_or_null("BulletTimer")
	check("run: BulletTimer without its notifications layer and deaf to gameOver", timer != null and not timer.has_node("NotificationsLayer") and not CurrentGame.is_connected("gameOver", timer, "_on_gameOver"))
	var fresh = load(c.GAME_FIELD).instance()
	var masks = true
	for mask in c.GAME_FIELD_MASKS:
		masks = masks and field.get(mask) == ringValue("./AsteroidField", mask) and field.get(mask) != fresh.get(mask)
	check("run: the field traces nothing into the save, puts its ships in the sim zone, takes the ring scene's masks, the arena's map, and doesn't process", field.tracedAtReady == false and field.zone == "sim" and masks and field.mapInstance == layer._map and field.mapInstance.get_script() == load(MAP_SCRIPT) and not field.is_processing() and field.map.is_empty())
	check("run: the field's map has the dialog's chaos and density", is_equal_approx(layer._map.chaos, settings.getValue("chaos")) and is_equal_approx(layer._map.density, settings.getValue("density")))
	var arrival = ringValue(".", c.GAME_ARRIVAL_SECONDS)
	var prefill = int(arrival / field.spawnEvery)
	var radii = true
	for r in field.spawns:
		radii = radii and r == field.cutsceneSpawnRadius
	check("run: the field is filled first as during the arrival (the ring scene's arrival over spawnEvery spawns, at the cutscene's radius), then its radius restored", field.spawns.size() == prefill and prefill > 0 and radii and field.minSpawnRadius == fresh.minSpawnRadius, [field.spawns.size(), prefill])
	fresh.free()
	var ship = layer._ship
	var fuel = ship.fullConfig.config.fuel if ship != null else {}
	var ammo = ship.fullConfig.config.ammo if ship != null else {}
	check("run: the player's ship is built from the screen's config as the simulator builds it: test, sim zone, player-controlled, preheated, marked; the field's focus; CurrentGame's player ship", ship != null and ship.get_parent() == field and ship.test and ship.zone == "sim" and ship.playerControlled and ship.preheat and ship.has_meta(shipMeta) and field.focusObject == ship and CurrentGame.playerShip == ship and ship.model == s.tuning.previewedConfig.model and ship.transponder == s.tuning.previewedConfig.transponder)
	check("run: its remass is the capacity times Initial remass, its other tanks full; the screen's config untouched", ship != null and is_equal_approx(fuel.initial, fuel.capacity * settings.getValue("remass")) and ammo.initial == ammo.capacity and s.tuning.previewedConfig.config.fuel.initial == sim("TRTL", "").config.fuel.initial, [fuel, ammo])
	var enemies = shipsIn(field)
	enemies.erase(ship)
	var built = pirateScript.get_meta("made")
	var alike = enemies.size() == number
	for e in enemies:
		alike = alike and e.faction == "pirate" and e.ai and e.preheat and not e.has_meta(disarmedMeta)
	check("run: Number enemies, pirates with the AI on, preheated, armed", alike, enemies.size())
	check("run: a TRTL is the pirate event's (story/PirateCombat.gd makeAt), without the civilian and without loot", built.size() == number and same(built[0], [false, 0, 1, 1]), built)
	var placed = field.blueprints.size() == number
	var origin = ship.global_position if ship != null else Vector2()
	var far = []
	for b in field.blueprints:
		var d = (b[0] - origin).length() / units
		far.append(d)
		placed = placed and b[1] == c.PLACEMENT_RANDOMNESS * units
	for e in enemies:
		var d = (e.global_position - origin).length() / units
		placed = placed and d >= distance - 0.01 and d <= sqrt(pow(distance + c.SPAWN_SPREAD, 2) + pow(c.GROUP_SPACING * number, 2))
	check("run: each enemy is placed by the field (spawnByBlueprint, with PLACEMENT_RANDOMNESS) at Distance or more", placed, far)
	var line = enemies.size() == number and number >= 2
	if line:
		var mid = Vector2()
		for e in enemies:
			mid += e.global_position / enemies.size()
		var across = enemies[-1].global_position - enemies[0].global_position
		var along = mid - origin
		for i in range(1, enemies.size()):
			line = line and abs((enemies[i].global_position - enemies[i - 1].global_position).length() - c.GROUP_SPACING * units) < 1.0
		line = line and abs(across.normalized().dot(along.normalized())) < 0.001 and along.length() / units >= distance - 0.01 and along.length() / units <= distance + c.SPAWN_SPREAD + 0.01
	check("run: grouped, they are side by side, GROUP_SPACING apart, across one bearing, from Distance to Distance + SPAWN_SPREAD", line)
	var clean = true
	for e in shipsIn(field):
		clean = clean and e.exitedToEnceladus and e.zone == "sim" and not e.hailable and typeof(e.dialogTree) == TYPE_NODE_PATH and e.dialogTree.is_empty() and typeof(e.farewellDialogTree) == TYPE_NODE_PATH and not e.talkWhenDocksToPlayer and not e.talkWhenInCargoHold
	check("run: every ship in the arena: exitedToEnceladus, the sim zone, not hailable, no dialog trees (empty paths)", clean)
	check("run: the map counts the arena's ships", layer._map.howManyShips() == number + 1, layer._map.howManyShips())
	check("run: the pirates' faction is frozen", Factions.frozenFactions.has("pirate"))
	var spot = CurrentGame.globalOffset / s.ring.pixelToKm
	check("run: the global offset is a pixel's centre of the ring, away from its edges", spot.x - floor(spot.x) == 0.5 and spot.y - floor(spot.y) == 0.5 and spot.x >= c.SPOT_EDGE_MARGIN and spot.x < s.ring.size.x - c.SPOT_EDGE_MARGIN and spot.y < s.ring.size.y, spot)
	check("run: at the station, NoBulletTime stops, the music pauses, the cursor fades as in the ring scene, the focus is let go", not s.noBulletTime.is_physics_processing() and s.players[0].stream_paused and s.players[1].stream_paused and s.mouse.fadeTime == ringValue("./MouseLayer", "fadeTime") and s.mouse.fadeTime != mouseFade and s.vr.get_focus_owner() == null, [s.mouse.fadeTime, s.vr.get_focus_owner()])
	yield(frames(int(c.FADE_SECONDS * Engine.iterations_per_second) + 10), "completed")
	check("run: once faded in, the station's background and menu are hidden", is_equal_approx(layer._texture.modulate.a, 1.0) and not s.background.visible and not s.menu.visible)
	check("run: the layer sends the field's mood", field.moods > 0 and field.processed == 0, [field.moods, field.processed])
	# Ships and nodes entering later: a lifepod-like ship with a dialog and a story flag, and a ship outside the arena.
	var pod = load(SHIP_SCENE).instance()
	pod.zone = "rings"
	pod.dialogTree = NodePath("Dialog")
	pod.talkWhenInCargoHold = true
	pod.talkWhenDocksToPlayer = true
	var flag = Parts.Flagged.new()
	pod.add_child(flag)
	field.add_child(pod)
	var outside = load(SHIP_SCENE).instance()
	outside.zone = "rings"
	outside.dialogTree = NodePath("Dialog")
	add_child(outside)
	check("run: a ship entering later is cleaned up too, and a node's story flag cleared", pod.exitedToEnceladus and pod.zone == "sim" and not pod.hailable and pod.dialogTree.is_empty() and not pod.talkWhenInCargoHold and not pod.talkWhenDocksToPlayer and flag.storyFlag == "")
	check("run: a ship outside the arena is left alone", not outside.exitedToEnceladus and outside.zone == "rings" and outside.hailable and outside.dialogTree == NodePath("Dialog"))
	outside.free()
	pod.free()
	# What the extension drops, and the save's tables written into.
	var talent = cg.state.crew["Ann Bell"].talent
	var experience = cg.state.crew["Ann Bell"].experience
	cg.giveXp(1.0, 1.0, true)
	check("run: giveXp gives talent and drops experience", cg.state.crew["Ann Bell"].talent > talent and cg.state.crew["Ann Bell"].experience == experience, cg.state.crew["Ann Bell"])
	cg.setStory("vilcy.bbw.destroyed", 1)
	check("run: story flags aren't set, ships don't join the fleet", not cg.state.story.has("vilcy.bbw.destroyed") and cg.addShip(enemies[0]) == false)
	CurrentGame.state.dispositions["KEEP-1"]["pirate"] = 0.9
	CurrentGame.state.dispositions["NEW-X"] = {"player": 0.8}
	CurrentGame.state.shipNames["NEW-X"] = "Named"
	CurrentGame.state.factions["pirate"]["player"] = 0.7
	CurrentGame.state["encounteredShips"] = {"NEW-X": {}}
	check("run: the ships made wrote new transponders into the save, as the game's Shipyard does", CurrentGame.state.transponders.lookup.size() > copies.transponders.lookup.size())
	# Input.
	var probe = Parts.Probe.new()
	viewport.add_child(probe)
	var started = s.simulation.started.size()
	yield(tap(key(KEY_J)), "completed")
	check("input: J goes into the arena's viewport (where the ship's camera opens the OMS) and starts nothing at the station", probe.events.size() == 1 and probe.events[0].scancode == KEY_J and s.simulation.started.size() == started and not ui.isOpen(), probe.events.size())
	yield(tap(key(KEY_J, true)), "completed")
	check("input: Shift+J too, and the dialog stays closed", probe.events.size() == 2 and not ui.isOpen() and s.simulation.started.size() == started)
	CurrentGame.inventoryMode = true
	yield(tap(escKey()), "completed")
	check("input: with the OMS open, Esc goes into the viewport (where it closes the OMS), asking nothing", probe.events.size() == 3 and probe.events[2].scancode == KEY_ESCAPE and not layer._confirm.visible and not get_tree().paused)
	CurrentGame.inventoryMode = false
	var moods = field.moods
	yield(tap(escKey()), "completed")
	check("confirm: with the OMS closed, Esc asks whether to end the run, pausing the game and filtering the music, not into the viewport", layer._confirm.visible and get_tree().paused and musicFilter() and probe.events.size() == 3)
	check("confirm: Cancel has the focus, as in the game's own confirmations, so accepting at once goes on with the run", layer._confirm.get_cancel().has_focus(), layer._confirm.get_focus_owner())
	check("confirm: the station's pause menu doesn't open", not pauseShown(s))
	moods = field.moods
	yield(frames(5), "completed")
	check("confirm: while it asks, the arena stands still (no mood sent, the field's container stopped)", field.moods == moods and not upscale.can_process())
	yield(tap(escKey()), "completed")
	check("confirm: Esc again answers No: the game goes on, the music unfiltered", not layer._confirm.visible and not get_tree().paused and not musicFilter() and layer.isRunning())
	yield(tap(escKey()), "completed")
	layer._confirm.get_cancel().emit_signal("pressed")
	yield(frames(2), "completed")
	check("confirm: No goes on", not layer._confirm.visible and not get_tree().paused and not musicFilter() and layer.isRunning())
	yield(tap(joyButton(JOY_START)), "completed")
	var asked = layer._confirm.visible and get_tree().paused
	yield(tap(joyButton(JOY_START)), "completed")
	check("confirm: the controller's Start asks, and again answers No", asked and not layer._confirm.visible and not get_tree().paused and layer.isRunning())
	s.pause.pauseGame(true)
	check("pause menu: its pauseGame during a run asks instead, without showing itself", layer._confirm.visible and get_tree().paused and not pauseShown(s))
	s.pause.pauseGame(false)
	check("pause menu: its pauseGame(false) during a run changes nothing", layer._confirm.visible and get_tree().paused and not pauseShown(s))
	layer._confirm.get_cancel().emit_signal("pressed")
	CurrentGame.emit_signal("pauseGame", true)
	check("pause menu: CurrentGame's pauseGame (a controller lost, the Steam overlay) asks too", layer._confirm.visible and not pauseShown(s))
	layer._confirm.get_cancel().emit_signal("pressed")
	s.pause.notification(MainLoop.NOTIFICATION_WM_FOCUS_OUT)
	yield(frames(3), "completed")
	check("pause menu: losing the window's focus asks too", layer._confirm.visible and not pauseShown(s))
	layer._confirm.get_cancel().emit_signal("pressed")
	yield(frames(2), "completed")
	check("confirm: still running, not paused", layer.isRunning() and not get_tree().paused)
	# Bullet time, which NoBulletTime would undo, then Yes.
	Engine.time_scale = 0.5
	yield(frames(3), "completed")
	check("run: the arena's time scale stays (NoBulletTime stopped)", Engine.time_scale == 0.5)
	yield(tap(escKey()), "completed")
	layer._confirm.get_ok().emit_signal("pressed")
	check("confirm: Yes ends the run: no longer paused, the station's background and menu shown", not layer._confirm.visible and not get_tree().paused and not musicFilter() and s.background.visible and s.menu.visible)
	yield(waitEnd(layer), "completed")
	check("end: the run is over and the layer hidden; CurrentGame's _csArena cleared", not layer.isRunning() and not layer.visible and cg._csArena == null)
	check("end: the player ship, the OMS state (signalled) and the time scale target are back", CurrentGame.playerShip == stationShip and CurrentGame.inventoryMode == false and inventorySignals == [false] and CurrentGame.targetTimeScale == 1.0, inventorySignals)
	check("end: NoBulletTime runs again and puts the time scale back to 1", s.noBulletTime.is_physics_processing() and Engine.time_scale == 1.0, Engine.time_scale)
	check("end: the music plays on, the cursor fades as before", not s.players[0].stream_paused and not s.players[1].stream_paused and s.mouse.fadeTime == mouseFade)
	check("end: the pirates' faction is unfrozen, the global offset back at the station's", not Factions.frozenFactions.has("pirate") and CurrentGame.globalOffset == Vector2(0, 0))
	check("end: the focus is back on the button", s.vr.get_focus_owner() == s.vr, s.vr.get_focus_owner())
	var restored = not CurrentGame.state.has("encounteredShips")
	for k in tables:
		restored = restored and CurrentGame.state[k] == tables[k] and same(CurrentGame.state[k], copies[k])
	check("end: the save's tables are as at Start (the same dictionaries), one missing then missing again", restored, [CurrentGame.state.dispositions, CurrentGame.state.transponders.lookup.size()])
	experience = cg.state.crew["Ann Bell"].experience
	cg.giveXp(1.0, 1.0, true)
	check("end: giveXp gives experience again", cg.state.crew["Ann Bell"].experience > experience)
	check("end: the viewport is emptied, and nothing entering the tree is watched", viewport.get_child_count() == 0 and not get_tree().is_connected("node_added", layer, "_onNodeAdded"), viewport.get_child_count())
	CurrentGame.playerShip = null
	stationShip.free()

func runTwo(s):
	var root = s.root
	var layer = root._csLayer
	var ui = root._csDialog
	var c = load(LAYER_SCRIPT).get_script_constant_map()
	var units = load(SETTINGS_SCRIPT).UNITS_PER_METRE
	var disarmedMeta = load(SETTINGS_SCRIPT).DISARMED_META
	var number = int(S.number.min) + 1
	settings.setValue("ship", "ATLAS")
	settings.setValue("number", number)
	settings.setValue("grouped", false)
	settings.setValue("distance", S.distance.min)
	settings.setValue("disabledWeapons", true)
	settings.setValue("remass", S.remass.max)
	var stationShip = Node2D.new()
	CurrentGame.playerShip = stationShip
	Shipyard.created.clear()
	fieldScript.set_meta("refuse", 1)
	s.vr.grab_focus()
	yield(tap(key(KEY_J, true)), "completed")
	tabButton(ui, 1, "Start").emit_signal("pressed")
	var field = layer._field
	var ship = layer._ship
	var enemies = shipsIn(field)
	enemies.erase(ship)
	check("run 2: a spot the field refuses is drawn again", field.blueprints.size() == number + 1 and enemies.size() == number, [field.blueprints.size(), enemies.size()])
	var made = true
	for e in enemies:
		var d = (e.global_position - ship.global_position).length() / units
		made = made and e.faction == "pirate" and e.has_meta(disarmedMeta) and d >= S.distance.min - 0.01 and d <= S.distance.min + c.SPAWN_SPREAD + 0.01
	check("run 2: ungrouped, each enemy from Distance to Distance + SPAWN_SPREAD away; with Disabled weapons each is marked disarmed", made)
	check("run 2: a model the game builds new is made by the Shipyard with the pirate faction (createShipByName)", Shipyard.created.count(["ATLAS", "pirate"]) == number, Shipyard.created)
	var fuel = ship.fullConfig.config.fuel
	check("run 2: at the most remass, the tanks are full", is_equal_approx(fuel.initial, fuel.capacity))
	var fired = fireThrough(enemies[0])
	check("run 2: the enemy's hardpoints and turrets fire nothing, their switches on", same(fired.slot, [0]) and same(fired.turret, [0]) and fired.firepower == 0 and fired.slotEnabled and fired.turretEnabled, fired)
	yield(frames(10), "completed")
	ship.emit_signal("removal")
	check("run 2: losing the ship ends the run without asking", not layer._confirm.visible and not get_tree().paused)
	yield(waitEnd(layer), "completed")
	check("run 2: over, the player ship back, the pirates unfrozen", not layer.isRunning() and CurrentGame.playerShip == stationShip and not Factions.frozenFactions.has("pirate") and s.background.visible and s.menu.visible)
	CurrentGame.playerShip = null
	stationShip.free()
