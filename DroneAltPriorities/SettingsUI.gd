extends Tabs

# DroneAltPriorities's OMS tab: the switch at the top, a line on what it does, one slider per weight (Settings.gd
# WEIGHTS) with its name before it, and a button that puts every setting back to its default. Built from the
# Geologist tab's own parts (hud/SystemMineralList.gd), as GeologyByMass's tab is: its on/off switch, its names and its
# Minimum value slider, which keeps the game's focus and controller handling (press the value to edit it, left and
# right to change it, accept or cancel to leave). A `Tabs` node, as every page of the OMS is (hud/OMS.tscn).
#
# With a gamepad: the D-pad goes down from the switch through each slider's value to Reset and back up, and stays in the
# tab (_linkFocus). The game's tooltip node (menu/sfx/PlaySoundsOnTheseButtons.tscn) shows a control's tooltip when it
# gets the focus, as on hover, for the controls it took in: each slider has one of its own, which takes in its bar and
# its value (so the weight's description goes on both), and Reset gets one in its row.

const GAME_TOGGLE = "res://hud/components/MineralSystemToggle.tscn"
const GAME_NAME_LABEL = "res://hud/components/MineralLabel.tscn"
const GAME_SLIDER = "res://hud/components/PriceLabel.tscn"
# The slider's value, the button the D-pad lands on, which A turns into the bar (hud/components/PriceLabel.tscn, as
# hud/SystemMineralList.gd getChildOrLabel picks it).
const GAME_SLIDER_VALUE = "Box/MarginContainer/Label"
# The slider's bar, which A turns the value into (hud/components/PriceLabel.tscn).
const GAME_SLIDER_BAR = "Box/HSlider"
# Ends a text's key to make the key of its description, as the game's Tuning screen makes them (Tuning.gd tuningChanged).
const DESCRIPTION_SUFFIX = "_DESC"
const GAME_TOOLTIPS = "res://menu/sfx/PlaySoundsOnTheseButtons.tscn"
const HINT = "DRONEALTPRIORITIES_HINT"
const RESET = "DRONEALTPRIORITIES_RESET"

# The sliders while the switch is off: dimmed, still adjustable. As the Geologist tab dims a switch the HUD can't use
# (hud/SystemMineralList.gd modulateDisabled).
const DIMMED = Color(1, 1, 1, 0.25)
const MARGIN = 16
# The width of each slider's bar, in px: wider than the game's Minimum value bar (hud/components/PriceLabel.tscn), so
# each step is easier to hit.
const SLIDER_WIDTH = 500
# The gap between the switch and its label, in px.
const TOGGLE_SPACING = 12

var _settings
var _toggle
var _grid
var _sliders = {} # by weight key
var _reset

# Builds the tab for `settings` (Settings.gd, one ship's); the values are filled in once it is in the tree.
func setup(settings):
	_settings = settings
	var margin = MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	for side in ["left", "top", "right", "bottom"]:
		margin.add_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	var box = VBoxContainer.new()
	margin.add_child(box)

	var header = HBoxContainer.new()
	header.add_constant_override("separation", TOGGLE_SPACING)
	box.add_child(header)
	_toggle = load(GAME_TOGGLE).instance()
	_toggle.pressed = settings.isEnabled()
	_toggle.connect("toggled", self, "_onEnabledToggled")
	header.add_child(_toggle)
	var title = Label.new()
	title.text = settings.ENABLED.label
	title.size_flags_vertical = SIZE_SHRINK_CENTER
	header.add_child(title)

	var hint = Label.new()
	hint.text = HINT
	hint.autowrap = true
	box.add_child(hint)

	_grid = GridContainer.new()
	_grid.columns = 2
	box.add_child(_grid)
	for desc in settings.WEIGHTS:
		var label = load(GAME_NAME_LABEL).instance()
		label.text = desc.label
		label.focus_mode = FOCUS_NONE
		_grid.add_child(label)
		var slider = load(GAME_SLIDER).instance()
		slider.format = "%s " + desc.unit.replace("%", "%%") # the unit can be % itself
		var bar = slider.get_node(GAME_SLIDER_BAR)
		bar.min_value = desc.min * desc.shown
		bar.max_value = desc.max * desc.shown
		bar.step = desc.step * desc.shown
		bar.rect_min_size.x = SLIDER_WIDTH
		bar.hint_tooltip = desc.label + DESCRIPTION_SUFFIX
		slider.get_node(GAME_SLIDER_VALUE).hint_tooltip = bar.hint_tooltip
		slider.connect("valueChanged", self, "_onWeightChanged", [desc.key])
		_grid.add_child(slider)
		_sliders[desc.key] = slider

	var footer = HBoxContainer.new()
	box.add_child(footer)
	_reset = Button.new()
	_reset.text = RESET
	_reset.hint_tooltip = RESET + DESCRIPTION_SUFFIX
	_reset.connect("pressed", self, "_onResetPressed")
	footer.add_child(_reset)
	if ResourceLoader.exists(GAME_TOOLTIPS):
		footer.add_child(load(GAME_TOOLTIPS).instance())
	_linkFocus()
	_dim()
	connect("visibility_changed", self, "_refresh")

# The D-pad's way through the tab, set as the Geologist tab sets its own (hud/SystemMineralList.gd adjustFocus): down
# from the switch through each slider's value, in WEIGHTS order, to Reset, and back up. At either end, and to the sides,
# it stays where it is, so it never leaves the tab for the rest of the OMS; left and right are the value's once A has
# turned it into the bar.
func _linkFocus():
	var chain = [_toggle]
	for desc in _settings.WEIGHTS:
		chain.append(_sliders[desc.key].get_node(GAME_SLIDER_VALUE))
	chain.append(_reset)
	for i in chain.size():
		var node = chain[i]
		node.focus_neighbour_top = node.get_path_to(chain[max(i - 1, 0)])
		node.focus_neighbour_bottom = node.get_path_to(chain[min(i + 1, chain.size() - 1)])
		node.focus_neighbour_left = "."
		node.focus_neighbour_right = "."

func _ready():
	_refresh()

# The stored values, set only where they differ, so neither a signal nor a write follows. PriceLabel.gd writes its
# value's text from its _ready on, so this waits for the tree.
func _refresh():
	if _settings == null or not is_inside_tree():
		return
	if _toggle.pressed != _settings.isEnabled():
		_toggle.pressed = _settings.isEnabled()
	for key in _sliders:
		var shown = _settings.toShown(key, _settings.getWeight(key))
		if _sliders[key].value != shown:
			_sliders[key].value = shown
	_dim()

func _dim():
	_grid.modulate = Color.white if _settings.isEnabled() else DIMMED

func _onEnabledToggled(how):
	_settings.setEnabled(how)
	_dim()

func _onWeightChanged(shown, key):
	_settings.setWeight(key, _settings.fromShown(key, shown))

func _onResetPressed():
	_settings.reset()
	_refresh()
