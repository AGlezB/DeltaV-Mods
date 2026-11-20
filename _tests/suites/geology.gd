extends "res://harness/suite.gd"

# GeologyByMass: with the switch on its OMS tab on, the player's ship judges an identified chunk, for every row of the
# Geologist tab (the HUD's for the info boxes, an arm's, a drone plant's), by the mass of each mineral switched on in
# that row, against the base mass plus that mineral's extra mass, instead of by its value (ships/ship-ctrl.gd
# isValidMineralTarget, which every system asks with its own row); the settings live in the HUD's mineralConfig (the
# ship's "hud.config"), next to the Geologist tab's own, and a format-1 entry (1.0.0's minMass) still loads; the tab
# comes right after the Geologist tab, with a row for every mineral of the market, H2O too. The rule runs on ships of
# the game's ship-ctrl.gd (with the mod, its extension), out of the tree, compared with the same ship on the game's
# script where the game decides. The tab runs on HUDs from harness/geology_hud.tscn (the game's Hud.gd, with an
# Inventory placeholder of harness/geology_oms.tscn: the game's OMS.gd and TabsWithGamepadControl.gd, and the OMS's
# four role tabs) on harness/geology_ship.gd, whose isValidMineralTarget records each call in place of the game's
# rule. While the switch is on, the Geologist tab (the game's hud/SystemMineralList.gd, with the mod its extension,
# added to that OMS's Geologist tab) hides its rows' Minimum values and that column's title. The mod's settings
# descriptions and constants are read from the mod, so any value of them passes. The control checks run on the game's
# own Hud.gd, ship-ctrl.gd and SystemMineralList.gd.

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

# Whether no control of the list has a focus neighbour on a hidden Minimum value (SystemMineralList.gd adjustFocus).
func focusSkipsHidden(list) -> bool:
	var hidden = []
	for c in controls(list, "value").values():
		if not shown(c):
			hidden.append(c.label.get_path())
	for c in list.get_children():
		if c.is_queued_for_deletion():
			continue
		var n = c.label if "label" in c and c.label else c
		if n is Control:
			for side in ["focus_neighbour_left", "focus_neighbour_right", "focus_neighbour_top", "focus_neighbour_bottom"]:
				if hidden.has(n.get(side)):
					return false
	return true

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

# What the tab shows after a mineral's slider: its least mass, base plus extra.
func totalText(tab, unit, kg) -> String:
	return (tab.TOTAL_FORMAT + unit) % CurrentGame.formatThousands(kg)

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
	var base = model.BASE_MASS
	var extra = model.EXTRA_MASS
	var b = inside(base) # a base and an extra mass inside their ranges
	var e = inside(extra)
	var k = b + e # the least mass they give
	var most = base.max + extra.max + 1 # above any least mass
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
	var shown = []
	for c in tabs.get_children():
		shown.append(c.visible)
	var expectShown = []
	for i in tabs.get_child_count():
		expectShown.append(i == tabs.current_tab)
	check("only the current tab shows", shown == expectShown, shown)
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
	var baseName = kids[0]
	var baseSlider = kids[1]
	var baseBar = baseSlider.get_node("Box/HSlider")
	var baseEmpty = kids[2]
	check("the base row comes first: its name is its key, which has a translation, in the Geologist tab's names (MineralLabel), taking no focus; nothing in the third column", grid.columns == 3 and baseName.get_script().resource_path == "res://hud/components/MineralLabel.gd" and baseName.text == base.label and tr(base.label) != base.label and baseName.focus_mode == Control.FOCUS_NONE and baseSlider == tab._baseSlider and baseEmpty.get_class() == "Control" and baseEmpty.get_child_count() == 0)
	check("the base slider is the Minimum value control with BASE_MASS's range, step, unit and tooltip, and shows the stored base", baseSlider.get_script().resource_path == "res://hud/components/PriceLabel.gd" and baseBar.min_value == base.min and baseBar.max_value == base.max and baseBar.step == base.step and baseBar.hint_tooltip == base.label + "_DESC" and tr(baseBar.hint_tooltip) != baseBar.hint_tooltip and baseSlider.format == "%s " + base.unit and baseSlider.value == settings.getBaseMass() and baseSlider.label.text == baseSlider.format % CurrentGame.formatThousands(baseSlider.value), baseSlider.label.text)
	var minerals = []
	var totals = {}
	var colours = true
	var ranges = true
	var values = true
	for i in range(3, kids.size() - 2, 3):
		var label = kids[i]
		var slider = kids[i + 1]
		var total = kids[i + 2]
		minerals.append(label.mineral)
		totals[label.mineral] = total
		colours = colours and label.modulate == CurrentGame.specificMineralColors.get(label.mineral, Color.white) and label.focus_mode == Control.FOCUS_NONE
		var bar = slider.get_node("Box/HSlider")
		ranges = ranges and slider.get_script().resource_path == "res://hud/components/PriceLabel.gd" and bar.min_value == extra.min and bar.max_value == extra.max and bar.step == extra.step and bar.hint_tooltip == extra.label and slider.format == tab.EXTRA_FORMAT + extra.unit
		values = values and slider.value == settings.getExtraMass(label.mineral) and slider.label.text == slider.format % CurrentGame.formatThousands(slider.value) and total is Label and total.text == totalText(tab, extra.unit, settings.getMinMass(label.mineral))
	check("then one row per mineral of the market, H2O too, in the order of the Geologist tab's columns", minerals == CurrentGame.mineralPrices.keys() and minerals == settings.minerals() and minerals.has("H2O") and kids.size() == 3 * (minerals.size() + 1), minerals)
	check("each name is the Geologist tab's, in the mineral's colour, and takes no focus", colours)
	check("each mineral's slider is the Minimum value control with EXTRA_MASS's range, step and tooltip, and the extra mass as EXTRA_FORMAT", ranges)
	var widths = []
	var wide = true
	for i in range(1, kids.size(), 3):
		var bar = kids[i].get_node("Box/HSlider")
		widths.append(bar.rect_size.x)
		wide = wide and bar.rect_min_size.x == tab.SLIDER_WIDTH and bar.rect_size.x == tab.SLIDER_WIDTH
	check("each bar, the base's too, is the tab's SLIDER_WIDTH wide, once laid out", wide and widths.size() == minerals.size() + 1, widths)
	var header = toggle.get_parent()
	var title = header.get_child(header.get_child_count() - 1)
	var gap = title.rect_position.x - (toggle.rect_position.x + toggle.rect_size.x)
	check("the switch's label stands the tab's TOGGLE_SPACING after it, once laid out", header is HBoxContainer and title is Label and title != toggle and gap == tab.TOGGLE_SPACING, gap)
	check("each mineral's slider shows its stored extra mass, and its total the base plus that", values)
	check("the rows are dimmed while the switch is off, and not while it is on", (grid.modulate == Color.white) == settings.isEnabled() and (settings.isEnabled() or grid.modulate.a < 1.0), grid.modulate)

	var before = settings.isEnabled()
	toggle.pressed = not before
	check("pressing the switch stores it, in the HUD's mineralConfig", settings.isEnabled() == (not before) and hud.mineralConfig.get(modId, {}).get("enabled") == (not before))
	toggle.pressed = true
	check("switched on, the rows are not dimmed", grid.modulate == Color.white, grid.modulate)
	toggle.pressed = false
	check("switched off, the rows are dimmed, the base row too", grid.modulate.a < 1.0 and baseSlider.get_parent() == grid, grid.modulate)
	var first = minerals[0]
	var firstSlider = kids[4]
	firstSlider.get_node("Box/HSlider").value = e
	check("moving a mineral's slider stores its extra mass", settings.getExtraMass(first) == e and hud.mineralConfig[modId].extraMass.get(first) == e, settings.getExtraMass(first))
	check("and shows it with a plus, in the mod's unit, and its total", firstSlider.label.text == "+%s %s" % [CurrentGame.formatThousands(e), extra.unit] and totals[first].text == totalText(tab, extra.unit, base.default + e), [firstSlider.label.text, totals[first].text])
	baseBar.value = b
	var all = true
	for m in totals:
		all = all and totals[m].text == totalText(tab, extra.unit, b + settings.getExtraMass(m))
	check("moving the base slider stores it, and every total follows", settings.getBaseMass() == b and hud.mineralConfig[modId].baseMass == b and all and totals[first].text == totalText(tab, extra.unit, k), totals[first].text)
	check("the base slider shows the mass in the mod's unit", baseSlider.label.text == "%s %s" % [CurrentGame.formatThousands(b), base.unit], baseSlider.label.text)
	firstSlider.get_node("Box/HSlider").value = extra.default
	baseBar.value = base.default

	tabs.current_tab = 0
	tabs.get_node("CREW_OCCUPATION_MECHANIC/Fix").grab_focus()
	yield(idle(), "completed")
	tabs.current_tab = index
	yield(idle(), "completed")
	check("choosing the tab focuses its switch", tabs.get_focus_owner() == toggle, tabs.get_focus_owner())

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
	rule.setBaseMass(b)
	for m in rule.minerals():
		rule.setExtraMass(m, e)
	check("below a mineral's base plus extra mass: refused", not s.isValidMineralTarget(chunk(s, {"Be": k - 1}), hudRow))
	check("at a mineral's base plus extra mass: passes", s.isValidMineralTarget(chunk(s, {"Be": k}), hudRow))
	check("above a mineral's base plus extra mass: passes", s.isValidMineralTarget(chunk(s, {"Be": k + 1}), hudRow))
	hudRow.minerals.erase("Be")
	check("a mineral switched off in the row doesn't count, however much there is", not s.isValidMineralTarget(chunk(s, {"Be": most}), hudRow))
	hudRow.minerals.append("Be")
	check("one of two minerals reaching its mass is enough", s.isValidMineralTarget(chunk(s, {"Be": k - 1, "Fe": k}), hudRow))
	check("two minerals both below their mass: refused", not s.isValidMineralTarget(chunk(s, {"Be": k - 1, "Fe": k - 1}), hudRow))
	check("only minerals not switched on: refused", not s.isValidMineralTarget(chunk(s, {"H2O": most}), hudRow))
	check("no minerals: refused", not s.isValidMineralTarget(chunk(s, {}), hudRow))
	hudRow.minValue = 1e12
	var cheap = chunk(s, {"Be": k}, 1.0)
	check("the Minimum value no longer counts: a cheap chunk with the mass passes, where the game refuses it", s.isValidMineralTarget(cheap, hudRow) and not gameAnswer(s, cheap, hudRow))
	hudRow.minValue = 0
	check("the value no longer counts: a rich chunk without the mass is refused", not s.isValidMineralTarget(chunk(s, {"Be": k - 1}, 1e12), hudRow))
	rule.setExtraMass("Fe", extra.min)
	check("each mineral's own extra mass counts: Fe without one needs only the base, Be still needs base plus extra", s.isValidMineralTarget(chunk(s, {"Fe": b + extra.min}), hudRow) and not s.isValidMineralTarget(chunk(s, {"Fe": b + extra.min - 1}), hudRow) and not s.isValidMineralTarget(chunk(s, {"Be": k - 1}), hudRow))
	for m in rule.minerals():
		rule.setExtraMass(m, extra.min)
	var alone = true
	for m in hudRow.minerals:
		alone = alone and s.isValidMineralTarget(chunk(s, {m: b + extra.min}), hudRow) and not s.isValidMineralTarget(chunk(s, {m: b + extra.min - 1}), hudRow)
	check("with no extra masses the base alone decides, for every switched-on mineral", alone and not hudRow.minerals.empty())
	var short = chunk(s, {"Fe": b + extra.min - 1})
	var under = s.isValidMineralTarget(short, hudRow)
	rule.setBaseMass(base.min)
	check("the base moves every mineral's least mass: lowered, a chunk short of it passes", not under and s.isValidMineralTarget(short, hudRow))
	check("every slider at its minimum: any switched-on mineral passes, as the game with no Minimum value", s.isValidMineralTarget(chunk(s, {"Fe": float(base.min + extra.min)}), hudRow) and not s.isValidMineralTarget(chunk(s, {"H2O": most}), hudRow))

	# An arm's or a drone plant's row: its own switches, H2O among them, its own Minimum value and albedo; the same masses
	rule.setBaseMass(b)
	for m in rule.minerals():
		rule.setExtraMass(m, e)
	var w = inside(extra) + extra.step if inside(extra) + extra.step <= extra.max else extra.min # an H2O extra other than e
	rule.setExtraMass("H2O", w)
	var armRow = row(["H2O", "Be"], 1e12, 50.0)
	check("a row with H2O switched on: H2O counts, against the base plus its own extra mass", s.isValidMineralTarget(chunk(s, {"H2O": b + w}), armRow) and not s.isValidMineralTarget(chunk(s, {"H2O": b + w - 1}), armRow) and w != e)
	check("the HUD's row, without H2O, refuses that chunk", not s.isValidMineralTarget(chunk(s, {"H2O": most}), hudRow))
	check("each row its own switches: Fe counts in the HUD's row, not in a row without it", s.isValidMineralTarget(chunk(s, {"Fe": k}), hudRow) and not s.isValidMineralTarget(chunk(s, {"Fe": most}), armRow))
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

	# The Geologist tab: its rows' Minimum values and that column's title, hidden while the switch is on. The rows: the
	# HUD itself, an arm and a cargo container's dock, whose Minimum value the game hides.
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
	check("switched off, the Geologist tab shows each row's Minimum value as the game: the HUD's and the arm's, not the dock's", prices.size() == 3 and shown(prices[hud]) and shown(prices[arm]) and not shown(prices[dock]))
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
	check("switched on, once the Geologist tab shows: the HUD's and the arm's Minimum value hidden, the dock's still", not shown(prices[hud]) and not shown(prices[arm]) and not shown(prices[dock]))
	var albedos = controls(list, "albedo")
	check("the Minimum Albedo controls stay as the game set them: the arm's shown, the HUD's and the dock's hidden", albedos.size() == 3 and shown(albedos[arm]) and not shown(albedos[hud]) and not shown(albedos[dock]))
	check("the focus skips the hidden Minimum values", focusSkipsHidden(list))
	check("switched on: the column's title empty, taking no focus, and the column takes no room", priceTitle.text == "" and priceTitle.focus_mode == Control.FOCUS_NONE and list.get_combined_minimum_size().x < listWidth, [priceTitle.text, priceTitle.focus_mode, list.get_combined_minimum_size().x, listWidth])
	check("the Geologist tab stores nothing", JSON.print(ship.shipConfig) == configBefore)
	tabs.current_tab = index
	yield(idle(), "completed")
	settings.setEnabled(false)
	tabs.current_tab = geologistIndex
	yield(idle(), "completed")
	check("switched off again: back as the game set them, with their values", shown(prices[hud]) and shown(prices[arm]) and not shown(prices[dock]) and prices[arm].value == arm.getMinValue() and prices[hud].value == hud.getMinValue())
	check("switched off again: the title back, with the game's focus, and the column's room", priceTitle.text == "HUD_MIN_PRICE" and priceTitle.focus_mode == priceTitleFocus and list.get_combined_minimum_size().x == listWidth, [priceTitle.text, priceTitle.focus_mode, list.get_combined_minimum_size().x, listWidth])
	settings.setEnabled(true)
	ship.emit_signal("systemsChanged", ship.getSystems())
	var rebuilt = controls(list, "value")
	check("rows built anew while it is on: hidden at once", rebuilt.size() == 3 and rebuilt[hud] != prices[hud] and not shown(rebuilt[hud]) and not shown(rebuilt[arm]) and not shown(rebuilt[dock]))
	var rebuiltTitle = header(list)
	check("rows built anew while it is on: the new title empty, taking no focus", rebuiltTitle != priceTitle and rebuiltTitle.text == "" and rebuiltTitle.focus_mode == Control.FOCUS_NONE, [rebuiltTitle.text, rebuiltTitle.focus_mode])
	ship.playerControlled = false
	yield(idle(), "completed")
	check("another ship's Geologist tab: as the game", shown(rebuilt[hud]) and shown(rebuilt[arm]) and not shown(rebuilt[dock]))
	check("another ship's Geologist tab: the title as the game's", rebuiltTitle.text == "HUD_MIN_PRICE" and rebuiltTitle.focus_mode == priceTitleFocus, [rebuiltTitle.text, rebuiltTitle.focus_mode])
	ship.playerControlled = true
	settings.setEnabled(false)

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
	var defaults = s2.isEnabled() == enabledDesc.default and s2.getBaseMass() == float(base.default)
	for m in s2.minerals():
		defaults = defaults and s2.getExtraMass(m) == float(extra.default) and s2.getMinMass(m) == float(base.default + extra.default)
	check("a ship without the mod's entry gets the defaults", defaults)
	s2.setEnabled(enabledDesc.default)
	s2.setBaseMass(base.default)
	s2.setExtraMass("Be", extra.default)
	check("reading, or setting a value already held, stores nothing", not config.has(modId), config.keys())
	check("the minerals are every one of the market, H2O too, whatever the HUD can switch on (onlyMinerals)", s2.minerals() == CurrentGame.mineralPrices.keys() and hud2.onlyMinerals, s2.minerals())
	s2.setExtraMass("Be", extra.min - extra.step)
	var low = s2.getExtraMass("Be")
	s2.setExtraMass("Be", extra.max + extra.step)
	var high = s2.getExtraMass("Be")
	s2.setExtraMass("Be", extra.min + extra.step * 1.4)
	var between = s2.getExtraMass("Be")
	s2.setExtraMass("Be", "lots")
	var text = s2.getExtraMass("Be")
	check("an extra mass set is clamped to the range, snapped to a step, a non-number gives the default", low == extra.min and high == extra.max and between == extra.min + extra.step and text == float(extra.default), [low, high, between, text])
	s2.setBaseMass(base.min - base.step)
	low = s2.getBaseMass()
	s2.setBaseMass(base.max + base.step)
	high = s2.getBaseMass()
	s2.setBaseMass(base.min + base.step * 1.4)
	between = s2.getBaseMass()
	s2.setBaseMass("lots")
	text = s2.getBaseMass()
	check("the base set is clamped to the range, snapped to a step, a non-number gives the default", low == base.min and high == base.max and between == base.min + base.step and text == float(base.default), [low, high, between, text])
	var game = {"minerals": config.minerals.duplicate(), "minValue": config.minValue, "albedo": config.albedo}
	s2.setEnabled(not enabledDesc.default)
	s2.setBaseMass(b)
	s2.setExtraMass("Be", e)
	var entry = config.get(modId, {})
	check("stored under the mod's id, with the format and the mod's version", entry.get("formatVersion") == model.FORMAT_VERSION and entry.get("modVersion") == manifestVersion() and s2.modVersion() == manifestVersion() and entry.get("enabled") == (not enabledDesc.default) and entry.get("baseMass") == b and entry.get("extraMass", {}).get("Be") == e and entry.size() == 5, entry)
	check("the Geologist tab's own settings are untouched", config.minerals == game.minerals and config.minValue == game.minValue and config.albedo == game.albedo and config.size() == 4, config.keys())
	check("stored in the ship's config itself (hud.config), as the game's are", ship2.getConfig("hud.config") == config and ship2.shipConfig.hud.config.has(modId))
	var ship3 = makeShip(JSON.parse(JSON.print(ship2.shipConfig)).result)
	var s3 = makeHud(ship3)._geologyByMass()
	check("after a save and load (JSON) the values are back", s3.isEnabled() == (not enabledDesc.default) and s3.getBaseMass() == b and s3.getExtraMass("Be") == e and s3.getMinMass("Be") == k, [s3.isEnabled(), s3.getBaseMass(), s3.getExtraMass("Be")])
	config[modId] = {"enabled": "yes", "baseMass": base.max * 2, "extraMass": {"Be": extra.min - extra.step, "Fe": "lots", "Pd": extra.max * 2, "V": extra.min + extra.step * 2.6}}
	check("a hand-edited entry is clamped, snapped, and non-values give the defaults", s2.isEnabled() == enabledDesc.default and s2.getBaseMass() == base.max and s2.getExtraMass("Be") == extra.min and s2.getExtraMass("Fe") == float(extra.default) and s2.getExtraMass("Pd") == extra.max and s2.getExtraMass("V") == extra.min + 3 * extra.step, [s2.isEnabled(), s2.getBaseMass(), s2.getExtraMass("Be"), s2.getExtraMass("Fe"), s2.getExtraMass("Pd"), s2.getExtraMass("V")])
	config[modId] = {"enabled": true, "baseMass": "lots", "extraMass": [1, 2], "minMass": {"Be": e}}
	check("a base that isn't a number, or extra masses that aren't a dictionary, give the defaults; minMass is read only without extraMass", s2.getBaseMass() == float(base.default) and s2.getExtraMass("Be") == float(extra.default))

	# An entry stored by format 1 (no base; each mineral's least mass in minMass)
	config[modId] = {"formatVersion": 1, "modVersion": "stored", "enabled": true, "minMass": {"Be": e}}
	check("a format-1 entry's minMass reads as the extra masses, with the default base", s2.isEnabled() and s2.getBaseMass() == float(base.default) and s2.getExtraMass("Be") == e and s2.getMinMass("Be") == base.default + e and s2.getExtraMass("Fe") == float(extra.default))
	var changed = base.max if base.default != base.max else base.min # a base other than the default
	s2.setBaseMass(changed)
	entry = config.get(modId, {})
	check("its first change stores it in this format, minMass as extraMass", entry.get("formatVersion") == model.FORMAT_VERSION and entry.get("enabled") == true and entry.get("baseMass") == changed and entry.get("extraMass", {}).get("Be") == e and not entry.has("minMass"), entry)

	# A preheated ship: the HUD's _ready builds the OMS before it loads mineralConfig from the ship
	var stored = {"formatVersion": model.FORMAT_VERSION, "modVersion": "stored", "enabled": not enabledDesc.default, "baseMass": b, "extraMass": {"Be": e}}
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
		var beTotal = tab4._totals.get("Be")
		check("and it shows the ship's stored values", tab4._toggle.pressed == stored.enabled and tab4._baseSlider.value == b and beSlider != null and beSlider.value == e and beTotal != null and beTotal.text == totalText(tab4, extra.unit, k) and (tab4._grid.modulate == Color.white) == stored.enabled, [tab4._toggle.pressed, tab4._baseSlider.value, beSlider.value if beSlider != null else null, beTotal.text if beTotal != null else null])
		check("and stores nothing on its own", hud4.mineralConfig[modId] == stored and stored.modVersion == "stored")

	# The texts (i18n/en.po), also in a language without them (Godot's fallback, en)
	var keys = [tabName, enabledDesc.label, load(UI).HINT, base.label, base.label + "_DESC", extra.label]
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
