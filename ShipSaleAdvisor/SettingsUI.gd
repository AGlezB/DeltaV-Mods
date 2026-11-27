extends PanelContainer

# ShipSaleAdvisor's settings screen: one more of the station's right-hand screens, opened by Shift+Click (or its
# gamepad twin) on a Sell button of the Fleet screen (Code.gd). It copies the Fleet
# screen's frame and place, and is built from the game's own Tuning parts, the way enceladus/Tuning.tscn nests them:
# the header, a window with the description of the selected setting (framed as the Tuning screen's), then the group of
# sliders. It behaves like the game's screens (enceladus/Tuning.gd, enceladus/Crew.gd): the Shower fades it in and out,
# focusing another entry of the menu closes it (the screens container's `hidefoka`), and Esc or the controller's back
# button closes it and shows the Fleet screen again, with the focus on the Sell button that opened it.

const ShipSaleAdvisor = preload("res://ShipSaleAdvisor/Settings.gd")

const GAME_SHOWER = "res://enceladus/Shower.tscn"
const GAME_HEADER = "res://enceladus/HeaderWithMoney.tscn"
const GAME_TUNING_ITEMS = "res://enceladus/Tuning/TuningItems.tscn"
# The live Tuning screen's description window (enceladus/Tuning.tscn), whose frame the description's copies: the
# margins around it (and their theme), its panel, and the margins inside it.
const GAME_WINDOW_MARGIN = "VB/WindowMargin"
const GAME_WINDOW = "VB/WindowMargin/Window"
const GAME_WINDOW_INSIDE = "VB/WindowMargin/Window/VBoxContainer/MarginContainer"
# The Fleet screen's header (enceladus/Owned.tscn), whose title the screen takes, and its Shower, whose hiding the
# screen waits out before showing the Fleet screen again (Dealer.gd show does nothing while it plays).
const GAME_FLEET_TITLE = "VB/HeaderWithMoney/MarketLabel"
const GAME_FLEET_SHOWER = "Shower"
# The groups, in display order: the `group` of the settings in it, and its title, a translation key of i18n/en.po.
const GROUPS = [
	["sale", "SHIPSALEADVISOR_GROUP_SALE"],
]
# Ends a setting's label to make the translation key of its description, as the game's Tuning screen makes them
# (Tuning.gd tuningChanged).
const DESCRIPTION_SUFFIX = "_DESC"
# The lines of text the description's window keeps room for, so the group below doesn't move as the description
# changes; a longer one makes it grow.
const DESCRIPTION_LINES = 5
# The frames the screen waits, at most, for the Fleet screen to finish hiding, and then for it to list its ships and
# focus its first entry (Dealer.gd doAddShips) before the Sell button takes the focus back.
const WAIT_HIDDEN_FRAMES = 120
const WAIT_LISTED_FRAMES = 6

var lastFocus
var _settings = ShipSaleAdvisor.shared()
var _description = null
var _scroll = null
var _items = null
var _rows = {} # each row's dictionary by the row's name: the same one the row holds as its `tune`
var _keys = {} # the setting key of each row, by the row's name
var _fleet = null # the Fleet screen, shown again on closing
var _fleetLastFocus = null # what the Fleet screen gives the focus back to when it closes (Dealer.gd lastFocus)
var _returnTo = null # the Sell button that opened the screen

# `fleet` is the station's Fleet screen, `tuning` its Tuning screen (or null).
func setup(fleet: Control, tuning):
	name = "ShipSaleAdvisorSettings"
	theme = fleet.theme
	add_stylebox_override("panel", fleet.get_stylebox("panel"))
	rect_min_size = fleet.rect_min_size
	size_flags_horizontal = fleet.size_flags_horizontal
	size_flags_vertical = fleet.size_flags_vertical
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
	var title = fleet.get_node_or_null(GAME_FLEET_TITLE)
	header.get_node("MarketLabel").text = title.text if title is Label else ""
	vb.add_child(header)
	vb.add_child(_descriptionWindow(tuning))
	_scroll = ScrollContainer.new()
	_scroll.name = "ScrollContainer"
	_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	vb.add_child(_scroll)

# The description's window, nested as Tuning.tscn nests its own (WindowMargin > Window > … > Description, without the
# simulator's parts), with the live Tuning screen's theme, margins and panel; where the game lacks them, it is plain.
func _descriptionWindow(tuning) -> Control:
	var margin = MarginContainer.new()
	margin.name = "WindowMargin"
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	var window = PanelContainer.new()
	window.name = "Window"
	window.size_flags_horizontal = SIZE_EXPAND_FILL
	margin.add_child(window)
	var inside = MarginContainer.new()
	inside.name = "MarginContainer"
	window.add_child(inside)
	_description = Label.new()
	_description.name = "Description"
	_description.autowrap = true
	_description.size_flags_horizontal = SIZE_EXPAND_FILL
	inside.add_child(_description)
	if tuning is Control:
		var gameMargin = tuning.get_node_or_null(GAME_WINDOW_MARGIN)
		if gameMargin is Control:
			margin.theme = gameMargin.theme
		_copyMargins(gameMargin, margin)
		var gameWindow = tuning.get_node_or_null(GAME_WINDOW)
		if gameWindow is Control:
			window.add_stylebox_override("panel", gameWindow.get_stylebox("panel"))
		_copyMargins(tuning.get_node_or_null(GAME_WINDOW_INSIDE), inside)
	return margin

func _copyMargins(from, to: MarginContainer):
	if from is MarginContainer:
		for side in ["left", "top", "right", "bottom"]:
			to.add_constant_override("margin_" + side, from.get_constant("margin_" + side))

func _ready():
	visible = false
	get_parent().connect("hidefoka", self, "hide")

# Opens the screen from the Fleet screen, as a menu entry opens its own: the other screens hide (`hidefoka`), the
# Fleet screen with them. `returnTo` is the Sell button clicked; the Fleet screen's own way back to the menu is kept
# for when it shows again.
func open(fleet: Control, returnTo: Control):
	_fleet = fleet
	_fleetLastFocus = fleet.get("lastFocus")
	_returnTo = returnTo
	get_parent().hidefoka()
	show()

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

func _input(_event):
	if visible and (Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("pause")):
		get_tree().set_input_as_handled()
		hide()
		_backToFleet()

func unfocus():
	if lastFocus and get_focus_owner() == null:
		lastFocus.grab_focus()
		lastFocus = null

# The Fleet screen again, once it has finished hiding, with its own way back to the menu as it had it, and the focus
# on the Sell button that opened the settings once the screen has listed its ships (it focuses its first entry then).
func _backToFleet():
	var fleet = _fleet
	if not is_instance_valid(fleet):
		return
	var shower = fleet.get_node_or_null(GAME_FLEET_SHOWER)
	for i in WAIT_HIDDEN_FRAMES:
		if not (shower is AnimationPlayer and shower.is_playing()):
			break
		yield(get_tree(), "idle_frame")
	if not is_instance_valid(fleet):
		return
	fleet.show()
	if "lastFocus" in fleet and is_instance_valid(_fleetLastFocus):
		fleet.lastFocus = _fleetLastFocus
	for i in WAIT_LISTED_FRAMES:
		yield(get_tree(), "physics_frame")
	var button = _returnTo
	if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
		button.grab_focus()

# The Tuning group as Tuning.gd fillTuneableSystems builds them, in an Items box as Tuning.tscn has: one per GROUPS
# entry, titled by it, with a row per setting of that group, in SETTINGS order: a slider (TuningFloatValue, with the
# setting's range, step and value as the screen shows them, toShown, and its unit), named by its label in the game's
# language. The screen is filled each time it opens, so the names and the description follow a language change; the
# description is empty until the first row takes the focus.
func _fill():
	_description.text = ""
	_keepDescriptionHeight()
	if _items != null:
		_scroll.remove_child(_items)
		_items.queue_free()
	_items = VBoxContainer.new()
	_items.name = "Items"
	_items.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.add_child(_items)
	_rows = {}
	_keys = {}
	var first = null
	for entry in GROUPS:
		var tuning = {}
		for key in ShipSaleAdvisor.SETTINGS:
			var setting = ShipSaleAdvisor.SETTINGS[key]
			if setting.group != entry[0]:
				continue
			var rowName = tr(setting.label)
			var row = {
				"type": setting.type,
				"current": _settings.toShown(key, _settings.getValue(key)),
				"testProtocol": "",
				"unit": setting.unit,
			}
			for field in ["min", "max", "step", "default"]:
				row[field] = _settings.toShown(key, setting[field])
			if setting.has("format"):
				row.format = setting.format
			tuning[rowName] = row
			_rows[rowName] = row
			_keys[rowName] = key
		if tuning.empty():
			continue
		var group = load(GAME_TUNING_ITEMS).instance()
		group.system = entry[1]
		group.key = null
		group.tuning = tuning
		_items.add_child(group)
		group.connect("tuningChanged", self, "_onTuningChanged")
		if first == null:
			first = group
	if first != null:
		Tool.deferCallWhenIdle(first, "focus")

# Room for DESCRIPTION_LINES lines in the description, as Godot sizes an autowrapping Label: its font's height per line
# and its line spacing between lines. Run in the tree, where the theme gives both.
func _keepDescriptionHeight():
	var lineHeight = _description.get_font("font").get_height()
	var spacing = _description.get_constant("line_spacing")
	_description.rect_min_size.y = DESCRIPTION_LINES * lineHeight + (DESCRIPTION_LINES - 1) * spacing

# A row emits this when it changes, and also when it gets the focus. A slider sends the value it shows, stored as
# fromShown gives it back (TuningFloatValue.gd changed keeps its own). setValue stores nothing when the value is
# unchanged. The window shows the row's description, so it follows the selection.
func _onTuningChanged(_group, item, to, _protocol):
	_rows[item].current = to
	var key = _keys[item]
	var setting = ShipSaleAdvisor.SETTINGS[key]
	_settings.setValue(key, _settings.fromShown(key, to))
	_description.text = tr(setting.label + DESCRIPTION_SUFFIX)
