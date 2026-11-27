extends "res://harness/suite.gd"

# GeologyByMass: with the switch on its OMS tab on, the player's ship judges an identified chunk, for every row of the
# Geologist tab (the HUD's for the info boxes, an arm's, a drone plant's), by the mass of each mineral switched on in
# the mod's tab, against that mineral's least mass, instead of by its value and the row's own mineral switches
# (ships/ship-ctrl.gd isValidMineralTarget, which every system asks with its own row); the settings live in the HUD's
# mineralConfig (the ship's "hud.config"), next to the Geologist tab's own, and the entries of the earlier formats
# (1.0.0's minMass, 1.1.0's base and extra masses) still load; the tab comes right after the Geologist tab, with the
# switch that turns every mineral on when a dive starts (Code.gd _ready, for the player's ship as Game.gd _respawn_ship
# builds it), a row for every mineral of the market, H2O too: its switch, its name, its least mass and what that is
# worth at the day's price, and at the bottom a line on the geologist aboard. The rule runs on ships of the game's ship-ctrl.gd (with the
# mod, its extension), out of the tree, compared with the same ship on the game's script where the game decides. The
# tab runs on HUDs from harness/geology_hud.tscn (the game's Hud.gd, with an Inventory placeholder of
# harness/geology_oms.tscn: the game's OMS.gd and TabsWithGamepadControl.gd, and the OMS's four role tabs) on
# harness/geology_ship.gd, whose isValidMineralTarget records each call in place of the game's rule. While the switch
# is on, the Geologist tab (the game's hud/SystemMineralList.gd, with the mod its extension, added to that OMS's
# Geologist tab) disables and dims the mineral switches and the Minimum values of the rows the mod judges. The mod's
# settings descriptions and constants are read from the mod, so any value of them passes. The control checks run on
# the game's own Hud.gd, ship-ctrl.gd and SystemMineralList.gd.

const MOD = "GeologyByMass"
const SETTINGS = "res://GeologyByMass/Settings.gd"
const UI = "res://GeologyByMass/SettingsUI.gd"
const MANIFEST = "res://GeologyByMass/Mod.manifest"
const HUD_SCENE = "res://harness/geology_hud.tscn"
const SHIP = "res://ships/ship-ctrl.gd"
const GEOLOGIST_LIST = "res://hud/SystemMineralList.gd"
const TABS = "MarginContainer/VBoxContainer/TabHintContainer/TabContainer"
const GEOLOGIST = "CREW_OCCUPATION_GEOLOGIST"
const ROLE_TABS = ["CREW_OCCUPATION_MECHANIC", "CREW_OCCUPATION_ASTROGATOR", "CREW_OCCUPATION_GEOLOGIST", "CREW_OCCUPATION_PILOT"]
# A Minimum value control's value, the button that opens its bar, and the bar (hud/components/PriceLabel.tscn).
const PRICE_VALUE = "Box/MarginContainer/Label"
const PRICE_BAR = "Box/HSlider"
# The game's English for the geologist's Price prediction accuracy (i18n/en.po CREW_STATS_GEOLOGIST_PREDICTION), as a
# test translation of the key.
const PREDICTION_TEXT = "Price prediction accuracy"

var _bodies = []
var _ships = []
var _gameScript # the game's own ship-ctrl.gd, under every extension

func makeShip(config = {}, preheat = false):
	var ship = Node2D.new()
	ship.set_script(load("res://harness/geology_ship.gd"))
	ship.shipConfig = config
	ship.preheat = preheat
	add_child(ship)
	return ship

# A HUD on `ship`, as the ship's scene holds it. Hud.gd's processing goes off at once: it would draw power and drive
# the displays, which neither the stub nor the suite has.
func makeHud(ship):
	var hud = load(HUD_SCENE).instance()
	ship.add_child(hud)
	hud.set_process(false)
	hud.set_physics_process(false)
	return hud

func idle(count = 2):
	for i in count:
		yield(get_tree(), "idle_frame")

# A press and release of a gamepad button (JOY_*), as Input delivers a player's: the actions it is bound to follow
# (Godot's defaults: the D-pad moves the focus, button 0 is ui_accept), then the focused control gets it. Input hands
# parsed events on at the next frame, so this waits for it.
func tapJoy(button):
	yield(get_tree(), "idle_frame")
	for pressed in [true, false]:
		var event = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")

# The game builds the OMS on the ship's `instance` signal (Hud.gd _ready connects it); the mod adds its tab once the
# frame is idle.
func buildOms(ship):
	ship.emit_signal("instance")
	yield(idle(), "completed")

func names(tabs) -> Array:
	var list = []
	for c in tabs.get_children():
		list.append(c.name)
	return list

# An identified chunk: kg by mineral and estimated value, as MineralMark.gd stores them (ship-ctrl.gd
# addIdentifiedObject).
func chunk(ship, masses, value = 0.0):
	var body = RigidBody2D.new()
	_bodies.append(body)
	ship.identifiedObjects[hash(body)] = [masses, value, Vector2.ZERO, body]
	return body

func unidentified():
	var body = RigidBody2D.new()
	_bodies.append(body)
	return body

# Whether the game decides: the HUD asks the ship with its own mineralConfig, and passes either answer on.
func handedToGame(hud, ship, body) -> bool:
	var before = ship.calls.size()
	var results = []
	for answer in [true, false]:
		ship.answer = answer
		results.append(hud.isValidMineralTarget(body))
	ship.answer = true
	return results == [true, false] and ship.calls.size() == before + 2 and ship.calls.back()[0] == body and ship.calls.back()[1] == hud.mineralConfig

# A row of the Geologist tab, as a system keeps it in its config (hud/Hud.gd, DockingArm.gd and drone-plant.gd _ready):
# the minerals switched on, the Minimum value in E$ and the albedo in %.
func row(minerals, minValue = 0.0, albedo = 0.0) -> Dictionary:
	return {"minerals": minerals.duplicate(), "minValue": minValue, "albedo": albedo}

# A ship of `script` (the game's ships/ship-ctrl.gd, or with the mod its extension), out of the tree (its _ready never
# runs), with `hudConfig` as its HUD's mineralConfig (the ship's "hud.config"), where the mod's settings live.
func gameShip(script, hudConfig, player = true):
	var s = RigidBody2D.new()
	s.set_script(script)
	s.playerControlled = player
	s.shipConfig = {"hud": {"config": hudConfig}}
	_ships.append(s)
	return s

# A ship as Game.gd _respawn_ship builds the player's, of the game's ship-ctrl.gd (with the mod, its extension), out of
# the tree: in `zone`, with `initialize`, its HUD's row holding the mod's entry (under `modId`) with the switch at the
# top on, Be's least mass `kg`, every mineral switched off but Fe, and the switch for the start of a dive `allAtDive`.
func diveShip(modId, kg, allAtDive, zone, initialize = true, player = true):
	var switches = {}
	for m in CurrentGame.mineralPrices:
		switches[m] = m == "Fe"
	var hudConfig = row(CurrentGame.traceMinerals)
	hudConfig[modId] = {"modVersion": "stored", "enabled": true, "allAtDive": allAtDive, "minMass": {"Be": kg}, "mineralOn": switches}
	var s = gameShip(load(SHIP), hudConfig, player)
	s.zone = zone
	s.initialize = initialize
	return s

# Whether `ship` answers for `body` as the game does, with each of `configs`, and the game's answers are `expected`
# (both ways where it can, so the check shows the game deciding): the same ship on the game's own script, sharing its
# config, identified chunks and AI target.
func asGame(ship, body, configs, expected) -> bool:
	var twin = gameShip(_gameScript, ship.shipConfig.hud.config, ship.playerControlled)
	twin.identifiedObjects = ship.identifiedObjects
	twin.ai = ship.ai
	twin.aiTarget = ship.aiTarget
	var answers = []
	for config in configs:
		var answer = ship.isValidMineralTarget(body, config)
		if answer != twin.isValidMineralTarget(body, config):
			return false
		answers.append(answer)
	return answers == expected

# The Geologist tab's list of rows (the game's hud/SystemMineralList.gd; with the mod, its extension), added where the
# game nests it, in the OMS's Geologist tab: it finds the ship through the HUD (Hud.gd getShip), and builds its rows on
# the ship's systemsChanged, as the game does.
func makeGeologist(tabs):
	var list = GridContainer.new()
	list.set_script(load(GEOLOGIST_LIST))
	tabs.get_node(GEOLOGIST).add_child(list)
	return list

# A system with mineral targeting for the Geologist tab: an arm, or with `only` a cargo container's dock.
func system(ship, only, minValue = 0.0):
	var s = Node.new()
	s.set_script(load("res://harness/geology_system.gd"))
	s.onlyMinerals = only
	s.mineralConfig = row(CurrentGame.traceMinerals, minValue)
	ship.add_child(s)
	return s

# The list's controls whose valueChanged reaches its `method` ("value": the Minimum values; "albedo": the Minimum
# Albedos), by the system of their row, as SystemMineralList.gd updateSystems connects them; rows being freed left out.
func controls(list, method) -> Dictionary:
	var found = {}
	for c in list.get_children():
		if c.is_queued_for_deletion() or not c.has_signal("valueChanged"):
			continue
		for connection in c.get_signal_connection_list("valueChanged"):
			if connection.target == list and connection.method == method:
				found[connection.binds[0]] = c
	return found

# The list's mineral switches, a list by the system of their row, as SystemMineralList.gd updateSystems connects them
# (toggled -> toggle); rows being freed left out.
func mineralSwitches(list) -> Dictionary:
	var found = {}
	for c in list.get_children():
		if c.is_queued_for_deletion() or not c.has_signal("toggled"):
			continue
		for connection in c.get_signal_connection_list("toggled"):
			if connection.target == list and connection.method == "toggle":
				if not found.has(connection.binds[0]):
					found[connection.binds[0]] = []
				found[connection.binds[0]].append(c)
	return found

# How the list's rows look and answer: for each mineral switch its state, `disabled` and `modulate`; for each Minimum
# value and Minimum Albedo control whether it shows, its value, whether its button opens its bar (`disabled`), whether
# its bar can be dragged (`editable`) and its `modulate`. By control, so two looks of the same rows compare with same().
func look(list) -> Dictionary:
	var state = {}
	for switches in mineralSwitches(list).values():
		for s in switches:
			state[s] = [s.pressed, s.disabled, s.modulate]
	for method in ["value", "albedo"]:
		for c in controls(list, method).values():
			state[c] = [shown(c), c.value, c.get_node(PRICE_VALUE).disabled, c.get_node(PRICE_BAR).editable, c.modulate]
	return state

# The part of `state` (a look) for `nodes`.
func lookOf(state, nodes) -> Dictionary:
	var part = {}
	for n in nodes:
		part[n] = state[n]
	return part

# The Minimum value column's title: the last cell of the list's first row (SystemMineralList.gd updateSystems); rows
# being freed left out.
func header(list):
	var live = []
	for c in list.get_children():
		if not c.is_queued_for_deletion():
			live.append(c)
	return live[list.columns - 1]

# Whether a Minimum value control shows its slider and its value (PriceLabel.gd: disabled hides both).
func shown(control) -> bool:
	return control.box.visible and control.label.visible

# The game's own answer for `body` on `ship`, with `config`.
func gameAnswer(ship, body, config) -> bool:
	var twin = gameShip(_gameScript, ship.shipConfig.hud.config, ship.playerControlled)
	twin.identifiedObjects = ship.identifiedObjects
	return twin.isValidMineralTarget(body, config)

func manifestVersion() -> String:
	var manifest = ConfigFile.new()
	manifest.load(MANIFEST)
	return "%d.%d.%d" % [manifest.get_value("version", "version_major"), manifest.get_value("version", "version_minor"), manifest.get_value("version", "version_bugfix")]

# A slider position inside the range of `desc` (a mass description of Settings.gd), above its minimum.
func inside(desc) -> float:
	var at = stepify((desc.min + desc.max) / 2.0, desc.step)
	if at <= desc.min:
		at = desc.min + desc.step
	return float(at)

# What the tab shows after a mineral's slider: what `kg` of it is worth at the day's price.
func worthText(tab, mineral, kg) -> String:
	return tab.VALUE_FORMAT % CurrentGame.formatThousands(kg * CurrentGame.getMineralMarketPricePerKg(mineral))

# The line the tab should show for a best geologist of `talent` and `morale`: the game's text for the stat's name, then
# the crew's Price prediction accuracy as Your Crew shows it (enceladus/CurrentCrewManagement.gd fillStats: 100 times
# the stat, in the format of enceladus/Crew.tscn GeologistPredictionValue), from the talent raised or lowered by morale
# (CurrentGame.gd getCrewStats) through the game's deriveStats.
func geologistText(tab, talent, morale = 0.0) -> String:
	var stats = CurrentGame.makeEmptyStats()
	stats[GEOLOGIST].talent = pow(talent, 1 - morale)
	var accuracy = CurrentGame.deriveStats(stats)[tab.GAME_PREDICTION]
	return tab.STAT_FORMAT % [tr(tab.GAME_PREDICTION), tab.PREDICTION_FORMAT % (100 * accuracy)]

# A crew member for CurrentGame.state.crew: `aboard`, in the dive crew (CurrentGame.isCrewMemberActive), unless on leave.
func member(occupation, talent, aboard = true, onLeave = false) -> Dictionary:
	var m = {"occupation": occupation, "talent": talent, "experience": 0.5, "active": aboard}
	if onLeave:
		m.leave = CurrentGame.getInGameTimestamp() + 24 * 3600
	return m

# The game's tooltip node (menu/sfx/PlaySoundsOnTheseButtons.gd) among `node`'s children, or null.
func tooltipNode(node):
	for c in node.get_children():
		if c.has_method("connectSounds"):
			return c
	return null

# The tooltip `node` carries: its own, or once `tips` (a tooltip node) has taken it in, what it keeps for the node.
func tipOf(node, tips) -> String:
	if node.hint_tooltip != "":
		return node.hint_tooltip
	return tips.tooltips.get(node, "") if tips != null else ""

# Shows the tab again (another tab first), as the player does, which refreshes what it shows.
func reopen(tabs, index):
	tabs.current_tab = 0
	yield(idle(), "completed")
	tabs.current_tab = index
	yield(idle(), "completed")

func run():
	var mod = hasMod(MOD)
	var ship = makeShip()
	var hud = makeHud(ship)
	yield(buildOms(ship), "completed")
	var tabs = hud.inventory.get_node(TABS)
	var shipScript = load(SHIP)
	# The game's script is the bottom of the chain, however many mods extend it, in whatever order.
	_gameScript = shipScript
	while _gameScript.get_base_script() != null:
		_gameScript = _gameScript.get_base_script()
	if not mod:
		check("control: the OMS keeps the game's four tabs", names(tabs) == ROLE_TABS, names(tabs))
		check("control: the HUD asks its ship about an identified chunk, with its own row", handedToGame(hud, ship, chunk(ship, {"Be": 1.0}, 1.0)))
		check("control: and about a chunk not yet identified", handedToGame(hud, ship, unidentified()))
		var game = gameShip(shipScript, row(CurrentGame.traceMinerals))
		var rich = chunk(game, {"Be": 1.0}, 1.0)
		check("control: the ship judges an identified chunk by its value against the row's Minimum value", game.isValidMineralTarget(rich, row(CurrentGame.traceMinerals, 1.0)) and not game.isValidMineralTarget(rich, row(CurrentGame.traceMinerals, 2.0)))
		var controlList = makeGeologist(tabs)
		var controlArm = system(ship, false, 3000.0)
		var controlDock = system(ship, true)
		ship.mineralSystems = {"hud": {"ref": hud, "name": "SYSTEM_HUD"}, "arm": {"ref": controlArm, "name": "SYSTEM_SALVAGE_ARM"}, "dock": {"ref": controlDock, "name": "SYSTEM_EXSTORAGE"}}
		ship.emit_signal("systemsChanged", ship.getSystems())
		tabs.current_tab = names(tabs).find(GEOLOGIST)
		yield(idle(), "completed")
		var controlPrices = controls(controlList, "value")
		check("control: the Geologist tab shows the HUD's and the arm's Minimum value, not the cargo dock's", controlPrices.size() == 3 and shown(controlPrices[hud]) and shown(controlPrices[controlArm]) and not shown(controlPrices[controlDock]))
		_free()
		return

	var model = load(SETTINGS)
	var enabledDesc = model.ENABLED
	var mass = model.MIN_MASS
	var k = inside(mass) # a least mass inside the range, above its minimum
	var most = mass.max + 1 # above any least mass
	var settings = hud._geologyByMass()
	var modId = settings.modId()
	var tabName = hud._GEOLOGY_BY_MASS_TAB

	# The tab
	var expected = ROLE_TABS.duplicate()
	expected.insert(ROLE_TABS.find(GEOLOGIST) + 1, tabName)
	check("the tab comes right after the Geologist tab", names(tabs) == expected, names(tabs))
	var index = names(tabs).find(tabName)
	# get_tab_title gives the node's name; the TabContainer draws it through tr(), as it draws the role tabs' keys.
	check("its title is its key, which has a translation", index != -1 and tabs.get_tab_title(index) == tabName and tr(tabName) != tabName, tabs.get_tab_title(index) if index != -1 else "")
	var showing = []
	for c in tabs.get_children():
		showing.append(c.visible)
	var expectVisible = []
	for i in tabs.get_child_count():
		expectVisible.append(i == tabs.current_tab)
	check("only the current tab shows", showing == expectVisible, showing)
	ship.emit_signal("instance")
	hud.instance()
	yield(idle(), "completed")
	check("the tab is added once, however often the OMS is built", names(tabs).count(tabName) == 1, names(tabs))
	tabs.current_tab = index
	yield(idle(), "completed")
	check("opening the tab stores nothing", not hud.mineralConfig.has(modId), hud.mineralConfig.keys())

	var tab = tabs.get_node(tabName)
	var toggle = tab._toggle
	var grid = tab._grid
	check("the switch is the Geologist tab's (MineralSystemToggle), and shows the stored state", toggle is CheckButton and toggle.get_script().resource_path == "res://hud/components/MineralSystemToggle.gd" and toggle.pressed == settings.isEnabled())
	var kids = grid.get_children()
	var minerals = []
	var switchesOk = true
	var colours = true
	var ranges = true
	var values = true
	for i in range(0, kids.size() - 3, 4):
		var mineralSwitch = kids[i]
		var label = kids[i + 1]
		var slider = kids[i + 2]
		var worth = kids[i + 3]
		var m = label.mineral
		minerals.append(m)
		switchesOk = switchesOk and mineralSwitch is CheckButton and mineralSwitch.get_script().resource_path == "res://hud/components/MineralSystemToggle.gd" and mineralSwitch == tab._switches.get(m) and mineralSwitch.pressed == settings.isMineralOn(m)
		colours = colours and label.get_script().resource_path == "res://hud/components/MineralLabel.gd" and label.modulate == CurrentGame.specificMineralColors.get(m, Color.white) and label.focus_mode == Control.FOCUS_NONE
		var bar = slider.get_node(PRICE_BAR)
		ranges = ranges and slider.get_script().resource_path == "res://hud/components/PriceLabel.gd" and slider == tab._sliders.get(m) and bar.min_value == mass.min and bar.max_value == mass.max and bar.step == mass.step and bar.hint_tooltip == mass.label and slider.label.hint_tooltip == mass.label and slider.format == tab.MASS_FORMAT + mass.unit
		values = values and slider.value == settings.getMinMass(m) and slider.label.text == slider.format % CurrentGame.formatThousands(slider.value) and worth is Label and worth == tab._values.get(m) and worth.text == worthText(tab, m, settings.getMinMass(m))
	check("a grid of four columns, one row per mineral of the market, H2O too, in the order of the Geologist tab's columns", grid.columns == 4 and minerals == CurrentGame.mineralPrices.keys() and minerals == settings.minerals() and minerals.has("H2O") and kids.size() == 4 * minerals.size(), minerals)
	check("each row starts with a switch, the Geologist tab's (MineralSystemToggle), showing the mineral's stored state", switchesOk)
	var gameDefaults = true
	for m in minerals:
		gameDefaults = gameDefaults and tab._switches[m].pressed == CurrentGame.traceMinerals.has(m)
	check("the mineral switches start as the game's own for a new row: every trace mineral on, H2O off", gameDefaults and not tab._switches["H2O"].pressed)
	check("then its name, the Geologist tab's, in the mineral's colour, taking no focus", colours)
	check("then its slider, the Minimum value control with MIN_MASS's range, step, unit and tooltip, the mass as MASS_FORMAT", ranges)
	var widths = []
	var wide = true
	for i in range(2, kids.size(), 4):
		var bar = kids[i].get_node(PRICE_BAR)
		widths.append(bar.rect_size.x)
		wide = wide and bar.rect_min_size.x == tab.SLIDER_WIDTH and bar.rect_size.x == tab.SLIDER_WIDTH
	check("each bar is the tab's SLIDER_WIDTH wide, once laid out", wide and widths.size() == minerals.size(), widths)
	var header = toggle.get_parent()
	var title = header.get_child(header.get_child_count() - 1)
	var gap = title.rect_position.x - (toggle.rect_position.x + toggle.rect_size.x)
	check("the switch's label stands the tab's TOGGLE_SPACING after it, once laid out", header is HBoxContainer and title is Label and title != toggle and gap == tab.TOGGLE_SPACING, gap)
	check("each slider shows its stored mass, and after it what that mass is worth at the day's price, as VALUE_FORMAT", values)
	check("the rows are dimmed while the switch is off, and not while it is on", (grid.modulate == Color.white) == settings.isEnabled() and (settings.isEnabled() or grid.modulate.a < 1.0), grid.modulate)
	var allAtDive = tab._allAtDive
	var allAtDiveRow = allAtDive.get_parent()
	var allAtDiveLabel = allAtDiveRow.get_child(allAtDiveRow.get_child_count() - 1)
	var box = grid.get_parent()
	var above = box.get_child(allAtDiveRow.get_index() - 1)
	var allAtDiveGap = allAtDiveLabel.rect_position.x - (allAtDive.rect_position.x + allAtDive.rect_size.x)
	check("between the line on what it does and the rows, the switch for the start of a dive: the Geologist tab's (MineralSystemToggle), showing the stored state (ALL_AT_DIVE's default at first), its label ALL_AT_DIVE's, TOGGLE_SPACING after it", allAtDive is CheckButton and allAtDive.get_script().resource_path == "res://hud/components/MineralSystemToggle.gd" and allAtDive.pressed == settings.isAllAtDive() and allAtDive.pressed == model.ALL_AT_DIVE.default and allAtDiveRow is HBoxContainer and allAtDiveRow.get_parent() == box and allAtDiveRow.get_index() == grid.get_index() - 1 and above is Label and above.text == tab.HINT and allAtDiveLabel is Label and allAtDiveLabel != allAtDive and allAtDiveLabel.text == model.ALL_AT_DIVE.label and allAtDiveGap == tab.TOGGLE_SPACING, [allAtDiveRow.get_index(), grid.get_index(), allAtDiveGap])
	var sectionGap = allAtDiveRow.rect_position.y - (above.rect_position.y + above.rect_size.y)
	check("the tab's parts stand its SECTION_SPACING apart, once laid out", box.get_constant("separation") == tab.SECTION_SPACING and sectionGap == tab.SECTION_SPACING, sectionGap)

	var before = settings.isEnabled()
	toggle.pressed = not before
	check("pressing the switch stores it, in the HUD's mineralConfig", settings.isEnabled() == (not before) and hud.mineralConfig.get(modId, {}).get("enabled") == (not before))
	toggle.pressed = true
	check("switched on, the rows and the switch for the start of a dive are not dimmed", grid.modulate == Color.white and allAtDiveRow.modulate == Color.white, [grid.modulate, allAtDiveRow.modulate])
	toggle.pressed = false
	check("switched off, the rows and the switch for the start of a dive are dimmed", grid.modulate.a < 1.0 and allAtDiveRow.modulate == grid.modulate, [grid.modulate, allAtDiveRow.modulate])
	tab._switches["H2O"].pressed = true
	check("pressing a mineral's switch stores it", settings.isMineralOn("H2O") and hud.mineralConfig[modId].get("mineralOn", {}).get("H2O") == true, hud.mineralConfig[modId])
	tab._switches["H2O"].pressed = false
	check("and pressing it again stores that", not settings.isMineralOn("H2O") and hud.mineralConfig[modId].mineralOn.H2O == false)
	allAtDive.pressed = not model.ALL_AT_DIVE.default
	check("pressing the switch for the start of a dive stores it", settings.isAllAtDive() == (not model.ALL_AT_DIVE.default) and hud.mineralConfig[modId].get("allAtDive") == (not model.ALL_AT_DIVE.default), hud.mineralConfig[modId])
	allAtDive.pressed = model.ALL_AT_DIVE.default
	check("and pressing it again stores that", settings.isAllAtDive() == model.ALL_AT_DIVE.default and hud.mineralConfig[modId].allAtDive == model.ALL_AT_DIVE.default)
	# A dive starting while the tab isn't showing (Settings.gd diveStarted, which Code.gd calls): the tab shows it.
	settings.setAllAtDive(true)
	settings.setMineralOn(CurrentGame.traceMinerals[0], false)
	settings.diveStarted()
	yield(reopen(tabs, index), "completed")
	var shownAllOn = allAtDive.pressed
	for m in minerals:
		shownAllOn = shownAllOn and tab._switches[m].pressed
	check("each time the tab shows, it shows the switches as a dive's start left them: every mineral on, H2O too", shownAllOn and tab._switches["H2O"].pressed)
	settings.setAllAtDive(model.ALL_AT_DIVE.default)
	for m in minerals:
		settings.setMineralOn(m, settings.mineralDefault(m))
	yield(reopen(tabs, index), "completed")
	var first = minerals[0]
	var firstSlider = tab._sliders[first]
	firstSlider.get_node(PRICE_BAR).value = k
	check("moving a slider stores its mineral's mass", settings.getMinMass(first) == k and hud.mineralConfig[modId].get("minMass", {}).get(first) == k, settings.getMinMass(first))
	check("and shows it in the mod's unit, and what it is worth after it", firstSlider.label.text == "%s %s" % [CurrentGame.formatThousands(k), mass.unit] and tab._values[first].text == worthText(tab, first, k), [firstSlider.label.text, tab._values[first].text])
	var price = CurrentGame.mineralPrices[first]
	var cheapText = tab._values[first].text
	CurrentGame.mineralPrices[first] = price * 3
	yield(reopen(tabs, index), "completed")
	var dearText = worthText(tab, first, k)
	var shownText = tab._values[first].text
	CurrentGame.mineralPrices[first] = price
	yield(reopen(tabs, index), "completed")
	check("each time the tab shows, the worth follows the day's price", shownText == dearText and dearText != cheapText and tab._values[first].text == cheapText, [cheapText, shownText, dearText])
	firstSlider.get_node(PRICE_BAR).value = mass.default

	tabs.current_tab = 0
	tabs.get_node("CREW_OCCUPATION_MECHANIC/Fix").grab_focus()
	yield(idle(), "completed")
	tabs.current_tab = index
	yield(idle(), "completed")
	check("choosing the tab focuses its switch", tabs.get_focus_owner() == toggle, tabs.get_focus_owner())

	# The line at the bottom, on the geologist aboard: who counts is the dive crew (CurrentGame.getCrewNumberWithRole);
	# the figure is the crew's Price prediction accuracy as Your Crew shows it, named by the game's text for it (a test
	# translation of its key: the harness doesn't load the game's .po files).
	var prediction = Translation.new()
	prediction.locale = TranslationServer.get_locale()
	prediction.add_message(tab.GAME_PREDICTION, PREDICTION_TEXT)
	TranslationServer.add_translation(prediction)
	var warning = tr(tab.NO_GEOLOGIST)
	CurrentGame.state.crew = {}
	yield(reopen(tabs, index), "completed")
	check("no crew: the line warns that there is no Geologist on board", tab._geologist.text == warning and warning != tab.NO_GEOLOGIST and tab._geologist.get_parent() == grid.get_parent() and tab._geologist.get_index() > grid.get_index(), tab._geologist.text)
	var nobody = []
	for crew in [{"P": member("CREW_OCCUPATION_PILOT", 1.0)}, {"G": member(GEOLOGIST, 1.0, false)}, {"G": member(GEOLOGIST, 1.0, true, true)}]:
		CurrentGame.state.crew = crew
		nobody.append(tab._geologistLine())
	check("no Geologist in the dive crew: the warning, with only a Pilot, a Geologist not aboard or one on leave", nobody == [warning, warning, warning], nobody)
	var lines = []
	var expectLines = []
	for talent in [0.0, 0.2, 0.25, 0.4, 0.6, 0.74, 0.8, 1.0]:
		CurrentGame.state.crew = {"G": member(GEOLOGIST, talent)}
		lines.append(tab._geologistLine())
		expectLines.append(geologistText(tab, talent))
	check("a Geologist aboard: the crew's Price prediction accuracy, named by the game's text, as Your Crew shows it", lines == expectLines and lines[0].begins_with(PREDICTION_TEXT), lines)
	var moods = []
	for morale in [-0.5, 0.0, 0.5]:
		var moody = member(GEOLOGIST, 0.5)
		moody.morale = morale
		CurrentGame.state.crew = {"G": moody}
		moods.append(tab._geologistLine())
	check("morale counts, as on Your Crew: bad lowers the figure, good raises it", moods == [geologistText(tab, 0.5, -0.5), geologistText(tab, 0.5), geologistText(tab, 0.5, 0.5)] and moods[0] != moods[1] and moods[1] != moods[2], moods)
	CurrentGame.state.crew = {"A": member(GEOLOGIST, 0.3), "B": member(GEOLOGIST, 0.99, false), "C": member("CREW_OCCUPATION_PILOT", 0.99), "D": member(GEOLOGIST, 0.6), "E": member(GEOLOGIST, 0.95, true, true)}
	var best = tab._geologistLine()
	check("several: the best Geologist in the dive crew", best == geologistText(tab, 0.6) and best != geologistText(tab, 0.3) and best != geologistText(tab, 0.99), best)
	yield(reopen(tabs, index), "completed")
	check("the line follows the crew each time the tab shows", tab._geologist.text == best, tab._geologist.text)
	CurrentGame.state.crew = {}
	yield(reopen(tabs, index), "completed")
	TranslationServer.remove_translation(prediction)

	# With a gamepad: down from the switch at the top to the switch for the start of a dive, then to the first row's
	# switch, up and down a column (the switches, or the sliders' values), left and right between a row's switch and its
	# slider's value, and nowhere out of the tab; each mineral's switch and each value carries its description, which its
	# own tooltip node shows when it gets the focus.
	var switchColumn = []
	var valueColumn = []
	var described = true
	for m in minerals:
		var mineralSwitch = tab._switches[m]
		var value = tab._sliders[m].label
		switchColumn.append(mineralSwitch)
		valueColumn.append(value)
		var switchTip = tipOf(mineralSwitch, tooltipNode(mineralSwitch))
		var valueTip = tipOf(value, tooltipNode(tab._sliders[m].get_node("Box")))
		described = described and switchTip == model.MINERAL_SWITCH.label and tr(switchTip) != switchTip and valueTip == mass.label and tr(valueTip) != valueTip
	check("gamepad: each mineral's switch carries its description, taken in by a game's tooltip node of its own, and each slider's value its own", described)
	var firstTips = tooltipNode(switchColumn[0])
	switchColumn[0].grab_focus()
	yield(idle(), "completed")
	check("gamepad: a mineral's switch shows its description when it gets the focus", firstTips != null and firstTips.tooltipPosition.visible and firstTips.tooltipLabel.text == model.MINERAL_SWITCH.label, firstTips.tooltipLabel.text if firstTips != null else null)
	var beforeWalk = hud.mineralConfig.get(modId, {}).duplicate(true)
	var lastRow = minerals.size() - 1
	var walk = []
	toggle.grab_focus()
	for button in [JOY_DPAD_UP, JOY_DPAD_LEFT, JOY_DPAD_RIGHT]:
		yield(tapJoy(button), "completed")
		walk.append(tabs.get_focus_owner())
	check("gamepad: up, left and right stay on the switch at the top", walk == [toggle, toggle, toggle], walk)
	walk = []
	for i in minerals.size() + 2:
		yield(tapJoy(JOY_DPAD_DOWN), "completed")
		walk.append(tabs.get_focus_owner())
	check("gamepad: down goes from it to the switch for the start of a dive, then through each mineral's switch, and stays on the last", walk == [allAtDive] + switchColumn + [switchColumn[lastRow]], walk)
	walk = []
	allAtDive.grab_focus()
	for button in [JOY_DPAD_LEFT, JOY_DPAD_RIGHT, JOY_DPAD_UP]:
		yield(tapJoy(button), "completed")
		walk.append(tabs.get_focus_owner())
	check("gamepad: left and right stay on the switch for the start of a dive, up goes back to the switch at the top", walk == [allAtDive, allAtDive, toggle], walk)
	walk = []
	for i in [0, lastRow]:
		switchColumn[i].grab_focus()
		for button in [JOY_DPAD_RIGHT, JOY_DPAD_RIGHT, JOY_DPAD_LEFT, JOY_DPAD_LEFT]:
			yield(tapJoy(button), "completed")
			walk.append(tabs.get_focus_owner())
	check("gamepad: right goes from a switch to its row's value and stays there, left back to the switch and stays there", walk == [valueColumn[0], valueColumn[0], switchColumn[0], switchColumn[0], valueColumn[lastRow], valueColumn[lastRow], switchColumn[lastRow], switchColumn[lastRow]], walk)
	walk = []
	valueColumn[0].grab_focus()
	for i in minerals.size():
		yield(tapJoy(JOY_DPAD_DOWN), "completed")
		walk.append(tabs.get_focus_owner())
	check("gamepad: down goes through each slider's value, and stays on the last", walk == valueColumn.slice(1, lastRow) + [valueColumn[lastRow]], walk)
	var upValues = valueColumn.duplicate()
	upValues.invert()
	var upSwitches = switchColumn.duplicate()
	upSwitches.invert()
	walk = []
	for column in [valueColumn, switchColumn]:
		column[lastRow].grab_focus()
		for i in minerals.size():
			yield(tapJoy(JOY_DPAD_UP), "completed")
			walk.append(tabs.get_focus_owner())
	check("gamepad: up goes back through either column, and from the first row to the switch for the start of a dive", walk == upValues.slice(1, lastRow) + [allAtDive] + upSwitches.slice(1, lastRow) + [allAtDive], walk)
	check("gamepad: walking the tab changes nothing", same(hud.mineralConfig.get(modId, {}), beforeWalk), hud.mineralConfig.get(modId))

	# The HUD: its info boxes ask the ship, with the HUD's row, whatever the switch
	settings.setEnabled(true)
	check("the HUD hands an identified chunk to its ship, with its own row, the switch on", handedToGame(hud, ship, chunk(ship, {"Be": most}, 1.0)))
	check("and a chunk not yet identified", handedToGame(hud, ship, unidentified()))
	settings.setEnabled(false)

	# The rule, on a ship of the game's ship-ctrl.gd: the HUD's row is its hud.config, where the settings live too
	var hudRow = row(CurrentGame.traceMinerals)
	var s = gameShip(shipScript, hudRow)
	var rule = s._geologyByMass()
	var heavy = chunk(s, {"Be": most}, 1.0)
	check("switched off, the game decides", asGame(s, heavy, [row(CurrentGame.traceMinerals), row(CurrentGame.traceMinerals, 1e12)], [true, false]))
	rule.setEnabled(true)
	for m in rule.minerals():
		rule.setMinMass(m, k)
	check("below a mineral's least mass: refused", not s.isValidMineralTarget(chunk(s, {"Be": k - 1}), hudRow))
	check("at a mineral's least mass: passes", s.isValidMineralTarget(chunk(s, {"Be": k}), hudRow))
	check("above a mineral's least mass: passes", s.isValidMineralTarget(chunk(s, {"Be": k + 1}), hudRow))
	check("H2O, switched off on the tab at first: refused however much, even in a row with it switched on", not s.isValidMineralTarget(chunk(s, {"H2O": most}), hudRow) and not s.isValidMineralTarget(chunk(s, {"H2O": most}), row(["H2O"])))
	rule.setMineralOn("H2O", true)
	check("H2O switched on on the tab: it counts for the HUD's row too, which can't switch it on", s.isValidMineralTarget(chunk(s, {"H2O": k}), hudRow) and not s.isValidMineralTarget(chunk(s, {"H2O": k - 1}), hudRow) and not hudRow.minerals.has("H2O"))
	rule.setMineralOn("H2O", false)
	check("the row's own switches no longer count: a mineral switched on on the tab passes a row without it", s.isValidMineralTarget(chunk(s, {"Fe": k}), row(["Be"])) and s.isValidMineralTarget(chunk(s, {"Fe": k}), row([])))
	rule.setMineralOn("Be", false)
	check("a mineral switched off on the tab doesn't count, however much there is, even switched on in the row", not s.isValidMineralTarget(chunk(s, {"Be": most}), hudRow) and hudRow.minerals.has("Be"))
	rule.setMineralOn("Be", true)
	check("one of two minerals reaching its mass is enough", s.isValidMineralTarget(chunk(s, {"Be": k - 1, "Fe": k}), hudRow))
	check("two minerals both below their mass: refused", not s.isValidMineralTarget(chunk(s, {"Be": k - 1, "Fe": k - 1}), hudRow))
	check("no minerals: refused", not s.isValidMineralTarget(chunk(s, {}), hudRow))
	hudRow.minValue = 1e12
	var cheap = chunk(s, {"Be": k}, 1.0)
	check("the Minimum value no longer counts: a cheap chunk with the mass passes, where the game refuses it", s.isValidMineralTarget(cheap, hudRow) and not gameAnswer(s, cheap, hudRow))
	hudRow.minValue = 0
	check("the value no longer counts: a rich chunk without the mass is refused", not s.isValidMineralTarget(chunk(s, {"Be": k - 1}, 1e12), hudRow))
	rule.setMinMass("Fe", mass.min)
	check("each mineral's own mass counts: Fe at its minimum passes with that, Be still needs its own", s.isValidMineralTarget(chunk(s, {"Fe": float(mass.min)}), hudRow) and not s.isValidMineralTarget(chunk(s, {"Be": k - 1}), hudRow))
	for m in rule.minerals():
		rule.setMinMass(m, mass.min)
	var any = true
	for m in CurrentGame.traceMinerals:
		any = any and s.isValidMineralTarget(chunk(s, {m: float(mass.min)}), hudRow)
	check("every mass at its minimum: any mineral switched on that the chunk holds is enough, a switched-off one never", any and not s.isValidMineralTarget(chunk(s, {"H2O": most}), hudRow))
	for m in rule.minerals():
		rule.setMineralOn(m, false)
	check("every mineral switched off on the tab: no identified chunk passes", not s.isValidMineralTarget(chunk(s, {"Be": most, "Fe": most, "H2O": most}), hudRow))
	for m in rule.minerals():
		rule.setMineralOn(m, rule.mineralDefault(m))
		rule.setMinMass(m, k)

	# An arm's or a drone plant's row: its own switches, H2O among them, its own Minimum value and albedo
	var armRow = row(["H2O", "Be"], 1e12, 50.0)
	check("a row with H2O switched on: H2O still counts only once switched on on the tab", not s.isValidMineralTarget(chunk(s, {"H2O": most}), armRow))
	var poor = chunk(s, {"Be": k}, 1.0)
	check("the row's Minimum value and albedo don't count for an identified chunk with the mass, which the game refuses", s.isValidMineralTarget(poor, armRow) and not gameAnswer(s, poor, armRow))
	check("a chunk not yet identified: the game decides, by the row's albedo", asGame(s, unidentified(), [row(["H2O", "Be"]), row(["H2O", "Be"], 0.0, 50.0)], [true, false]))
	check("a row without mineral targeting: the game decides", asGame(s, heavy, [{}, {"minerals": ["Be"]}], [true, true]))
	s.playerControlled = false
	s.ai = true
	s.aiTarget = heavy
	var itsTarget = asGame(s, heavy, [hudRow, armRow], [true, true])
	s.aiTarget = null
	check("another ship: the game decides", itsTarget and asGame(s, heavy, [hudRow, armRow], [false, false]))
	s.ai = false
	s.playerControlled = true
	rule.setEnabled(false)
	check("switched off again, the game decides the arm's row", asGame(s, poor, [armRow, row(["H2O", "Be"])], [false, true]))

	# The Geologist tab: the mineral switches and Minimum values of the rows the mod judges, disabled and dimmed while
	# the switch is on. The rows: the HUD itself, an arm and a cargo container's dock, whose Minimum value the game hides.
	settings.setEnabled(false)
	var list = makeGeologist(tabs)
	var arm = system(ship, false, 3000.0)
	var dock = system(ship, true)
	ship.mineralSystems = {"hud": {"ref": hud, "name": "SYSTEM_HUD"}, "arm": {"ref": arm, "name": "SYSTEM_SALVAGE_ARM"}, "dock": {"ref": dock, "name": "SYSTEM_EXSTORAGE"}}
	ship.emit_signal("systemsChanged", ship.getSystems())
	var geologistIndex = names(tabs).find(GEOLOGIST)
	tabs.current_tab = geologistIndex
	yield(idle(), "completed")
	var prices = controls(list, "value")
	var switches = mineralSwitches(list)
	var gameLook = look(list)
	check("switched off, the Geologist tab as the game: the HUD's and the arm's Minimum value shown, not the dock's, and each row's mineral switches", prices.size() == 3 and shown(prices[hud]) and shown(prices[arm]) and not shown(prices[dock]) and switches.size() == 3 and not switches[hud].empty() and not switches[arm].empty() and not switches[dock].empty())
	var priceTitle = header(list)
	var priceTitleFocus = priceTitle.focus_mode
	var listWidth = list.get_combined_minimum_size().x
	check("switched off, the Minimum value column's title as the game's, taking focus", priceTitle.text == "HUD_MIN_PRICE" and priceTitleFocus != Control.FOCUS_NONE, [priceTitle.text, priceTitleFocus])
	tabs.current_tab = index
	yield(idle(), "completed")
	settings.setEnabled(true)
	var configBefore = JSON.print(ship.shipConfig)
	tabs.current_tab = geologistIndex
	yield(idle(), "completed")
	var dim = list.modulateDisabled
	var off = true
	for sys in [hud, arm]:
		for mineralSwitch in switches[sys]:
			off = off and mineralSwitch.disabled and mineralSwitch.modulate == dim and mineralSwitch.pressed == gameLook[mineralSwitch][0]
	check("switched on, once the Geologist tab shows: every mineral switch of the HUD's and the arm's rows disabled and dimmed, as the game dims a switch a row can't use, still showing its state", off)
	var dimmed = true
	for p in [prices[hud], prices[arm]]:
		dimmed = dimmed and shown(p) and p.value == gameLook[p][1] and p.get_node(PRICE_VALUE).disabled and not p.get_node(PRICE_BAR).editable and p.modulate == dim
	check("their Minimum values still shown, with their values, dimmed, the value's button disabled and the bar not draggable", dimmed)
	var nowLook = look(list)
	var dockNodes = switches[dock] + [prices[dock]]
	check("the dock's row as the game set it", same(lookOf(nowLook, dockNodes), lookOf(gameLook, dockNodes)))
	var albedos = controls(list, "albedo").values()
	check("the Minimum Albedo controls as the game set them", albedos.size() == 3 and same(lookOf(nowLook, albedos), lookOf(gameLook, albedos)))
	check("the column's title as the game's, taking focus, and the list as wide", priceTitle.text == "HUD_MIN_PRICE" and priceTitle.focus_mode == priceTitleFocus and list.get_combined_minimum_size().x == listWidth, [priceTitle.text, priceTitle.focus_mode, list.get_combined_minimum_size().x, listWidth])
	var hudSwitch = switches[hud][0]
	var armValue = prices[arm].get_node(PRICE_VALUE)
	var armBar = prices[arm].get_node(PRICE_BAR)
	hudSwitch.grab_focus()
	yield(tapJoy(JOY_BUTTON_0), "completed")
	var switchHeld = tabs.get_focus_owner() == hudSwitch and hudSwitch.pressed == gameLook[hudSwitch][0]
	armValue.grab_focus()
	yield(tapJoy(JOY_BUTTON_0), "completed")
	check("a disabled switch keeps its focus, and A changes nothing; A on a disabled Minimum value doesn't open its bar", switchHeld and tabs.get_focus_owner() == armValue, tabs.get_focus_owner())
	check("the Geologist tab stores nothing", JSON.print(ship.shipConfig) == configBefore)
	tabs.current_tab = index
	yield(idle(), "completed")
	settings.setEnabled(false)
	tabs.current_tab = geologistIndex
	yield(idle(), "completed")
	check("switched off again: every control back as the game set it, with its value", same(look(list), gameLook) and prices[arm].value == arm.getMinValue() and prices[hud].value == hud.getMinValue())
	armValue.grab_focus()
	yield(tapJoy(JOY_BUTTON_0), "completed")
	var opened = tabs.get_focus_owner() == armBar
	yield(tapJoy(JOY_BUTTON_0), "completed")
	check("and A on the arm's Minimum value opens its bar again, as in the game", opened)
	settings.setEnabled(true)
	ship.emit_signal("systemsChanged", ship.getSystems())
	var rebuiltPrices = controls(list, "value")
	var rebuiltSwitches = mineralSwitches(list)
	var atOnce = rebuiltPrices.size() == 3 and rebuiltPrices[hud] != prices[hud] and shown(rebuiltPrices[hud]) and rebuiltPrices[hud].get_node(PRICE_VALUE).disabled and rebuiltPrices[arm].get_node(PRICE_VALUE).disabled and not shown(rebuiltPrices[dock])
	for sys in [hud, arm]:
		for mineralSwitch in rebuiltSwitches[sys]:
			atOnce = atOnce and mineralSwitch.disabled and mineralSwitch.modulate == dim
	check("rows built anew while it is on: disabled and dimmed at once", atOnce)
	ship.playerControlled = false
	yield(idle(), "completed")
	var asGameAgain = not rebuiltPrices[hud].get_node(PRICE_VALUE).disabled and rebuiltPrices[arm].get_node(PRICE_BAR).editable and rebuiltPrices[arm].modulate != dim
	for mineralSwitch in rebuiltSwitches[arm]:
		asGameAgain = asGameAgain and not mineralSwitch.disabled
	check("another ship's Geologist tab: as the game", asGameAgain)
	ship.playerControlled = true
	settings.setEnabled(false)

	# The start of a dive: Godot runs Code.gd's _ready as Game.gd _respawn_ship adds the player's ship to the ring scene.
	# Called directly, it runs the mod's alone (a direct call takes the most derived), not the game's, which needs a whole
	# ship.
	var diving = diveShip(modId, k, true, "rings")
	diving._ready()
	var dived = diving._geologyByMass()
	var allOn = true
	for m in dived.minerals():
		allOn = allOn and dived.isMineralOn(m)
	check("a dive starts (the player's ship in the rings, initialize on), the switch for it on: every mineral switched on, H2O too", allOn and dived.isMineralOn("H2O"), diving.shipConfig.hud.config[modId].mineralOn)
	check("and the switch at the top, the least masses and the switch for the start of a dive as they were", dived.isEnabled() and dived.getMinMass("Be") == k and dived.getMinMass("Fe") == float(mass.default) and dived.isAllAtDive())
	var untouched = []
	for built in [diveShip(modId, k, false, "rings"), diveShip(modId, k, true, ""), diveShip(modId, k, true, "sim"), diveShip(modId, k, true, "rings", false), diveShip(modId, k, true, "rings", true, false)]:
		var beforeDive = JSON.print(built.shipConfig)
		built._ready()
		untouched.append(JSON.print(built.shipConfig) == beforeDive)
	check("nothing changes, nor is stored: the switch for it off, the station's ship (no zone), the simulator's (sim), a teleport's copy (initialize off), another ship", untouched == [true, true, true, true, true], untouched)
	var noRow = gameShip(load(SHIP), {}, true)
	noRow.zone = "rings"
	noRow._ready()
	check("a ship whose HUD keeps no Geologist tab settings: nothing stored", noRow.shipConfig.hud.config.empty(), noRow.shipConfig)

	# A HUD without mineral targeting: no tab
	var shipBare = makeShip()
	var hudBare = load(HUD_SCENE).instance()
	hudBare.mineralTargetting = false
	shipBare.add_child(hudBare)
	hudBare.set_process(false)
	hudBare.set_physics_process(false)
	yield(buildOms(shipBare), "completed")
	var tabsBare = hudBare.inventory.get_node(TABS)
	check("a HUD without mineral targeting gets no tab", not tabsBare.has_node(tabName), names(tabsBare))

	# The settings
	var ship2 = makeShip()
	var hud2 = makeHud(ship2)
	var s2 = hud2._geologyByMass()
	var config = hud2.mineralConfig
	var defaults = s2.isEnabled() == enabledDesc.default and s2.isAllAtDive() == model.ALL_AT_DIVE.default
	for m in s2.minerals():
		defaults = defaults and s2.getMinMass(m) == float(mass.default) and s2.isMineralOn(m) == CurrentGame.traceMinerals.has(m) and s2.mineralDefault(m) == CurrentGame.traceMinerals.has(m)
	check("a ship without the mod's entry gets the defaults, the switches the game's own for a new row", defaults)
	s2.setEnabled(enabledDesc.default)
	s2.setAllAtDive(model.ALL_AT_DIVE.default)
	s2.setMinMass("Be", mass.default)
	s2.setMineralOn("Be", true)
	s2.setMineralOn("H2O", false)
	check("reading, or setting a value already held, stores nothing", not config.has(modId), config.keys())
	check("the minerals are every one of the market, H2O too, whatever the HUD can switch on (onlyMinerals)", s2.minerals() == CurrentGame.mineralPrices.keys() and hud2.onlyMinerals, s2.minerals())
	s2.setMinMass("Be", mass.min - mass.step)
	var low = s2.getMinMass("Be")
	s2.setMinMass("Be", mass.max + mass.step)
	var high = s2.getMinMass("Be")
	s2.setMinMass("Be", mass.min + mass.step * 1.4)
	var between = s2.getMinMass("Be")
	s2.setMinMass("Be", "lots")
	var text = s2.getMinMass("Be")
	check("a mass set is clamped to the range, snapped to a step, a non-number gives the default", low == mass.min and high == mass.max and between == mass.min + mass.step and text == float(mass.default), [low, high, between, text])
	var game = {"minerals": config.minerals.duplicate(), "minValue": config.minValue, "albedo": config.albedo}
	s2.setEnabled(not enabledDesc.default)
	s2.setAllAtDive(not model.ALL_AT_DIVE.default)
	s2.setMinMass("Be", k)
	s2.setMineralOn("H2O", true)
	var entry = config.get(modId, {})
	var everyMineral = entry.get("minMass", {}).keys() == s2.minerals() and entry.get("mineralOn", {}).keys() == s2.minerals()
	check("stored under the mod's id, with the format and the mod's version, both switches, and every mineral's mass and switch", entry.get("formatVersion") == model.FORMAT_VERSION and entry.get("modVersion") == manifestVersion() and s2.modVersion() == manifestVersion() and entry.get("enabled") == (not enabledDesc.default) and entry.get("allAtDive") == (not model.ALL_AT_DIVE.default) and entry.get("minMass", {}).get("Be") == k and entry.get("mineralOn", {}).get("H2O") == true and everyMineral and entry.size() == 6, entry)
	check("the Geologist tab's own settings are untouched", config.minerals == game.minerals and config.minValue == game.minValue and config.albedo == game.albedo and config.size() == 4, config.keys())
	check("stored in the ship's config itself (hud.config), as the game's are", ship2.getConfig("hud.config") == config and ship2.shipConfig.hud.config.has(modId))
	var ship3 = makeShip(JSON.parse(JSON.print(ship2.shipConfig)).result)
	var s3 = makeHud(ship3)._geologyByMass()
	check("after a save and load (JSON) the values are back", s3.isEnabled() == (not enabledDesc.default) and s3.isAllAtDive() == (not model.ALL_AT_DIVE.default) and s3.getMinMass("Be") == k and s3.isMineralOn("H2O") and s3.isMineralOn("Fe"), [s3.isEnabled(), s3.isAllAtDive(), s3.getMinMass("Be"), s3.isMineralOn("H2O")])
	config[modId] = {"enabled": "yes", "allAtDive": 1, "minMass": {"Be": mass.min - mass.step, "Fe": "lots", "Pd": mass.max * 2, "V": mass.min + mass.step * 2.6}, "mineralOn": {"Be": "yes", "H2O": true, "Fe": false}}
	check("a hand-edited entry is clamped, snapped, and non-values give the defaults", s2.isEnabled() == enabledDesc.default and s2.isAllAtDive() == model.ALL_AT_DIVE.default and s2.getMinMass("Be") == mass.min and s2.getMinMass("Fe") == float(mass.default) and s2.getMinMass("Pd") == mass.max and s2.getMinMass("V") == mass.min + 3 * mass.step and s2.isMineralOn("Be") and s2.isMineralOn("H2O") and not s2.isMineralOn("Fe"), [s2.isEnabled(), s2.getMinMass("Be"), s2.getMinMass("Fe"), s2.getMinMass("Pd"), s2.getMinMass("V"), s2.isMineralOn("Be")])
	config[modId] = {"enabled": true, "minMass": [1, 2], "mineralOn": "all"}
	var notDictionaries = true
	for m in s2.minerals():
		notDictionaries = notDictionaries and s2.getMinMass(m) == float(mass.default) and s2.isMineralOn(m) == s2.mineralDefault(m)
	check("masses or switches that aren't a dictionary give the defaults", notDictionaries)

	# Entries stored by earlier formats: format 1 kept each mineral's least mass in minMass, format 2 a base for every
	# mineral (baseMass) and each mineral's extra mass on top of it (extraMass); neither had mineral switches.
	var changed = mass.max if mass.default != mass.max else mass.min # a mass other than the default
	config[modId] = {"formatVersion": 1, "modVersion": "stored", "enabled": true, "minMass": {"Be": k}}
	var oldSwitches = true
	for m in s2.minerals():
		oldSwitches = oldSwitches and s2.isMineralOn(m) == s2.mineralDefault(m)
	check("a format-1 entry's minMass reads as the least masses, the switches as their defaults", s2.isEnabled() and s2.getMinMass("Be") == k and s2.getMinMass("Fe") == float(mass.default) and oldSwitches and s2.isAllAtDive() == model.ALL_AT_DIVE.default)
	s2.setMinMass("Fe", changed)
	entry = config.get(modId, {})
	check("its first change stores it in this format", entry.get("formatVersion") == model.FORMAT_VERSION and entry.get("enabled") == true and entry.get("allAtDive") == model.ALL_AT_DIVE.default and entry.get("minMass", {}).get("Be") == k and entry.get("minMass", {}).get("Fe") == changed and entry.get("mineralOn", {}).get("H2O") == false and entry.size() == 6, entry)
	var base = mass.step # a base and an extra mass, and a pair whose sum is past the range
	var extra = k
	var stored2 = {"formatVersion": 2, "modVersion": "stored", "enabled": true, "baseMass": base, "extraMass": {"Be": extra, "Pt": mass.max}}
	config[modId] = stored2.duplicate(true)
	oldSwitches = true
	for m in s2.minerals():
		oldSwitches = oldSwitches and s2.isMineralOn(m) == s2.mineralDefault(m)
	check("a format-2 entry keeps every threshold: the base plus each extra, the base alone without one, the slider's most past it", s2.isEnabled() and s2.getMinMass("Be") == base + extra and s2.getMinMass("Fe") == base and s2.getMinMass("Pt") == mass.max and oldSwitches, [s2.getMinMass("Be"), s2.getMinMass("Fe"), s2.getMinMass("Pt")])
	check("reading it stores nothing", same(config[modId], stored2), config[modId])
	s2.setMineralOn("V", false)
	entry = config.get(modId, {})
	check("its first change stores it in this format, with every mineral's least mass", entry.get("formatVersion") == model.FORMAT_VERSION and entry.get("minMass", {}).get("Be") == base + extra and entry.get("minMass", {}).get("Fe") == base and entry.get("mineralOn", {}).get("V") == false and entry.get("allAtDive") == model.ALL_AT_DIVE.default and not entry.has("baseMass") and not entry.has("extraMass") and entry.size() == 6, entry)

	# A preheated ship: the HUD's _ready builds the OMS before it loads mineralConfig from the ship
	var stored = {"formatVersion": model.FORMAT_VERSION, "modVersion": "stored", "enabled": not enabledDesc.default, "allAtDive": not model.ALL_AT_DIVE.default, "minMass": {"Be": k}, "mineralOn": {"H2O": true, "Be": false}}
	var hot = {"minerals": CurrentGame.traceMinerals.duplicate(), "minValue": 0, "albedo": 0}
	hot[modId] = stored
	var ship4 = makeShip({"hud": {"config": hot}}, true)
	var hud4 = makeHud(ship4)
	yield(idle(), "completed")
	var tabs4 = hud4.inventory.get_node(TABS) if hud4.inventory != null else null
	var tab4 = tabs4.get_node_or_null(tabName) if tabs4 != null else null
	check("a preheated ship's OMS gets the tab", tab4 != null)
	if tab4 != null:
		var beSlider = tab4._sliders.get("Be")
		var beValue = tab4._values.get("Be")
		check("and it shows the ship's stored values", tab4._toggle.pressed == stored.enabled and tab4._allAtDive.pressed == stored.allAtDive and tab4._switches.H2O.pressed and not tab4._switches.Be.pressed and tab4._switches.Fe.pressed and beSlider != null and beSlider.value == k and beValue != null and beValue.text == worthText(tab4, "Be", k) and (tab4._grid.modulate == Color.white) == stored.enabled, [tab4._toggle.pressed, beSlider.value if beSlider != null else null, beValue.text if beValue != null else null])
		check("and stores nothing on its own", hud4.mineralConfig[modId] == stored and stored.modVersion == "stored")

	# The texts (i18n/en.po), also in a language without them (Godot's fallback, en)
	var ui = load(UI)
	var keys = [tabName, enabledDesc.label, ui.HINT, model.ALL_AT_DIVE.label, model.MINERAL_SWITCH.label, mass.label, ui.NO_GEOLOGIST]
	var translated = true
	for key in keys:
		translated = translated and tr(key) != key
	check("the tab's texts are translated", translated, keys)
	var locale = TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	translated = true
	for key in keys:
		translated = translated and tr(key) != key
	check("a language without them shows the English texts", translated)
	TranslationServer.set_locale(locale)
	_free()

func _free():
	for body in _bodies:
		body.free()
	_bodies = []
	for s in _ships:
		s.free()
	_ships = []
