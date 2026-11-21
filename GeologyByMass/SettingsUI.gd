extends Tabs

# GeologyByMass's OMS tab: the switch at the top, a line on what it does, the base slider, then one row per mineral of
# the Geologist tab's columns, Water too: its extra mass slider and the total it gives with the base. Built from that
# tab's own parts (hud/SystemMineralList.gd): its on/off switch, its mineral names, coloured the same way, and its
# Minimum value slider, which keeps the game's focus and controller handling (press the value to edit it, left and
# right to change it, accept or cancel to leave). A `Tabs` node, as every page of the OMS is (hud/OMS.tscn).
#
# With a gamepad: the D-pad goes down from the switch through the base slider's value and each mineral's to the last,
# and back up, and stays in the tab (_linkFocus). Each slider has the game's tooltip node
# (menu/sfx/PlaySoundsOnTheseButtons.tscn), which shows a control's tooltip when it gets the focus, as on hover, for its
# bar and its value: the description goes on both.

const GeologyByMass = preload("res://GeologyByMass/Settings.gd")

const GAME_TOGGLE = "res://hud/components/MineralSystemToggle.tscn"
const GAME_MINERAL_LABEL = "res://hud/components/MineralLabel.tscn"
const GAME_SLIDER = "res://hud/components/PriceLabel.tscn"
# The slider's value, the button the D-pad lands on, which A turns into the bar (hud/components/PriceLabel.tscn, as
# hud/SystemMineralList.gd getChildOrLabel picks it).
const GAME_SLIDER_VALUE = "Box/MarginContainer/Label"
# The slider's bar, which A turns the value into (hud/components/PriceLabel.tscn).
const GAME_SLIDER_BAR = "Box/HSlider"
# Ends a text's key to make the key of its description, as the game's Tuning screen makes them (Tuning.gd tuningChanged).
const DESCRIPTION_SUFFIX = "_DESC"
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
# What each mineral's slider shows (its extra mass) and the total after it (the base plus that), with the unit after
# each.
const EXTRA_FORMAT = "+%s "
const TOTAL_FORMAT = "= %s "

var _settings
var _toggle
var _grid
var _baseSlider
var _sliders = {} # by mineral
var _totals = {} # by mineral

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
	title.text = GeologyByMass.ENABLED.label
	title.size_flags_vertical = SIZE_SHRINK_CENTER
	header.add_child(title)

	var hint = Label.new()
	hint.text = HINT
	hint.autowrap = true
	box.add_child(hint)

	_grid = GridContainer.new()
	_grid.columns = 3
	box.add_child(_grid)

	var base = GeologyByMass.BASE_MASS
	var baseName = load(GAME_MINERAL_LABEL).instance()
	baseName.text = base.label
	baseName.focus_mode = FOCUS_NONE
	_grid.add_child(baseName)
	_baseSlider = _slider(base, "%s ", base.label + DESCRIPTION_SUFFIX)
	_baseSlider.connect("valueChanged", self, "_onBaseMassChanged")
	_grid.add_child(_baseSlider)
	_grid.add_child(Control.new())

	var extra = GeologyByMass.EXTRA_MASS
	for mineral in settings.minerals():
		var label = load(GAME_MINERAL_LABEL).instance()
		label.mineral = mineral
		label.focus_mode = FOCUS_NONE
		if mineral in CurrentGame.specificMineralColors:
			label.modulate = CurrentGame.specificMineralColors[mineral]
		_grid.add_child(label)
		var slider = _slider(extra, EXTRA_FORMAT, extra.label)
		slider.connect("valueChanged", self, "_onExtraMassChanged", [mineral])
		_grid.add_child(slider)
		_sliders[mineral] = slider
		var total = Label.new()
		total.valign = Label.VALIGN_CENTER
		_grid.add_child(total)
		_totals[mineral] = total
	_showTotals()
	_linkFocus()
	_dim()
	connect("visibility_changed", self, "_refresh")

# The D-pad's way through the tab, set as the Geologist tab sets its own (hud/SystemMineralList.gd adjustFocus): down
# from the switch through the base slider's value, then each mineral's in the rows' order, and back up. At either end,
# and to the sides, it stays where it is, so it never leaves the tab for the rest of the OMS; left and right are the
# value's once A has turned it into the bar.
func _linkFocus():
	var chain = [_toggle, _baseSlider.get_node(GAME_SLIDER_VALUE)]
	for mineral in _settings.minerals():
		chain.append(_sliders[mineral].get_node(GAME_SLIDER_VALUE))
	for i in chain.size():
		var node = chain[i]
		node.focus_neighbour_top = node.get_path_to(chain[max(i - 1, 0)])
		node.focus_neighbour_bottom = node.get_path_to(chain[min(i + 1, chain.size() - 1)])
		node.focus_neighbour_left = "."
		node.focus_neighbour_right = "."

func _ready():
	_refresh()

# A Minimum value control for a setting described by `desc` (Settings.gd), showing its value as `format` with the unit
# after it.
func _slider(desc, format, tooltip):
	var slider = load(GAME_SLIDER).instance()
	slider.format = format + desc.unit
	var bar = slider.get_node(GAME_SLIDER_BAR)
	bar.min_value = desc.min
	bar.max_value = desc.max
	bar.step = desc.step
	bar.rect_min_size.x = SLIDER_WIDTH
	bar.hint_tooltip = tooltip
	slider.get_node(GAME_SLIDER_VALUE).hint_tooltip = tooltip
	return slider

# The stored values, set only where they differ, so neither a signal nor a write follows. PriceLabel.gd writes its
# value's text from its _ready on, so this waits for the tree.
func _refresh():
	if _settings == null or not is_inside_tree():
		return
	_toggle.pressed = _settings.isEnabled()
	var base = _settings.getBaseMass()
	if _baseSlider.value != base:
		_baseSlider.value = base
	for mineral in _sliders:
		var slider = _sliders[mineral]
		var kg = _settings.getExtraMass(mineral)
		if slider.value != kg:
			slider.value = kg
	_showTotals()
	_dim()

func _showTotals():
	for mineral in _totals:
		_showTotal(mineral)

func _showTotal(mineral):
	_totals[mineral].text = (TOTAL_FORMAT + GeologyByMass.EXTRA_MASS.unit) % CurrentGame.formatThousands(_settings.getMinMass(mineral))

func _dim():
	_grid.modulate = Color.white if _settings.isEnabled() else DIMMED

func _onEnabledToggled(how):
	_settings.setEnabled(how)
	_dim()

func _onBaseMassChanged(kg):
	_settings.setBaseMass(kg)
	_showTotals()

func _onExtraMassChanged(kg, mineral):
	_settings.setExtraMass(mineral, kg)
	_showTotal(mineral)
