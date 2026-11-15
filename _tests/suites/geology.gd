extends "res://harness/suite.gd"

# GeologyByMass: with the switch on its OMS tab on, the HUD judges an identified chunk by the mass of each mineral
# switched on in the Geologist tab, against the base mass plus that mineral's extra mass, instead of by its value
# (hud/Hud.gd isValidMineralTarget, which the info boxes ask); the settings live in the HUD's mineralConfig (the ship's
# "hud.config"), next to the Geologist tab's own, and a format-1 entry (1.0.0's minMass) still loads; the tab comes
# right after the Geologist tab. The HUDs are harness/geology_hud.tscn (the game's Hud.gd, with an Inventory
# placeholder of harness/geology_oms.tscn: the game's OMS.gd and TabsWithGamepadControl.gd, and the OMS's four role
# tabs) on harness/geology_ship.gd, whose isValidMineralTarget records each call in place of the game's rule. The
# mod's settings descriptions and constants are read from the mod, so any value of them passes. The control checks
# run on the game's own Hud.gd.

const MOD = "GeologyByMass"
const SETTINGS = "res://GeologyByMass/Settings.gd"
const UI = "res://GeologyByMass/SettingsUI.gd"
const MANIFEST = "res://GeologyByMass/Mod.manifest"
const HUD_SCENE = "res://harness/geology_hud.tscn"
const TABS = "MarginContainer/VBoxContainer/TabHintContainer/TabContainer"
const GEOLOGIST = "CREW_OCCUPATION_GEOLOGIST"
const ROLE_TABS = ["CREW_OCCUPATION_MECHANIC", "CREW_OCCUPATION_ASTROGATOR", "CREW_OCCUPATION_GEOLOGIST", "CREW_OCCUPATION_PILOT"]
const FULL = 1 # judged(): the mod kept the info box full
const DIMINISHED = 0
const ASKED = -1

var _bodies = []

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

# The mod's answer: FULL or DIMINISHED; ASKED when it asked the game instead.
func judged(hud, ship, body):
	var before = ship.calls.size()
	var result = hud.isValidMineralTarget(body)
	if ship.calls.size() != before:
		return ASKED
	return FULL if result else DIMINISHED

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
	if not mod:
		check("control: the OMS keeps the game's four tabs", names(tabs) == ROLE_TABS, names(tabs))
		check("control: the game decides an identified chunk", handedToGame(hud, ship, chunk(ship, {"Be": 1.0}, 1.0)))
		check("control: the game decides a chunk not yet identified", handedToGame(hud, ship, unidentified()))
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
	check("then one row per mineral the HUD can switch on, in the Geologist tab's order", minerals == settings.minerals() and kids.size() == 3 * (minerals.size() + 1), minerals)
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

	# The rule
	settings.setEnabled(false)
	var heavy = chunk(ship, {"Be": most}, 1.0)
	check("switched off, the game decides", handedToGame(hud, ship, heavy))
	settings.setEnabled(true)
	settings.setBaseMass(b)
	for m in settings.minerals():
		settings.setExtraMass(m, e)
	check("below a mineral's base plus extra mass: diminished", judged(hud, ship, chunk(ship, {"Be": k - 1})) == DIMINISHED)
	check("at a mineral's base plus extra mass: full", judged(hud, ship, chunk(ship, {"Be": k})) == FULL)
	check("above a mineral's base plus extra mass: full", judged(hud, ship, chunk(ship, {"Be": k + 1})) == FULL)
	hud.setMineralConfig("Be", false)
	check("a mineral switched off in the Geologist tab doesn't count, however much there is", judged(hud, ship, chunk(ship, {"Be": most})) == DIMINISHED)
	hud.setMineralConfig("Be", true)
	check("one of two minerals reaching its mass is enough", judged(hud, ship, chunk(ship, {"Be": k - 1, "Fe": k})) == FULL)
	check("two minerals both below their mass: diminished", judged(hud, ship, chunk(ship, {"Be": k - 1, "Fe": k - 1})) == DIMINISHED)
	check("only minerals not switched on: diminished", judged(hud, ship, chunk(ship, {"H2O": most})) == DIMINISHED)
	check("no minerals: diminished", judged(hud, ship, chunk(ship, {})) == DIMINISHED)
	hud.setMinValue(1e12)
	check("the Minimum value no longer counts: a cheap chunk with the mass is full", judged(hud, ship, chunk(ship, {"Be": k}, 1.0)) == FULL)
	hud.setMinValue(0)
	check("the value no longer counts: a rich chunk without the mass is diminished", judged(hud, ship, chunk(ship, {"Be": k - 1}, 1e12)) == DIMINISHED)
	settings.setExtraMass("Fe", extra.min)
	check("each mineral's own extra mass counts: Fe without one needs only the base, Be still needs base plus extra", judged(hud, ship, chunk(ship, {"Fe": b + extra.min})) == FULL and judged(hud, ship, chunk(ship, {"Fe": b + extra.min - 1})) == DIMINISHED and judged(hud, ship, chunk(ship, {"Be": k - 1})) == DIMINISHED)
	for m in settings.minerals():
		settings.setExtraMass(m, extra.min)
	var alone = true
	for m in hud.mineralConfig.minerals:
		alone = alone and judged(hud, ship, chunk(ship, {m: b + extra.min})) == FULL and judged(hud, ship, chunk(ship, {m: b + extra.min - 1})) == DIMINISHED
	check("with no extra masses the base alone decides, for every switched-on mineral", alone and not hud.mineralConfig.minerals.empty())
	var short = chunk(ship, {"Fe": b + extra.min - 1})
	var under = judged(hud, ship, short)
	settings.setBaseMass(base.min)
	check("the base moves every mineral's least mass: lowered, a chunk short of it is full", under == DIMINISHED and judged(hud, ship, short) == FULL)
	check("every slider at its minimum: any switched-on mineral keeps the box, as the game with no Minimum value", judged(hud, ship, chunk(ship, {"Fe": float(base.min + extra.min)})) == FULL and judged(hud, ship, chunk(ship, {"H2O": most})) == DIMINISHED)
	check("a chunk not yet identified: the game decides", handedToGame(hud, ship, unidentified()))
	ship.playerControlled = false
	check("another ship's HUD: the game decides", handedToGame(hud, ship, heavy))
	ship.playerControlled = true
	var bare = load("res://hud/Hud.gd").new()
	bare.ship = ship
	bare.mineralTargetting = false
	bare._geologyByMass().setEnabled(true)
	bare._geologyByMass().setBaseMass(b)
	check("a HUD without mineral targeting: the game decides, and nothing is stored", handedToGame(bare, ship, heavy) and bare.mineralConfig.empty())
	bare.free()

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
	var trace = []
	for m in CurrentGame.mineralPrices:
		if CurrentGame.traceMinerals.has(m):
			trace.append(m)
	check("the HUD's minerals are the market's it can target (onlyMinerals)", s2.minerals() == trace, s2.minerals())
	hud2.onlyMinerals = false
	check("without onlyMinerals, every mineral of the market", s2.minerals() == CurrentGame.mineralPrices.keys(), s2.minerals())
	hud2.onlyMinerals = true
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
