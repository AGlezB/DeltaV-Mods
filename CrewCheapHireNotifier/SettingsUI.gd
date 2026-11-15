extends PanelContainer

# CrewCheapHireNotifier's settings screen: one more of the station's right-hand screens, opened from the menu's Crew
# entry (Code.gd). It copies the Tuning screen's frame and place and is built from the game's own Tuning parts, the
# way enceladus/Tuning.tscn nests them: the header, then the groups of rows. It behaves like the game's screens
# (enceladus/Tuning.gd, enceladus/Crew.gd): the Shower fades it in and out, Esc or the controller's back button closes
# it, and so does focusing another entry of the menu (the screens container's `hidefoka`).

const CrewCheapHireNotifier = preload("res://CrewCheapHireNotifier/Settings.gd")

const GAME_SHOWER = "res://enceladus/Shower.tscn"
const GAME_HEADER = "res://enceladus/HeaderWithMoney.tscn"
const GAME_TUNING_ITEMS = "res://enceladus/Tuning/TuningItems.tscn"
# The title of the group of the settings that are not per job: a translation key of i18n/en.po.
const GROUP_LABEL = "CREWCHEAPHIRENOTIFIER_GROUP"

var lastFocus
var _settings = CrewCheapHireNotifier.shared()
var _scroll = null
var _items = null
var _keys = {} # the setting key of each row of the first group, by the row's label

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

# Tuning groups as Tuning.gd fillTuneableSystems builds them, in an Items box as Tuning.tscn has: first one with a row
# per setting that is not per job, titled GROUP_LABEL, then one for each per-job setting, titled by its label, with a
# row per job named by the job's key, in alphabetical order of the jobs' names. The game's Labels translate every
# title and row name.
func _fill():
	if _items != null:
		_scroll.remove_child(_items)
		_items.queue_free()
	_items = VBoxContainer.new()
	_items.name = "Items"
	_items.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.add_child(_items)
	_keys = {}
	var general = {}
	for key in CrewCheapHireNotifier.SETTINGS:
		if not _settings.isPerJob(key):
			var label = CrewCheapHireNotifier.SETTINGS[key].label
			general[label] = _row(key, _settings.getValue(key))
			_keys[label] = key
	if not general.empty():
		_addGroup(GROUP_LABEL, null, general)
	for key in CrewCheapHireNotifier.SETTINGS:
		if _settings.isPerJob(key):
			var rows = {}
			for job in _jobsByName():
				rows[job] = _row(key, _settings.getValue(key, job))
			_addGroup(CrewCheapHireNotifier.SETTINGS[key].label, key, rows)
	if _items.get_child_count() > 0:
		Tool.deferCallWhenIdle(_items.get_child(0), "focus")

# The jobs in alphabetical order of their names in the game's language, as the player reads them, whatever the case.
# The screen is filled each time it opens, so the order follows a language change.
func _jobsByName() -> Array:
	var list = _settings.jobs()
	list.sort_custom(self, "_isJobNameBefore")
	return list

func _isJobNameBefore(a, b) -> bool:
	return tr(a).nocasecmp_to(tr(b)) < 0

# `key` comes back as the first argument of tuningChanged: a per-job setting's key, or null for the first group.
func _addGroup(title, key, rows):
	var group = load(GAME_TUNING_ITEMS).instance()
	group.system = title
	group.key = key
	group.tuning = rows
	_items.add_child(group)
	group.connect("tuningChanged", self, "_onTuningChanged")

# One row of a setting, starting from `value`, in the units shown.
func _row(key, value):
	var setting = CrewCheapHireNotifier.SETTINGS[key]
	return {
		"type": "float",
		"min": _settings.toShown(key, setting.min),
		"max": _settings.toShown(key, setting.max),
		"step": _settings.toShown(key, setting.step),
		"default": _settings.toShown(key, setting.default),
		"current": _settings.toShown(key, value),
		"unit": setting.unit,
		"testProtocol": "",
	}

# A row emits this when it gets the focus too (TuningFloatValue.gd _focus), with its value unchanged, and then
# setValue stores nothing. In a per-job setting's group, the row is the job.
func _onTuningChanged(group, item, to, _protocol):
	if CrewCheapHireNotifier.SETTINGS.has(group):
		_settings.setValue(group, _settings.fromShown(group, to), item)
	else:
		var key = _keys[item]
		_settings.setValue(key, _settings.fromShown(key, to))
