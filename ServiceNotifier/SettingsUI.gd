extends PanelContainer

# ServiceNotifier's settings screen: one more of the station's right-hand screens, opened from the menu's Services entry
# (Code.gd). It copies the Services screen's frame and place, and is built from the game's
# own Tuning parts, the way enceladus/Tuning.tscn nests them: the header, a window with the description of the selected
# service (framed as the Tuning screen's), then a group of switches per kind of service (Settings.gd KINDS), a switch
# per service, named as the game names it. It behaves like the game's screens (enceladus/Services.gd,
# enceladus/Tuning.gd): the Shower fades it in and out, Esc or the controller's back button closes it, and so does
# focusing another entry of the menu (the screens container's `hidefoka`).

const ServiceNotifier = preload("res://ServiceNotifier/Settings.gd")

const GAME_SHOWER = "res://enceladus/Shower.tscn"
const GAME_HEADER = "res://enceladus/HeaderWithMoney.tscn"
const GAME_TUNING_ITEMS = "res://enceladus/Tuning/TuningItems.tscn"
# The live Tuning screen's description window (enceladus/Tuning.tscn), whose frame the description's copies: the
# margins around it (and their theme), its panel, and the margins inside it.
const GAME_WINDOW_MARGIN = "VB/WindowMargin"
const GAME_WINDOW = "VB/WindowMargin/Window"
const GAME_WINDOW_INSIDE = "VB/WindowMargin/Window/VBoxContainer/MarginContainer"
# A switch row's switch (enceladus/Tuning/TuningBoolValue.tscn).
const GAME_ROW_SWITCH = "HBoxContainer/Value"
# Ends a service's name to make the translation key of its offer, where its row names none, as the Services screen
# makes it (enceladus/ServiceUI.gd view).
const GAME_OFFER_SUFFIX = "_OFFER"
# The lines of text the description's window keeps room for, so the groups below don't move as the description
# changes: the longest, The Twins', with its offer; a longer one makes it grow.
const DESCRIPTION_LINES = 8

var lastFocus
var _settings = ServiceNotifier.shared()
var _serviceRows = [] # the Services screen's rows the mod watches (Code.gd _snRows)
var _description = null
var _scroll = null
var _items = null
var _rows = {} # each row's dictionary by the row's name (its service's serviceName): the same one the row holds as its `tune`
var _services = {} # the Services screen's row of each row, by the row's name

# `services` is the station's Services screen, `tuning` its Tuning screen (or null), `title` the translation key of the
# header, `rows` the Services screen's rows the mod watches.
func setup(services: Control, tuning, title: String, rows: Array):
	name = "ServiceNotifierSettings"
	theme = services.theme
	add_stylebox_override("panel", services.get_stylebox("panel"))
	rect_min_size = services.rect_min_size
	size_flags_horizontal = services.size_flags_horizontal
	size_flags_vertical = services.size_flags_vertical
	_serviceRows = rows
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

# Tuning groups as Tuning.gd fillTuneableSystems builds them, in an Items box as Tuning.tscn has: one per kind of
# service (Settings.gd KINDS), titled by it, with a switch (TuningBoolValue) per service of that kind, in the Services
# screen's order, named by the service's name key, which the game's Labels and Buttons translate; each switch's tooltip
# is the setting's label. A kind without services has no group. The screen is filled each time it opens, so the
# description follows a language change; it is empty until the first row takes the focus.
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
	_services = {}
	var first = null
	for kind in ServiceNotifier.KINDS:
		var tuning = {}
		for service in _serviceRows:
			if not is_instance_valid(service) or ServiceNotifier.kindOf(service) != kind:
				continue
			var row = {
				"type": "bool",
				"default": ServiceNotifier.SETTINGS.alert.default,
				"current": _settings.getValue("alert", service.serviceName),
				"testProtocol": "",
			}
			tuning[service.serviceName] = row
			_rows[service.serviceName] = row
			_services[service.serviceName] = service
		if tuning.empty():
			continue
		var group = load(GAME_TUNING_ITEMS).instance()
		group.system = ServiceNotifier.KINDS[kind].title
		group.key = null
		group.tuning = tuning
		_items.add_child(group)
		group.connect("tuningChanged", self, "_onTuningChanged")
		for row in group.get_children():
			if "tuningItem" in row and _services.has(row.tuningItem):
				var toggle = row.get_node_or_null(GAME_ROW_SWITCH)
				if toggle is Control:
					toggle.hint_tooltip = ServiceNotifier.SETTINGS.alert.label
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

# A service's description: its kind's text, with the service's name, its cooldown where the kind has one (written as
# the game writes a time span, Tool.readableTimeSpan, without zero hours: 30d), and the game's own offer for it, as the
# Services screen shows it; an offer the game has no text for is left out.
func _describe(service):
	var kind = ServiceNotifier.KINDS[ServiceNotifier.kindOf(service)]
	var offerKey = service.serviceOffer if service.serviceOffer else service.serviceName + GAME_OFFER_SUFFIX
	var offer = tr(offerKey) if tr(offerKey) != offerKey else ""
	var args = [tr(service.serviceName)]
	if kind.withCooldown:
		args.append(Tool.readableTimeSpan(service.cooldownHours * 3600, true))
	args.append(offer)
	_description.text = (tr(kind.description) % args).strip_edges()

# A row emits this when it changes, and also when it gets the focus. A switch then sends the `current` of its
# dictionary (TuningBoolValue.gd _focus), which it never updates itself; setting it here keeps a switch from going
# back when it is focused again. setValue stores nothing when the value is unchanged. The window shows the row's
# description, so it follows the selection.
func _onTuningChanged(_group, item, to, _protocol):
	if not _rows.has(item):
		return
	_rows[item].current = to
	_settings.setValue("alert", to, item)
	if is_instance_valid(_services[item]):
		_describe(_services[item])
