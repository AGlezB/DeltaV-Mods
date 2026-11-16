extends PanelContainer

# DiveSkipTransit's settings screen: one more of the station's right-hand screens, opened from the menu's dive entry
# (StationMenu.gd), built as CrewCheapHireNotifier's is. It copies the Tuning screen's frame and place and is built from
# the game's own Tuning parts, the way enceladus/Tuning.tscn nests them: the header, then a group of switches. It
# behaves like the game's screens (enceladus/Tuning.gd, enceladus/Crew.gd): the Shower fades it in and out, Esc or the
# controller's back button closes it, and so does focusing another entry of the menu (the screens container's
# `hidefoka`).

const DiveSkipTransit = preload("res://DiveSkipTransit/Settings.gd")

const GAME_SHOWER = "res://enceladus/Shower.tscn"
const GAME_HEADER = "res://enceladus/HeaderWithMoney.tscn"
const GAME_TUNING_ITEMS = "res://enceladus/Tuning/TuningItems.tscn"
# The title of the group of switches: a translation key of i18n/en.po.
const GROUP_LABEL = "DIVESKIPTRANSIT_GROUP"

var lastFocus
var _settings = DiveSkipTransit.shared()
var _scroll = null
var _items = null
var _rows = {} # each row's description by the row's label: the same dictionary the row holds as its `tune`
var _keys = {} # the setting key of each row, by the row's label

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

# One Tuning group as Tuning.gd fillTuneableSystems builds it, in an Items box as Tuning.tscn has: titled GROUP_LABEL,
# with a switch (TuningBoolValue) per setting, named by its label. The game's Labels translate the title and the names.
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
	for key in DiveSkipTransit.SETTINGS:
		var setting = DiveSkipTransit.SETTINGS[key]
		_rows[setting.label] = {
			"type": setting.type,
			"default": setting.default,
			"current": _settings.getValue(key),
			"testProtocol": "",
		}
		_keys[setting.label] = key
	var group = load(GAME_TUNING_ITEMS).instance()
	group.system = GROUP_LABEL
	group.key = null
	group.tuning = _rows
	_items.add_child(group)
	group.connect("tuningChanged", self, "_onTuningChanged")
	Tool.deferCallWhenIdle(group, "focus")

# A switch emits this when it is toggled, and also when it gets the focus, with the `current` of its description
# (TuningBoolValue.gd _focus), which the row never updates itself. Setting it here keeps a switch from going back when
# it is focused again; setValue stores nothing when the value is unchanged.
func _onTuningChanged(_group, item, to, _protocol):
	_rows[item].current = to
	_settings.setValue(_keys[item], to)
