extends VBoxContainer

# The dialog's second tab (SettingsUI.gd): the enemy ship, picked from a list laid out as the Dealer and Fleet screens'
# (enceladus/Dealer.tscn), as DealerNotifier's settings screen builds it (DealerNotifier/SettingsUI.gd; the two mods
# ship separately, so its code is copied here, adapted to one choice). A note with the setting's description, then the
# ships, each in a row like a Dealer entry: the ship's picture, its name, and a switch where the Dealer has Buy. The
# rows are the game's Tuning switches in Tuning groups, as enceladus/Tuning.tscn nests them, one group per series.
# The switches act as radio buttons: the current model's is on, switching another on picks it, and the current one
# can't be switched off. The tab's description window (SettingsUI.gd) shows the focused ship's description, as the
# Dealer shows it.

signal describe(text) # the description window's text, for the row that got the focus or changed

const CombatSimulator = preload("res://CombatSimulator/Settings.gd")

# A Tuning switch's own nodes (enceladus/Tuning/TuningBoolValue.tscn): its row, the switch and the reset button.
const GAME_ROW = "HBoxContainer"
const GAME_ROW_SWITCH = "HBoxContainer/Value"
const GAME_ROW_RESET = "HBoxContainer/Reset"
# A Dealer entry (enceladus/SystemBuyUI.tscn, never added to the tree): the size of its picture and the sprite that
# shows it, the width of its Buy button, and the viewport its ship is drawn in (camera, lights, environment).
const GAME_ENTRY = "res://enceladus/SystemBuyUI.tscn"
const GAME_ENTRY_PICTURE = "HBox/Margin"
const GAME_ENTRY_SPRITE = "HBox/Margin/Sprite"
const GAME_ENTRY_BUY = "HBox/Buy"
const GAME_ENTRY_VIEWPORT = "HBox/ViewportContainer/Viewport"
# The faction of the dealer's ships (CurrentGame.gd createShipInstanceWithCache), which the ships drawn here get too.
const GAME_DEALER_FACTION = "dealer"
# A ship's hardpoints in its config: weaponSlot.<hardpoint>.type holds what is mounted (ships/WeaponSlot.gd _getType),
# and SYSTEM_NONE is nothing: a hardpoint's default (WeaponSlot.gd `default`), the Equipment screen's None
# (enceladus/Upgrades/WeaponSlotUpgrade.tscn).
const GAME_HARDPOINTS = "weaponSlot"
const GAME_HARDPOINT_SYSTEM = "type"
const GAME_NO_SYSTEM = "SYSTEM_NONE"
# The hardpoint script and scene: a ship's scene gives it hardpoints as nodes with the script, or as placeholders of the
# scene.
const GAME_HARDPOINT_SCRIPT = "res://ships/WeaponSlot.gd"
const GAME_HARDPOINT_SCENE = "res://weapons/WeaponSlot.tscn"
# The title of the group of the ships whose series has no other ship in the list: a translation key of i18n/en.po.
const OTHERS_LABEL = "COMBATSIMULATOR_OTHERS"
# How long a ship is drawn before its picture is taken, in seconds, so its looks have settled. The Dealer takes its
# entries' pictures at the end of a flicker (enceladus/Flicker.tscn).
const PICTURE_DELAY = 0.5

var _settings = CombatSimulator.shared()
var _note = null
var _scroll = null
var _items = null
var _rows = {} # each row's dictionary by the row's name (its ship's name key): the same one the row holds as its `tune`
var _models = {} # the model of each row, by the row's name
var _rowNodes = {} # each row (the game's TuningBoolValue), by model
var _pictures = {} # each row's picture (a Sprite), by model
var _syncing = false # while the list itself switches a row, whose signal changes nothing
var _entry = null # what is read from a Dealer entry
var _drawing = false
var _drawingLeft = 0 # the pictures still being taken
var _hardpointSlot = null # the hardpoint scene's own slot, read once

func _init():
	name = "ShipList"
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	_note = Label.new()
	_note.name = "Note"
	_note.autowrap = true
	_note.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(_note)
	_scroll = ScrollContainer.new()
	_scroll.name = "ScrollContainer"
	_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	add_child(_scroll)

# Tuning groups as Tuning.gd fillTuneableSystems builds them, in an Items box as Tuning.tscn has: one per series
# (_groups), with a switch per model, on for the current one. Filled each time the dialog opens, so the names follow
# a language change.
func fill():
	_note.text = CombatSimulator.SETTINGS.ship.label + CombatSimulator.DESCRIPTION_SUFFIX
	if _items != null:
		_scroll.remove_child(_items)
		_items.queue_free()
	_items = VBoxContainer.new()
	_items.name = "Items"
	_items.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.add_child(_items)
	_rows = {}
	_models = {}
	_rowNodes = {}
	_pictures = {}
	var current = _settings.getValue("ship")
	var order = []
	for entry in _groups():
		var tuning = {}
		for model in entry[1]:
			# A row is known by its name (a Tuning group keys its rows by it); two models named alike are told apart
			# by their keys.
			var rowName = _settings.modelName(model)
			if _models.has(rowName):
				rowName = "%s (%s)" % [tr(rowName), model]
			var row = {
				"type": "bool",
				"default": model == CombatSimulator.SETTINGS.ship.default,
				"current": model == current,
				"testProtocol": "",
			}
			tuning[rowName] = row
			_rows[rowName] = row
			_models[rowName] = model
			order.append(model)
		var group = load(CombatSimulator.GAME_TUNING_ITEMS).instance()
		group.system = entry[0]
		group.key = null
		group.tuning = tuning
		_items.add_child(group)
		group.connect("tuningChanged", self, "_onTuningChanged")
		for row in group.get_children():
			if "tuningItem" in row and _models.has(row.tuningItem):
				_dressRow(row, _models[row.tuningItem])
	_drawPictures(order)

# The note in the font of the tab's description window (SettingsUI.gd), where the theme of the rows around it would
# give it the menus' large one.
func setNoteFont(font: Font):
	_note.add_font_override("font", font)

# The focus on the current model's row, which then shows its ship, and the list scrolled to it. The list's follow_focus
# scrolls as the row takes the focus, which can come before the tab's rows are laid out: once they are, a frame later,
# the list is scrolled to the row again.
func focusCurrent():
	var row = _rowNodes.get(_settings.getValue("ship"))
	if row == null or not is_instance_valid(row):
		return
	row.focus()
	yield(get_tree(), "idle_frame")
	if is_instance_valid(row) and row.is_inside_tree():
		_scroll.ensure_control_visible(row)

# The groups, in display order, each [its title, its models]: the models of each series (Settings.gd series), titled by
# the series' name (the name of the model the others are variants of), in alphabetical order of the series' names; then
# the models whose series has no other in the list, under OTHERS_LABEL. Inside a group, the models are in alphabetical
# order of their names. Names in the game's language, as the player reads them, whatever the case.
func _groups() -> Array:
	var bySeries = {}
	for model in _settings.models():
		var series = _settings.series(model)
		if not bySeries.has(series):
			bySeries[series] = []
		bySeries[series].append(model)
	var out = []
	var others = []
	for series in bySeries:
		var models = bySeries[series]
		if models.size() > 1:
			models.sort_custom(self, "_isModelBefore")
			out.append([_settings.modelName(series), models])
		else:
			others += models
	out.sort_custom(self, "_isGroupBefore")
	if not others.empty():
		others.sort_custom(self, "_isModelBefore")
		out.append([OTHERS_LABEL, others])
	return out

func _isModelBefore(a, b) -> bool:
	return tr(_settings.modelName(a)).nocasecmp_to(tr(_settings.modelName(b))) < 0

func _isGroupBefore(a, b) -> bool:
	return tr(a[0]).nocasecmp_to(tr(b[0])) < 0

# A Tuning switch dressed as a Dealer entry: the ship's picture first, in a frame of the size of the entry's picture and
# with a sprite placed, scaled and flipped as the entry's; the switch's slot as wide as the entry's Buy button, at the
# row's right end, where Buy is; no reset button. The switch's tooltip is the setting's label.
func _dressRow(row, model):
	var entry = _gameEntry()
	var hbox = row.get_node(GAME_ROW)
	var picture = Control.new()
	picture.name = "Picture"
	picture.rect_min_size = entry.pictureSize
	picture.rect_clip_content = true
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite = Sprite.new()
	sprite.name = "Sprite"
	for property in entry.sprite:
		sprite.set(property, entry.sprite[property])
	sprite.texture = _pictureCache().get(model)
	picture.add_child(sprite)
	hbox.add_child(picture)
	hbox.move_child(picture, 0)
	var reset = row.get_node_or_null(GAME_ROW_RESET)
	if reset is Control:
		reset.visible = false
	var value = row.get_node(GAME_ROW_SWITCH)
	value.rect_min_size.x = max(value.rect_min_size.x, entry.buyWidth)
	value.hint_tooltip = CombatSimulator.SETTINGS.ship.label
	_pictures[model] = sprite
	_rowNodes[model] = row

# What the rows take from a Dealer entry, read once from an instance of its scene that never enters the tree.
func _gameEntry() -> Dictionary:
	if _entry == null:
		_entry = {"pictureSize": Vector2.ZERO, "sprite": {}, "buyWidth": 0.0}
		var scene = load(GAME_ENTRY)
		if scene is PackedScene:
			var node = scene.instance()
			var picture = node.get_node_or_null(GAME_ENTRY_PICTURE)
			if picture is Control:
				_entry.pictureSize = picture.rect_min_size
			var sprite = node.get_node_or_null(GAME_ENTRY_SPRITE)
			if sprite is Sprite:
				for property in ["position", "scale", "centered", "offset", "flip_h", "flip_v"]:
					_entry.sprite[property] = sprite.get(property)
			var buy = node.get_node_or_null(GAME_ENTRY_BUY)
			if buy is Control:
				_entry.buyWidth = buy.rect_size.x
			node.free()
	return _entry

# A row emits this when it changes, and also when it gets the focus, resending its dictionary's `current` (which the
# list keeps up to date). Switching another model on picks it and switches the current one off; switching the current
# one off puts it back on (deferred: the switch is still sending its signal). The window shows the row's ship.
func _onTuningChanged(_group, item, to, _protocol):
	if _syncing or not _models.has(item):
		return
	var model = _models[item]
	var current = _settings.getValue("ship")
	if to and model != current:
		_rows[item].current = true
		_settings.setValue("ship", model)
		_setRow(current, false)
	elif not to and model == current:
		call_deferred("_setRow", model, true)
	emit_signal("describe", _description(model))

# Switches a row on or off, keeping its dictionary's `current` with it, without the row's signal changing anything.
func _setRow(model, on: bool):
	var row = _rowNodes.get(model)
	if row == null or not is_instance_valid(row):
		return
	_rows[row.tuningItem].current = on
	_syncing = true
	row.get_node(GAME_ROW_SWITCH).pressed = on
	_syncing = false

# What Dealer.gd displayShip shows of a ship: its series' description, only where it differs from the ship's own, then
# the ship's.
func _description(model) -> String:
	var own = _settings.modelDescription(model)
	var base = _settings.modelDescription(_settings.series(model))
	if base != own:
		return tr(base) + "\n\n" + tr(own)
	return tr(own)

# The ships' pictures, the way the Dealer makes its entries' (SystemBuyUI.gd addShip, checkPrice, stopUpdating): every
# model at once, each ship drawn in a viewport of its own (a Dealer entry's) and a picture taken once it has settled;
# then the viewport is freed with the ship still in it, and anything the ship put beside itself. The ships set up
# together, sharing the game's budget for that (Tool.gd's idle queue), and wait for their pictures together. Each
# picture shows as soon as it is taken, so the tab opens at once. Kept for the whole game session, in this script's
# metadata: the ships look the same in every save game.
func _drawPictures(order: Array):
	if _drawing:
		return
	var cache = _pictureCache()
	var pending = []
	for model in order:
		if not cache.has(model):
			pending.append(model)
	if pending.empty() or not Shipyard.has_method("getDefaultConfigByName"):
		return
	_drawing = true
	_drawingLeft = pending.size()
	# As a Dealer entry holds its viewport: under a hidden Node2D. The list's own, with timers of its own, so nothing
	# resumes once the station is gone.
	var holder = Node2D.new()
	holder.name = "Pictures"
	holder.visible = false
	add_child(holder)
	for model in pending:
		_drawPicture(model, holder)

# One model's picture (_drawPictures). The ship is drawn as the dealer sells it, but with nothing on its hardpoints
# (_emptyHardpoints), so the picture shows the ship itself. The last picture to be taken frees the holder.
func _drawPicture(model, holder):
	var viewport = _gameViewport()
	var config = Shipyard.getDefaultConfigByName(model)
	var ship = _previewShip(config) if viewport != null and config is Dictionary else null
	if ship != null:
		holder.add_child(viewport)
		var timer = Timer.new()
		timer.one_shot = true
		holder.add_child(timer)
		_emptyHardpoints(ship)
		ship.setDummy(true)
		ship.dummy = true
		ship.setReactorState(false)
		viewport.add_child(ship)
		ship.preheat = false
		ship.cutscene = true
		if not ship.setup:
			yield(ship, "setup")
		viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
		timer.start(PICTURE_DELAY)
		yield(timer, "timeout")
		var picture = _picture(viewport)
		# The viewport goes with the ship still in it, so the ship's areas are freed before the viewport's physics
		# space. A ship taken out first leaves its monitoring areas pointing into that space, and freeing them after it
		# writes into freed memory: an intermittent crash (Godot 3's CollisionObject2DSW _set_space, fixed only in
		# Godot 4.3, PR #81809).
		holder.remove_child(viewport)
		viewport.queue_free()
		timer.queue_free()
		if picture != null:
			_pictureCache()[model] = picture
			var sprite = _pictures.get(model)
			if is_instance_valid(sprite):
				sprite.texture = picture
	elif viewport != null:
		viewport.free()
	_drawingLeft -= 1
	if _drawingLeft == 0:
		holder.queue_free()
		_drawing = false

# A Dealer entry's viewport, taken out of a new instance of the entry's scene, with its camera, lights and environment.
func _gameViewport():
	var scene = load(GAME_ENTRY)
	if not scene is PackedScene:
		return null
	var node = scene.instance()
	var viewport = node.get_node_or_null(GAME_ENTRY_VIEWPORT)
	if viewport is Viewport:
		viewport.get_parent().remove_child(viewport)
	else:
		viewport = null
	node.free()
	return viewport

# A ship of `config`, a full config as the dealer's (Shipyard.gd getDefaultConfigByName), made as the dealer makes its
# ships (createShipByConfig), with what keeps it out of the save game: a transponder (else createShipByConfig registers
# a new one in CurrentGame.state.transponders), a name (else getShipName stores one in state.shipNames) and a making
# time (else the ship is aged at random).
func _previewShip(config: Dictionary):
	if not Shipyard.has_method("createShipByConfig"):
		return null
	config.faction = GAME_DEALER_FACTION
	config.transponder = _settings.modId()
	config.shipName = _settings.modName()
	config.madeIn = CurrentGame.getInGameTimestamp()
	return Shipyard.createShipByConfig(config, true, 0, 1)

# Empties every hardpoint of `ship`, a ship not yet in the tree: in its config, each hardpoint its scene has
# (_hardpoints) and each one the config names holds None. The ship keeps its config by reference, so that is what its
# hardpoints mount as they enter the tree (ships/WeaponSlot.gd _ready). A hardpoint's other settings and the other
# slots (the thrusters, the main engine, …) stay as the dealer sells them.
func _emptyHardpoints(ship):
	var slots = _hardpoints(ship)
	var named = ship.getConfig(GAME_HARDPOINTS)
	if named is Dictionary:
		slots += named.keys()
	for slot in slots:
		ship.setConfig("%s.%s.%s" % [GAME_HARDPOINTS, slot, GAME_HARDPOINT_SYSTEM], GAME_NO_SYSTEM)

# The slots of the hardpoints under `node`, in a ship's scene: the nodes with the hardpoint script, inline, some nested
# (the Kitsune's is Front/WeaponSlot, the Tsukuyomi's in its turrets), and the placeholders of the hardpoint scene
# (RA-TRTL's, the Vulture Prospector's, the OCP-209's). A placeholder stores only the values it overrides
# (get_stored_values): where it leaves its slot to the scene, the slot is the scene's own (_hardpointSceneSlot).
func _hardpoints(node) -> Array:
	var out = []
	for child in node.get_children():
		if child is InstancePlaceholder:
			if child.get_instance_path() == GAME_HARDPOINT_SCENE:
				var slot = child.get_stored_values().get("slot", _hardpointSceneSlot())
				if slot != null:
					out.append(slot)
		else:
			var script = child.get_script()
			if script != null and script.resource_path == GAME_HARDPOINT_SCRIPT:
				out.append(child.slot)
			out += _hardpoints(child)
	return out

# The slot the hardpoint scene gives its root, its own or its script's default: read from one instance, never added to
# the tree, the first time it is needed; null where there is no such scene.
func _hardpointSceneSlot():
	if _hardpointSlot == null:
		var scene = load(GAME_HARDPOINT_SCENE)
		if scene is PackedScene:
			var node = scene.instance()
			if "slot" in node:
				_hardpointSlot = node.slot
			node.free()
	return _hardpointSlot

# The picture as SystemBuyUI.gd stopUpdating takes it; null where the viewport has drawn nothing to take.
func _picture(viewport):
	var image = viewport.get_texture().get_data()
	if image == null or image.is_empty():
		return null
	var texture = ImageTexture.new()
	texture.flags = ImageTexture.FLAG_FILTER | ImageTexture.FLAG_MIPMAPS
	texture.create_from_image(image)
	return texture

func _pictureCache() -> Dictionary:
	var script = get_script()
	if not script.has_meta("pictures"):
		script.set_meta("pictures", {})
	return script.get_meta("pictures")
