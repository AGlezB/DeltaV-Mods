extends "res://harness/suite.gd"

# DroneAltPriorities: with the switch on its OMS tab on, the player's tug and haul plants (weapons/drone-plant.gd
# scanForTarget) pick, among the chunks the game lets them take, the one with the best ore value x ore mass x intake
# (each over the best eligible chunk's, raised to its weight), keeping their current target unless another scores more
# than 1 + KEEP_TARGET_MARGIN times as much; the USV-GOT's queue comes first and the eligibility stays the game's; the
# switch off, another ship or the maintenance drones: the game's rule. The settings live in the ship's "hud.config"
# (the HUD's mineralConfig) under the mod's id, where every plant of the ship reads them; the tab comes right after the
# Geologist tab (GeologyByMass's too, when loaded) and has a button that puts every setting back to its default. The
# plants are harness/drones_plant.tscn (the game's drone-plant.gd, with stub children) on harness/drones_ship.gd; the
# HUDs are the geology suite's (harness/geology_hud.tscn, the game's Hud.gd and OMS). The mod's settings descriptions
# and constants are read from the mod, so any value of them passes. The control checks run on the game's own
# drone-plant.gd and Hud.gd.

const MOD = "DroneAltPriorities"
const OTHER_TAB_MOD = "GeologyByMass"
const SETTINGS = "res://DroneAltPriorities/Settings.gd"
const UI = "res://DroneAltPriorities/SettingsUI.gd"
const MANIFEST = "res://DroneAltPriorities/Mod.manifest"
const SHIP = "res://harness/drones_ship.gd"
const PLANT = "res://harness/drones_plant.tscn"
const SLOT = "res://harness/weapon_slot.gd"
const EXCAVATOR = "res://harness/drones_excavator.gd"
const HUD_SCENE = "res://harness/geology_hud.tscn"
const TABS = "MarginContainer/VBoxContainer/TabHintContainer/TabContainer"
const GEOLOGIST = "CREW_OCCUPATION_GEOLOGIST"
const ROLE_TABS = ["CREW_OCCUPATION_MECHANIC", "CREW_OCCUPATION_ASTROGATOR", "CREW_OCCUPATION_GEOLOGIST", "CREW_OCCUPATION_PILOT"]
const SYSTEMS = {"tug": "SYSTEM_DND_TS", "haul": "SYSTEM_DND_HAUL", "repair": "SYSTEM_DND_FIX"}
const EXCAVATOR_AT = Vector2(0, -300) # px from the ship's centre, ahead of it
# px: the chunks of the ranking cases stand this far from the haul drones' gathering spot, beyond the slow zone, where
# the game hauls them at haulVelocity (inside it, a chunk's own velocity mostly stands for the one wanted)
const RING = 2500.0

var _bodies = []
var _slots = 0

# --- building ---

# A ship with an excavator; with `hudConfig`, the mineralConfig its HUD would have made (the mod's settings go there).
func makeShip(hudConfig = true):
	var ship = Node2D.new()
	ship.set_script(load(SHIP))
	if hudConfig:
		ship.shipConfig = {"hud": {"config": {"minerals": CurrentGame.traceMinerals.duplicate(), "minValue": 0, "albedo": 0}}}
	add_child(ship)
	var excavator = Node2D.new()
	excavator.set_script(load(EXCAVATOR))
	excavator.position = EXCAVATOR_AT
	ship.add_child(excavator)
	ship.firedBy = {"x": [excavator]}
	return ship

# A plant of `function` in a hardpoint of `ship`, as its slot holds it. Its processing goes off at once (it would draw
# power and launch drones); the suite calls scanForTarget itself. Energy threshold 1, as the game's slots set it low.
func makePlant(ship, function):
	_slots += 1
	var slot = Node2D.new()
	slot.set_script(load(SLOT))
	slot.slot = "slot%d" % _slots
	ship.add_child(slot)
	ship.setConfig("weaponSlot.%s.type" % slot.slot, SYSTEMS[function])
	var plant = load(PLANT).instance()
	plant.droneFunction = function
	plant.systemName = SYSTEMS[function]
	plant.minEnergyToTarget = 1
	slot.add_child(plant)
	plant.set_physics_process(false)
	return plant

func makeHud(ship):
	var hud = load(HUD_SCENE).instance()
	ship.add_child(hud)
	hud.set_process(false)
	hud.set_physics_process(false)
	return hud

# A chunk in the plants' space (the ship's parent: this suite), still unless given a velocity; `masses` (kg by
# mineral) makes it identified, as MineralMark.gd stores it (ship-ctrl.gd addIdentifiedObject).
func chunk(ship, pos, velocity = Vector2(), mass = 3.0, masses = null, script = null):
	var body = RigidBody2D.new()
	if script != null:
		body.set_script(script)
	body.gravity_scale = 0
	body.mass = mass
	body.position = pos
	add_child(body)
	body.linear_velocity = velocity
	if masses != null:
		ship.identifiedObjects[hash(body)] = [masses, 0.0, pos, body]
	_bodies.append(body)
	return body

# A chunk script with the game's inCargoHold (asteroids/mineral.gd), set to `held`.
func heldScript(held):
	var s = GDScript.new()
	s.source_code = "extends RigidBody2D\nvar inCargoHold = %d\n" % held
	s.reload()
	return s

func idle(count = 2):
	for i in count:
		yield(get_tree(), "idle_frame")

# A press and release of a gamepad button (JOY_*), as Input delivers a player's: the actions it is bound to follow
# (Godot's defaults: the D-pad moves the focus), then the focused control gets it. Input hands parsed events on at the
# next frame, so this waits for it.
func tapJoy(button):
	yield(get_tree(), "idle_frame")
	for pressed in [true, false]:
		var event = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")

# The game's tooltip node (menu/sfx/PlaySoundsOnTheseButtons.gd) among `node`'s children, or null.
func tooltipNode(node):
	for c in node.get_children():
		if c.has_method("connectSounds"):
			return c
	return null

func buildOms(ship):
	ship.emit_signal("instance")
	yield(idle(), "completed")

func names(tabs) -> Array:
	var list = []
	for c in tabs.get_children():
		list.append(c.name)
	return list

func manifestVersion() -> String:
	var manifest = ConfigFile.new()
	manifest.load(MANIFEST)
	return "%d.%d.%d" % [manifest.get_value("version", "version_major"), manifest.get_value("version", "version_minor"), manifest.get_value("version", "version_bugfix")]

# --- picking ---

# What the plant picks at its next scan, from `chunks` in its reach, with `previous` as its current target.
func pick(plant, chunks, previous = null):
	plant.targets = chunks.duplicate()
	plant.target = previous
	plant.scanProcess = plant.scanEvery
	plant.scanForTarget(0.001)
	return plant.target

# The game's pick among `chunks` (weapons/drone-plant.gd scanForTarget, no queue): the most mass x |desired -
# velocity|^2 / distance for haul, mass x speed^2 for tug, above the energy threshold.
func gamePick(plant, chunks):
	var best = plant.minEnergyToTarget
	var choice = null
	for t in chunks:
		var dist = plant.global_position.distance_to(t.global_position)
		var check
		if plant.droneFunction == "haul":
			check = t.mass * pow((plant.desiredVelicityFor(t) - t.linear_velocity).length(), 2) / dist
		else:
			check = t.mass * pow(t.linear_velocity.length(), 2)
		if check > best:
			best = check
			choice = t
	return choice

# The weights, by key, on a ship (through a settings object of its own, as the tab writes them).
func setWeights(settings, value, mass, intake):
	settings.setWeight("value", value)
	settings.setWeight("mass", mass)
	settings.setWeight("intake", intake)

func run():
	var mod = hasMod(MOD)
	if not mod:
		yield(control(), "completed")
		_free()
		return
	ranking()
	_free()
	yield(tab(), "completed")
	settingsCases()
	texts()
	_free()

# --- without the mod: the game's own rule ---

func control():
	var ship = makeShip()
	var haul = makePlant(ship, "haul")
	var tug = makePlant(ship, "tug")
	var chunks = rankingChunks(ship, haul)
	var haulPick = pick(haul, chunks.all)
	check("control: a haul plant picks by the game's rule", haulPick != null and haulPick == gamePick(haul, chunks.all), haulPick)
	var tugPick = pick(tug, chunks.all)
	check("control: a tug plant picks by the game's rule", tugPick != null and tugPick == gamePick(tug, chunks.all), tugPick)
	var hud = makeHud(ship)
	yield(buildOms(ship), "completed")
	var tabs = hud.inventory.get_node(TABS)
	check("control: the OMS keeps the game's four tabs", names(tabs) == ROLE_TABS, names(tabs))

# Three identified chunks the same distance from the haul drones' gathering spot (so the same intake): a light Be one,
# slow (the most valuable: price x kg); a heavy, fast Fe one, the game's pick (the most ore); a Pt one between them.
func rankingChunks(ship, plant):
	var excavator = ship.firedBy.x[0]
	var spot = excavator.global_position + plant.haulGatherSpot.rotated(excavator.global_rotation) # as drone-plant.gd
	var be = chunk(ship, spot + Vector2(RING, 0), Vector2(0, 10), 0.7, {"Be": 100.0, "H2O": 900.0})
	var fe = chunk(ship, spot + Vector2(-RING, 0), Vector2(300, 300), 7.0, {"Fe": 1000.0, "H2O": 200.0})
	var pt = chunk(ship, spot + Vector2(0, -RING), Vector2(0, 50), 3.0, {"Pt": 500.0, "H2O": 500.0})
	return {"be": be, "fe": fe, "pt": pt, "all": [be, fe, pt], "spot": spot}

# --- with the mod: the ranking ---

func ranking():
	var model = load(SETTINGS)
	var ship = makeShip()
	var settings = model.new(ship) # the tab's, apart from each plant's own: what one writes, the others read
	var haul = makePlant(ship, "haul")
	var tug = makePlant(ship, "tug")
	var c = rankingChunks(ship, haul)
	check("the game's pick here is the heavy, fast Fe chunk (the cases below rely on it)", gamePick(haul, c.all) == c.fe and gamePick(tug, c.all) == c.fe)

	settings.setEnabled(false)
	setWeights(settings, 1, 1, 0)
	check("switch off: haul plants pick by the game's rule", pick(haul, c.all) == c.fe)
	check("switch off: tug plants too", pick(tug, c.all) == c.fe)
	settings.setEnabled(true)
	ship.playerControlled = false
	check("another ship's plants pick by the game's rule", pick(haul, c.all) == c.fe and pick(tug, c.all) == c.fe)
	ship.playerControlled = true

	check("switch on, ore value and mass alike: the chunk worth the most (Be: price x kg)", pick(haul, c.all) == c.be)
	check("tug plants too", pick(tug, c.all) == c.be)
	setWeights(settings, 0, 1, 0)
	check("ore mass alone: the chunk with the most ore (Fe)", pick(haul, c.all) == c.fe)
	setWeights(settings, 1, 0, 0)
	check("ore value alone: the dearest ore (Be)", pick(haul, c.all) == c.be)
	var watery = chunk(ship, c.spot + Vector2(0, RING), Vector2(), 3.0, {"Fe": 10.0, "H2O": 100000.0})
	setWeights(settings, 0, 1, 0)
	check("only ore counts as mass, not the water around it", pick(haul, [watery, c.pt]) == c.pt)

	var unknown = chunk(ship, c.spot + Vector2(0, RING), Vector2(400, 400), 7.0)
	setWeights(settings, 1, 1, 0)
	check("a chunk not yet identified comes after the identified ones", pick(haul, [unknown, c.pt]) == c.pt)
	setWeights(settings, 0, 0, 0)
	var all = c.all + [unknown]
	check("every weight at 0: the game's rule decides", pick(haul, all) == gamePick(haul, all) and pick(tug, all) == gamePick(tug, all))
	var near = chunk(ship, c.spot + Vector2(RING / 5, 0), Vector2(), 3.0)
	setWeights(settings, 0, 0, 1)
	check("intake alone: the chunk nearest the gathering spot", pick(haul, c.all + [near, unknown]) == near)
	setWeights(settings, 0, 0, 2)
	check("tug plants ignore intake: the game's rule decides", pick(tug, c.all + [near]) == gamePick(tug, c.all + [near]))

	# Keeping the target: with ore mass alone, a chunk with share x of the best's ore scores (x + floor) times
	# 1 + margin while it is the target, against 1 + floor for the best. Code.gd's constants come through a plant: once
	# installed, Code.gd has taken over the game's path, and loading it again would make it its own parent.
	setWeights(settings, 0, 1, 0)
	var floorShare = haul.SCORE_FLOOR
	var threshold = (1.0 + floorShare) / (1.0 + haul.KEEP_TARGET_MARGIN) - floorShare
	var big = chunk(ship, c.spot + Vector2(RING, -RING / 2), Vector2(), 3.0, {"Fe": 1000.0})
	var above = chunk(ship, c.spot + Vector2(-RING, -RING / 2), Vector2(), 3.0, {"Fe": 1000.0 * min(threshold + 0.1, 0.99)})
	var below = chunk(ship, c.spot + Vector2(-RING, RING / 2), Vector2(), 3.0, {"Fe": 1000.0 * max(threshold - 0.1, 0.01)})
	check("with no current target, the best", pick(haul, [big, above]) == big)
	check("the current target stays while the best scores up to 1 + KEEP_TARGET_MARGIN times as much", threshold > 0 and pick(haul, [big, above], above) == above, threshold)
	check("and gives way to one that scores more", pick(haul, [big, below], below) == big)
	setWeights(settings, 1, 1, 0)

	# The queue and the game's filters
	ship.droneQueue = [c.fe]
	check("the USV-GOT's queue comes first", pick(haul, c.all) == c.fe and pick(tug, c.all) == c.fe)
	ship.droneQueue = []
	ship.refusedByFilter = [c.be]
	check("a chunk the plant's Geologist-tab row turns down is never picked", pick(haul, c.all) == c.pt)
	ship.refusedByFilter = []
	ship.refusedByBus = [c.be]
	check("nor one another system of the ship has taken", pick(haul, c.all) == c.pt)
	ship.refusedByBus = []
	var far = chunk(ship, Vector2(haul.getRangeMax() * 10 + 100, 0), Vector2(), 0.7, {"Be": 1000.0})
	check("nor one beyond the plant's reach", pick(haul, c.all + [far]) == c.be)
	var held = chunk(ship, c.spot + Vector2(RING / 2, 0), Vector2(), 0.7, {"Be": 1000.0}, heldScript(1))
	check("nor one in the cargo hold", pick(haul, c.all + [held]) == c.be)
	var elsewhere = RigidBody2D.new()
	ship.add_child(elsewhere)
	_bodies.append(elsewhere)
	ship.identifiedObjects[hash(elsewhere)] = [{"Be": 1000.0}, 0.0, Vector2(), elsewhere]
	check("nor one outside the plant's space", pick(haul, c.all + [elsewhere]) == c.be)
	var still = chunk(ship, c.spot + Vector2(RING / 2, RING / 2), Vector2(), 0.7, {"Be": 1000.0})
	check("tug plants leave still chunks, as the game's", pick(tug, c.all + [still]) == c.be)

	# Between scans
	haul.targets = c.all.duplicate()
	haul.target = c.fe
	haul.scanProcess = 0
	haul.scanForTarget(0.001)
	check("between scans the target stays", haul.target == c.fe)
	var leaving = chunk(ship, c.spot, Vector2(), 3.0, {"Fe": 10.0}, heldScript(1))
	haul.target = leaving
	haul.scanProcess = 0
	haul.scanForTarget(0.001)
	check("a target taken into the hold is dropped between scans, as the game does", haul.target == null)

	# The maintenance drones
	var fix = makePlant(ship, "repair")
	ship.systems = {"SYSTEM_TEST": {"key": "SYSTEM_TEST", "damage": [{"current": 90.0, "maxRaw": 100.0}]}}
	check("maintenance drones pick by the game's rule (the damaged ship)", pick(fix, []) == ship)
	ship.systems = {}

	# A ship whose HUD keeps no settings (no hud.config): the defaults, and nothing stored
	var bare = makeShip(false)
	var barePlant = makePlant(bare, "haul")
	var b = rankingChunks(bare, barePlant)
	var bareSettings = model.new(bare)
	bareSettings.setEnabled(true)
	check("a ship without hud.config: the game's rule, and nothing stored", not bareSettings.available() and pick(barePlant, b.all) == gamePick(barePlant, b.all) and bare.getConfig("hud.config") == null)

# --- with the mod: the tab ---

func tab():
	var model = load(SETTINGS)
	var ship = makeShip(false)
	var hud = makeHud(ship)
	yield(buildOms(ship), "completed")
	var tabs = hud.inventory.get_node(TABS)
	var settings = hud._droneAltPriorities()
	var modId = settings.modId()
	var tabName = hud._DRONE_ALT_PRIORITIES_TAB
	var list = names(tabs)
	var at = list.find(GEOLOGIST)
	if hasMod(OTHER_TAB_MOD):
		var after = list.slice(at + 1, at + 2) if at != -1 and list.size() > at + 2 else []
		check("with GeologyByMass, both tabs come right after the Geologist tab", after.size() == 2 and after.has(tabName) and list.size() == ROLE_TABS.size() + 2, list)
	else:
		var expected = ROLE_TABS.duplicate()
		expected.insert(ROLE_TABS.find(GEOLOGIST) + 1, tabName)
		check("the tab comes right after the Geologist tab", list == expected, list)
	var index = list.find(tabName)
	check("its title is its key, which has a translation", index != -1 and tabs.get_tab_title(index) == tabName and tr(tabName) != tabName)
	ship.emit_signal("instance")
	hud.instance()
	yield(idle(), "completed")
	check("the tab is added once, however often the OMS is built", names(tabs).count(tabName) == 1, names(tabs))
	tabs.current_tab = index
	yield(idle(), "completed")
	check("opening the tab stores nothing", not hud.mineralConfig.has(modId), hud.mineralConfig.keys())

	var page = tabs.get_node(tabName)
	var toggle = page._toggle
	var grid = page._grid
	check("the switch is the Geologist tab's (MineralSystemToggle), and shows the stored state", toggle is CheckButton and toggle.get_script().resource_path == "res://hud/components/MineralSystemToggle.gd" and toggle.pressed == settings.isEnabled())
	var kids = grid.get_children()
	var rows = true
	var keys = []
	for i in range(0, kids.size() - 1, 2):
		var label = kids[i]
		var slider = kids[i + 1]
		var desc = model.WEIGHTS[i / 2] if i / 2 < model.WEIGHTS.size() else null
		if desc == null:
			rows = false
			break
		keys.append(desc.key)
		var bar = slider.get_node("Box/HSlider")
		rows = rows and label.get_script().resource_path == "res://hud/components/MineralLabel.gd" and label.text == desc.label and tr(desc.label) != desc.label and label.focus_mode == Control.FOCUS_NONE
		rows = rows and slider.get_script().resource_path == "res://hud/components/PriceLabel.gd" and bar.min_value == desc.min * desc.shown and bar.max_value == desc.max * desc.shown and bar.step == desc.step * desc.shown
		rows = rows and bar.hint_tooltip == desc.label + "_DESC" and tr(bar.hint_tooltip) != bar.hint_tooltip and slider.format == "%s " + desc.unit.replace("%", "%%")
		rows = rows and slider.value == settings.toShown(desc.key, settings.getWeight(desc.key)) and slider.label.text == slider.format % CurrentGame.formatThousands(slider.value)
		rows = rows and bar.rect_min_size.x == page.SLIDER_WIDTH
	check("one row per weight, in WEIGHTS order: its name (MineralLabel, its key, translated, no focus), then the Minimum value control with its range, step, unit and tooltip in shown units, showing the stored weight", rows and grid.columns == 2 and keys == settings.keys() and kids.size() == 2 * keys.size(), keys)
	check("the rows are dimmed while the switch is off", (grid.modulate == Color.white) == settings.isEnabled() and (settings.isEnabled() or grid.modulate.a < 1.0), grid.modulate)

	var before = settings.isEnabled()
	toggle.pressed = not before
	check("pressing the switch stores it, in the HUD's mineralConfig", settings.isEnabled() == (not before) and hud.mineralConfig.get(modId, {}).get("enabled") == (not before))
	toggle.pressed = true
	check("switched on, the rows are not dimmed", grid.modulate == Color.white)
	var first = model.WEIGHTS[0]
	var moved = first.max if first.default != first.max else first.min
	kids[1].get_node("Box/HSlider").value = moved * first.shown
	check("moving a slider stores its weight, from the units shown", settings.getWeight(first.key) == moved and hud.mineralConfig[modId].weights.get(first.key) == moved, settings.getWeight(first.key))
	check("and shows it in the units shown", kids[1].label.text == "%s %s" % [CurrentGame.formatThousands(moved * first.shown), first.unit], kids[1].label.text)

	var reset = page._reset
	var resetTips = tooltipNode(reset.get_parent())
	var resetTip = resetTips.tooltips.get(reset, "") if resetTips != null else ""
	check("a reset button, with its text translated, and its tooltip, translated, taken in by the game's tooltip node in its row", reset is Button and reset.text == load(UI).RESET and tr(reset.text) != reset.text and resetTip == load(UI).RESET + "_DESC" and tr(resetTip) != resetTip, resetTip)
	reset.emit_signal("pressed")
	var defaults = toggle.pressed == model.ENABLED.default and settings.isEnabled() == model.ENABLED.default
	for i in range(0, kids.size() - 1, 2):
		var desc = model.WEIGHTS[i / 2]
		defaults = defaults and kids[i + 1].value == desc.default * desc.shown and settings.getWeight(desc.key) == desc.default
	check("pressing it puts the switch and every weight back to their defaults, on the tab too", defaults)
	check("and leaves no entry, as a ship that never had one", not hud.mineralConfig.has(modId), hud.mineralConfig.keys())
	check("the rows dim again with the switch off by default", model.ENABLED.default or grid.modulate.a < 1.0)

	tabs.current_tab = 0
	tabs.get_node("CREW_OCCUPATION_MECHANIC/Fix").grab_focus()
	yield(idle(), "completed")
	tabs.current_tab = index
	yield(idle(), "completed")
	check("choosing the tab focuses its switch", tabs.get_focus_owner() == toggle, tabs.get_focus_owner())

	# With a gamepad: the D-pad goes down from the switch through each slider's value to Reset and back up, and stays in
	# the tab at either end and to the sides; each value carries its weight's description, which the slider's own tooltip
	# node shows when it gets the focus, and Reset shows its own.
	var chain = [toggle]
	var described = true
	for i in range(1, kids.size(), 2):
		chain.append(kids[i].label)
		described = described and kids[i].label.hint_tooltip == model.WEIGHTS[i / 2].label + "_DESC"
	chain.append(reset)
	check("gamepad: each slider's value carries its weight's description", described)
	var down = []
	for i in range(1, chain.size()):
		yield(tapJoy(JOY_DPAD_DOWN), "completed")
		down.append(tabs.get_focus_owner())
	yield(tapJoy(JOY_DPAD_DOWN), "completed")
	down.append(tabs.get_focus_owner())
	check("gamepad: down goes from the switch through each slider's value to Reset, and stays there", down == chain.slice(1, chain.size() - 1) + [reset], down)
	check("gamepad: Reset shows its description when it gets the focus", resetTips != null and resetTips.tooltipPosition.visible and resetTips.tooltipLabel.text == resetTip, resetTips.tooltipLabel.text if resetTips != null else null)
	var sides = []
	for node in [reset, chain[1], toggle]:
		node.grab_focus()
		for button in [JOY_DPAD_LEFT, JOY_DPAD_RIGHT]:
			yield(tapJoy(button), "completed")
			sides.append(tabs.get_focus_owner() == node)
	check("gamepad: left and right stay where they are, on Reset, a slider's value and the switch", not sides.has(false), sides)
	reset.grab_focus()
	var up = []
	for i in range(chain.size() - 1):
		yield(tapJoy(JOY_DPAD_UP), "completed")
		up.append(tabs.get_focus_owner())
	yield(tapJoy(JOY_DPAD_UP), "completed")
	up.append(tabs.get_focus_owner())
	var back = chain.slice(0, chain.size() - 2)
	back.invert()
	check("gamepad: up goes back to the switch, and stays there", up == back + [toggle], up)
	check("gamepad: walking the tab changes nothing", not hud.mineralConfig.has(modId), hud.mineralConfig.keys())

	# The plants read what the tab writes
	var plant = makePlant(ship, "haul")
	var c = rankingChunks(ship, plant)
	toggle.pressed = true
	check("a plant of the ship follows the tab's switch at once", pick(plant, c.all) == c.be)
	toggle.pressed = false
	check("and its switch off", pick(plant, c.all) == c.fe)

	# A HUD without mineral targeting: no tab
	var ship2 = makeShip(false)
	var hud2 = load(HUD_SCENE).instance()
	hud2.mineralTargetting = false
	ship2.add_child(hud2)
	hud2.set_process(false)
	hud2.set_physics_process(false)
	yield(buildOms(ship2), "completed")
	var tabs2 = hud2.inventory.get_node(TABS)
	check("a HUD without mineral targeting gets no tab", not tabs2.has_node(tabName), names(tabs2))

	# A preheated ship: the HUD's _ready builds the OMS before it loads mineralConfig from the ship
	var stored = {"formatVersion": model.FORMAT_VERSION, "modVersion": "stored", "enabled": not model.ENABLED.default, "weights": {first.key: moved}}
	var hot = {"minerals": CurrentGame.traceMinerals.duplicate(), "minValue": 0, "albedo": 0}
	hot[modId] = stored
	var ship3 = Node2D.new()
	ship3.set_script(load(SHIP))
	ship3.shipConfig = {"hud": {"config": hot}}
	ship3.preheat = true
	add_child(ship3)
	var hud3 = makeHud(ship3)
	yield(idle(), "completed")
	var tabs3 = hud3.inventory.get_node(TABS) if hud3.inventory != null else null
	var page3 = tabs3.get_node_or_null(tabName) if tabs3 != null else null
	check("a preheated ship's OMS gets the tab", page3 != null)
	if page3 != null:
		var s3 = page3._sliders.get(first.key)
		check("and it shows the ship's stored values", page3._toggle.pressed == stored.enabled and s3 != null and s3.value == moved * first.shown, [page3._toggle.pressed, s3.value if s3 != null else null])
		check("and stores nothing on its own", hud3.mineralConfig[modId] == stored and stored.modVersion == "stored")

# --- with the mod: the stored settings ---

func settingsCases():
	var model = load(SETTINGS)
	var ship = makeShip()
	var settings = model.new(ship)
	var config = ship.getConfig("hud.config")
	var modId = settings.modId()
	var defaults = settings.isEnabled() == model.ENABLED.default
	for desc in model.WEIGHTS:
		defaults = defaults and settings.getWeight(desc.key) == float(desc.default)
	check("a ship without the mod's entry gets the defaults", defaults)
	settings.setEnabled(model.ENABLED.default)
	for desc in model.WEIGHTS:
		settings.setWeight(desc.key, desc.default)
	settings.reset()
	check("reading, setting a value already held, or resetting stores nothing", not config.has(modId), config.keys())
	var desc = model.WEIGHTS[0]
	var key = desc.key
	settings.setWeight(key, desc.min - desc.step)
	var low = settings.getWeight(key)
	settings.setWeight(key, desc.max + desc.step)
	var high = settings.getWeight(key)
	settings.setWeight(key, desc.min + desc.step * 1.4)
	var between = settings.getWeight(key)
	settings.setWeight(key, "lots")
	var text = settings.getWeight(key)
	check("a weight set is clamped to the range, snapped to a step, a non-number gives the default", low == desc.min and high == desc.max and between == desc.min + desc.step and text == float(desc.default), [low, high, between, text])
	settings.setWeight("nothing", desc.max)
	check("an unknown weight is ignored", not config.get(modId, {}).get("weights", {}).has("nothing"))
	check("toShown and fromShown convert with the weight's `shown`", settings.toShown(key, desc.max) == desc.max * desc.shown and settings.fromShown(key, desc.max * desc.shown) == desc.max)

	var game = {"minerals": config.minerals.duplicate(), "minValue": config.minValue, "albedo": config.albedo}
	var w = desc.max if desc.default != desc.max else desc.min
	settings.setEnabled(not model.ENABLED.default)
	settings.setWeight(key, w)
	var entry = config.get(modId, {})
	var weights = entry.get("weights", {})
	check("stored under the mod's id, with the format, the mod's version, the switch and every weight", entry.get("formatVersion") == model.FORMAT_VERSION and entry.get("modVersion") == manifestVersion() and settings.modVersion() == manifestVersion() and entry.get("enabled") == (not model.ENABLED.default) and weights.get(key) == w and weights.size() == model.WEIGHTS.size() and entry.size() == 4, entry)
	check("the Geologist tab's own settings are untouched", config.minerals == game.minerals and config.minValue == game.minValue and config.albedo == game.albedo and config.size() == 4, config.keys())
	check("stored in the ship's config itself (hud.config), as the game's are", ship.shipConfig.hud.config.has(modId))
	var ship2 = Node2D.new()
	ship2.set_script(load(SHIP))
	ship2.shipConfig = JSON.parse(JSON.print(ship.shipConfig)).result
	add_child(ship2)
	var s2 = model.new(ship2)
	check("after a save and load (JSON) the values are back", s2.isEnabled() == (not model.ENABLED.default) and s2.getWeight(key) == w)
	config[modId] = {"enabled": "yes", "weights": {key: desc.max * 3, model.WEIGHTS[1].key: "lots"}}
	check("a hand-edited entry is clamped, and non-values give the defaults", settings.isEnabled() == model.ENABLED.default and settings.getWeight(key) == desc.max and settings.getWeight(model.WEIGHTS[1].key) == float(model.WEIGHTS[1].default))
	config[modId] = {"enabled": true, "weights": [1, 2]}
	check("weights that aren't a dictionary give the defaults", settings.isEnabled() and settings.getWeight(key) == float(desc.default))
	settings.reset()
	check("reset removes the entry", not config.has(modId))

# --- the texts (i18n/en.po), also in a language without them (Godot's fallback, en) ---

func texts():
	var model = load(SETTINGS)
	var ui = load(UI)
	var keys = [model.ENABLED.label, ui.HINT, ui.RESET, ui.RESET + "_DESC", "DRONEALTPRIORITIES_TAB"]
	for desc in model.WEIGHTS:
		keys.append(desc.label)
		keys.append(desc.label + "_DESC")
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

func _free():
	for body in _bodies:
		if is_instance_valid(body):
			body.free()
	_bodies = []
