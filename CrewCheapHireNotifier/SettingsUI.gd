extends PanelContainer

# CrewCheapHireNotifier's settings screen: one more of the station's right-hand screens, opened from the menu's Crew
# entry (Code.gd). It copies the Tuning screen's frame and place and is built from the game's own Tuning parts, the
# way enceladus/Tuning.tscn nests them. It behaves like the game's screens (enceladus/Tuning.gd, enceladus/Crew.gd):
# the Shower fades it in and out, Esc or the controller's back button closes it, and so does focusing another entry
# of the menu (the screens container's `hidefoka`).

const CrewCheapHireNotifier = preload("res://CrewCheapHireNotifier/Settings.gd")

const GAME_SHOWER = "res://enceladus/Shower.tscn"
const GAME_HEADER = "res://enceladus/HeaderWithMoney.tscn"
const GAME_TUNING_ITEMS = "res://enceladus/Tuning/TuningItems.tscn"
const GROUP_LABEL = "Cheap hire alert"

var lastFocus
var _settings = CrewCheapHireNotifier.shared()
var _scroll = null
var _items = null
var _keys = {} # the setting key of each row, by the row's label

# `tuning` is the station's Tuning screen, `title` the translation key of the header.
func setup(tuning: Control, title: String):
	name = "CrewCheapHireNotifierSettings"
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

# A Tuning group with one row per setting, from the current values, as Tuning.gd fillTuneableSystems builds it.
func _fill():
	if _items != null:
		_scroll.remove_child(_items)
		_items.queue_free()
	var tuning = {}
	_keys = {}
	for key in CrewCheapHireNotifier.SETTINGS:
		var setting = CrewCheapHireNotifier.SETTINGS[key]
		tuning[setting.label] = {
			"type": "float",
			"min": _settings.toShown(key, setting.min),
			"max": _settings.toShown(key, setting.max),
			"step": _settings.toShown(key, setting.step),
			"default": _settings.toShown(key, setting.default),
			"current": _settings.toShown(key, _settings.getValue(key)),
			"unit": setting.unit,
			"testProtocol": "",
		}
		_keys[setting.label] = key
	_items = load(GAME_TUNING_ITEMS).instance()
	_items.system = GROUP_LABEL
	_items.tuning = tuning
	_scroll.add_child(_items)
	_items.connect("tuningChanged", self, "_onTuningChanged")
	Tool.deferCallWhenIdle(_items, "focus")

func _onTuningChanged(_system, item, to, _protocol):
	var key = _keys[item]
	_settings.setValue(key, _settings.fromShown(key, to))
