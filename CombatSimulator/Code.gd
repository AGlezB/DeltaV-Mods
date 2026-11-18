extends "res://enceladus/Enceladus.gd"

# CombatSimulator's extension of the station (enceladus/Enceladus.gd): Shift+Click on the simulator's button, or Shift
# plus its key (the game's jury_rig action, J by default), opens the dialog (SettingsUI.gd) instead of the simulator,
# and its Start runs the arena (CombatLayer.gd) with the ship that screen's simulator would fly. Each button gets a
# tooltip that says so. The station is rebuilt after every load and new game, so the save's settings load here.
# Godot 3 runs _ready and _input at every level of the script chain by itself: neither calls the parent's.

const CombatSimulator = preload("res://CombatSimulator/Settings.gd")
const _CS_SETTINGS_UI = preload("res://CombatSimulator/SettingsUI.gd")
const _CS_COMBAT_LAYER = preload("res://CombatSimulator/CombatLayer.gd")

# The simulator's button, as every screen that has one instances it (Tuning, Equipment, the Dealer and the Fleet).
const _CS_LAUNCH_VR_BUTTON = "res://enceladus/Simulator/LaunchVRButton.tscn"
# The simulator's layer, a child of the station root (enceladus/Enceladus.tscn).
const _CS_SIMULATION_LAYER = "SimulationLayer"
# The Tuning screen among the station's right-hand screens, whose frame the dialog copies.
const _CS_TUNING = "Tuning"
# What each screen's _on_LaunchVR_pressed sends the simulator: Tuning and Equipment (Tuning.gd, Upgrades.gd) their
# previewedConfig, the Dealer and the Fleet (Dealer.gd) their currentConfig.
const _CS_CONFIGS = ["previewedConfig", "currentConfig"]
# The simulator's action (the button's shortcut).
const _CS_ACTION = "jury_rig"
# The buttons' tooltip, a translation key of i18n/en.po: %s the Shift key (twice), the action's key, the mod's name.
const _CS_TOOLTIP = "COMBATSIMULATOR_TOOLTIP"
# The game's tooltip node (with its sounds), as the station's menus and entries instance it.
const _CS_GAME_TOOLTIPS = "res://menu/sfx/PlaySoundsOnTheseButtons.tscn"

var _csButtons = []
var _csTooltips = null
var _csDialog = null
var _csLayer = null
var _csSimulation = null
var _csSim = null # what the dialog's Start runs: the config the screen's simulator would have flown
var _csLastFocus = null # where the focus was when the dialog opened

func _ready():
	CombatSimulator.shared().loadFromState()
	_csSimulation = get_node_or_null(_CS_SIMULATION_LAYER)
	_csLayer = _CS_COMBAT_LAYER.new()
	_csLayer.setup(self)
	add_child(_csLayer)
	if _csSimulation != null:
		move_child(_csLayer, _csSimulation.get_index() + 1)
	_csDialog = _CS_SETTINGS_UI.new()
	_csDialog.setup(menusContainer.get_node_or_null(_CS_TUNING) if menusContainer != null else null)
	add_child(_csDialog)
	_csDialog.connect("startRequested", self, "_csStart")
	if ResourceLoader.exists(_CS_GAME_TOOLTIPS):
		_csTooltips = load(_CS_GAME_TOOLTIPS).instance()
		_csDialog.add_child(_csTooltips)
	if menusContainer != null:
		_csFindButtons(menusContainer)

# Each button gets the tooltip, shown by the game's own tooltip node: the released game moves Godot's tooltips off
# the screen (project.godot display/mouse_cursor/tooltip_position_offset.release) and draws its own, through a
# PlaySoundsOnTheseButtons (menu/sfx/PlaySoundsOnTheseButtons.gd), none of which covers these buttons. One of its own
# sits on the dialog's layer, drawn above the screens: its parent there is no Control, so it takes over nothing by
# itself, and connectSounds registers each button (with the hover and focus sounds the game's menus have). It takes
# over the button's hint_tooltip, and reads it again on every hover, so setting it again is enough.
func _csFindButtons(node):
	for child in node.get_children():
		if child is BaseButton and child.filename == _CS_LAUNCH_VR_BUTTON:
			_csButtons.append(child)
			child.connect("gui_input", self, "_csOnButtonInput", [child])
			child.connect("visibility_changed", self, "_csUpdateTooltip", [child])
			_csUpdateTooltip(child)
			if _csTooltips != null and _csTooltips.has_method("connectSounds"):
				_csTooltips.connectSounds(child)
		_csFindButtons(child)

func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		for button in _csButtons:
			if is_instance_valid(button):
				_csUpdateTooltip(button)

# Rebuilt whenever the button shows, so it follows a change of the key in the game's settings.
func _csUpdateTooltip(button):
	if not button.is_visible_in_tree():
		return
	var shift = OS.get_scancode_string(KEY_SHIFT)
	button.hint_tooltip = tr(_CS_TOOLTIP) % [shift, shift, _csActionKey(), CombatSimulator.shared().modName()]

# The first key bound to the action, as the keyboard shows it.
func _csActionKey() -> String:
	for event in InputMap.get_action_list(_CS_ACTION):
		if event is InputEventKey:
			var code = event.scancode if event.scancode != 0 else event.physical_scancode
			return OS.get_scancode_string(code)
	return ""

# Shift+Click opens the dialog instead of the simulator. The gui_input signal comes before the button's own
# _gui_input, and accepting the press there keeps the button from pressing.
func _csOnButtonInput(event, button):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT and event.shift \
			and not button.disabled:
		button.accept_event()
		_csOpen(button)

# Shift plus the simulator's key opens the dialog. An action bound to a key alone also matches it with Shift held
# (is_action_pressed), while the button's shortcut matches the key exactly, so without the mod Shift+J does nothing at
# the station. The event is marked handled anyway, so nothing after _input sees it. Nothing at the station polls the
# action.
func _input(event):
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not event.shift or event.control or event.alt or event.meta or not event.is_action_pressed(_CS_ACTION):
		return
	if _csSimulation != null and _csSimulation.visible:
		return
	if _csDialog.isOpen() or _csLayer.isRunning():
		return
	for button in _csButtons:
		if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
			get_tree().set_input_as_handled()
			_csOpen(button)
			return

# The ship that screen's simulator would fly; with none, nothing happens, as with the simulator.
func _csOpen(button):
	var screen = button.get_parent()
	while screen != null and _csConfigProperty(screen) == "":
		screen = screen.get_parent()
	if screen == null or _csLayer.isRunning():
		return
	var sim = screen.get(_csConfigProperty(screen))
	if not sim is Dictionary or not sim.has("config"):
		return
	_csSim = sim
	_csLastFocus = button.get_focus_owner()
	_csDialog.open(_csLastFocus, screen.get_global_rect() if screen is Control else Rect2())

# The screen's property its simulator's button sends, or "" for a node that isn't such a screen.
func _csConfigProperty(node) -> String:
	for property in _CS_CONFIGS:
		if property in node:
			return property
	return ""

func _csStart():
	_csLayer.start(_csSim, _csLastFocus)
