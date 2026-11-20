extends Node

# ShotRenderer: takes the users' wiki's screenshots in the isolated copy of the game that _shots\shots.ps1 sets up. It
# runs the steps of the job file next to the executable (shotrenderer.cfg), then quits. Without that file it does
# nothing, so it is harmless anywhere else; and it stops the game at once if the game's user folder (where the saves
# are) isn't inside the shots folder.
#
# Steps, one string each, fields separated by |; node paths are relative to the scene the game's Loader shows, or, when
# they start with ship:, to the player's ship (whose node name in the ring scene isn't fixed):
#   newgame                       the fixture: a new game with money, one hire per job and three more ships; saved
#   load                          loads the save and goes to the station, then waits until it is there
#   dive                          from the station, goes to the ring scene, then waits until the player's ship is out of
#                                 the arrival cutscene; nothing is saved
#   wait|<seconds>
#   press|<path>                  presses a button (its pressed signal)
#   shiftclick|<path>             Shift+Click on a control (its gui_input signal), as the mods' settings open
#   pressfind|<path>|<name>|<n>   presses the n-th (from 0) visible node named <name> under <path>
#   click|<path>                  clicks a control with the mouse, as a player does (input events at its centre)
#   clickfind|<path>|<name>|<n>   clicks the n-th (from 0) visible node named <name> under <path>
#   action|<action>               presses and releases an input action, as its key does (jury_rig, J, opens the OMS)
#   set|<path>|<property>[/<key>...]|<json>
#                                 sets a node's property, or a key of a dictionary it holds (missing ones are made), to
#                                 a JSON value
#   tab|<path>|<n or name>        shows tab n, or the tab with that node name, of a TabContainer
#   scroll|<path>|<pixels>        scrolls the first ScrollContainer under <path> (itself included) down
#   shot|<file>[|x,y,w,h]         saves the window, or that part of it, as a PNG
#   ship|<model>|<file>           draws a ship model (a key of Shipyard.ships) alone and saves it as a PNG: nose up, on a
#                                 plain background, its hardpoints empty (a built-in turret keeps its weapon), with the
#                                 heat map of where a hit damages its reactors (_heatMap) and a scale bar
#   weapon|<system>|<model>|<slots>|<file>
#                                 mounts a system (a node name of weapons/WeaponSlot.tscn, or - for what the ship's own
#                                 scene mounts there, as its built-in turrets) on the hardpoints <slots> (comma-separated
#                                 slot names) of a ship model, its other hardpoints empty, and saves a PNG of two panels:
#                                 the ship close up with the weapon's cone, and a wide view of the weapon's reach
#                                 (_closeUp, _wideView)
# The ship and weapon pictures are drawn in a viewport of their own, never on the window, so they need no station
# screen; they are RGB, with text left out (the wiki says what the scale bars measure: the run prints their lengths).
# After the last step it prints SHOTRENDERER done: shots.ps1 fails a run that ends without it.

const ENCELADUS = "res://enceladus/Enceladus.tscn"
const GAME = "res://Game.tscn" # the ring scene
const BOOT = "res://Boot.tscn"
const SHIP_PREFIX = "ship:"
const POLL = 0.5 # seconds between checks while waiting for a scene
const SETTLE = 2.0 # seconds to wait once the title screen is up

# The fixture.
const FIXTURE_SEED = 12345
const FIXTURE_SHIP = ["WK-0001", "Wiki One"]
const FIXTURE_SPARE = ["WK-0002", "Wiki Two"] # the same model as the ship flown
const FIXTURE_OTHERS = [["EIME", "WK-0003", "Wiki Three"], ["COTHON", "WK-0004", "Wiki Four"]] # other models
const FIXTURE_MONEY = 3000000

# The ship and weapon pictures. A ship is drawn as DealerNotifier draws the Dealer's (its SettingsUI.gd _drawPicture):
# in the viewport of a Dealer entry (enceladus/SystemBuyUI.tscn, never added to the tree), with its lights and
# environment but without its camera, made as the dealer makes its ships, with what keeps it out of the save game (a
# transponder, a name and a making time: Shipyard.gd createShipByConfig), as a dummy with its reactors off.
const PICTURE_ENTRY = "res://enceladus/SystemBuyUI.tscn"
const PICTURE_VIEWPORT = "HBox/ViewportContainer/Viewport"
const PICTURE_FACTION = "dealer" # the dealer's ships' (CurrentGame.gd createShipInstanceWithCache)
const PICTURE_TRANSPONDER = "WK-0000"
const PICTURE_NAME = "Wiki Picture"
const PICTURE_SETTLE = 0.5 # seconds a ship is drawn before its picture is taken, so its looks have settled
const PICTURE_SETUP_LIMIT = 20.0 # seconds to wait for a ship's setup before giving up
const PICTURE_FRAMES = 3 # frames drawn after the view changes, before the picture is taken
# A ship's hardpoints in its config: weaponSlot.<slot>.type holds what is mounted (ships/WeaponSlot.gd), SYSTEM_NONE
# is nothing; a ship's scene gives it hardpoints as nodes with the hardpoint script, or as placeholders of its scene.
const HARDPOINTS = "weaponSlot"
const HARDPOINT_SYSTEM = "type"
const NO_SYSTEM = "SYSTEM_NONE"
const HARDPOINT_SCRIPT = "res://ships/WeaponSlot.gd"
const HARDPOINT_SCENE = "res://weapons/WeaponSlot.tscn"
const KEEP_MOUNTED = "-" # a weapon step's system that keeps what the ship's scene mounts
const UNITS_PER_METRE = 10.0 # the game shows 10 world units as 1 m
# The overlays are drawn on a canvas layer above the ones the game's environment tone-maps (WorldEnvironmentHDR.tscn
# background_canvas_max_layer), so they keep their colours; the background, on one below the ship.
const OVERLAY_LAYER = 20
const BACKGROUND_LAYER = -1
const BACKGROUND = Color(0.035, 0.04, 0.05)

# Ship pictures: every ship at the same scale, except where that would make the picture's longer side larger than
# SHIP_MAX_PX (big ships, scaled down to that) or smaller than SHIP_MIN_PX (small ships, scaled up to that). The margin
# around the ship is a share of the longer side, at least SHIP_MARGIN_MIN_PX.
const SHIP_PX_PER_METRE = 10.0
const SHIP_MAX_PX = 1100.0
const SHIP_MIN_PX = 200.0
const SHIP_MARGIN = 0.1
const SHIP_MARGIN_MIN_PX = 40.0

# The heat map of where a kinetic hit damages a reactor (ships/Reactor.gd and ships/modules/FusionReactor.gd
# _on_impact): a hit of power P at a point p gives P*100/d^2 damage, less a threshold, with p in the reactor's own frame
# (its position, rotation and scale) and d = max(reactorMinRadius, |p| - reactorRadius). The fission reactor's damage
# is Reactor leak, the fusion reactor's (the EIME's) Coolant, each with its own colours. One scale for every ship, so
# pictures compare: full colour where 1/d^2 is that of the standard fission reactor's core (HEAT_REFERENCE's
# reactorMinRadius), fading on a log scale to nothing HEAT_DECADES powers of ten weaker, with a contour line at each
# power of ten and around each reactor's core (where d = reactorMinRadius, the damage at its most). Sampled every
# HEAT_STEP px.
const HEAT_REFERENCE = "res://ships/modules/NuclearReactor.tscn"
const HEAT_DECADES = 3
const HEAT_STEP = 1
const HEAT_LEAK = [
	[0.0, Color(0.5, 0.0, 0.0, 0.0)],
	[0.333, Color(0.7, 0.08, 0.04, 0.09)],
	[0.667, Color(0.95, 0.3, 0.05, 0.2)],
	[0.95, Color(1.0, 0.55, 0.1, 0.3)],
	[1.0, Color(1.0, 0.75, 0.25, 0.32)],
]
const HEAT_LEAK_LINE = Color(1.0, 0.78, 0.4, 0.9)
const HEAT_COOLANT = [
	[0.0, Color(0.0, 0.1, 0.5, 0.0)],
	[0.333, Color(0.04, 0.25, 0.8, 0.09)],
	[0.667, Color(0.08, 0.5, 1.0, 0.2)],
	[0.95, Color(0.3, 0.75, 1.0, 0.3)],
	[1.0, Color(0.55, 0.9, 1.0, 0.32)],
]
const HEAT_COOLANT_LINE = Color(0.55, 0.88, 1.0, 0.9)

# Weapon pictures: two square panels of PANEL_PX side by side, GAP_PX apart. The close-up has the ship at most at the
# ship pictures' scale, within CLOSE_WIDTH and CLOSE_HEIGHT of the panel, its tail CLOSE_BOTTOM above the bottom edge;
# the wide view frames the ship and the weapon's reach (to its range, or a turret's pick-up areas) with WIDE_MARGIN.
const PANEL_PX = 640.0
const GAP_PX = 4
const GAP = Color(0.25, 0.27, 0.3)
const CLOSE_WIDTH = 0.8
const CLOSE_HEIGHT = 0.5
const CLOSE_BOTTOM = 0.06
const WIDE_MARGIN = 0.08
# Where mass drivers' slugs fly on past the AI's aim (massdriver.gd boresight range; they have no lifetime), the cone
# goes on, fainter, to this many times that range.
const ENDLESS_REACH = 1.5
const MARKER_PX = 7.0 # least radius of the ship's marker in the wide view
const TURRET_ARC_PX = 70.0 # radius of a turret's arcs in the close-up
const TURN_SECONDS = 1.0 # the turret's turn drawn: how far it turns in this time from rest, either way
# The physics layers of a turret's pick-up area (project.godot 2d_physics layer names): rock; ship, ships-small,
# ships-large and drone.
const LAYER_ROCKS = 1
const LAYER_SHIPS = 5634
const ARC_STEPS = 96 # points on a full circle
const CONE_SLICES = 24 # slices of a plume, whose colour fades with distance
const PLUME_FAINTEST = 0.3 # the least share of the plume's colour, where its damage has faded most
const PLUME_OUTER = 0.4 # the share of the plume's colour outside the cone of half its rays
const LINE_PX = 2.0
const THIN_PX = 1.5
const BAR_SHARE = 0.22 # the scale bar's length, at most, as a share of the picture's width
const BAR_INSET = 18.0
const BAR_TICK = 5.0
const COLOURS = {
	"bar": Color(0.92, 0.92, 0.92, 0.95),
	"cone": Color(1.0, 0.86, 0.3, 0.3), # a weapon's spread, new and at its default tuning
	"coneEdge": Color(1.0, 0.86, 0.3, 0.95),
	"worst": Color(1.0, 0.5, 0.2, 0.85), # its widest: the most power its tuning allows, with full focus damage
	"range": Color(0.95, 0.95, 0.95, 0.8),
	"plume": Color(1.0, 0.5, 0.15, 0.75), # an exhaust weapon's plume, fading as its damage does
	"plumeEdge": Color(1.0, 0.55, 0.2, 0.9),
	"gimbal": Color(0.35, 0.8, 1.0, 0.16), # where a turret can aim
	"gimbalEdge": Color(0.35, 0.8, 1.0, 0.8),
	"turn": Color(0.35, 0.8, 1.0, 0.38), # where it aims within TURN_SECONDS from rest
	"safety": Color(0.55, 1.0, 0.55, 0.9), # a turret's safety distance
	"ships": Color(1.0, 0.35, 0.6), # pick-up areas: for ships, rocks, both
	"rocks": Color(1.0, 0.68, 0.2),
	"both": Color(0.7, 0.55, 1.0),
	"areaFill": 0.12, # the alpha of an area's fill
	"marker": Color(0.6, 0.95, 1.0, 0.95),
}

var _job = null
var _hardpointSlot = null # the hardpoint scene's own slot, read once
var _heatReference = null # the standard reactor's reactorMinRadius, read once
var _gradients = {}

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

func _ready():
	if _job == null:
		return
	pause_mode = PAUSE_MODE_PROCESS
	while not _scene():
		yield(get_tree().create_timer(POLL), "timeout")
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
			"dive":
				# As the station launches a dive (enceladus/Enceladus.gd _on_DiveTarget_launch, goToRing), without the
				# dive target screen, which saves (DiveTarget.gd). The ring scene makes the player's ship and starts its
				# arrival cutscene in its _ready (Game.gd).
				Loader.go(Loader.prepare(GAME, true))
				CurrentGame.freeShipInstanceCache()
				while not _scene() or _scene().filename != GAME:
					yield(get_tree().create_timer(POLL), "timeout")
				var ship = CurrentGame.getPlayerShip()
				while not is_instance_valid(ship) or not ship.is_inside_tree() or ship.cutscene:
					yield(get_tree().create_timer(POLL), "timeout")
					ship = CurrentGame.getPlayerShip()
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
			"action":
				for down in [true, false]:
					var press = InputEventAction.new()
					press.action = parts[1]
					press.pressed = down
					Input.parse_input_event(press)
					yield(get_tree(), "idle_frame")
			"set":
				var target = _node(parts[1])
				var parsed = JSON.parse(parts[3])
				if parsed.error != OK:
					printerr("SHOTRENDERER: not JSON: ", parts[3])
				elif target:
					_assign(target, parts[2].split("/"), parsed.result)
			"tab":
				var tabs = _node(parts[1])
				if tabs:
					var index = _tabIndex(tabs, parts[2])
					if index < 0:
						printerr("SHOTRENDERER: no tab ", parts[2], " in ", parts[1])
					else:
						tabs.current_tab = index
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
			"ship":
				yield(_shipPicture(parts[1], parts[2]), "completed")
			"weapon":
				yield(_weaponPicture(parts[1], parts[2], parts[3], parts[4]), "completed")
			_:
				printerr("SHOTRENDERER: unknown step ", step)
	print("SHOTRENDERER done")
	get_tree().quit()

# The scene the game's Loader switched to last (it doesn't use the tree's current scene), or null.
func _scene():
	var scene = Loader.current
	if scene != null and is_instance_valid(scene) and scene.is_inside_tree() and scene.filename != BOOT:
		return scene
	return null

func _node(path):
	var node = null
	if path.begins_with(SHIP_PREFIX):
		var ship = CurrentGame.getPlayerShip()
		if is_instance_valid(ship):
			node = ship.get_node_or_null(path.substr(SHIP_PREFIX.length()))
	else:
		node = _scene().get_node_or_null(path)
	if node == null:
		printerr("SHOTRENDERER: no node ", path)
	return node

# Sets `keys[0]` of a node to `value`, or, with more keys, the last key of the dictionary the others lead to inside that
# property, making the dictionaries that are missing.
func _assign(node, keys, value):
	if keys.size() == 1:
		node.set(keys[0], value)
		return
	var holder = node.get(keys[0])
	for i in range(1, keys.size() - 1):
		if not holder is Dictionary:
			break
		if not holder.get(keys[i]) is Dictionary:
			holder[keys[i]] = {}
		holder = holder[keys[i]]
	if holder is Dictionary:
		holder[keys[keys.size() - 1]] = value
	else:
		printerr("SHOTRENDERER: not a dictionary on the way to ", keys.join("/"))

# A tab's index in a TabContainer, from its number or its node name; -1 when there is none. Its tabs are its Control
# children that aren't set as top level, as the TabContainer counts them.
func _tabIndex(tabs, which):
	if which.is_valid_integer():
		return int(which)
	var index = 0
	for child in tabs.get_children():
		if child is Control and not child.is_set_as_toplevel():
			if child.name == which:
				return index
			index += 1
	return -1

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

# --- Ship and weapon pictures ---

# The ship step: the ship framed with a margin, the heat map of its reactors over it, and a scale bar.
func _shipPicture(model, file):
	var viewport = yield(_stage(model, {}), "completed")
	if viewport == null:
		return
	var ship = viewport.get_meta("ship")
	var bounds = _shipBounds(ship)
	for reactor in _reactors(ship):
		bounds = bounds.merge(_reactorCore(reactor))
	var scale = _shipScale(bounds.size)
	print("SHOTRENDERER ship ", model, ": ", bounds.size / UNITS_PER_METRE, " m, ", scale * UNITS_PER_METRE, " px/m")
	var margin = max(SHIP_MARGIN_MIN_PX, SHIP_MARGIN * max(bounds.size.x, bounds.size.y) * scale)
	var size = (bounds.size * scale + Vector2(2, 2) * margin).ceil()
	var view = _view(bounds.position + bounds.size / 2, scale, size)
	var ops = []
	var heat = _heatMap(ship, view, size)
	if heat != null:
		ops.append(["image", heat, Rect2(Vector2.ZERO, Vector2(ceil(size.x / HEAT_STEP), ceil(size.y / HEAT_STEP)) * HEAT_STEP)])
	ops += _scaleBar(size, scale, file)
	var img = yield(_render(viewport, view, size, ops), "completed")
	print("SHOTRENDERER saved ", file, " ", img.get_size(), " ", img.save_png(file))
	_unstage(viewport)

# The weapon step: the close-up and the wide view side by side.
func _weaponPicture(system, model, slotList, file):
	var slots = Array(slotList.split(","))
	var mounts = {}
	if system != KEEP_MOUNTED:
		for slot in slots:
			mounts[slot] = system
	var viewport = yield(_stage(model, mounts), "completed")
	if viewport == null:
		return
	var ship = viewport.get_meta("ship")
	var mounted = _mounted(ship, slots)
	if mounted.empty():
		printerr("SHOTRENDERER: nothing mounted on ", slotList, " of ", model)
		_unstage(viewport)
		return
	var bounds = _shipBounds(ship)
	var left = yield(_closeUp(viewport, bounds, mounted, file), "completed")
	var right = yield(_wideView(viewport, bounds, mounted, file), "completed")
	var img = Image.new()
	img.create(int(PANEL_PX) * 2 + GAP_PX, int(PANEL_PX), false, Image.FORMAT_RGB8)
	img.fill(GAP)
	img.blit_rect(left, Rect2(Vector2.ZERO, left.get_size()), Vector2.ZERO)
	img.blit_rect(right, Rect2(Vector2.ZERO, right.get_size()), Vector2(PANEL_PX + GAP_PX, 0))
	print("SHOTRENDERER saved ", file, " ", img.get_size(), " ", img.save_png(file))
	_unstage(viewport)

# A Dealer entry's viewport holding a ship of `model` (its meta "ship") once the ship is set up and has settled, or
# null. Every hardpoint is empty (_emptyHardpoints) but those `mounts` names (slot: system). The viewport's camera is
# freed: _render sets the view.
func _stage(model, mounts):
	yield(get_tree(), "idle_frame")
	if not model in Shipyard.ships:
		printerr("SHOTRENDERER: no ship model ", model)
		return null
	var scene = load(PICTURE_ENTRY)
	var entry = scene.instance() if scene is PackedScene else null
	var viewport = entry.get_node_or_null(PICTURE_VIEWPORT) if entry != null else null
	if not viewport is Viewport:
		printerr("SHOTRENDERER: no viewport ", PICTURE_VIEWPORT, " in ", PICTURE_ENTRY)
		if entry != null:
			entry.free()
		return null
	viewport.get_parent().remove_child(viewport)
	entry.free()
	for child in viewport.get_children():
		if child is Camera2D:
			viewport.remove_child(child)
			child.free()
	var background = CanvasLayer.new()
	background.layer = BACKGROUND_LAYER
	var fill = ColorRect.new()
	fill.color = BACKGROUND
	fill.rect_size = Vector2(SHIP_MAX_PX, SHIP_MAX_PX) * 4
	background.add_child(fill)
	viewport.add_child(background)
	var config = Shipyard.getDefaultConfigByName(model)
	config.faction = PICTURE_FACTION
	config.transponder = PICTURE_TRANSPONDER
	config.shipName = PICTURE_NAME
	config.madeIn = CurrentGame.getInGameTimestamp()
	var ship = Shipyard.createShipByConfig(config, true, 0, 1)
	_emptyHardpoints(ship)
	for slot in mounts:
		ship.setConfig("%s.%s.%s" % [HARDPOINTS, slot, HARDPOINT_SYSTEM], mounts[slot])
	ship.setDummy(true)
	ship.dummy = true
	ship.setReactorState(false)
	viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	viewport.msaa = Viewport.MSAA_4X
	add_child(viewport)
	viewport.add_child(ship)
	ship.preheat = false
	ship.cutscene = true
	var waited = 0.0
	while not ship.setup and waited < PICTURE_SETUP_LIMIT:
		yield(get_tree().create_timer(POLL), "timeout")
		waited += POLL
	if not ship.setup:
		printerr("SHOTRENDERER: ship ", model, " never got set up")
		_unstage(viewport)
		return null
	_restMicrowaves(ship)
	yield(get_tree().create_timer(PICTURE_SETTLE), "timeout")
	viewport.set_meta("ship", ship)
	return viewport

# An MWG hides its beam and sparks in its _process while it doesn't fire (weapons/emp.gd), which a dummy ship's
# systems never run (ship-ctrl.gd setDummy): run it once.
func _restMicrowaves(node):
	for child in node.get_children():
		if child.has_method("getSpread") and child.has_method("_process"):
			child._process(0.0)
		_restMicrowaves(child)

# Frees the viewport, with the ship and anything the ship put beside itself (a drone cradle lets its drone go into the
# ship's parent: ships/modules/ClaimOwner.gd).
func _unstage(viewport):
	if viewport.get_parent() != null:
		viewport.get_parent().remove_child(viewport)
	viewport.queue_free()

# Empties every hardpoint of `ship`, a ship not yet in the tree: in its config, each hardpoint its scene has
# (_hardpoints) and each one the config names holds None. The ship keeps its config by reference, so that is what its
# hardpoints mount as they enter the tree (ships/WeaponSlot.gd _ready).
func _emptyHardpoints(ship):
	var slots = _hardpoints(ship)
	var named = ship.getConfig(HARDPOINTS)
	if named is Dictionary:
		slots += named.keys()
	for slot in slots:
		ship.setConfig("%s.%s.%s" % [HARDPOINTS, slot, HARDPOINT_SYSTEM], NO_SYSTEM)

# The slots of the hardpoints under `node`, in a ship's scene, as DealerNotifier finds them (its SettingsUI.gd
# _hardpoints), but none inside a built-in turret (a node with ships/modules/PDT.gd, as the Tsukuyomi's): what the
# turret mounts is part of the ship.
func _hardpoints(node) -> Array:
	var out = []
	for child in node.get_children():
		if child is InstancePlaceholder:
			if child.get_instance_path() == HARDPOINT_SCENE:
				var slot = child.get_stored_values().get("slot", _hardpointSceneSlot())
				if slot != null:
					out.append(slot)
		elif not _isTurret(child):
			var script = child.get_script()
			if script != null and script.resource_path == HARDPOINT_SCRIPT:
				out.append(child.slot)
			out += _hardpoints(child)
	return out

# The slot the hardpoint scene gives its root, read from one instance, never added to the tree; null where there is
# no such scene.
func _hardpointSceneSlot():
	if _hardpointSlot == null:
		var scene = load(HARDPOINT_SCENE)
		if scene is PackedScene:
			var node = scene.instance()
			if "slot" in node:
				_hardpointSlot = node.slot
			node.free()
	return _hardpointSlot

func _isTurret(node) -> bool:
	return "gimbalLimit" in node and "rotationPerSecond" in node

func _isHardpoint(node) -> bool:
	return "directMount" in node and "slot" in node

# What the hardpoints with these slots hold, once the ship is set up: for each, the weapon (`gun`) and the turret that
# aims it (`turret`, or null): a turret mounted on the hardpoint (ships/modules/PDT.gd, whose `system` is its weapon),
# or the built-in turret the hardpoint is part of (ships/modules/PDT.tscn, whose `system` is the hardpoint).
func _mounted(ship, slots) -> Array:
	var hardpoints = []
	_findHardpoints(ship, slots, hardpoints)
	var out = []
	for hardpoint in hardpoints:
		var turret = null
		var up = hardpoint.get_parent()
		while up != null and up != ship:
			if _isTurret(up):
				turret = up
				break
			up = up.get_parent()
		var node = hardpoint.get("system")
		while node != null:
			if _isTurret(node):
				turret = node
				node = node.get("system")
			elif _isHardpoint(node):
				node = node.get("system")
			else:
				break
		if node != null and node.has_method("boresight"):
			out.append({"turret": turret, "gun": node})
	return out

func _findHardpoints(node, slots, out):
	for child in node.get_children():
		if _isHardpoint(child) and child.slot in slots:
			out.append(child)
		_findHardpoints(child, slots, out)

# The reactors of a ship: its children that take kinetic damage as reactors do (ships/Reactor.gd,
# ships/modules/FusionReactor.gd).
func _reactors(ship) -> Array:
	var out = []
	for child in ship.get_children():
		if "reactorRadius" in child and "reactorMinRadius" in child and child.has_method("_on_impact"):
			out.append(child)
	return out

# The square around a reactor's core: where its damage is full (reactorRadius + reactorMinRadius, in its own frame).
func _reactorCore(reactor) -> Rect2:
	var radius = (reactor.reactorRadius + reactor.reactorMinRadius) * reactor.global_transform.get_scale().x
	return Rect2(reactor.global_position - Vector2(radius, radius), Vector2(radius, radius) * 2)

# The ship's outline, in world units: its own collision shapes, its hull sprites (ship-ctrl.gd spriteHullPaths) and
# what its hardpoints and built-in turrets hold (_partPoints).
func _shipBounds(ship) -> Rect2:
	var points = []
	for child in ship.get_children():
		if child is CollisionPolygon2D:
			for p in child.polygon:
				points.append(child.global_transform.xform(p))
		elif child is CollisionShape2D and child.shape != null:
			points += Array(_shapeOutline(child.shape, child.global_transform))
	for path in ship.spriteHullPaths:
		var hull = ship.get_node_or_null(NodePath(path))
		if hull is Sprite:
			_spritePoints(hull, points)
	_partPoints(ship, points, false)
	if points.empty():
		points.append(ship.global_position)
	return _boundsOf(points)

# The corners of the visible sprites under `node` that are parts of what a hardpoint or a built-in turret holds: a
# weapon's own sprite (its children are its effects: beams, sparks, flares), a turret's other sprites; not an exhaust
# weapon's, whose sprite is its plume.
func _partPoints(node, points, inside):
	for child in node.get_children():
		if child is CanvasItem and not child.is_visible_in_tree():
			continue
		if child.has_method("boresight") and not _isTurret(child) and not _isHardpoint(child):
			if inside and child is Sprite and not ("heatCone" in child):
				_spritePoints(child, points)
			continue
		var within = inside or _isTurret(child) or _isHardpoint(child)
		if within and child is Sprite:
			_spritePoints(child, points)
		_partPoints(child, points, within)

func _spritePoints(sprite, points):
	var r = sprite.get_rect()
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		points.append(sprite.global_transform.xform(corner))

func _boundsOf(points) -> Rect2:
	var rect = Rect2(points[0], Vector2.ZERO)
	for p in points:
		rect = rect.expand(p)
	return rect

func _shipScale(size: Vector2) -> float:
	var scale = SHIP_PX_PER_METRE / UNITS_PER_METRE
	var longest = max(size.x, size.y)
	if longest * scale > SHIP_MAX_PX:
		scale = SHIP_MAX_PX / longest
	elif longest * scale < SHIP_MIN_PX:
		scale = SHIP_MIN_PX / longest
	return scale

# World to pixels: `centre` in the middle of a picture of `size`, at `scale` pixels per world unit, nose up.
func _view(centre: Vector2, scale: float, size: Vector2) -> Transform2D:
	return Transform2D(Vector2(scale, 0), Vector2(0, scale), size / 2 - centre * scale)

# The viewport's picture through `view`, `size` pixels, with `ops` (_Overlay) over it, as RGB.
func _render(viewport, view, size, ops):
	viewport.size = size
	viewport.canvas_transform = view
	var layer = CanvasLayer.new()
	layer.layer = OVERLAY_LAYER
	var overlay = Overlay.new()
	overlay.ops = ops
	layer.add_child(overlay)
	viewport.add_child(layer)
	for i in PICTURE_FRAMES:
		yield(get_tree(), "idle_frame")
	yield(VisualServer, "frame_post_draw")
	var img = viewport.get_texture().get_data()
	img.flip_y()
	img.convert(Image.FORMAT_RGB8)
	viewport.remove_child(layer)
	layer.free()
	return img

# The heat map (see HEAT_REFERENCE) over the reactors of `ship`, as a texture sampled every HEAT_STEP pixels of the
# picture; null for a ship without reactors. Where reactors overlap, a pixel shows the one it is most dangerous for. A
# sample is on a contour line where its band (the power of ten it is in, or the core) differs from that of the sample on
# its right or below it.
func _heatMap(ship, view, size):
	var reactors = []
	for reactor in _reactors(ship):
		reactors.append([reactor.global_transform.affine_inverse(), float(reactor.reactorRadius), float(reactor.reactorMinRadius), "damageCoolantCapacity" in reactor])
	if reactors.empty():
		return null
	var full = _heatReferenceRadius()
	var span = HEAT_DECADES * log(10) / 2 # 1/d^2 falls HEAT_DECADES powers of ten as d grows by half as many
	var leak = _gradient("leak", HEAT_LEAK)
	var coolant = _gradient("coolant", HEAT_COOLANT)
	var w = int(ceil(size.x / HEAT_STEP))
	var h = int(ceil(size.y / HEAT_STEP))
	var strength = PoolRealArray()
	var band = PoolIntArray()
	var kind = PoolByteArray()
	strength.resize(w * h)
	band.resize(w * h)
	kind.resize(w * h)
	var inverse = view.affine_inverse()
	for y in h:
		for x in w:
			var p = inverse.xform(Vector2((x + 0.5) * HEAT_STEP, (y + 0.5) * HEAT_STEP))
			var best = 0.0
			var core = false
			var isCoolant = false
			for r in reactors:
				var d = max(r[2], r[0].xform(p).length() - r[1])
				var t = 1.0 - log(d / full) / span
				if t > best:
					best = t
					core = d <= r[2]
					isCoolant = r[3]
			var i = y * w + x
			strength[i] = best
			band[i] = HEAT_DECADES + 1 if core else int(floor(clamp(best, 0.0, 1.0) * HEAT_DECADES))
			kind[i] = 1 if isCoolant else 0
	var img = Image.new()
	img.create(w, h, false, Image.FORMAT_RGBA8)
	img.lock()
	for y in h:
		for x in w:
			var i = y * w + x
			if strength[i] <= 0.0:
				continue
			var b = band[i]
			var edge = (x + 1 < w and band[i + 1] != b) or (y + 1 < h and band[i + w] != b) or (x > 0 and band[i - 1] != b) or (y > 0 and band[i - w] != b)
			if edge:
				img.set_pixel(x, y, HEAT_COOLANT_LINE if kind[i] == 1 else HEAT_LEAK_LINE)
			else:
				img.set_pixel(x, y, (coolant if kind[i] == 1 else leak).interpolate(min(strength[i], 1.0)))
	img.unlock()
	var texture = ImageTexture.new()
	texture.create_from_image(img, Texture.FLAG_FILTER)
	return texture

func _heatReferenceRadius() -> float:
	if _heatReference == null:
		_heatReference = 1.0
		var scene = load(HEAT_REFERENCE)
		if scene is PackedScene:
			var node = scene.instance()
			if "reactorMinRadius" in node:
				_heatReference = float(node.reactorMinRadius)
			node.free()
	return _heatReference

func _gradient(key, stops) -> Gradient:
	if not _gradients.has(key):
		var g = Gradient.new()
		var offsets = PoolRealArray()
		var colors = PoolColorArray()
		for stop in stops:
			offsets.append(stop[0])
			colors.append(stop[1])
		g.offsets = offsets
		g.colors = colors
		_gradients[key] = g
	return _gradients[key]

# What a weapon's shots cover, in world units, from its own values: where they start, the way it points
# (Vector2(0, -1) turned by its boresight direction), its range (its boresight's: the AI's aim for a mass driver and
# the iron thrower, the ray's length for a laser, an SPC, an MWG and the other exhaust weapons), and the half-angle of
# its spread new and at its default tuning (`half`) and at its widest (`worst`):
# - a mass driver (weapons/massdriver.gd _physics_process: firingVector): +-1/2 defocusAngleDegrees * (focus damage^2
#   + focusMin), at its widest with full focus damage; its slugs fly on past the range (`endless`);
# - an MWG (weapons/emp.gd getSpread, its ray turned by up to half of it): its spread at the tuned power, at its widest
#   at the most power TUNE_EMP_POWER allows, with full focus damage;
# - an exhaust weapon (sfx/thruster.gd _physics_process): its plume, the damage ray, as long as its sprite's rect
#   ((size - position) * scale).y (`plume`), turned by (randf() - 0.5)^3 * randomness, its damage falling as
#   1 / max(1, distance / distanceScale) (`falloff`); past it, to a range of its own (the iron thrower's
#   rangeOverride), what it throws (setupExhaust), straight on;
# - a laser or an SPC: a straight ray.
func _gunShape(gun):
	var bore = gun.boresight()
	if not bore is Dictionary:
		return null
	var shape = {
		"start": bore.start,
		"dir": Vector2(0, -1).rotated(bore.direction),
		"range": float(bore.range),
		"half": 0.0,
		"worst": 0.0,
		"endless": false,
		"falloff": 0.0,
		"plume": 0.0,
		"inner": 0.0,
	}
	if "defocusAngleDegrees" in gun:
		var defocus = deg2rad(gun.defocusAngleDegrees)
		shape.half = 0.5 * defocus * (gun.focusCache + gun.focusMin)
		shape.worst = 0.5 * defocus * (1.0 + gun.focusMin)
		shape.endless = true
	elif gun.has_method("getSpread"):
		shape.half = 0.5 * gun.getSpread()
		var tuning = gun.getTuneables().get("TUNE_EMP_POWER", {})
		var top = float(tuning.get("max", gun.powerDraw / 1000.0)) * 1000.0 / gun.powerDraw + 1.0
		shape.worst = 0.5 * (gun.spread + (top - 1.0) * 2.0 * gun.spread)
	elif "heatCone" in gun and "distanceScale" in gun:
		var rect = gun.get_rect()
		shape.plume = ((rect.size - rect.position) * gun.scale).y
		shape.half = pow(0.5, 3) * gun.randomness
		shape.worst = shape.half
		shape.inner = pow(0.25, 3) * gun.randomness # where half the rays go: |randf() - 0.5| <= 1/4
		shape.falloff = float(gun.distanceScale)
	return shape

# The close-up panel: the ship as large as the ship pictures show it, where it fits, its tail near the bottom, with each
# weapon's cone out of the panel (or to its range) and, for a turret, its arcs (_turretOps).
func _closeUp(viewport, bounds, mounted, file):
	var size = Vector2(PANEL_PX, PANEL_PX)
	var scale = min(_shipScale(bounds.size), min(size.x * CLOSE_WIDTH / bounds.size.x, size.y * CLOSE_HEIGHT / bounds.size.y))
	var centre = Vector2(bounds.position.x + bounds.size.x / 2, bounds.end.y - size.y * (0.5 - CLOSE_BOTTOM) / scale)
	var view = _view(centre, scale, size)
	var reach = size.length() / scale
	var turrets = 0
	for m in mounted:
		if m.turret != null:
			turrets += 1
	var arc = TURRET_ARC_PX / sqrt(max(1, turrets))
	var ops = []
	for m in mounted:
		var shape = _gunShape(m.gun)
		if shape == null:
			continue
		if m.turret != null:
			ops += _turretOps(view, m.turret, shape, scale, arc)
		ops += _coneOps(view, shape, min(shape.range, reach), false)
	ops += _scaleBar(size, scale, file + " close-up")
	return yield(_render(viewport, view, size, ops), "completed")

# The wide view: for a fixed weapon, its cone out to its range, with a mark there; for a turret, its pick-up areas,
# the bodies it aims at once they are in one (ships/modules/PDT.gd _on_DefendArea_body_entered), and its weapon's
# range all around where it can aim. The ship is a marker.
func _wideView(viewport, bounds, mounted, file):
	var size = Vector2(PANEL_PX, PANEL_PX)
	var frame = bounds
	var ops = []
	var areas = []
	for m in mounted:
		var shape = _gunShape(m.gun)
		if shape == null:
			continue
		if m.turret != null:
			for area in _pickUpAreas(m.turret):
				areas.append(area)
				frame = frame.merge(_boundsOf(Array(area[0])))
		else:
			var half = max(shape.half, shape.worst)
			frame = frame.merge(_boundsOf([shape.start, shape.start + shape.dir.rotated(half) * shape.range, shape.start + shape.dir.rotated(-half) * shape.range, shape.start + shape.dir * shape.range]))
	frame = frame.grow(max(frame.size.x, frame.size.y) * WIDE_MARGIN)
	var scale = min(size.x / frame.size.x, size.y / frame.size.y)
	var view = _view(frame.position + frame.size / 2, scale, size)
	for area in areas:
		var points = _toPixels(view, area[0])
		var fill = COLOURS[area[1]]
		fill.a = COLOURS.areaFill
		ops.append(["fill", points, fill])
		ops.append(["line", _closed(points), COLOURS[area[1]], LINE_PX])
	for m in mounted:
		var shape = _gunShape(m.gun)
		if shape == null:
			continue
		if m.turret != null:
			ops += _turretRangeOps(view, m.turret, shape)
		else:
			ops += _coneOps(view, shape, shape.range, true)
	var centre = view.xform(bounds.position + bounds.size / 2)
	var radius = max(MARKER_PX, 0.5 * bounds.size.length() * scale + THIN_PX)
	ops.append(["line", _closed(_arc(centre, radius, 0, TAU)), COLOURS.marker, THIN_PX])
	ops += _scaleBar(size, scale, file + " wide")
	return yield(_render(viewport, view, size, ops), "completed")

# A turret's pick-up areas: [outline in world units, "ships", "rocks" or "both"] for each shape of each of its Area2D
# children whose bodies it takes as targets, by the physics layers the area looks at.
func _pickUpAreas(turret) -> Array:
	var out = []
	for area in turret.get_children():
		if not area is Area2D or not area.is_connected("body_entered", turret, "_on_DefendArea_body_entered"):
			continue
		var ships = (area.collision_mask & LAYER_SHIPS) != 0
		var rocks = (area.collision_mask & LAYER_ROCKS) != 0
		if not ships and not rocks:
			continue
		var kind = "both" if ships and rocks else ("ships" if ships else "rocks")
		for child in area.get_children():
			if child is CollisionShape2D and child.shape != null and not child.disabled:
				out.append([_shapeOutline(child.shape, child.global_transform), kind])
	return out

# A turret's arcs in the close-up, around its pivot, `radius` pixels: where it can aim (its gimbalLimit either way from
# rest, all around for -1), where it aims within TURN_SECONDS (rotationPerSecond), and its safety distance (where its
# safety protocol starts looking for what is in the way: PDT.gd isSafeToFireWithAngleAdjustment), when it has that
# protocol.
func _turretOps(view, turret, shape, scale, radius) -> Array:
	var ops = []
	var pivot = turret.get("pivot")
	var at = pivot.global_position if pivot is Node2D else turret.global_position
	var centre = view.xform(at)
	var rest = shape.dir.rotated(-pivot.rotation if pivot is Node2D else 0.0).angle()
	var limit = deg2rad(turret.gimbalLimit) if turret.gimbalLimit >= 0 else PI
	var turn = min(turret.rotationPerSecond * TURN_SECONDS, limit)
	var gimbal = _sector(centre, radius, rest - limit, rest + limit)
	ops.append(["fill", gimbal, COLOURS.gimbal])
	ops.append(["line", _closed(gimbal) if limit < PI else _closed(_arc(centre, radius, 0, TAU)), COLOURS.gimbalEdge, THIN_PX])
	ops.append(["fill", _sector(centre, radius, rest - turn, rest + turn), COLOURS.turn])
	if turret.safetyProtocol:
		ops.append(["line", _closed(_arc(centre, turret.safetyDistance * scale, 0, TAU)), COLOURS.safety, THIN_PX])
	return ops

# A turret's weapon's range in the wide view, around the pivot: a circle where the turret aims all around; else the
# directions it can aim (its gimbalLimit either way from rest) out to the range, and its weapon's cone at rest.
func _turretRangeOps(view, turret, shape) -> Array:
	var pivot = turret.get("pivot")
	var at = pivot.global_position if pivot is Node2D else turret.global_position
	var rest = shape.dir.rotated(-pivot.rotation if pivot is Node2D else 0.0).angle()
	var limit = deg2rad(turret.gimbalLimit) if turret.gimbalLimit >= 0 else PI
	var radius = shape.range * view.get_scale().x
	var centre = view.xform(at)
	if limit >= PI:
		return [["line", _closed(_arc(centre, radius, 0, TAU)), COLOURS.range, THIN_PX]]
	var gimbal = _sector(centre, radius, rest - limit, rest + limit)
	return [["fill", gimbal, COLOURS.gimbal], ["line", _closed(gimbal), COLOURS.gimbalEdge, THIN_PX]] + _coneOps(view, shape, shape.range, true)

# A weapon's cone out to `length` world units: filled at its spread new (a line where it has none), its widest as two
# edges, a mark at the range when `mark`, and for a mass driver, fainter, beyond it; an exhaust weapon's fades as its
# damage does (`falloff`).
func _coneOps(view, shape, length, mark) -> Array:
	var ops = []
	var start = view.xform(shape.start)
	var scale = view.get_scale().x
	var px = length * scale
	var angle = shape.dir.angle()
	if shape.falloff > 0.0:
		var plume = min(shape.plume, length) * scale
		for i in CONE_SLICES:
			var near = plume * i / CONE_SLICES
			var far = plume * (i + 1) / CONE_SLICES
			var colour = COLOURS.plume
			colour.a *= clamp(shape.falloff * scale / max(1.0, (near + far) / 2), PLUME_FAINTEST, 1.0)
			for part in [[shape.half, PLUME_OUTER], [shape.inner, 1.0]]:
				var tinted = colour
				tinted.a *= part[1]
				var piece = _slice(start, near, far, angle - part[0], angle + part[0]) if i > 0 else _sector(start, far, angle - part[0], angle + part[0])
				ops.append(["fill", piece, tinted])
		ops.append(["line", _closed(_sector(start, plume, angle - shape.half, angle + shape.half)), COLOURS.plumeEdge, THIN_PX])
		if px > plume:
			ops.append(["line", PoolVector2Array([start + shape.dir * plume, start + shape.dir * px]), COLOURS.plumeEdge, LINE_PX])
	elif shape.half > 0.0:
		ops.append(["fill", _sector(start, px, angle - shape.half, angle + shape.half), COLOURS.cone])
		ops.append(["line", _sector(start, px, angle - shape.half, angle + shape.half), COLOURS.coneEdge, THIN_PX])
	else:
		ops.append(["line", PoolVector2Array([start, start + shape.dir * px]), COLOURS.coneEdge, LINE_PX])
	if shape.worst > shape.half and shape.falloff <= 0.0:
		for side in [-1, 1]:
			ops.append(["line", PoolVector2Array([start, start + shape.dir.rotated(side * shape.worst) * px]), COLOURS.worst, THIN_PX])
	if mark:
		var spread = max(shape.half, shape.worst) if shape.range <= shape.plume or shape.plume <= 0.0 else 0.0
		var half = spread + atan2(BAR_TICK * 2, max(px, 1.0))
		ops.append(["line", _arc(start, px, angle - half, angle + half), COLOURS.range, LINE_PX])
		if shape.endless:
			var beyond = px * ENDLESS_REACH
			var faint = COLOURS.cone
			faint.a *= 0.5
			if shape.half > 0.0:
				ops.append(["fill", _slice(start, px, beyond, angle - shape.half, angle + shape.half), faint])
			else:
				var line = COLOURS.coneEdge
				line.a *= 0.4
				ops.append(["line", PoolVector2Array([start + shape.dir * px, start + shape.dir * beyond]), line, LINE_PX])
			if shape.worst > shape.half:
				var edge = COLOURS.worst
				edge.a *= 0.4
				for side in [-1, 1]:
					var d = shape.dir.rotated(side * shape.worst)
					ops.append(["line", PoolVector2Array([start + d * px, start + d * beyond]), edge, THIN_PX])
	return ops

# A scale bar at the bottom left: a round length (1, 2 or 5 times a power of ten, in metres) no longer than BAR_SHARE
# of the picture's width. Its length is printed, for the wiki.
func _scaleBar(size, scale, label) -> Array:
	var metres = size.x * BAR_SHARE / (scale * UNITS_PER_METRE)
	var power = pow(10, floor(log(metres) / log(10)))
	var rounded = power
	for factor in [5, 2]:
		if factor * power <= metres:
			rounded = factor * power
			break
	print("SHOTRENDERER scale bar ", label, ": ", rounded, " m")
	var y = size.y - BAR_INSET
	var x1 = BAR_INSET + rounded * UNITS_PER_METRE * scale
	return [
		["line", PoolVector2Array([Vector2(BAR_INSET, y), Vector2(x1, y)]), COLOURS.bar, LINE_PX],
		["line", PoolVector2Array([Vector2(BAR_INSET, y - BAR_TICK), Vector2(BAR_INSET, y + BAR_TICK)]), COLOURS.bar, LINE_PX],
		["line", PoolVector2Array([Vector2(x1, y - BAR_TICK), Vector2(x1, y + BAR_TICK)]), COLOURS.bar, LINE_PX],
	]

# A collision shape's outline in world units, through its node's transform: circles, capsules (Godot 3's height is
# between the centres of its ends), rectangles and convex polygons.
func _shapeOutline(shape, xf: Transform2D) -> PoolVector2Array:
	var local = PoolVector2Array()
	if shape is CircleShape2D:
		local = _arc(Vector2.ZERO, shape.radius, 0, TAU)
	elif shape is CapsuleShape2D:
		var h = shape.height / 2
		local = _arc(Vector2(0, -h), shape.radius, PI, TAU)
		local.append_array(_arc(Vector2(0, h), shape.radius, 0, PI))
	elif shape is RectangleShape2D:
		var e = shape.extents
		local = PoolVector2Array([Vector2(-e.x, -e.y), Vector2(e.x, -e.y), Vector2(e.x, e.y), Vector2(-e.x, e.y)])
	elif shape is ConvexPolygonShape2D:
		local = shape.points
	var out = PoolVector2Array()
	for p in local:
		out.append(xf.xform(p))
	return out

func _toPixels(view, points) -> PoolVector2Array:
	var out = PoolVector2Array()
	for p in points:
		out.append(view.xform(p))
	return out

func _closed(points) -> PoolVector2Array:
	var out = PoolVector2Array(points)
	if out.size() > 0:
		out.append(out[0])
	return out

# Points on an arc from angle `from` to `to` (radians, Godot's: 0 along +x, growing clockwise on screen).
func _arc(centre, radius, from, to) -> PoolVector2Array:
	var steps = max(2, int(ceil(ARC_STEPS * abs(to - from) / TAU)))
	var out = PoolVector2Array()
	for i in steps + 1:
		var a = from + (to - from) * i / steps
		out.append(centre + Vector2(cos(a), sin(a)) * radius)
	return out

func _sector(centre, radius, from, to) -> PoolVector2Array:
	if to - from >= TAU - 0.001:
		return _arc(centre, radius, 0, TAU)
	var out = PoolVector2Array([centre])
	out.append_array(_arc(centre, radius, from, to))
	return out

func _slice(centre, near, far, from, to) -> PoolVector2Array:
	var out = _arc(centre, far, from, to)
	var inner = _arc(centre, near, from, to)
	inner.invert()
	out.append_array(inner)
	return out

# What _render draws over a picture, in pixels: ["fill", points, colour], ["line", points, colour, width],
# ["image", texture, rect].
class Overlay extends Node2D:
	var ops = []

	func _draw():
		for op in ops:
			match op[0]:
				"fill":
					if op[1].size() >= 3:
						draw_colored_polygon(op[1], op[2])
				"line":
					draw_polyline(op[1], op[2], op[3], true)
				"image":
					draw_texture_rect(op[1], op[2], false)
