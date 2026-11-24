extends CanvasLayer

# CombatSimulator's dialog, opened instead of the simulator (Code.gd): what the next run spawns and how, with Start and
# Cancel. A popup on a layer of its own, the station root's last child, covering the screen it was opened from, which
# stays open behind it. It is laid out as the Crew screen (enceladus/Crew.tscn): the game's tab hints over two tabs,
# which the gamepad's shoulder buttons switch (menu/TabsWithGamepadControl.gd).
# - "Combat simulation": a window with the description of the selected setting, then groups of switches and sliders,
#   the game's own Tuning parts nested as enceladus/Tuning.tscn nests them, then Start and Cancel.
# - "Ship" (the setting's label): the ship list (ShipList.gd), under its own description window, then Start and
#   Cancel. The title stays short: a ship's name in it would make the tab bar wider than the screen.
# Each description window keeps one height, DESCRIPTION_LINES lines, and a longer text scrolls in it, so nothing below
# moves as the selection changes; with a gamepad, on the right stick.
# - Its _input runs before the screens' (the station root's last child: Godot 3 calls _input in reverse tree order),
#   so Esc or the gamepad's back button cancel here, and neither the screen behind nor the station's pause menu sees
#   them.
# - It is an exclusive popup: clicks outside it do nothing, and BaseButton ignores a shortcut outside the top modal
#   popup, so the simulator's button doesn't fire on J meanwhile.

signal startRequested()

const CombatSimulator = preload("res://CombatSimulator/Settings.gd")
const ShipList = preload("res://CombatSimulator/ShipList.gd")

# The theme of the Tuning screen and of the simulator's button (enceladus/Simulator/LaunchVRButton.tscn), for the
# tabs' contents when the Tuning screen is missing.
const GAME_THEME = "res://menu/MenuTheme.tres"
# The Crew screen's theme (its tabs), its tab hints (with the gamepad's buttons) and its tabs' script.
const GAME_TAB_THEME = "res://menu/SubMenuTheme.tres"
const GAME_TAB_HINTS = "res://hud/TabHintContainer.tscn"
const GAME_TABS_SCRIPT = "res://menu/TabsWithGamepadControl.gd"
# The live Tuning screen's description window (enceladus/Tuning.tscn), whose frame the descriptions' copy: the margins
# around it (and their theme), its panel, and the margins inside it.
const GAME_WINDOW_MARGIN = "VB/WindowMargin"
const GAME_WINDOW = "VB/WindowMargin/Window"
const GAME_WINDOW_INSIDE = "VB/WindowMargin/Window/VBoxContainer/MarginContainer"
# A Tuning row's name, the button that shows its key (enceladus/Tuning/TuningFloatValue.tscn, TuningBoolValue.tscn).
const GAME_ROW_NAME = "HBoxContainer/Name"
# The groups of the first tab, in display order: the `group` of the settings in it, and its title, a translation key of
# i18n/en.po. The ship (a "choice") has the second tab.
const GROUPS = [
	["enemies", "COMBATSIMULATOR_GROUP_ENEMIES"],
	["area", "COMBATSIMULATOR_GROUP_AREA"],
	["ship", "COMBATSIMULATOR_GROUP_SHIP"],
]
# The first tab's title and the buttons: translation keys of i18n/en.po. The ship tab's title is the Ship setting's
# label.
const TITLE = "COMBATSIMULATOR_TITLE"
const START = "COMBATSIMULATOR_START"
const CANCEL = "COMBATSIMULATOR_CANCEL"
# The tabs, by their place.
const SETTINGS_TAB_INDEX = 0
const SHIP_TAB_INDEX = 1
# The lines of text each description window shows; a longer text scrolls.
const DESCRIPTION_LINES = 6
# The right stick scrolls the description window of the tab shown, as it scrolls the game's lists: its actions
# (project.godot) and the game's speed at full tilt, in px per second (enceladus/ScrollWithAnalog.gd scrollSpeed). The
# D-pad can't, since nothing in the window takes the focus.
const DESCRIPTION_SCROLL_UP = "ui_scroll_up2"
const DESCRIPTION_SCROLL_DOWN = "ui_scroll_down2"
const DESCRIPTION_SCROLL_SPEED = 800.0
# The layer it draws on: the station screens', the CanvasLayer holding the Tuning screen (enceladus/Enceladus.tscn,
# EnceladusMenu's inner CanvasLayer), below the cursor's MouseLayer. This is that layer's number in the scene, for when
# the Tuning screen is missing.
const LAYER_FALLBACK = 9

var _settings = CombatSimulator.shared()
var pageTheme = null # the theme of the tabs' contents, which the arena's end confirmation takes too (CombatLayer.gd)
var _popup = null
var _root = null
var _tabs = null
var _description = null # the first tab's description
var _shipDescription = null # the second tab's
var _scroll = null
var _items = null
var _firstGroup = null
var _shipList = null
var _lastFocus = null
var _rows = {} # each row's dictionary by the row's name: the same one the row holds as its `tune`
var _keys = {} # the setting key of each row, by the row's name
var _namedRows = {} # the rows named by a choice setting (`namedBy`), by their setting key
var _startCancel = [] # Start and Cancel, on both tabs
var _descriptionScroll = 0.0 # the right stick's scroll of the description shown, in fractions of a pixel

# `tuning` is the station's Tuning screen (or null), whose theme and description window the tabs copy.
func setup(tuning):
	name = "CombatSimulatorDialog"
	layer = LAYER_FALLBACK
	var screensLayer = tuning.get_parent() if tuning is Control else null
	while screensLayer != null and not screensLayer is CanvasLayer:
		screensLayer = screensLayer.get_parent()
	if screensLayer != null:
		layer = screensLayer.layer
	_popup = Popup.new()
	_popup.name = "Popup"
	_popup.popup_exclusive = true
	add_child(_popup)
	pageTheme = tuning.theme if tuning is Control and tuning.theme != null else load(GAME_THEME)
	# Behind the tabs, the Tuning screen's panel: beside the tab titles, the tab bar shows what lies behind it, here the
	# screen the dialog covers.
	var backdrop = Panel.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	if tuning is Control:
		backdrop.add_stylebox_override("panel", tuning.get_stylebox("panel"))
	_popup.add_child(backdrop)
	_root = MarginContainer.new()
	_root.name = "Root"
	_root.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	_root.theme = load(GAME_TAB_THEME) if ResourceLoader.exists(GAME_TAB_THEME) else pageTheme
	_popup.add_child(_root)
	var holder = _root
	if ResourceLoader.exists(GAME_TAB_HINTS):
		holder = load(GAME_TAB_HINTS).instance()
		holder.name = "TabHintContainer"
		_root.add_child(holder)
	_tabs = TabContainer.new()
	_tabs.name = "Tabs"
	_tabs.show_behind_parent = true
	if ResourceLoader.exists(GAME_TABS_SCRIPT):
		_tabs.set_script(load(GAME_TABS_SCRIPT))
	holder.add_child(_tabs)
	var settingsPage = _page(TITLE, pageTheme)
	_description = _addDescriptionWindow(settingsPage, tuning)
	_scroll = ScrollContainer.new()
	_scroll.name = "ScrollContainer"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	settingsPage.add_child(_scroll)
	settingsPage.add_child(_buttons())
	var shipPage = _page(CombatSimulator.SETTINGS.ship.label, pageTheme)
	_shipDescription = _addDescriptionWindow(shipPage, tuning)
	_shipList = ShipList.new()
	shipPage.add_child(_shipList)
	shipPage.add_child(_buttons())
	_shipList.connect("describe", self, "_showDescription", [_shipDescription])
	_tabs.connect("tab_changed", self, "_onTabChanged")
	_settings.connect("settingsChanged", self, "_nameRows")

# A tab: a box named by its title's translation key (a TabContainer shows its children's names, translated), with the
# Tuning screen's theme for what it holds.
func _page(title: String, contentTheme: Theme) -> VBoxContainer:
	var page = VBoxContainer.new()
	page.name = title
	page.theme = contentTheme
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(page)
	return page

# Start and Cancel, the same on both tabs.
func _buttons() -> HBoxContainer:
	var buttons = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGN_CENTER
	for entry in [["Start", START, "_onStart"], ["Cancel", CANCEL, "close"]]:
		var button = Button.new()
		button.name = entry[0]
		button.text = entry[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.connect("pressed", self, entry[2])
		buttons.add_child(button)
		_startCancel.append(button)
	return buttons

# The game's tooltip node (Code.gd's, on this layer) gives Start and Cancel the focus and hover sounds of the game's
# buttons, which the D-pad then plays on them too.
func attachTooltips(tooltips):
	if tooltips == null or not tooltips.has_method("connectSounds"):
		return
	for button in _startCancel:
		tooltips.connectSounds(button)

# A description window, nested as Tuning.tscn nests its own (WindowMargin > Window > … > Description, without the
# simulator's parts), with the live Tuning screen's theme, margins and panel; where the game lacks them, it is plain.
# The text is in a ScrollContainer with no horizontal scroll, so it wraps to the window's width and scrolls when it is
# longer than the window (_keepDescriptionHeight). Returns the text's Label.
func _addDescriptionWindow(page: Control, tuning) -> Label:
	var margin = MarginContainer.new()
	margin.name = "WindowMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var window = PanelContainer.new()
	window.name = "Window"
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(window)
	var inside = MarginContainer.new()
	inside.name = "MarginContainer"
	window.add_child(inside)
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.scroll_horizontal_enabled = false
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inside.add_child(scroll)
	var label = Label.new()
	label.name = "Description"
	label.autowrap = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(label)
	if tuning is Control:
		var gameMargin = tuning.get_node_or_null(GAME_WINDOW_MARGIN)
		if gameMargin is Control:
			margin.theme = gameMargin.theme
		_copyMargins(gameMargin, margin)
		var gameWindow = tuning.get_node_or_null(GAME_WINDOW)
		if gameWindow is Control:
			window.add_stylebox_override("panel", gameWindow.get_stylebox("panel"))
		_copyMargins(tuning.get_node_or_null(GAME_WINDOW_INSIDE), inside)
	page.add_child(margin)
	return label

func _copyMargins(from, to: MarginContainer):
	if from is MarginContainer:
		for side in ["left", "top", "right", "bottom"]:
			to.add_constant_override("margin_" + side, from.get_constant("margin_" + side))

func isOpen() -> bool:
	return _popup != null and _popup.visible

# Opens on the first tab, covering `screen` (its rectangle on the screen, where the screens' layer draws it);
# `lastFocus` gets the focus back when it closes. The game's screens set no minimum size (enceladus/Tuning.tscn): the
# one they are laid out at is the size to copy. Without one, the dialog takes what its parts need, centred.
func open(lastFocus, screen: Rect2):
	if isOpen():
		return
	_lastFocus = lastFocus
	_tabs.current_tab = SETTINGS_TAB_INDEX
	_fill()
	_shipList.fill()
	_shipList.setNoteFont(_shipDescription.get_font("font"))
	_showDescription("", _shipDescription)
	var needed = _root.get_combined_minimum_size()
	if screen.size.x > 0 and screen.size.y > 0:
		_popup.popup(Rect2(screen.position, Vector2(max(screen.size.x, needed.x), max(screen.size.y, needed.y))))
	else:
		_popup.popup_centered_minsize(needed)
	_focusTab(SETTINGS_TAB_INDEX)

func close():
	if not isOpen():
		return
	_popup.hide()
	if _lastFocus != null and is_instance_valid(_lastFocus):
		_lastFocus.grab_focus()

func _onStart():
	_popup.hide()
	emit_signal("startRequested")

func _input(event):
	if isOpen() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_tree().set_input_as_handled()
		close()
	# The tabs' script switches tabs on the shoulder buttons in its own _input, which runs before this one (a child's),
	# and keeps the press only when it switches: at the first or last tab it lets it through, and the screen behind,
	# whose tabs use the same script (enceladus/Dealer.tscn, Upgrades.tscn), would switch its own.
	elif isOpen() and (event.is_action_pressed("ui_page_up") or event.is_action_pressed("ui_page_down")):
		get_tree().set_input_as_handled()

# The right stick on the description window of the tab shown, kept in fractions of a pixel as ScrollWithAnalog.gd keeps
# its scroll, and taken again from the window when something else scrolled it. Time is real time, as there.
func _process(delta):
	if not isOpen() or not InputMap.has_action(DESCRIPTION_SCROLL_UP) or not InputMap.has_action(DESCRIPTION_SCROLL_DOWN):
		return
	var scroll = (_shipDescription if _tabs.current_tab == SHIP_TAB_INDEX else _description).get_parent()
	var speed = Input.get_action_strength(DESCRIPTION_SCROLL_DOWN) - Input.get_action_strength(DESCRIPTION_SCROLL_UP)
	if speed == 0 or abs(scroll.scroll_vertical - _descriptionScroll) > 2:
		_descriptionScroll = float(scroll.scroll_vertical)
	if speed == 0:
		return
	var bar = scroll.get_v_scrollbar()
	var end = max(0.0, bar.max_value - bar.page)
	_descriptionScroll = clamp(_descriptionScroll + speed * DESCRIPTION_SCROLL_SPEED * delta / Engine.time_scale, 0.0, end)
	scroll.scroll_vertical = int(_descriptionScroll)

# A tab shown gets the focus on its first row, and the ship tab on the current ship. The tabs' script focuses the new
# tab's first button when nothing has the focus (TabsWithGamepadControl.gd _tab_changed); this comes after it.
func _onTabChanged(tab):
	_focusTab(tab)

func _focusTab(tab):
	if tab == SHIP_TAB_INDEX:
		Tool.deferCallWhenIdle(_shipList, "focusCurrent")
	elif _firstGroup != null:
		Tool.deferCallWhenIdle(_firstGroup, "focus")
		Tool.deferCallWhenIdle(self, "_scrollToTop")

# Focusing the first row scrolls the list to its slider (the ScrollContainer's follow_focus, before the rows are laid
# out), which hides the first group's title: the list starts at the top again.
func _scrollToTop():
	_scroll.scroll_vertical = 0

# Tuning groups as Tuning.gd fillTuneableSystems builds them, in an Items box as Tuning.tscn has: one per GROUPS entry,
# titled by it, with a row per setting of that group, in SETTINGS order: a switch (TuningBoolValue) or a slider
# (TuningFloatValue, with the setting's range, step, unit and format, in the units shown), named by its label in the
# game's language, or by the model its `namedBy` setting holds (_nameRows). Filled each time the dialog opens, so the
# names and the description follow a language change.
func _fill():
	_showDescription("", _description)
	_keepDescriptionHeight(_description)
	_keepDescriptionHeight(_shipDescription)
	if _items != null:
		_scroll.remove_child(_items)
		_items.queue_free()
	_items = VBoxContainer.new()
	_items.name = "Items"
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_items)
	_rows = {}
	_keys = {}
	_namedRows = {}
	_firstGroup = null
	for entry in GROUPS:
		var tuning = {}
		for key in CombatSimulator.SETTINGS:
			var setting = CombatSimulator.SETTINGS[key]
			if setting.group != entry[0] or not setting.type in ["bool", "float"]:
				continue
			var row = {"type": setting.type, "testProtocol": ""}
			if setting.type == "bool":
				row.default = setting.default
				row.current = _settings.getValue(key)
			else:
				row.default = _settings.toShown(key, setting.default)
				row.current = _settings.toShown(key, _settings.getValue(key))
				row.min = _settings.toShown(key, setting.min)
				row.max = _settings.toShown(key, setting.max)
				row.step = _settings.toShown(key, setting.step)
				row.unit = setting.unit
				row.format = setting.format
			var rowName = tr(setting.label)
			tuning[rowName] = row
			_rows[rowName] = row
			_keys[rowName] = key
		if tuning.empty():
			continue
		var group = load(CombatSimulator.GAME_TUNING_ITEMS).instance()
		group.system = entry[1]
		group.key = null
		group.tuning = tuning
		_items.add_child(group)
		group.connect("tuningChanged", self, "_onTuningChanged")
		if _firstGroup == null:
			_firstGroup = group
		for row in group.get_children():
			if "tuningItem" in row and _keys.has(row.tuningItem) and CombatSimulator.SETTINGS[_keys[row.tuningItem]].has("namedBy"):
				_namedRows[_keys[row.tuningItem]] = row
	_nameRows()

# Each row of a setting with `namedBy` shows the name of the model that setting holds, in the game's language, as the
# ship list names it. The row's key, its `tuningItem`, stays its label: the game's row shows it in its _ready, and its
# group sends it with tuningChanged. Run when the dialog is filled and on settingsChanged, so another ship picked on the
# ship tab shows at once.
func _nameRows():
	for key in _namedRows:
		var row = _namedRows[key]
		if is_instance_valid(row):
			row.get_node(GAME_ROW_NAME).text = tr(_settings.modelName(_settings.getValue(CombatSimulator.SETTINGS[key].namedBy)))

# Room for DESCRIPTION_LINES lines in a description window, as Godot sizes an autowrapping Label: its font's height per
# line and its line spacing between lines. The ScrollContainer holding the text gets that height, and the text scrolls
# beyond it. Run in the tree, where the theme gives both.
func _keepDescriptionHeight(label: Label):
	var lineHeight = label.get_font("font").get_height()
	var spacing = label.get_constant("line_spacing")
	label.get_parent().rect_min_size.y = DESCRIPTION_LINES * lineHeight + (DESCRIPTION_LINES - 1) * spacing

# A description window's text, scrolled back to its start.
func _showDescription(text: String, label: Label):
	label.text = text
	label.get_parent().scroll_vertical = 0

# A row emits this when it changes, and also when it gets the focus. A switch then sends the `current` of its
# dictionary (TuningBoolValue.gd _focus), which it never updates itself; setting it here keeps a switch from going
# back when it is focused again. setValue stores nothing when the value is unchanged. The window shows the row's
# description, as Tuning.gd tuningChanged does.
func _onTuningChanged(_group, item, to, _protocol):
	if not _keys.has(item):
		return
	_rows[item].current = to
	var key = _keys[item]
	var setting = CombatSimulator.SETTINGS[key]
	if setting.type == "bool":
		_settings.setValue(key, to)
	else:
		_settings.setValue(key, _settings.fromShown(key, to))
	_showDescription(tr(setting.label + CombatSimulator.DESCRIPTION_SUFFIX), _description)
