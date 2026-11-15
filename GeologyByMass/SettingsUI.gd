extends Tabs

# GeologyByMass's OMS tab: the switch at the top, a line on what it does, and one slider per mineral the HUD can switch
# on in the Geologist tab. Built from that tab's own parts (hud/SystemMineralList.gd): its on/off switch, its mineral
# names, coloured the same way, and its Minimum value slider, which keeps the game's focus and controller handling
# (press the value to edit it, left and right to change it, accept or cancel to leave). A `Tabs` node, as every page
# of the OMS is (hud/OMS.tscn).

const GeologyByMass = preload("res://GeologyByMass/Settings.gd")

const GAME_TOGGLE = "res://hud/components/MineralSystemToggle.tscn"
const GAME_MINERAL_LABEL = "res://hud/components/MineralLabel.tscn"
const GAME_SLIDER = "res://hud/components/PriceLabel.tscn"
const HINT = "GEOLOGYBYMASS_HINT"

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
var _sliders = {} # by mineral

# Builds the tab for `settings` (Settings.gd, one HUD's); the values are filled in once it is in the tree.
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
	title.text = GeologyByMass.ENABLED.label
	title.size_flags_vertical = SIZE_SHRINK_CENTER
	header.add_child(title)

	var hint = Label.new()
	hint.text = HINT
	hint.autowrap = true
	box.add_child(hint)

	_grid = GridContainer.new()
	_grid.columns = 2
	box.add_child(_grid)
	for mineral in settings.minerals():
		var label = load(GAME_MINERAL_LABEL).instance()
		label.mineral = mineral
		label.focus_mode = FOCUS_NONE
		if mineral in CurrentGame.specificMineralColors:
			label.modulate = CurrentGame.specificMineralColors[mineral]
		_grid.add_child(label)
		var slider = load(GAME_SLIDER).instance()
		slider.format = "%s " + GeologyByMass.MIN_MASS.unit
		var bar = slider.get_node("Box/HSlider")
		bar.min_value = GeologyByMass.MIN_MASS.min
		bar.max_value = GeologyByMass.MIN_MASS.max
		bar.step = GeologyByMass.MIN_MASS.step
		bar.rect_min_size.x = SLIDER_WIDTH
		bar.hint_tooltip = GeologyByMass.MIN_MASS.label
		slider.connect("valueChanged", self, "_onMinMassChanged", [mineral])
		_grid.add_child(slider)
		_sliders[mineral] = slider
	_dim()
	connect("visibility_changed", self, "_refresh")

func _ready():
	_refresh()

# The stored values, set only where they differ, so neither a signal nor a write follows. PriceLabel.gd writes its
# value's text from its _ready on, so this waits for the tree.
func _refresh():
	if _settings == null or not is_inside_tree():
		return
	_toggle.pressed = _settings.isEnabled()
	for mineral in _sliders:
		var slider = _sliders[mineral]
		var kg = _settings.getMinMass(mineral)
		if slider.value != kg:
			slider.value = kg
	_dim()

func _dim():
	_grid.modulate = Color.white if _settings.isEnabled() else DIMMED

func _onEnabledToggled(how):
	_settings.setEnabled(how)
	_dim()

func _onMinMassChanged(kg, mineral):
	_settings.setMinMass(mineral, kg)
