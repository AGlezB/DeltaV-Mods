extends Tabs

# GeologyByMass's OMS tab: the switch at the top, a line on what it does, then one row per mineral of the Geologist
# tab's columns, Water too: its switch, its name, its least mass slider and what that mass is worth at the day's price;
# at the bottom, a line on the geologist aboard, whose estimates the masses are judged on. Built from that tab's own
# parts (hud/SystemMineralList.gd): its on/off switches, its mineral names, coloured the same way, and its Minimum value
# slider, which keeps the game's focus and controller handling (press the value to edit it, left and right to change
# it, accept or cancel to leave). A `Tabs` node, as every page of the OMS is (hud/OMS.tscn).
#
# With a gamepad: the D-pad goes down from the switch at the top into the rows, up and down a column (the switches, or
# the sliders' values), and left and right between a row's switch and its slider's value, and stays in the tab
# (_linkFocus). Each slider has the game's tooltip node (menu/sfx/PlaySoundsOnTheseButtons.tscn), which shows a
# control's tooltip when it gets the focus, as on hover, for its bar and its value: the description goes on both. Each
# mineral switch gets one of its own.

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
# The occupation whose crew estimate the masses (CurrentGame.occupations, the key of its stats in getCrewStats).
const GAME_GEOLOGIST = "CREW_OCCUPATION_GEOLOGIST"
const HINT = "GEOLOGYBYMASS_HINT"
const GEOLOGIST = "GEOLOGYBYMASS_GEOLOGIST"
const NO_GEOLOGIST = "GEOLOGYBYMASS_NO_GEOLOGIST"

# The sliders while the switch is off: dimmed, still adjustable. As the Geologist tab dims a switch the HUD can't use
# (hud/SystemMineralList.gd modulateDisabled).
const DIMMED = Color(1, 1, 1, 0.25)
const MARGIN = 16
# The width of each slider's bar, in px: wider than the game's Minimum value bar (hud/components/PriceLabel.tscn), so
# each step is easier to hit.
const SLIDER_WIDTH = 500
# The gap between the switch and its label, in px.
const TOGGLE_SPACING = 12
# What each mineral's slider shows (its least mass, with the unit after it), what that mass is worth (as the info box
# shows a value, hud/MineralMark.gd priceFormat) and the most error of the geologist's estimates (as the Geologist
# tab's Minimum Albedo shows a percentage, hud/components/PercentLabel.tscn).
const MASS_FORMAT = "%s "
const VALUE_FORMAT = "%s E$"
const PERCENT_FORMAT = "%s%%"

var _settings
var _toggle
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
# from the switch at the top to the first mineral's switch; up and down a column, the switches or the sliders' values,
# in the rows' order, the first row's leading back up to the switch at the top; left and right between a row's switch
# and its slider's value. At the ends and the outer sides it stays where it is, so it never leaves the tab for the rest
# of the OMS; left and right are the value's once A has turned it into the bar.
func _linkFocus():
	var switches = []
	var values = []
	for mineral in _settings.minerals():
		switches.append(_switches[mineral])
		values.append(_sliders[mineral].get_node(GAME_SLIDER_VALUE))
	_link(_toggle, _toggle, switches[0], _toggle, _toggle)
	for i in switches.size():
		var last = min(i + 1, switches.size() - 1)
		_link(switches[i], _toggle if i == 0 else switches[i - 1], switches[last], switches[i], values[i])
		_link(values[i], _toggle if i == 0 else values[i - 1], values[last], switches[i], values[i])

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

# The line on the geologist aboard: a warning with none in the dive crew (CurrentGame.isCrewMemberActive, as
# getCrewStats counts it), whose chunks then get no info box and so no masses; else the Education of the best one, as
# their entry shows it (translateLevel of their talent), and the most error the game's formula gives that level, at its
# lowest talent (deriveStats: the info box's error is within ±(1 - CREW_STATS_GEOLOGIST_PREDICTION),
# hud/MineralMark.gd _ready). A hint, so the level's figure, as the player knows the level: morale, which also moves
# the error (getCrewStats), is left out.
func _geologistLine() -> String:
	var best = null
	for member in CurrentGame.state.crew.values():
		if member.get("occupation") == GAME_GEOLOGIST and CurrentGame.isCrewMemberActive(member):
			if best == null or member.talent > best:
				best = member.talent
	if best == null:
		return tr(NO_GEOLOGIST)
	var levels = CurrentGame.talentLevels
	var level = CurrentGame.translateLevel(best, levels)
	var stats = CurrentGame.makeEmptyStats()
	stats[GAME_GEOLOGIST].talent = float(levels.find(level)) / levels.size()
	var error = 1.0 - CurrentGame.deriveStats(stats).CREW_STATS_GEOLOGIST_PREDICTION
	return tr(GEOLOGIST) % [tr(level), PERCENT_FORMAT % int(round(error * 100))]

func _dim():
	_grid.modulate = Color.white if _settings.isEnabled() else DIMMED

func _onEnabledToggled(how):
	_settings.setEnabled(how)
	_dim()

func _onMineralToggled(how, mineral):
	_settings.setMineralOn(mineral, how)

func _onMinMassChanged(kg, mineral):
	_settings.setMinMass(mineral, kg)
	_showValue(mineral)
