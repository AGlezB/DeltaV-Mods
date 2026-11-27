extends Tabs

# GeologyByMass's OMS tab: the switch at the top, a line on what it does, the switch that turns every mineral on when a
# dive starts, then one row per mineral of the Geologist tab's columns, Water too: its switch, its name, its least mass
# slider and what that mass is worth at the day's price; at the bottom, a line on the geologist aboard, whose estimates
# the masses are judged on. Built from that tab's own parts (hud/SystemMineralList.gd): its on/off switches, its
# mineral names, coloured the same way, and its Minimum value slider, which keeps the game's focus and controller
# handling (press the value to edit it, left and right to change it, accept or cancel to leave). A `Tabs` node, as
# every page of the OMS is (hud/OMS.tscn).
#
# With a gamepad: the D-pad goes down from the switch at the top, through the switch for the start of a dive, into the
# rows, up and down a column (the switches, or the sliders' values), and left and right between a row's switch and its
# slider's value, and stays in the tab (_linkFocus). Each slider has the game's tooltip node
# (menu/sfx/PlaySoundsOnTheseButtons.tscn), which shows a control's tooltip when it gets the focus, as on hover, for its
# bar and its value: the description goes on both. Each mineral switch gets one of its own.

const GeologyByMass = preload("res://GeologyByMass/Settings.gd")

const GAME_TOGGLE = "res://hud/components/MineralSystemToggle.tscn"
const GAME_MINERAL_LABEL = "res://hud/components/MineralLabel.tscn"
const GAME_SLIDER = "res://hud/components/PriceLabel.tscn"
# The game's tooltip node (as hud/components/PriceLabel.tscn holds one): a child of a button shows the button's
# tooltip on hover and when it gets the focus.
const GAME_TOOLTIP = "res://menu/sfx/PlaySoundsOnTheseButtons.tscn"
# The slider's value, the button the D-pad lands on, which A turns into the bar (hud/components/PriceLabel.tscn, as
# hud/SystemMineralList.gd getChildOrLabel picks it).
const GAME_SLIDER_VALUE = "Box/MarginContainer/Label"
# The slider's bar, which A turns the value into (hud/components/PriceLabel.tscn).
const GAME_SLIDER_BAR = "Box/HSlider"
# The occupation whose crew estimate the masses (CurrentGame.occupations, as getCrewNumberWithRole counts it).
const GAME_GEOLOGIST = "CREW_OCCUPATION_GEOLOGIST"
# The geologist's Price prediction accuracy: its key in getCrewStats, and the game's text for its name, as Your Crew
# shows it (enceladus/Crew.tscn GeologistPredictionLabel).
const GAME_PREDICTION = "CREW_STATS_GEOLOGIST_PREDICTION"
const HINT = "GEOLOGYBYMASS_HINT"
const NO_GEOLOGIST = "GEOLOGYBYMASS_NO_GEOLOGIST"

# The sliders while the switch is off: dimmed, still adjustable. As the Geologist tab dims a switch the HUD can't use
# (hud/SystemMineralList.gd modulateDisabled).
const DIMMED = Color(1, 1, 1, 0.25)
const MARGIN = 16
# The gap between the tab's parts (the switch at the top, the line on what it does, the switch for the start of a dive,
# the rows and the line on the geologist), in px: less than the OMS theme gives (hud/TNTRL-theme-inventory.tres
# VBoxContainer separation), so that they all fit the OMS's height, the line on the geologist included. The game draws
# its UI in screen pixels (project.godot sets no stretch mode), so the OMS is shorter in a smaller window.
const SECTION_SPACING = 12
# The width of each slider's bar, in px: wider than the game's Minimum value bar (hud/components/PriceLabel.tscn), so
# each step is easier to hit.
const SLIDER_WIDTH = 500
# The gap between the switch and its label, in px.
const TOGGLE_SPACING = 12
# What each mineral's slider shows (its least mass, with the unit after it), what that mass is worth (as the info box
# shows a value, hud/MineralMark.gd priceFormat), the geologist's Price prediction accuracy (as Your Crew shows it,
# enceladus/Crew.tscn GeologistPredictionValue), and the line with its name, then its value (the game has no text for
# it: Your Crew puts them in two Labels).
const MASS_FORMAT = "%s "
const VALUE_FORMAT = "%s E$"
const PREDICTION_FORMAT = "%.0f%%"
const STAT_FORMAT = "%s: %s"

var _settings
var _toggle
var _allAtDive
var _allAtDiveRow
var _grid
var _switches = {} # by mineral
var _sliders = {} # by mineral
var _values = {} # by mineral
var _geologist

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
	box.add_constant_override("separation", SECTION_SPACING)
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

	_allAtDiveRow = HBoxContainer.new()
	_allAtDiveRow.add_constant_override("separation", TOGGLE_SPACING)
	box.add_child(_allAtDiveRow)
	_allAtDive = load(GAME_TOGGLE).instance()
	_allAtDive.pressed = settings.isAllAtDive()
	_allAtDive.connect("toggled", self, "_onAllAtDiveToggled")
	_allAtDiveRow.add_child(_allAtDive)
	var allAtDiveLabel = Label.new()
	allAtDiveLabel.text = GeologyByMass.ALL_AT_DIVE.label
	allAtDiveLabel.size_flags_vertical = SIZE_SHRINK_CENTER
	_allAtDiveRow.add_child(allAtDiveLabel)

	_grid = GridContainer.new()
	_grid.columns = 4
	box.add_child(_grid)

	var mass = GeologyByMass.MIN_MASS
	for mineral in settings.minerals():
		var mineralSwitch = load(GAME_TOGGLE).instance()
		mineralSwitch.pressed = settings.isMineralOn(mineral)
		mineralSwitch.hint_tooltip = GeologyByMass.MINERAL_SWITCH.label
		mineralSwitch.add_child(load(GAME_TOOLTIP).instance())
		mineralSwitch.connect("toggled", self, "_onMineralToggled", [mineral])
		_grid.add_child(mineralSwitch)
		_switches[mineral] = mineralSwitch
		var label = load(GAME_MINERAL_LABEL).instance()
		label.mineral = mineral
		label.focus_mode = FOCUS_NONE
		if mineral in CurrentGame.specificMineralColors:
			label.modulate = CurrentGame.specificMineralColors[mineral]
		_grid.add_child(label)
		var slider = _slider(mass, MASS_FORMAT, mass.label)
		slider.connect("valueChanged", self, "_onMinMassChanged", [mineral])
		_grid.add_child(slider)
		_sliders[mineral] = slider
		var value = Label.new()
		value.valign = Label.VALIGN_CENTER
		_grid.add_child(value)
		_values[mineral] = value

	_geologist = Label.new()
	_geologist.autowrap = true
	box.add_child(_geologist)
	_showValues()
	_linkFocus()
	_dim()
	connect("visibility_changed", self, "_refresh")

# The D-pad's way through the tab, set as the Geologist tab sets its own (hud/SystemMineralList.gd adjustFocus): down
# from the switch at the top to the switch for the start of a dive, then to the first mineral's switch; up and down a
# column, the switches or the sliders' values, in the rows' order, the first row's leading back up to the switch for
# the start of a dive; left and right between a row's switch and its slider's value. At the ends and the outer sides it
# stays where it is, so it never leaves the tab for the rest of the OMS; left and right are the value's once A has
# turned it into the bar.
func _linkFocus():
	var switches = []
	var values = []
	for mineral in _settings.minerals():
		switches.append(_switches[mineral])
		values.append(_sliders[mineral].get_node(GAME_SLIDER_VALUE))
	_link(_toggle, _toggle, _allAtDive, _toggle, _toggle)
	_link(_allAtDive, _toggle, switches[0], _allAtDive, _allAtDive)
	for i in switches.size():
		var last = min(i + 1, switches.size() - 1)
		_link(switches[i], _allAtDive if i == 0 else switches[i - 1], switches[last], switches[i], values[i])
		_link(values[i], _allAtDive if i == 0 else values[i - 1], values[last], switches[i], values[i])

func _link(node, top, bottom, left, right):
	node.focus_neighbour_top = node.get_path_to(top)
	node.focus_neighbour_bottom = node.get_path_to(bottom)
	node.focus_neighbour_left = node.get_path_to(left)
	node.focus_neighbour_right = node.get_path_to(right)

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
# value's text from its _ready on, so this waits for the tree. The values and the line on the geologist follow the day's
# price and the crew aboard each time the tab shows.
func _refresh():
	if _settings == null or not is_inside_tree():
		return
	_toggle.pressed = _settings.isEnabled()
	var allAtDive = _settings.isAllAtDive()
	if _allAtDive.pressed != allAtDive:
		_allAtDive.pressed = allAtDive
	for mineral in _sliders:
		var on = _settings.isMineralOn(mineral)
		if _switches[mineral].pressed != on:
			_switches[mineral].pressed = on
		var slider = _sliders[mineral]
		var kg = _settings.getMinMass(mineral)
		if slider.value != kg:
			slider.value = kg
	_showValues()
	_geologist.text = _geologistLine()
	_dim()

func _showValues():
	for mineral in _values:
		_showValue(mineral)

# What the mineral's least mass is worth at the day's price (CurrentGame.getMineralMarketPricePerKg, as the info box
# prices a chunk, getMarketPrice).
func _showValue(mineral):
	var worth = _settings.getMinMass(mineral) * CurrentGame.getMineralMarketPricePerKg(mineral)
	_values[mineral].text = VALUE_FORMAT % CurrentGame.formatThousands(worth)

# The line on the geologist aboard: a warning with none in the dive crew (CurrentGame.getCrewNumberWithRole), whose
# chunks then get no info box and so no masses; else the crew's Price prediction accuracy, as Your Crew shows it
# (enceladus/CurrentCrewManagement.gd fillStats), from which the info box's mass error comes (hud/MineralMark.gd _ready,
# CurrentGame.getGeologistAccurancy).
func _geologistLine() -> String:
	if CurrentGame.getCrewNumberWithRole(GAME_GEOLOGIST) == 0:
		return tr(NO_GEOLOGIST)
	var accuracy = CurrentGame.getCrewStats()[GAME_PREDICTION]
	return STAT_FORMAT % [tr(GAME_PREDICTION), PREDICTION_FORMAT % (100 * accuracy)]

func _dim():
	var shade = Color.white if _settings.isEnabled() else DIMMED
	_allAtDiveRow.modulate = shade
	_grid.modulate = shade

func _onEnabledToggled(how):
	_settings.setEnabled(how)
	_dim()

func _onAllAtDiveToggled(how):
	_settings.setAllAtDive(how)

func _onMineralToggled(how, mineral):
	_settings.setMineralOn(mineral, how)

func _onMinMassChanged(kg, mineral):
	_settings.setMinMass(mineral, kg)
	_showValue(mineral)
