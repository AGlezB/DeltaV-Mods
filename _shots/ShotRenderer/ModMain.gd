extends Node

# ShotRenderer: takes the users' wiki's screenshots in the isolated copy of the game that _shots\shots.ps1 sets up. It
# runs the steps of the job file next to the executable (shotrenderer.cfg), then quits. Without that file it does
# nothing, so it is harmless anywhere else; and it stops the game at once if the game's user folder (where the saves
# are) isn't inside the shots folder.
#
# Steps, one string each, fields separated by |; node paths are relative to the scene the game's Loader shows:
#   newgame                       the fixture: a new game with money, one hire per job and three more ships; saved
#   load                          loads the save and goes to the station, then waits until it is there
#   wait|<seconds>
#   press|<path>                  presses a button (its pressed signal)
#   shiftclick|<path>             Shift+Click on a control (its gui_input signal), as the mods' settings open
#   pressfind|<path>|<name>|<n>   presses the n-th (from 0) visible node named <name> under <path>
#   click|<path>                  clicks a control with the mouse, as a player does (input events at its centre)
#   clickfind|<path>|<name>|<n>   clicks the n-th (from 0) visible node named <name> under <path>
#   tab|<path>|<n>                shows tab n of a TabContainer
#   scroll|<path>|<pixels>        scrolls the first ScrollContainer under <path> (itself included) down
#   shot|<file>[|x,y,w,h]         saves the window, or that part of it, as a PNG

const ENCELADUS = "res://enceladus/Enceladus.tscn"
const BOOT = "res://Boot.tscn"
const POLL = 0.5 # seconds between checks while waiting for a scene
const SETTLE = 2.0 # seconds to wait once the title screen is up

# The fixture.
const FIXTURE_SEED = 12345
const FIXTURE_SHIP = ["WK-0001", "Wiki One"]
const FIXTURE_SPARE = ["WK-0002", "Wiki Two"] # the same model as the ship flown
const FIXTURE_OTHERS = [["EIME", "WK-0003", "Wiki Three"], ["COTHON", "WK-0004", "Wiki Four"]] # other models
const FIXTURE_MONEY = 3000000

var _job = null

func _init(modLoader = null):
	var exeDir = OS.get_executable_path().get_base_dir()
	var job = ConfigFile.new()
	if job.load(exeDir.plus_file("shotrenderer.cfg")) != OK:
		return
	var root = exeDir.get_base_dir().replace("\\", "/").to_lower()
	var userDir = OS.get_user_data_dir().replace("\\", "/").to_lower()
	print("SHOTRENDERER userdir=", userDir)
	if not userDir.begins_with(root + "/"):
		printerr("SHOTRENDERER: the user folder is outside the shots folder: stopping")
		OS.kill(OS.get_process_id())
		return
	_job = job
	_toOtherScreen()

func _ready():
	if _job == null:
		return
	pause_mode = PAUSE_MODE_PROCESS
	while not _scene():
		yield(get_tree().create_timer(POLL), "timeout")
	_toOtherScreen()
	yield(get_tree().create_timer(SETTLE), "timeout")
	for step in _job.get_value("job", "steps", []):
		print("SHOTRENDERER step ", step)
		var parts = step.split("|")
		match parts[0]:
			"newgame":
				_newGame()
			"load":
				CurrentGame.loadFromFile()
				Loader.go(Loader.prepare(ENCELADUS))
				while not _scene() or _scene().filename != ENCELADUS:
					yield(get_tree().create_timer(POLL), "timeout")
			"wait":
				yield(get_tree().create_timer(float(parts[1])), "timeout")
			"press":
				var button = _node(parts[1])
				if button:
					button.emit_signal("pressed")
			"shiftclick":
				var control = _node(parts[1])
				if control:
					var click = InputEventMouseButton.new()
					click.button_index = BUTTON_LEFT
					click.pressed = true
					click.shift = true
					click.position = control.rect_size / 2
					control.emit_signal("gui_input", click)
			"pressfind":
				var found = []
				var under = _node(parts[1])
				if under:
					_find(under, parts[2], found)
				if found.size() > int(parts[3]):
					found[int(parts[3])].emit_signal("pressed")
				else:
					printerr("SHOTRENDERER: no node ", parts[2], " number ", parts[3], " under ", parts[1])
			"click":
				yield(_click(_node(parts[1])), "completed")
			"clickfind":
				var targets = []
				var within = _node(parts[1])
				if within:
					_find(within, parts[2], targets)
				if targets.size() > int(parts[3]):
					yield(_click(targets[int(parts[3])]), "completed")
				else:
					printerr("SHOTRENDERER: no node ", parts[2], " number ", parts[3], " under ", parts[1])
			"tab":
				var tabs = _node(parts[1])
				if tabs:
					tabs.current_tab = int(parts[2])
			"scroll":
				var scroller = _scroller(_node(parts[1]))
				if scroller:
					scroller.scroll_vertical = int(parts[2])
				else:
					printerr("SHOTRENDERER: no ScrollContainer under ", parts[1])
			"shot":
				yield(VisualServer, "frame_post_draw")
				var img = get_viewport().get_texture().get_data()
				img.flip_y()
				if parts.size() > 2:
					var r = parts[2].split_floats(",")
					img = img.get_rect(Rect2(r[0], r[1], r[2], r[3]))
				print("SHOTRENDERER saved ", parts[1], " ", img.get_size(), " ", img.save_png(parts[1]))
			_:
				printerr("SHOTRENDERER: unknown step ", step)
	get_tree().quit()

# Centres the window on a screen other than the main one (the one at the desktop's origin), where there is one, so the
# runs stay out of the way of whoever works on the main screen. The game's own screen setting applies only outside a
# window (Settings.gd applySettings), and its window settings change only the size (scaleWindow), not the place.
func _toOtherScreen():
	for screen in OS.get_screen_count():
		if OS.get_screen_position(screen) != Vector2.ZERO:
			OS.window_position = OS.get_screen_position(screen) + (OS.get_screen_size(screen) - OS.window_size) / 2
			print("SHOTRENDERER window on screen ", screen, " at ", OS.window_position)
			return

# The scene the game's Loader switched to last (it doesn't use the tree's current scene), or null.
func _scene():
	var scene = Loader.current
	if scene != null and is_instance_valid(scene) and scene.is_inside_tree() and scene.filename != BOOT:
		return scene
	return null

func _node(path):
	var node = _scene().get_node_or_null(path)
	if node == null:
		printerr("SHOTRENDERER: no node ", path)
	return node

func _find(node, name, found):
	for child in node.get_children():
		if child.name == name and (not child is CanvasItem or child.is_visible_in_tree()):
			found.append(child)
		_find(child, name, found)

# A left click at the centre of a control, through the game's input, so focus and the button's own handling happen as
# with a player's click.
func _click(control):
	yield(get_tree(), "idle_frame")
	if control == null:
		return
	var at = control.get_global_transform_with_canvas().xform(control.rect_size / 2)
	var move = InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	yield(get_tree(), "idle_frame")
	for down in [true, false]:
		var click = InputEventMouseButton.new()
		click.button_index = BUTTON_LEFT
		click.pressed = down
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
		yield(get_tree(), "idle_frame")

func _scroller(node):
	if node == null or node is ScrollContainer:
		return node
	for child in node.get_children():
		var scroller = _scroller(child)
		if scroller:
			return scroller
	return null

# The fixture: a named game with money, one hire per job, and in the fleet a spare of the same model as the ship flown
# and ships of other models (Shipyard.gd getDefaultConfigByName, as the game makes the first ship), saved to the
# isolated user folder.
func _newGame():
	CurrentGame.newGamePlus(FIXTURE_SEED, FIXTURE_SHIP[0], FIXTURE_SHIP[1])
	CurrentGame.state.money = FIXTURE_MONEY
	var jobs = {}
	for member in CurrentGame.getAvailableCrew():
		if not member.occupation in jobs:
			jobs[member.occupation] = true
			CurrentGame.hireCrewmember(member)
	var spare = CurrentGame.state.ship.duplicate(true)
	spare.transponder = FIXTURE_SPARE[0]
	spare.shipName = FIXTURE_SPARE[1]
	CurrentGame.state.garage.append(spare)
	CurrentGame.setShipNameByTransponder(FIXTURE_SPARE[0], FIXTURE_SPARE[1])
	for other in FIXTURE_OTHERS:
		var cfg = Shipyard.getDefaultConfigByName(other[0])
		cfg.transponder = other[1]
		cfg.shipName = other[2]
		CurrentGame.state.garage.append(cfg)
		CurrentGame.setShipNameByTransponder(other[1], other[2])
	CurrentGame.markStateAsValid()
	CurrentGame.saveToFile()
