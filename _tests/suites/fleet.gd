extends "res://harness/suite.gd"

# ShipCopyPaste: on the Fleet screen, Copy makes a ship the template, held by the Fleet screen until it closes, and
# Paste, on the current ship's entry, makes the current ship like it when both are the same model: the differing
# equipment bought at the Equipment screen's prices, then the template's tuning, mineral targeting, slot configs and
# crew. The entries are the game's SystemBuyUI.gd in a stub of its scene (with the game's confirmation animations),
# under a stub of the Fleet screen (harness/fleet_screen.gd), next to a stub of the Equipment screen
# (harness/fleet_equipment.gd) holding the game's SystemShipUpgradeUI.gd items; the ships are harness/fleet_ship.gd,
# and the game's state is the CurrentGame stub's. The mod's node names, animation names and texts are read from the
# mod. The control checks run on the game's own SystemBuyUI.gd.

const MOD = "ShipCopyPaste"
const ENTRY = "res://enceladus/SystemBuyUI.tscn"
const ITEM = "res://enceladus/SystemShipUpgradeUI.tscn"
const GAME_BOX = ["ViewportContainer", "Margin", "ShipName", "V", "Use", "Buy", "Sell"] # an entry's HBox (SystemBuyUI.tscn)
const MODEL = "PROSPECTOR-VP"
const OTHER_MODEL = "EIME"
const NOW = 5000 # the in-game time
const ANIMATION_FRAMES = 75 # frames to let a confirmation animation (1 s) finish
const LIST_WIDTH = 1280 # the Fleet list's width: an entry's design width (SystemBuyUI.tscn, HBox margin_right + the root's margin)
const NARROW_WIDTH = 800 # a narrower list, as in a smaller window

# The Equipment screen's items: slot, system, price, and numVal, story flag and its minimum where given.
const ITEMS = [
	["weaponSlot.main.type", "SYSTEM_DRILL", 1000],
	["weaponSlot.main.type", "SYSTEM_ARM", 5000],
	["weaponSlot.left.type", "SYSTEM_GUN", 2000],
	["weaponSlot.left.type", "SYSTEM_NONE", 0],
	["propulsion.main", "SYSTEM_ENGINE_A", 3000],
	["propulsion.main", "SYSTEM_ENGINE_B", 8000],
	["propulsion.rcs", "SYSTEM_RCS_A", 500],
	["fuel.capacity", "SYSTEM_FUEL_20", 1000, 20000.0],
	["fuel.capacity", "SYSTEM_FUEL_50", 4000, 50000.0],
	["reactor.power", "SYSTEM_RODS_8", 2000, 8.0],
	["reactor.power", "SYSTEM_RODS_12", 6000, 12.0, "test.reactor", 1],
	["lidar.type", "SYSTEM_LIDAR_DOPPLER", 0],
	["lidar.type", "SYSTEM_LIDAR_X", 1000],
	["ammo.capacity", "SYSTEM_NONE", 0, 0.0],
	["ammo.capacity", "SYSTEM_AMMO_1000", 500, 1000.0],
	["hud.type", "SYSTEM_HUD_A", 0],
]

var screens # the station's screens: the Fleet screen, the ship market and the Equipment screen
var fleet
var market
var equipment
var player # the player's ship
var items = {} # the Equipment screen's items by system and slot

# The template, in repair.
func templateShip() -> Dictionary:
	return {"model": MODEL, "transponder": "SE1-0001", "madeIn": 100, "faction": "player", "maintaineceUntil": NOW + 9000, "config": {
		"weaponSlot": {
			"main": {"type": "SYSTEM_ARM", "config": {"minerals": ["Pt"], "minValue": 5, "albedo": 0.1}},
			"left": {"type": "SYSTEM_TWIST", "config": {"minerals": ["W"]}},
		},
		"propulsion": {"main": "SYSTEM_ENGINE_B", "rcs": "SYSTEM_RCS_A"},
		"fuel": {"capacity": 50000.0, "initial": 100.0},
		"reactor": {"power": 12.0},
		"hud": {"type": "SYSTEM_HUD_A", "config": {"minerals": ["Pt", "Pd"], "minValue": 3000, "albedo": 0.2, "AGlezB.GeologyByMass": {"enabled": true}}},
		"tuning": {"Hud": {"TUNE_MAX_VELOCITY": 50}, "weaponSlot": {"main": {"type_SYSTEM_ARM": {"TUNE_ARM_POWER_LIMIT": 70}}, "left": {"type_SYSTEM_TWIST": {"TUNE_X": 1}}}},
		"preferredCrew": ["Ann", "Bob"],
		"damage": {"Main_SYSTEM_ARM": {"wear": 0.5}},
		"processedCargo": {"Fe": 10.0},
	}}

# The spare, the current ship: no lidar or ammo entries the template has, and the template's lidar and ammo the same.
func spareShip() -> Dictionary:
	return {"model": MODEL, "transponder": "SE1-0002", "madeIn": 200, "faction": "player", "config": {
		"weaponSlot": {
			"main": {"type": "SYSTEM_DRILL", "config": {"minerals": ["Fe"], "minValue": 0, "albedo": 0}},
			"left": {"type": "SYSTEM_GUN", "config": {"minerals": ["Fe"]}},
		},
		"propulsion": {"main": "SYSTEM_ENGINE_A", "rcs": "SYSTEM_RCS_A"},
		"fuel": {"capacity": 20000.0, "initial": 20000.0},
		"reactor": {"power": 8.0},
		"lidar": {"type": "SYSTEM_LIDAR_DOPPLER"},
		"ammo": {"capacity": 0.0},
		"hud": {"type": "SYSTEM_HUD_A", "config": {"minerals": ["Fe"], "minValue": 0, "albedo": 0}},
		"tuning": {"Hud": {"TUNE_MAX_VELOCITY": 80, "TUNE_FBW": false}, "weaponSlot": {"main": {"type_SYSTEM_DRILL": {"TUNE_ARM_POWER_LIMIT": 20}}, "left": {"type_SYSTEM_GUN": {"TUNE_LASER_POWER": 3}}}},
		"preferredCrew": ["Cid"],
		"damage": {"Left_SYSTEM_GUN": {"wear": 0.3}},
		"currentCargo": ["res://asteroids/mineral-fe-1.tscn"],
		"processedCargo": {"Pt": 5.0},
	}}

func otherModelShip() -> Dictionary:
	var other = templateShip()
	other.model = OTHER_MODEL
	other.transponder = "SE1-0003"
	other.erase("maintaineceUntil")
	return other

func saleShip() -> Dictionary:
	var sale = spareShip()
	sale.transponder = "SE1-0099"
	return sale

func idle(count = 2):
	for i in count:
		yield(get_tree(), "idle_frame")

func names(node) -> Array:
	var list = []
	for c in node.get_children():
		list.append(c.name)
	return list

func press(button):
	button.emit_signal("pressed")

# Deep equality, a number equal to the same number of the other type.
func same(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not same(a[i], b[i]):
				return false
		return true
	var numbers = [TYPE_INT, TYPE_REAL]
	if typeof(a) != typeof(b):
		return numbers.has(typeof(a)) and numbers.has(typeof(b)) and a == b
	return a == b

func screen(script, nodeName):
	var node = load(script).new()
	node.name = nodeName
	var list = VBoxContainer.new()
	list.name = "Items"
	node.add_child(list)
	screens.add_child(node)
	return node

func makeScreens():
	screens = Control.new()
	screens.name = "MarginContainer"
	screens.rect_size = Vector2(1280, 720)
	add_child(screens)
	fleet = screen("res://harness/fleet_screen.gd", "Owned")
	fleet.get_node("Items").rect_size = Vector2(LIST_WIDTH, 0)
	market = screen("res://harness/fleet_screen.gd", "Dealer")
	market.visible = false
	equipment = load("res://harness/fleet_equipment.gd").new()
	equipment.name = "Upgrades"
	equipment.visible = false
	var list = VBoxContainer.new()
	list.name = "Items"
	equipment.add_child(list)
	screens.add_child(equipment)
	for spec in ITEMS:
		var item = load(ITEM).instance()
		item.slot = spec[0]
		item.system = spec[1]
		item.price = spec[2]
		if spec.size() > 3:
			item.numVal = spec[3]
		if spec.size() > 4:
			item.storyFlag = spec[4]
			item.storyFlagMin = spec[5]
		list.add_child(item)
		items[spec[1] + "@" + spec[0]] = item

# An entry as Dealer.gd doAddShips makes one: a ship of the config (the current one's a copy, as
# CurrentGame.getOwnedShips builds it), `owned` and `tradeIn` set before it enters the list, `current` after.
func makeEntry(list, full: Dictionary, owned: bool, isCurrent: bool):
	var ship = load("res://harness/fleet_ship.gd").new()
	ship.useConfig(full)
	var entry = load(ENTRY).instance()
	entry.ship = ship
	entry.owned = owned
	entry.tradeIn = 0
	list.add_child(entry)
	if owned:
		entry.current = isCurrent
	return entry

# As CurrentGame.switchShipTo, then Dealer.gd use(): the current ship's config goes to the garage, the new one's
# becomes the current ship's (a copy), and the entries' `current` follows.
func switchTo(newEntry, oldEntry):
	var cs = CurrentGame.state
	var garage = [cs.ship.duplicate(true)]
	for config in cs.garage:
		if config.transponder != newEntry.ship.transponder:
			garage.append(config)
	for config in cs.garage:
		if config.transponder == newEntry.ship.transponder:
			cs.ship = config.duplicate(true)
	cs.garage = garage
	player.useConfig(cs.ship)
	oldEntry.current = false
	newEntry.current = true

func garageConfig(transponder):
	for config in CurrentGame.state.garage:
		if config.transponder == transponder:
			return config
	return null

# An icon's colours: the mean of its light opaque pixels, and of its dark ones (the game's icons are light strokes with
# a dark edge).
func inks(image: Image) -> Array:
	var data = image.duplicate()
	if data.is_compressed():
		data.decompress()
	data.lock()
	var sums = [Color(0, 0, 0, 0), Color(0, 0, 0, 0)]
	var counts = [0, 0]
	for y in data.get_height():
		for x in data.get_width():
			var c = data.get_pixel(x, y)
			if c.a >= 0.5:
				var dark = 1 if (c.r + c.g + c.b) / 3.0 < 0.5 else 0
				sums[dark].r += c.r
				sums[dark].g += c.g
				sums[dark].b += c.b
				counts[dark] += 1
	data.unlock()
	var out = []
	for i in 2:
		out.append(Color(sums[i].r / counts[i], sums[i].g / counts[i], sums[i].b / counts[i], 1.0) if counts[i] > 0 else null)
	return out

func near(a: Color, b: Color) -> bool:
	return abs(a.r - b.r) < 0.01 and abs(a.g - b.g) < 0.01 and abs(a.b - b.b) < 0.01

# Whether every opaque pixel of `icon` has one of the two colours, and both are there.
func drawnIn(icon: Texture, colours: Array) -> bool:
	var data = icon.get_data()
	data.lock()
	var found = [0, 0]
	var ok = true
	for y in data.get_height():
		for x in data.get_width():
			var c = data.get_pixel(x, y)
			if c.a >= 0.5:
				if near(c, colours[0]):
					found[0] += 1
				elif near(c, colours[1]):
					found[1] += 1
				else:
					ok = false
	data.unlock()
	return ok and found[0] > 0 and found[1] > 0

# Whether the entry keeps the list's width and each node lies within it, left to right.
func fitsRow(entry, width: float, nodes: Array) -> bool:
	var row = entry.get_global_rect()
	var ok = abs(entry.rect_size.x - width) < 0.5
	for n in nodes:
		var r = n.get_global_rect()
		ok = ok and r.position.x >= row.position.x - 0.5 and r.end.x <= row.end.x + 0.5
	return ok

func pixels(icon: Texture) -> PoolByteArray:
	return icon.get_data().get_data()

func run():
	var mod = hasMod(MOD)
	CurrentGame.time = NOW
	CurrentGame.money = 1000000
	CurrentGame.state.ship = spareShip()
	CurrentGame.state.garage = [templateShip(), otherModelShip()]
	CurrentGame.state.shipNames = {"SE1-0001": "Tortoise", "SE1-0002": "Hare"}
	player = load("res://harness/fleet_ship.gd").new()
	player.useConfig(CurrentGame.state.ship)
	# Before the items are made: each caches its slot's count the first time it is priced (SystemShipUpgradeUI.gd
	# getNumber), until the next playerShipChanged.
	player.slots["propulsion.main"] = 2
	CurrentGame.playerShip = player
	makeScreens()
	var list = fleet.get_node("Items")
	var spare = makeEntry(list, CurrentGame.state.ship.duplicate(true), true, true)
	var template = makeEntry(list, CurrentGame.state.garage[0], true, false)
	var other = makeEntry(list, CurrentGame.state.garage[1], true, false)
	var sale = makeEntry(market.get_node("Items"), saleShip(), false, false)
	yield(idle(3), "completed")
	if not mod:
		check("control: Fleet entries get no Copy or Paste", names(spare.get_node("HBox")) == GAME_BOX and names(template.get_node("HBox")) == GAME_BOX, names(spare.get_node("HBox")))
		check("control: nor does the market's entry", names(sale.get_node("HBox")) == GAME_BOX)
		check("control: the entry's confirmation has only the game's panels", names(spare.get_node("ConfirmationCenter")) == ["BuyPanel", "SellPanel"])
		_free()
		return

	var copyName = spare._SHIP_COPY_PASTE_COPY_NODE
	var pasteName = spare._SHIP_COPY_PASTE_PASTE_NODE
	var panelName = spare._SHIP_COPY_PASTE_PANEL_NODE
	var meta = spare._SHIP_COPY_PASTE_TEMPLATE
	var entries = [spare, template, other]
	var copy = {}
	var paste = {}
	for e in entries:
		copy[e] = e.get_node_or_null("HBox/" + copyName)
		paste[e] = e.get_node_or_null("HBox/" + pasteName)

	# The buttons
	check("the market's entry gets no Copy or Paste", names(sale.get_node("HBox")) == GAME_BOX, names(sale.get_node("HBox")))
	var expected = GAME_BOX.duplicate()
	expected.insert(GAME_BOX.find("Use"), pasteName)
	expected.insert(GAME_BOX.find("Use"), copyName)
	var placed = true
	for e in entries:
		placed = placed and names(e.get_node("HBox")) == expected
	check("every Fleet entry gets Copy, then Paste, right before Use", placed, names(spare.get_node("HBox")))
	var use = spare.get_node("HBox/Use")
	var likeUse = true
	for e in entries:
		for b in [copy[e], paste[e]]:
			likeUse = likeUse and b is Button and b.flat == use.flat and b.shortcut_in_tooltip == use.shortcut_in_tooltip and b.has_node("SmoothScrollTo") and not b.disabled
	check("they are copies of Use (flat, its smooth scrolling), enabled", likeUse)
	check("Copy shows on the other ships' entries, with its tooltip, not on the current ship's (the only one Paste can change); with no template, Paste shows nowhere", not copy[spare].visible and copy[template].visible and copy[other].visible and copy[template].hint_tooltip == spare._SHIP_COPY_PASTE_TIP_COPY and not paste[spare].visible and not paste[template].visible and not paste[other].visible)
	check("Paste has its tooltip", paste[spare].hint_tooltip == spare._SHIP_COPY_PASTE_TIP_PASTE)
	var uses = []
	template.connect("use", self, "_recordUse", [uses])
	press(copy[template])
	press(copy[template])
	check("pressing Copy doesn't switch ships (no `use`)", uses.empty())
	var useIcon = use.icon
	var useData = useIcon.get_data() if useIcon != null else null
	check("the Use button shows the game's icon, whose pixels can be read", useIcon is Texture and useData is Image, useIcon)
	if useData is Image:
		var colours = inks(useData)
		var copyIcon = copy[spare].icon
		var pasteIcon = paste[spare].icon
		check("the icons have the Use icon's size and flags", copyIcon.get_size() == useIcon.get_size() and pasteIcon.get_size() == useIcon.get_size() and copyIcon.flags == useIcon.flags and pasteIcon.flags == useIcon.flags, [copyIcon.get_size(), useIcon.get_size()])
		check("the Use icon has light and dark pixels", colours[0] != null and colours[1] != null, colours)
		check("the icons are drawn in its colours: light strokes with a dark edge (the means of its light and dark pixels)", colours[1] != null and drawnIn(copyIcon, colours) and drawnIn(pasteIcon, colours), colours)
		check("and differ from each other and from the Use icon", pixels(copyIcon) != pixels(pasteIcon) and pixels(copyIcon) != useData.get_data())

	# The template
	var before = JSON.print(CurrentGame.state)
	press(copy[template])
	check("Copy makes the ship the template, held by the Fleet screen", fleet.get_meta(meta) == "SE1-0001" if fleet.has_meta(meta) else false)
	var mark = template.get_node("HBox/V/Owned").modulate
	check("the template's Copy shows pressed, in the Owned label's colour, with the template's tooltip", copy[template].pressed and copy[template].modulate == mark and copy[template].hint_tooltip == spare._SHIP_COPY_PASTE_TIP_TEMPLATE)
	check("the other entry's Copy doesn't", not copy[other].pressed and copy[other].modulate == Color.white and copy[other].hint_tooltip == spare._SHIP_COPY_PASTE_TIP_COPY)
	check("Paste shows on the current ship's entry only", paste[spare].visible and not paste[template].visible and not paste[other].visible)
	press(copy[other])
	check("a template of another model: no Paste", fleet.get_meta(meta) == "SE1-0003" and not paste[spare].visible and copy[other].pressed and not copy[template].pressed)
	press(copy[other])
	check("pressing the template's Copy again forgets it", not fleet.has_meta(meta) and not copy[other].pressed and not paste[spare].visible)
	press(copy[template])
	fleet.visible = false
	check("closing the Fleet screen forgets the template", not fleet.has_meta(meta))
	fleet.visible = true
	yield(idle(), "completed")
	check("reopened, there is no template, and no Paste", not copy[template].pressed and not paste[spare].visible)
	check("Copy, forgetting and closing wrote nothing to the game's state", JSON.print(CurrentGame.state) == before)

	# The template survives switches while the screen stays open
	press(copy[template])
	switchTo(template, spare)
	check("switched to the template itself: it is still the template, its entry has no Copy, the old current ship's has, and there is no Paste", fleet.get_meta(meta) == "SE1-0001" and not copy[template].visible and copy[spare].visible and not paste[template].visible and not paste[spare].visible)
	switchTo(spare, template)
	check("switched back to the spare: the template is back on Copy, and the spare has Paste", fleet.get_meta(meta) == "SE1-0001" and copy[template].visible and copy[template].pressed and not copy[spare].visible and paste[spare].visible)
	press(copy[template])

	# A template that was sold
	press(copy[template])
	var sold = garageConfig("SE1-0001")
	CurrentGame.state.garage.erase(sold)
	spare.checkCurrentAndOwned()
	check("a template no longer owned (sold) is forgotten, and Paste hides", not fleet.has_meta(meta) and not paste[spare].visible)
	CurrentGame.state.garage.insert(0, sold)

	# The prices, as the Equipment screen sets them for the current ship (Upgrades.gd updatePricesAndAvailability):
	# the main slot's damaged piece has a trade-in value and a repair time; the others, the installed piece's price.
	# The main engine has two slots.
	for s in ["SYSTEM_DRILL", "SYSTEM_ARM"]:
		items[s + "@weaponSlot.main.type"].setValuesDiscount(0, 600, 7200)
	for s in ["SYSTEM_ENGINE_A", "SYSTEM_ENGINE_B"]:
		items[s + "@propulsion.main"].setValuesDiscount(3000)
	for s in ["SYSTEM_FUEL_20", "SYSTEM_FUEL_50"]:
		items[s + "@fuel.capacity"].setValuesDiscount(1000)
	var arm = 5000 * 1 - 600
	var engine = (8000 - 3000) * 2
	var fuel = (4000 - 1000) * 1
	var total = arm + engine + fuel
	var unfit = PoolStringArray([tr("SYSTEM_TWIST"), "reactor.power %s" % CurrentGame.formatThousands(12.0)]).join(", ")
	var header = tr(spare._SHIP_COPY_PASTE_TEXT_CONFIRM) % "Tortoise"
	var priceLine = tr(spare._SHIP_COPY_PASTE_TEXT_PRICE)
	var repairsLine = tr(spare._SHIP_COPY_PASTE_TEXT_REPAIRS) % Tool.readableTimeSpan(7200)
	var unfitLine = tr(spare._SHIP_COPY_PASTE_TEXT_UNFIT) % unfit

	# The confirmation
	var panel = spare.get_node_or_null("ConfirmationCenter/" + panelName)
	var label = panel.get_node("MarginContainer/VBoxContainer/BuyPrice") if panel != null else null
	var ok = panel.get_node("MarginContainer/VBoxContainer/HBoxContainer/BuyConfirm") if panel != null else null
	var cancel = panel.get_node("MarginContainer/VBoxContainer/HBoxContainer/BuyCancel") if panel != null else null
	var buy = spare.get_node("HBox/Buy")
	var player0 = spare.get_node("ConfirmationPlayer")
	check("the entry has a hidden copy of the Buy confirmation", panel is PanelContainer and not panel.visible and label is Label and ok is Button and cancel is Button)
	var retargeted = player0.has_animation(spare._SHIP_COPY_PASTE_SHOW) and player0.has_animation(spare._SHIP_COPY_PASTE_HIDE)
	for animationName in [spare._SHIP_COPY_PASTE_SHOW, spare._SHIP_COPY_PASTE_HIDE]:
		if player0.has_animation(animationName):
			var animation = player0.get_animation(animationName)
			var paths = []
			for i in animation.get_track_count():
				paths.append(String(animation.track_get_path(i)))
			var source = player0.get_animation("BuyShow" if animationName == spare._SHIP_COPY_PASTE_SHOW else "BuyHide")
			retargeted = retargeted and animation != source and animation.get_track_count() == source.get_track_count() and animation.length == source.length
			for p in paths:
				retargeted = retargeted and not ("BuyPanel" in p) and not p.begins_with("HBox/Buy") and (panelName in p or pasteName in p)
	check("with copies of the Buy confirmation's animations, retargeted to it and to Paste", retargeted)

	press(copy[template])
	var stateBefore = JSON.print(CurrentGame.state)
	var templateBefore = JSON.print(garageConfig("SE1-0001"))
	press(paste[spare])
	yield(idle(ANIMATION_FRAMES), "completed")
	check("Paste first brings the Equipment screen's prices up to date", equipment.repriced == 1, equipment.repriced)
	check("then shows the confirmation, not the game's Buy confirmation", panel.visible and panel.modulate.a == 1.0 and not spare.get_node("ConfirmationCenter/BuyPanel").visible)
	var text = PoolStringArray([header, priceLine % CurrentGame.formatThousands(total), repairsLine, unfitLine]).join("\n")
	check("it names the template, gives the equipment's price and the repair time, and lists what isn't sold (the lidar the template lacks reads as the ship's default, the ammo it lacks as none)", label.text == text, label.text)
	check("while it shows, Paste hides as Buy does, and the entry's Buy button stays hidden", not paste[spare].visible and not buy.visible)
	var registration = spare.get_node("HBox/V/Registration")
	var inner = LIST_WIDTH - spare.get_constant("margin_left") - spare.get_constant("margin_right")
	check("its text wraps, in the small font of the entry's registration, not the game's menu font", label.autowrap and label.get_font("font") == registration.get_font("font") and label.get_font("font") != spare.get_font("font"))
	check("at no more than the entry's share for it (TEXT_SHARE)", label.rect_size.x <= inner * spare._SHIP_COPY_PASTE_TEXT_SHARE + 0.5 and label.get_line_count() >= 4, [label.rect_size.x, label.get_line_count()])
	check("the entry keeps the list's width (the list doesn't scroll sideways), and the confirmation, OK and Cancel lie within it", fitsRow(spare, LIST_WIDTH, [panel, ok, cancel]), [spare.rect_size.x, panel.get_global_rect(), cancel.get_global_rect()])
	press(cancel)
	yield(idle(ANIMATION_FRAMES), "completed")
	check("Cancel hides it, Paste comes back with the focus, Buy stays hidden", not panel.visible and paste[spare].visible and spare.get_focus_owner() == paste[spare] and not buy.visible)
	check("and nothing changed", JSON.print(CurrentGame.state) == stateBefore)
	fleet.get_node("Items").rect_size = Vector2(NARROW_WIDTH, 0)
	yield(idle(), "completed")
	press(paste[spare])
	yield(idle(ANIMATION_FRAMES), "completed")
	check("in a narrower list too, the entry keeps its width and the confirmation fits in it", fitsRow(spare, NARROW_WIDTH, [panel, ok, cancel]), [spare.rect_size.x, panel.get_global_rect(), cancel.get_global_rect()])
	press(cancel)
	yield(idle(ANIMATION_FRAMES), "completed")
	fleet.get_node("Items").rect_size = Vector2(LIST_WIDTH, 0)
	yield(idle(), "completed")

	# Not enough money
	CurrentGame.money = total - 1
	press(paste[spare])
	yield(idle(ANIMATION_FRAMES), "completed")
	check("above the player's money, OK is disabled and the confirmation says so", ok.disabled and label.text == text + "\n" + tr(spare._SHIP_COPY_PASTE_TEXT_NO_MONEY), label.text)
	press(ok)
	check("and pressing it changes nothing", JSON.print(CurrentGame.state) == stateBefore and CurrentGame.money == total - 1)
	press(cancel)
	yield(idle(ANIMATION_FRAMES), "completed")
	CurrentGame.money = 1000000

	# A plan that changed while the confirmation showed
	press(paste[spare])
	yield(idle(ANIMATION_FRAMES), "completed")
	for s in ["SYSTEM_FUEL_20", "SYSTEM_FUEL_50"]:
		items[s + "@fuel.capacity"].setValuesDiscount(2000)
	fuel = (4000 - 2000) * 1
	total = arm + engine + fuel
	text = PoolStringArray([header, priceLine % CurrentGame.formatThousands(total), repairsLine, unfitLine]).join("\n")
	press(ok)
	check("a price changed since it showed: OK shows the new plan and pastes nothing", panel.visible and label.text == text and not ok.disabled and JSON.print(CurrentGame.state) == stateBefore, label.text)

	# Paste
	var config = CurrentGame.state.ship.config
	var moneyBefore = CurrentGame.money
	var logsBefore = CurrentGame.logs.size()
	var spareBefore = spareShip()
	var templateConfig = templateShip().config
	var validatedBefore = CurrentGame.validated.size()
	press(ok)
	yield(idle(ANIMATION_FRAMES), "completed")
	check("OK buys the differing pieces at the shown total", CurrentGame.money == moneyBefore - total, [CurrentGame.money, moneyBefore - total])
	check("each fitted as the Equipment screen fits it: the slot's damage cleared, its value set", player.cleared == ["weaponSlot.main.type", "propulsion.main", "fuel.capacity"] and config.weaponSlot.main.type == "SYSTEM_ARM" and config.propulsion.main == "SYSTEM_ENGINE_B" and same(config.fuel.capacity, 50000.0), player.cleared)
	check("pieces already the same, and pieces not sold, left as they are", config.propulsion.rcs == "SYSTEM_RCS_A" and config.weaponSlot.left.type == "SYSTEM_GUN" and same(config.reactor.power, 8.0) and config.lidar.type == "SYSTEM_LIDAR_DOPPLER" and same(config.ammo.capacity, 0.0) and config.hud.type == "SYSTEM_HUD_A")
	check("the repair time grows by the pieces' replacement time, counted from now, not the template's", CurrentGame.state.ship.get("maintaineceUntil") == NOW + 7200, CurrentGame.state.ship.get("maintaineceUntil"))
	var logged = CurrentGame.logs.back() if CurrentGame.logs.size() == logsBefore + 1 else []
	check("the purchase is logged as the Equipment screen logs it", logged.size() == 2 and logged[0] == "LOG_EVENT_UPGRADE" and same(logged[1], {"LOG_EVENT_DETAILS_COST": -total, "SYSTEM_ARM": -arm, "SYSTEM_ENGINE_B": -engine, "SYSTEM_FUEL_50": -fuel}), logged)
	var tuning = templateConfig.tuning.duplicate(true)
	tuning.weaponSlot.left["type_SYSTEM_GUN"] = {"TUNE_LASER_POWER": 3}
	check("the tuning is the template's (a value the spare tuned and the template didn't is gone), with the spare's own for the piece it kept", same(config.tuning, tuning), config.tuning)
	check("the mineral targeting is the template's, other mods' entries in it too", same(config.hud.config, templateConfig.hud.config))
	check("the slot configs are the template's, but for the slot kept", same(config.weaponSlot.main.config, templateConfig.weaponSlot.main.config) and same(config.weaponSlot.left.config, spareBefore.config.weaponSlot.left.config))
	check("the crew list is the template's", same(config.preferredCrew, templateConfig.preferredCrew))
	check("and the game puts it aboard at once (validateEmployment, after the list is written), not only when the docked ship is rebuilt", CurrentGame.validated.size() == validatedBefore + 1 and same(CurrentGame.validated.back(), templateConfig.preferredCrew), CurrentGame.validated)
	var full = CurrentGame.state.ship
	check("identity, damage, cargo and consumables are the spare's", full.transponder == "SE1-0002" and full.model == MODEL and full.madeIn == 200 and full.faction == "player" and same(config.damage, spareBefore.config.damage) and same(config.currentCargo, spareBefore.config.currentCargo) and same(config.processedCargo, spareBefore.config.processedCargo) and same(config.fuel.initial, 20000.0))
	check("the template is untouched", JSON.print(garageConfig("SE1-0001")) == templateBefore)
	config.hud.config.minValue = -1
	check("(changing the pasted mineral targeting leaves the template's)", garageConfig("SE1-0001").config.hud.config.minValue == 3000)
	config.hud.config.minValue = templateConfig.hud.config.minValue
	check("then, as after a switch, the Fleet screen's shipChanged and addShips", fleet.changed == 1 and fleet.added == 1, [fleet.changed, fleet.added])
	check("the confirmation closes, Paste comes back, Buy stays hidden", not panel.visible and paste[spare].visible and not buy.visible)

	# A refund: the template's piece is cheaper than the one fitted
	garageConfig("SE1-0001").config.propulsion.main = "SYSTEM_ENGINE_A"
	for s in ["SYSTEM_ENGINE_A", "SYSTEM_ENGINE_B"]:
		items[s + "@propulsion.main"].setValuesDiscount(8000)
	var refund = (8000 - 3000) * 2
	moneyBefore = CurrentGame.money
	var maintenance = CurrentGame.state.ship.maintaineceUntil
	press(paste[spare])
	yield(idle(ANIMATION_FRAMES), "completed")
	text = PoolStringArray([header, tr(spare._SHIP_COPY_PASTE_TEXT_REFUND) % CurrentGame.formatThousands(refund), unfitLine]).join("\n")
	check("a cheaper piece: the confirmation shows the refund, and no repair time when the piece replaced isn't damaged", label.text == text, label.text)
	press(ok)
	yield(idle(ANIMATION_FRAMES), "completed")
	check("OK pays the refund, and the repair time stays", CurrentGame.money == moneyBefore + refund and config.propulsion.main == "SYSTEM_ENGINE_A" and CurrentGame.state.ship.maintaineceUntil == maintenance, [CurrentGame.money, moneyBefore + refund])

	# The same equipment: settings and crew only. The template, copied from the garage, has no crew list (the game keeps
	# one only once the crew changed while the ship was flown): its crew is unknown.
	garageConfig("SE1-0001").config.tuning.Hud.TUNE_MAX_VELOCITY = 60
	garageConfig("SE1-0001").config.erase("preferredCrew")
	moneyBefore = CurrentGame.money
	logsBefore = CurrentGame.logs.size()
	var cleared = player.cleared.size()
	validatedBefore = CurrentGame.validated.size()
	press(paste[spare])
	yield(idle(ANIMATION_FRAMES), "completed")
	var crewUnknown = tr(spare._SHIP_COPY_PASTE_TEXT_CREW_UNKNOWN) % "Tortoise"
	text = PoolStringArray([header, tr(spare._SHIP_COPY_PASTE_TEXT_SAME), unfitLine, crewUnknown]).join("\n")
	check("the same equipment: the confirmation says only settings and crew are copied, and that the template's crew is unknown", label.text == text and not ok.disabled, label.text)
	press(ok)
	yield(idle(ANIMATION_FRAMES), "completed")
	check("OK buys nothing, logs nothing, adds no repair time", CurrentGame.money == moneyBefore and CurrentGame.logs.size() == logsBefore and player.cleared.size() == cleared and CurrentGame.state.ship.maintaineceUntil == maintenance)
	check("and copies the settings; with the template's crew unknown, the spare's crew list is left as it is, and nothing is put aboard", config.tuning.Hud.TUNE_MAX_VELOCITY == 60 and same(config.get("preferredCrew"), templateConfig.preferredCrew) and CurrentGame.validated.size() == validatedBefore, config.get("preferredCrew"))

	# Closing the Fleet screen with the confirmation open
	press(paste[spare])
	yield(idle(ANIMATION_FRAMES), "completed")
	fleet.visible = false
	check("closing the Fleet screen hides the confirmation at once, and forgets the template", not panel.visible and not fleet.has_meta(meta))
	fleet.visible = true
	yield(idle(), "completed")

	# The texts (i18n/en.po), also in a language without them (Godot's fallback, en)
	var keys = [spare._SHIP_COPY_PASTE_TIP_COPY, spare._SHIP_COPY_PASTE_TIP_TEMPLATE, spare._SHIP_COPY_PASTE_TIP_PASTE, spare._SHIP_COPY_PASTE_TEXT_CONFIRM, spare._SHIP_COPY_PASTE_TEXT_PRICE, spare._SHIP_COPY_PASTE_TEXT_REFUND, spare._SHIP_COPY_PASTE_TEXT_SAME, spare._SHIP_COPY_PASTE_TEXT_REPAIRS, spare._SHIP_COPY_PASTE_TEXT_UNFIT, spare._SHIP_COPY_PASTE_TEXT_CREW_UNKNOWN, spare._SHIP_COPY_PASTE_TEXT_NO_MONEY]
	var translated = true
	for key in keys:
		translated = translated and tr(key) != key
	check("the texts are translated", translated, keys)
	var locale = TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	translated = true
	for key in keys:
		translated = translated and tr(key) != key
	check("a language without them shows the English texts", translated)
	TranslationServer.set_locale(locale)

	# Other mods that find the entries by script (ShipHighlightTypeAndPrice, ShipSortByTypeAndPrice)
	check("the entries' script keeps the game's path", spare.get_script().resource_path == "res://enceladus/SystemBuyUI.gd" and sale.get_script().resource_path == "res://enceladus/SystemBuyUI.gd")
	_free()

func _recordUse(_ship, list):
	list.append(true)

func _free():
	CurrentGame.playerShip = null
	if is_instance_valid(player):
		player.free()
	if is_instance_valid(screens):
		screens.queue_free()
