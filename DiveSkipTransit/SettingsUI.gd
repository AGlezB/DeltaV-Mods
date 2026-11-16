extends PanelContainer

# DiveSkipTransit's settings screen: one more of the station's right-hand screens, opened from the menu's dive entry
# (StationMenu.gd), built as CrewCheapHireNotifier's is. It copies the Tuning screen's frame and place and is built from
# the game's own Tuning parts, the way enceladus/Tuning.tscn nests them: the header, then groups of switches and
# sliders. It behaves like the game's screens (enceladus/Tuning.gd, enceladus/Crew.gd): the Shower fades it in and out,
# Esc or the controller's back button closes it, and so does focusing another entry of the menu (the screens
# container's `hidefoka`).

const DiveSkipTransit = preload("res://DiveSkipTransit/Settings.gd")

const GAME_SHOWER = "res://enceladus/Shower.tscn"
const GAME_HEADER = "res://enceladus/HeaderWithMoney.tscn"
const GAME_TUNING_ITEMS = "res://enceladus/Tuning/TuningItems.tscn"
# The groups, in display order: the `group` of the settings in it, and its title, a translation key of i18n/en.po.
const GROUPS = [
	["transit", "DIVESKIPTRANSIT_GROUP_TRANSIT"],
	["skip", "DIVESKIPTRANSIT_GROUP"],
]
# The note under the groups: a translation key of i18n/en.po, whose %s is the mark.
const REMASS_NOTE = "DIVESKIPTRANSIT_REMASS_NOTE"
# Ends the name of each switch whose skip charges remass (a `remass` setting), and starts the note that explains it.
const REMASS_MARK = "*"
# The opacity of a row while it doesn't apply (a `dimmedWhen` setting whose switch is on).
const DIMMED = 0.4

var lastFocus
var _settings = DiveSkipTransit.shared()
var _scroll = null
var _items = null
var _rows = {} # each row's description by the row's name: the same dictionary the row holds as its `tune`
var _keys = {} # the setting key of each row, by the row's name
var _rowNodes = {} # each row (the game's TuningBoolValue or TuningFloatValue), by the row's name

# `tuning` is the station's Tuning screen, `title` the translation key of the header.
func setup(tuning: Control, title: String):
	name = "DiveSkipTransitSettings"
	theme = tuning.theme
	add_stylebox_override("panel", tuning.get_stylebox("panel"))
	rect_min_size = tuning.rect_min_size
	size_flags_horizontal = tuning.size_flags_horizontal
	size_flags_vertical = tuning.size_flags_vertical
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
	_scroll = ScrollContainer.new()
	_scroll.name = "ScrollContainer"
	_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	vb.add_child(_scroll)

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
# (TuningFloatValue, with the setting's range, step, unit and format), named by its label in the game's language and,
# where skipping charges remass, REMASS_MARK. Then the note that explains the mark. The screen is filled each time it
# opens, so the names follow a language change.
func _fill():
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
	var first = null
	for entry in GROUPS:
		var tuning = {}
		for key in DiveSkipTransit.SETTINGS:
			var setting = DiveSkipTransit.SETTINGS[key]
			if setting.group != entry[0]:
				continue
			var rowName = tr(setting.label)
			if setting.get("remass", false):
				rowName += " " + REMASS_MARK
			var row = {
				"type": setting.type,
				"default": setting.default,
				"current": _settings.getValue(key),
				"testProtocol": "",
			}
			if setting.type == "float":
				for field in ["min", "max", "step", "unit", "format"]:
					row[field] = setting[field]
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
		if first == null:
			first = group
	var note = Label.new()
	note.name = "RemassNote"
	note.autowrap = true
	note.size_flags_horizontal = SIZE_EXPAND_FILL
	note.text = tr(REMASS_NOTE) % REMASS_MARK
	_items.add_child(note)
	_dimRows()
	if first != null:
		Tool.deferCallWhenIdle(first, "focus")

# A row is dimmed while the switch its setting names in `dimmedWhen` is on: the setting doesn't apply then.
func _dimRows():
	for rowName in _rowNodes:
		var toggle = DiveSkipTransit.SETTINGS[_keys[rowName]].get("dimmedWhen", "")
		_rowNodes[rowName].modulate.a = DIMMED if toggle != "" and _settings.getValue(toggle) else 1.0

# A row emits this when it changes, and also when it gets the focus. A switch then sends the `current` of its
# description (TuningBoolValue.gd _focus), which it never updates itself; setting it here keeps a switch from going
# back when it is focused again (a slider keeps its own, TuningFloatValue.gd changed). setValue stores nothing when the
# value is unchanged.
func _onTuningChanged(_group, item, to, _protocol):
	_rows[item].current = to
	_settings.setValue(_keys[item], to)
	_dimRows()
