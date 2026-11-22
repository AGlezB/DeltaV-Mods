extends "res://enceladus/Enceladus.gd"

# CombatSimulator's extension of the station (enceladus/Enceladus.gd): Shift+Click on the simulator's button, or Shift
# plus its key (the game's jury_rig action, J by default), opens the dialog (SettingsUI.gd) instead of the simulator,
# and its Start runs the arena (CombatLayer.gd) with the ship that screen's simulator would fly. With a gamepad,
# Badge.gd's PAD_BUTTON on the highlighted button while its PAD_MODIFIER is held (isPadShortcut), or the action's
# gamepad button (Back) while PAD_MODIFIER is held, does the same. Each button gets a Shift badge inside it, on the
# left, whose tooltip says so; it reads PAD_TEXT with a gamepad. The station is rebuilt after every load and new game,
# so the save's settings load here.
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
# The Shift badge's tooltip, a translation key of i18n/en.po: %s the Shift key, the mod's name. And the same while the
# game is played with a gamepad (Badge.gd setShiftTooltips): the button to press, the one to hold, the mod's name.
const _CS_TOOLTIP = "COMBATSIMULATOR_TOOLTIP"
const _CS_TOOLTIP_PAD = "COMBATSIMULATOR_TOOLTIP_PAD"
# The game's tooltip node (with its sounds), as the station's menus and entries instance it.
const _CS_GAME_TOOLTIPS = "res://menu/sfx/PlaySoundsOnTheseButtons.tscn"
# Where the simulator's button holds the game's key glyph showing its key (the J, in a box anchored to its right edge),
# whose place the Shift badge mirrors.
const _CS_KEY_HINT = "MarginContainer/ContextSensitiveControlDisplay"
# The badges' script: their look, and their tooltip as their only interaction.
const _CS_BADGE_SCRIPT = preload("res://CombatSimulator/Badge.gd")
# The Shift badge's node name in a button.
const _CS_SHIFT_BADGE = "CombatSimulatorShiftBadge"

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
	_csDialog = _CS_SETTINGS_UI.new()
	_csDialog.setup(menusContainer.get_node_or_null(_CS_TUNING) if menusContainer != null else null)
	_csLayer = _CS_COMBAT_LAYER.new()
	_csLayer.setup(self, _csSimulation, _csDialog.pageTheme)
	add_child(_csLayer)
	if _csSimulation != null:
		move_child(_csLayer, _csSimulation.get_index() + 1)
	add_child(_csDialog)
	_csDialog.connect("startRequested", self, "_csStart")
	if ResourceLoader.exists(_CS_GAME_TOOLTIPS):
		_csTooltips = load(_CS_GAME_TOOLTIPS).instance()
		_csDialog.add_child(_csTooltips)
		_csDialog.attachTooltips(_csTooltips)
	if menusContainer != null:
		_csFindButtons(menusContainer)

# Each button gets the Shift badge, and the badge the tooltip, shown by the game's own tooltip node: the released game
# moves Godot's tooltips off the screen (project.godot display/mouse_cursor/tooltip_position_offset.release) and draws
# its own, through a PlaySoundsOnTheseButtons (menu/sfx/PlaySoundsOnTheseButtons.gd), none of which covers these
# buttons. One of its own sits on the dialog's layer, drawn above the screens: its parent there is no Control, so it
# takes over nothing by itself, and connectSounds registers each button (with the hover and focus sounds the game's
# menus have) and each badge (without them, Badge.gd). It takes over the badge's hint_tooltip, and reads it again on
# every hover; the button's stays empty, so it shows none.
func _csFindButtons(node):
	for child in node.get_children():
		if child is BaseButton and child.filename == _CS_LAUNCH_VR_BUTTON:
			_csButtons.append(child)
			child.connect("gui_input", self, "_csOnButtonInput", [child])
			_csMakeShiftBadge(child)
			if _csTooltips != null and _csTooltips.has_method("connectSounds"):
				_csTooltips.connectSounds(child)
		_csFindButtons(child)

# The Shift badge (Badge.gd), in the button's own frame and font colour, inside the button on the left, centred on it
# from top to bottom, mirroring the button's key glyph, the J on its right (enceladus/Simulator/LaunchVRButton.tscn):
# as far from the left edge as the J is from the right one (its box's margin from the edge, plus half the room the box,
# which centres it, leaves beside it). Without the J, inside the margin the button keeps around its text (its normal
# stylebox's). A Button doesn't lay out its children, so the badge hangs from it directly, anchored to the middle of its
# left side, and grows right, up and down to its minimum size. On the button, it lets the mouse through: a click on it
# is the button's, as if it weren't there. Its tooltip is shown by the dialog's tooltip node: on hover, and with a
# gamepad, which shows no hover, while the button is highlighted.
func _csMakeShiftBadge(button):
	var badge = _CS_BADGE_SCRIPT.new()
	badge.name = _CS_SHIFT_BADGE
	badge.dress(button, OS.get_scancode_string(KEY_SHIFT), _CS_BADGE_SCRIPT.PAD_TEXT)
	var inset = 0.0
	var key = button.get_node_or_null(_CS_KEY_HINT)
	var box = key.get_parent() if key is Control else null
	if box is Control:
		inset = -box.margin_right + (box.margin_right - box.margin_left - key.rect_min_size.x) / 2
	elif button.get_stylebox("normal") != null:
		inset = button.get_stylebox("normal").get_margin(MARGIN_LEFT)
	badge.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	badge.margin_left = inset
	badge.margin_right = inset
	badge.margin_top = 0
	badge.margin_bottom = 0
	badge.grow_horizontal = Control.GROW_DIRECTION_END
	badge.grow_vertical = Control.GROW_DIRECTION_BOTH
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	button.add_child(badge)
	badge.attachTooltip(_csTooltips, button)
	badge.setShiftTooltips(_CS_TOOLTIP, _CS_TOOLTIP_PAD, CombatSimulator.shared().modName())

# Shift+Click opens the dialog instead of the simulator, and so does its gamepad twin on the highlighted button
# (Badge.gd isPadShortcut). A click's gui_input signal comes before the button's own _gui_input, and accepting the press
# there keeps the button from pressing; Badge.gd's PAD_BUTTON does nothing to a button.
func _csOnButtonInput(event, button):
	var shiftClick = event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT and event.shift
	if (shiftClick or _CS_BADGE_SCRIPT.isPadShortcut(event)) and not button.disabled:
		button.accept_event()
		_csOpen(button)

# Shift plus the simulator's key, or its gamepad button (Back) while Badge.gd's PAD_MODIFIER is held, opens the dialog.
# An action bound to a key alone also matches it with Shift held (is_action_pressed), while the button's shortcut
# matches the key exactly, so without the mod Shift+J does nothing at the station; a gamepad's buttons carry no
# modifiers, so without the mod Back while PAD_MODIFIER is held is Back, which starts the simulator. The event is
# marked handled, and the button's shortcut, which Godot checks after _input (BaseButton's _unhandled_input), never sees
# it. Nothing at the station polls the action.
func _input(event):
	if not _csIsShortcut(event):
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

# Shift plus the simulator's key and nothing else held, or its gamepad button while the gamepad twin's modifier
# (Badge.gd PAD_MODIFIER) is held on the same gamepad.
func _csIsShortcut(event) -> bool:
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return false
	if not event.pressed or event.is_echo() or not event.is_action_pressed(_CS_ACTION):
		return false
	if event is InputEventKey:
		return event.shift and not (event.control or event.alt or event.meta)
	return Input.is_joy_button_pressed(event.device, _CS_BADGE_SCRIPT.PAD_MODIFIER)

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
