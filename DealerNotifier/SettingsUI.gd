extends PanelContainer

# DealerNotifier's settings screen: one more of the station's right-hand screens, opened from the menu's Dealer entry
# (Code.gd). It copies the Dealer screen's frame and place, and is laid out as that screen is (enceladus/Dealer.tscn):
# the header, a window with the description of the selected ship (the game's own, as the Dealer shows it), the note
# that explains the switches, then the ships, each in a row like a Dealer entry: the ship's picture, its name, and its
# switch where the Dealer has Buy. The rows are the game's Tuning switches in Tuning groups, as enceladus/Tuning.tscn
# nests them, one group per series. It behaves like the game's screens (enceladus/Dealer.gd, enceladus/Tuning.gd): the
# Shower fades it in and out, Esc or the controller's back button closes it, and so does focusing another entry of the
# menu (the screens container's `hidefoka`).

const DealerNotifier = preload("res://DealerNotifier/Settings.gd")

const GAME_SHOWER = "res://enceladus/Shower.tscn"
const GAME_HEADER = "res://enceladus/HeaderWithMoney.tscn"
const GAME_TUNING_ITEMS = "res://enceladus/Tuning/TuningItems.tscn"
# A Dealer entry (enceladus/SystemBuyUI.tscn, never added to the tree): the size of its picture and the sprite that
# shows it, the width of its Buy button, and the viewport its ship is drawn in (camera, lights, environment).
const GAME_ENTRY = "res://enceladus/SystemBuyUI.tscn"
const GAME_ENTRY_PICTURE = "HBox/Margin"
const GAME_ENTRY_SPRITE = "HBox/Margin/Sprite"
const GAME_ENTRY_BUY = "HBox/Buy"
const GAME_ENTRY_VIEWPORT = "HBox/ViewportContainer/Viewport"
# The live Dealer screen's description window, whose frame the description's copies: the margins around it (and their
# theme), its panel and least size, the margins inside it, and the box of its two texts.
const GAME_WINDOW_MARGIN = "VB/VBoxContainer/WindowMargin"
const GAME_WINDOW = "VB/VBoxContainer/WindowMargin/TabHintContainer/Window"
const GAME_WINDOW_INSIDE = "VB/VBoxContainer/WindowMargin/TabHintContainer/Window/DEALER_TAB_DESC/MarginContainer"
const GAME_WINDOW_TEXTS = GAME_WINDOW_INSIDE + "/VBoxContainer/HBoxContainer/VBoxContainer"
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
const OTHERS_LABEL = "DEALERNOTIFIER_OTHERS"
# Ends a translation key to make that of its description: a setting's label, as the game's Tuning screen makes them
# (Tuning.gd tuningChanged), and a ship's name, as the Dealer does (Dealer.gd displayShip).
const DESCRIPTION_SUFFIX = "_DESC"
# How long a ship is drawn before its picture is taken, in seconds, so its looks have settled. The Dealer takes its
# entries' pictures at the end of a flicker (enceladus/Flicker.tscn).
const PICTURE_DELAY = 0.5

var lastFocus
var _settings = DealerNotifier.shared()
var _base = null # the description of the selected ship's series, shown for a variant
var _description = null
var _note = null
var _scroll = null
var _items = null
var _rows = {} # each row's dictionary by the row's name (its ship's name key): the same one the row holds as its `tune`
var _models = {} # the model of each row, by the row's name
var _pictures = {} # each row's picture (a Sprite), by model
var _entry = null # what is read from a Dealer entry
var _drawing = false
var _drawingLeft = 0 # the pictures still being taken
var _hardpointSlot = null # the hardpoint scene's own slot, read once

# `dealer` is the station's Dealer screen, `title` the translation key of the header.
func setup(dealer: Control, title: String):
	name = "DealerNotifierSettings"
	theme = dealer.theme
	add_stylebox_override("panel", dealer.get_stylebox("panel"))
	rect_min_size = dealer.rect_min_size
	size_flags_horizontal = dealer.size_flags_horizontal
	size_flags_vertical = dealer.size_flags_vertical
	var shower = load(GAME_SHOWER).instance()
	shower.name = "Shower"
	add_child(shower)
	var vb = VBoxContainer.new()
	vb.name = "VB"
	vb.size_flags_horizontal = SIZE_EXPAND_FILL
	vb.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(vb)
	var header = load(GAME_HEADER).instance()
	header.name = "HeaderWithMoney"
	header.get_node("MarketLabel").text = title
	vb.add_child(header)
	vb.add_child(_descriptionWindow(dealer))
	_note = Label.new()
	_note.name = "Note"
	_note.autowrap = true
	_note.size_flags_horizontal = SIZE_EXPAND_FILL
	vb.add_child(_note)
	_scroll = ScrollContainer.new()
	_scroll.name = "ScrollContainer"
	_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	vb.add_child(_scroll)

# The description's window, nested as Dealer.tscn nests its own (WindowMargin > Window > MarginContainer > the box of
# the series' description and the ship's), without the tabs and the ship's view behind the texts, with the live Dealer
# screen's theme, margins, panel and least size; where the game lacks them, it is plain. The texts are clipped, as the
# Dealer clips its own.
func _descriptionWindow(dealer: Control) -> Control:
	var margin = MarginContainer.new()
	margin.name = "WindowMargin"
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	var window = PanelContainer.new()
	window.name = "Window"
	window.size_flags_horizontal = SIZE_EXPAND_FILL
	margin.add_child(window)
	var inside = MarginContainer.new()
	inside.name = "MarginContainer"
	inside.rect_clip_content = true
	window.add_child(inside)
	var texts = VBoxContainer.new()
	texts.name = "VBoxContainer"
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	inside.add_child(texts)
	_base = Label.new()
	_base.name = "Base"
	_base.autowrap = true
	_base.visible = false
	texts.add_child(_base)
	_description = Label.new()
	_description.name = "Description"
	_description.autowrap = true
	texts.add_child(_description)
	var gameMargin = dealer.get_node_or_null(GAME_WINDOW_MARGIN)
	if gameMargin is Control:
		margin.theme = gameMargin.theme
	_copyMargins(gameMargin, margin)
	var gameWindow = dealer.get_node_or_null(GAME_WINDOW)
	if gameWindow is Control:
		window.add_stylebox_override("panel", gameWindow.get_stylebox("panel"))
		window.rect_min_size = gameWindow.rect_min_size
	_copyMargins(dealer.get_node_or_null(GAME_WINDOW_INSIDE), inside)
	var gameTexts = dealer.get_node_or_null(GAME_WINDOW_TEXTS)
	if gameTexts is BoxContainer:
		texts.add_constant_override("separation", gameTexts.get_constant("separation"))
	return margin

func _copyMargins(from, to: MarginContainer):
	if from is MarginContainer:
		for side in ["left", "top", "right", "bottom"]:
			to.add_constant_override("margin_" + side, from.get_constant("margin_" + side))

func _ready():
	visible = false
	get_parent().connect("hidefoka", self, "hide")

func show():
	if visible or $Shower.is_playing():
		return
	lastFocus = get_focus_owner()
	$Shower.play("show")
	_fill()

func hide():
	if not visible or $Shower.current_animation == "hide":
		return
	$Shower.play("hide")

func _input(event):
	if visible and (Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("pause")):
		get_tree().set_input_as_handled()
		hide()
		if lastFocus:
			lastFocus.grab_focus()

func unfocus():
	if lastFocus and get_focus_owner() == null:
		lastFocus.grab_focus()
		lastFocus = null

# Tuning groups as Tuning.gd fillTuneableSystems builds them, in an Items box as Tuning.tscn has: one per series
# (_groups), titled by it, with a switch (TuningBoolValue) per ship model, named by the model's name key, which the
# game's Labels and Buttons translate. Each row is then dressed as a Dealer entry (_dressRow). The screen is filled each
# time it opens, so the order follows a language change; the description is empty until the first row takes the focus.
func _fill():
	_note.text = DealerNotifier.SETTINGS.watched.label + DESCRIPTION_SUFFIX
	_base.text = ""
	_base.visible = false
	_description.text = ""
	if _items != null:
		_scroll.remove_child(_items)
		_items.queue_free()
	_items = VBoxContainer.new()
	_items.name = "Items"
	_items.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.add_child(_items)
	_rows = {}
	_models = {}
	_pictures = {}
	var first = null
	var order = []
	for entry in _groups():
		var tuning = {}
		for model in entry[1]:
			var rowName = _settings.shipNameKey(model)
			var row = {
				"type": "bool",
				"default": DealerNotifier.SETTINGS.watched.default,
				"current": _settings.getValue("watched", model),
				"testProtocol": "",
			}
			tuning[rowName] = row
			_rows[rowName] = row
			_models[rowName] = model
			order.append(model)
		var group = load(GAME_TUNING_ITEMS).instance()
		group.system = entry[0]
		group.key = null
		group.tuning = tuning
		_items.add_child(group)
		group.connect("tuningChanged", self, "_onTuningChanged")
		for row in group.get_children():
			if "tuningItem" in row and _models.has(row.tuningItem):
				_dressRow(row, _models[row.tuningItem])
		if first == null:
			first = group
	if first != null:
		Tool.deferCallWhenIdle(first, "focus")
	_drawPictures(order)

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
			out.append([_settings.shipNameKey(series), models])
		else:
			others += models
	out.sort_custom(self, "_isGroupBefore")
	if not others.empty():
		others.sort_custom(self, "_isModelBefore")
		out.append([OTHERS_LABEL, others])
	return out

func _isModelBefore(a, b) -> bool:
	return tr(_settings.shipNameKey(a)).nocasecmp_to(tr(_settings.shipNameKey(b))) < 0

func _isGroupBefore(a, b) -> bool:
	return tr(a[0]).nocasecmp_to(tr(b[0])) < 0

# A Tuning switch dressed as a Dealer entry: the ship's picture first, in a frame of the size of the entry's picture and
# with a sprite placed, scaled and flipped as the entry's; the switch's slot as wide as the entry's Buy button, at the
# row's right end, where Buy is; no reset button. The switch's tooltip is the setting's label.
func _dressRow(row, model):
	var entry = _gameEntry()
	var hbox = row.get_node("HBoxContainer")
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
	var reset = hbox.get_node_or_null("Reset")
	if reset is Control:
		reset.visible = false
	var value = hbox.get_node("Value")
	value.rect_min_size.x = max(value.rect_min_size.x, entry.buyWidth)
	value.hint_tooltip = DealerNotifier.SETTINGS.watched.label
	_pictures[model] = sprite

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

# A row emits this when it changes, and also when it gets the focus. A switch then sends the `current` of its
# dictionary (TuningBoolValue.gd _focus), which it never updates itself; setting it here keeps a switch from going
# back when it is focused again. setValue stores nothing when the value is unchanged. The window shows the row's ship.
func _onTuningChanged(_group, item, to, _protocol):
	if not _models.has(item):
		return
	_rows[item].current = to
	_settings.setValue("watched", to, _models[item])
	_describe(_models[item])

# What Dealer.gd displayShip shows of a ship: its series' description, only where it differs from the ship's own, then
# the ship's. The Labels translate the keys, so the texts follow the game's language.
func _describe(model):
	var key = _settings.shipNameKey(model)
	var base = _settings.baseShipNameKey(model)
	_base.text = base + DESCRIPTION_SUFFIX if base != "" else ""
	_base.visible = base != "" and base != key
	_description.text = key + DESCRIPTION_SUFFIX

# The ships' pictures, the way the Dealer makes its entries' (SystemBuyUI.gd addShip, checkPrice, stopUpdating): every
# model at once, each ship drawn in a viewport of its own (a Dealer entry's) and a picture taken once it has settled;
# then the ship is removed and the viewport freed, with anything the ship put beside itself. The ships set up together,
# sharing the game's budget for that (Tool.gd's idle queue), and wait for their pictures together. Each picture shows as
# soon as it is taken, so the screen opens at once. Kept for the whole game session, in this script's metadata: the
# ships look the same in every save game.
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
	# As a Dealer entry holds its viewport: under a hidden Node2D. The screen's own, with timers of its own, so nothing
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
		viewport.remove_child(ship)
		Tool.remove(ship)
		Tool.remove(viewport)
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
# (the Kitsune's is Front/WeaponSlot), and the placeholders of the hardpoint scene (RA-TRTL's, the Vulture
# Prospector's, the OCP-209's). A placeholder stores only the values it overrides (get_stored_values): where it leaves
# its slot to the scene, the slot is the scene's own (_hardpointSceneSlot).
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

# The slot the hardpoint scene gives its root, its own or its script's default (main, in game 1.92.5): read from one
# instance, never added to the tree, the first time it is needed; null where there is no such scene.
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
