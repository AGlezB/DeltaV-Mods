extends PanelContainer

# MarketAdvisor's settings screen: one more of the station's right-hand screens, opened from the menu's Mineral Market
# entry (StationMenu.gd), built as DiveSkipTransit's is. It copies the Mineral Market screen's frame and place, and is
# built from the game's own Tuning parts, the way enceladus/Tuning.tscn nests them: the header, a window with the
# description of the selected setting (framed as the Tuning screen's), then groups of sliders and switches. Under the
# cash group's rows, a row of the same layout shows the cash reserve they make, with its tolerance's range, its value
# under theirs. It behaves like the game's screens (enceladus/Tuning.gd, enceladus/Crew.gd): the Shower fades it in and
# out, Esc or the controller's back button closes it, and so does focusing another entry of the menu (the screens
# container's `hidefoka`).

const MarketAdvisor = preload("res://MarketAdvisor/Settings.gd")

const GAME_SHOWER = "res://enceladus/Shower.tscn"
const GAME_HEADER = "res://enceladus/HeaderWithMoney.tscn"
const GAME_TUNING_ITEMS = "res://enceladus/Tuning/TuningItems.tscn"
# The live Tuning screen's description window (enceladus/Tuning.tscn), whose frame the description's copies: the
# margins around it (and their theme), its panel, and the margins inside it.
const GAME_WINDOW_MARGIN = "VB/WindowMargin"
const GAME_WINDOW = "VB/WindowMargin/Window"
const GAME_WINDOW_INSIDE = "VB/WindowMargin/Window/VBoxContainer/MarginContainer"
# A slider row's line (enceladus/Tuning/TuningFloatValue.tscn: its name, value, unit and reset button), the row's
# slider, and the line's parts: the power of ten's row shows its value its own way, and the cash reserve's row is a
# copy of the line.
const GAME_ROW_LINE = "HBoxContainer"
const GAME_ROW_SLIDER = "HSlider"
const GAME_ROW_NAME = "HBoxContainer/Name"
const GAME_ROW_VALUE = "HBoxContainer/Value"
const GAME_ROW_RESET = "HBoxContainer/Reset"
# The groups, in display order: the `group` of the settings in it, and its title, a translation key of i18n/en.po.
const GROUPS = [
	["cash", "MARKETADVISOR_GROUP_CASH"],
	["trade", "MARKETADVISOR_GROUP_TRADE"],
]
# The group whose rows make the cash reserve, and the translation key of the name of the row under them.
const CASH_GROUP = "cash"
const CASH_TOTAL = "MARKETADVISOR_CASH_TOTAL"
# Ends a setting's label to make the translation key of its description, as the game's Tuning screen makes them
# (Tuning.gd tuningChanged).
const DESCRIPTION_SUFFIX = "_DESC"
# The lines of text the description's window keeps room for, so the groups below don't move as the description
# changes; a longer one makes it grow.
const DESCRIPTION_LINES = 5

var lastFocus
var _settings = MarketAdvisor.shared()
var _description = null
var _scroll = null
var _items = null
var _total = null # the value of the cash reserve's row
var _rows = {} # each row's dictionary by the row's name: the same one the row holds as its `tune`
var _keys = {} # the setting key of each row, by the row's name
var _rowNodes = {} # each row (the game's TuningBoolValue or TuningFloatValue), by the row's name

# `market` is the station's Mineral Market screen, `tuning` its Tuning screen (or null), `title` the translation key of
# the header.
func setup(market: Control, tuning, title: String):
	name = "MarketAdvisorSettings"
	theme = market.theme
	add_stylebox_override("panel", market.get_stylebox("panel"))
	rect_min_size = market.rect_min_size
	size_flags_horizontal = market.size_flags_horizontal
	size_flags_vertical = market.size_flags_vertical
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

# Tuning groups as Tuning.gd fillTuneableSystems builds them, in an Items box as Tuning.tscn has: one per GROUPS entry,
# titled by it, with a row per setting of that group, in SETTINGS order: a switch (TuningBoolValue) or a slider
# (TuningFloatValue, with the setting's range, step and value as the screen shows them, toShown, and its unit and
# format), named by its label in the game's language. The screen is filled each time it opens, so the names and the
# description follow a language change; the description is empty until the first row takes the focus.
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
	_rowNodes = {}
	_total = null
	var first = null
	for entry in GROUPS:
		var tuning = {}
		for key in MarketAdvisor.SETTINGS:
			var setting = MarketAdvisor.SETTINGS[key]
			if setting.group != entry[0]:
				continue
			var rowName = tr(setting.label)
			var row = {
				"type": setting.type,
				"default": setting.default,
				"current": _settings.getValue(key),
				"testProtocol": "",
			}
			if setting.type == "float":
				for field in ["min", "max", "step", "default"]:
					row[field] = _settings.toShown(key, setting[field])
				row.current = _settings.toShown(key, row.current)
				row.unit = setting.unit
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
		for row in group.get_children():
			if "tuningItem" in row:
				_rowNodes[row.tuningItem] = row
		if entry[0] == CASH_GROUP:
			_addCashRow(group)
		if first == null:
			first = group
	_showCash()
	if first != null:
		Tool.deferCallWhenIdle(first, "focus")

# The cash reserve's row, under the cash group's rows: a copy of a slider row's line, so its parts sit where theirs do
# and its value right under theirs (their unit is empty). It is copied without its signals, so its reset button can't
# reset the slider it comes from; the button keeps its room but can't be seen, pressed or focused, and neither can the
# name, which is a button in the line.
func _addCashRow(group: Node):
	var template = null
	for row in group.get_children():
		if "tuningItem" in row and row.has_node(GAME_ROW_SLIDER) and row.has_node(GAME_ROW_LINE):
			template = row
			break
	if template == null:
		return
	var line = template.get_node(GAME_ROW_LINE).duplicate(DUPLICATE_SCRIPTS | DUPLICATE_USE_INSTANCING)
	line.name = "CashTotal"
	group.add_child(line)
	var rowName = line.get_node_or_null(GAME_ROW_NAME.get_file())
	if rowName is Control:
		rowName.text = tr(CASH_TOTAL)
		rowName.focus_mode = FOCUS_NONE
		rowName.mouse_filter = MOUSE_FILTER_IGNORE
	var reset = line.get_node_or_null(GAME_ROW_RESET.get_file())
	if reset is BaseButton:
		reset.modulate.a = 0.0
		reset.disabled = true
		reset.focus_mode = FOCUS_NONE
		reset.mouse_filter = MOUSE_FILTER_IGNORE
	_total = line.get_node_or_null(GAME_ROW_VALUE.get_file())

# A setting's argument for its description: its `descriptionArg`, "" for none.
func _descriptionArg(setting: Dictionary) -> String:
	return setting.get("descriptionArg", "")

# A text of i18n/en.po, with `arg` translated in its %s where there is one.
func _text(key: String, arg: String) -> String:
	if arg == "":
		return tr(key)
	return tr(key) % tr(arg)

# Room for DESCRIPTION_LINES lines in the description, as Godot sizes an autowrapping Label: its font's height per line
# and its line spacing between lines. Run in the tree, where the theme gives both.
func _keepDescriptionHeight():
	var lineHeight = _description.get_font("font").get_height()
	var spacing = _description.get_constant("line_spacing")
	_description.rect_min_size.y = DESCRIPTION_LINES * lineHeight + (DESCRIPTION_LINES - 1) * spacing

# The power of ten's row shows the power it stands for (10K … 1B, or 1e4 … 1e9), and the cash reserve's row the cash to
# keep, with its tolerance's range (floorText), both as the notation switch says.
func _showCash():
	var scientific = _settings.getValue("scientific")
	for rowName in _rowNodes:
		if MarketAdvisor.SETTINGS[_keys[rowName]].get("power", false):
			var value = _rowNodes[rowName].get_node_or_null(GAME_ROW_VALUE)
			if value is Label:
				value.text = MarketAdvisor.formatFloor(1, _settings.getValue(_keys[rowName]), scientific)
	if _total is Label:
		_total.text = _settings.floorText()

# A row emits this when it changes, and also when it gets the focus. A switch then sends the `current` of its
# dictionary (TuningBoolValue.gd _focus), which it never updates itself; setting it here keeps a switch from going
# back when it is focused again (a slider keeps its own, TuningFloatValue.gd changed). A slider sends the value it
# shows, stored as fromShown gives it back. setValue stores nothing when the value is unchanged. The window shows the
# row's description, so it follows the selection.
func _onTuningChanged(_group, item, to, _protocol):
	_rows[item].current = to
	var key = _keys[item]
	var setting = MarketAdvisor.SETTINGS[key]
	_settings.setValue(key, _settings.fromShown(key, to) if setting.type == "float" else to)
	_description.text = _text(setting.label + DESCRIPTION_SUFFIX, _descriptionArg(setting))
	_showCash()
