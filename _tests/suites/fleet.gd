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
const LIST_WIDTH = 1280 # the Fleet list's width: an entry's design width (SystemBuyUI.tscn, HBox margin_right + the root's margin)

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

# The dialog's list of `lines`, each with the mod's bullet.
func bullets(entry, lines: Array) -> String:
	var out = []
	for line in lines:
		out.append(tr(entry._SHIP_COPY_PASTE_TEXT_BULLET) % line)
	return PoolStringArray(out).join("\n")

# A piece bought, as the dialog lists it: its name (the Equipment item's, here its system key) and price.
func itemLine(entry, system: String, price) -> String:
	return tr(entry._SHIP_COPY_PASTE_TEXT_ITEM_PRICE) % [tr(system), CurrentGame.formatThousands(price)]

# The game's bindings (its project.godot): ui_cancel is Esc, B (button 1) and Start (button 11); pause is Esc and Start.
func bindGameKeys():
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
	for binding in [["ui_cancel", escKey()], ["pause", escKey()]]:
		if not InputMap.action_has_event(binding[0], binding[1]):
			InputMap.action_add_event(binding[0], binding[1])

# A press and release of a key, as Input delivers a player's, in the idle part of a frame (where the game takes input).
func tap(event):
	yield(get_tree(), "idle_frame")
	for pressed in [true, false]:
		var e = event.duplicate()
		e.pressed = pressed
		Input.parse_input_event(e)

func escKey():
	var event = InputEventKey.new()
	event.scancode = KEY_ESCAPE
	return event

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
		check("control: the entry's confirmation has only the game's panels, and the entry no dialog", names(spare.get_node("ConfirmationCenter")) == ["BuyPanel", "SellPanel"] and spare.get_child_count() == load(ENTRY).instance().get_child_count())
		_free()
		return

	var copyName = spare._SHIP_COPY_PASTE_COPY_NODE
	var pasteName = spare._SHIP_COPY_PASTE_PASTE_NODE
	var dialogName = spare._SHIP_COPY_PASTE_DIALOG_NODE
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
			likeUse = likeUse and b is Button and b.flat == use.flat and b.shortcut_in_tooltip == use.shortcut_in_tooltip and b.has_node("SmoothScrollTo")
	check("they are copies of Use (flat, its smooth scrolling)", likeUse)
	check("one button per entry, never one that can't be used: Copy on the other ships' entries, Paste on the current ship's", copy[template].visible and copy[other].visible and not copy[spare].visible and paste[spare].visible and not paste[template].visible and not paste[other].visible)
	var columns = []
	for e in entries:
		var shownButton = paste[e] if e == spare else copy[e]
		columns.append([shownButton.get_global_rect().position.x, e.get_node("HBox/Use").get_global_rect().position.x])
	check("in the same spot on every entry, so the entries' buttons line up", columns[0] == columns[1] and columns[1] == columns[2], columns)
	check("Copy enabled on the other ship of the current ship's model, with its tooltip", not copy[template].disabled and copy[template].hint_tooltip == spare._SHIP_COPY_PASTE_TIP_COPY)
	check("disabled on a ship of another model, the tooltip saying so", copy[other].disabled and copy[other].hint_tooltip == spare._SHIP_COPY_PASTE_TIP_COPY_MODEL)
	check("with nothing copied, Paste is disabled, the tooltip saying to copy a ship of this model first", paste[spare].disabled and paste[spare].hint_tooltip == spare._SHIP_COPY_PASTE_TIP_PASTE_NOTHING)
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
	check("the other entry's Copy doesn't", not copy[other].pressed and copy[other].modulate == Color.white)
	check("Paste is enabled, with its tooltip", not paste[spare].disabled and paste[spare].hint_tooltip == spare._SHIP_COPY_PASTE_TIP_PASTE)
	press(copy[other])
	press(copy[spare])
	check("pressing a disabled or hidden Copy (another model, the current ship) changes nothing", fleet.get_meta(meta) == "SE1-0001" and copy[template].pressed and not copy[other].pressed and not copy[spare].pressed and not paste[spare].disabled)
	press(copy[template])
	check("pressing the template's Copy again forgets it, and Paste is disabled again", not fleet.has_meta(meta) and not copy[template].pressed and paste[spare].disabled and paste[spare].hint_tooltip == spare._SHIP_COPY_PASTE_TIP_PASTE_NOTHING)
	press(copy[template])
	fleet.visible = false
	check("closing the Fleet screen forgets the template", not fleet.has_meta(meta))
	fleet.visible = true
	yield(idle(), "completed")
	check("reopened, there is no template, and Paste is disabled", not copy[template].pressed and paste[spare].disabled)
	check("Copy, forgetting and closing wrote nothing to the game's state", JSON.print(CurrentGame.state) == before)

	# The template survives switches while the screen stays open
	press(copy[template])
	switchTo(template, spare)
	check("switched to the template itself: it is still the template; its entry shows Paste, disabled (nothing else of the model is copied), the old current ship's shows Copy, enabled", fleet.get_meta(meta) == "SE1-0001" and paste[template].visible and paste[template].disabled and not copy[template].visible and copy[spare].visible and not copy[spare].disabled and not paste[spare].visible)
	switchTo(spare, template)
	check("switched back to the spare: the template's entry shows Copy again, enabled and pressed, and the spare's Paste, enabled", fleet.get_meta(meta) == "SE1-0001" and copy[template].visible and not copy[template].disabled and copy[template].pressed and not paste[template].visible and paste[spare].visible and not paste[spare].disabled and not copy[spare].visible)
	press(copy[template])

	# A template that was sold
	press(copy[template])
	var sold = garageConfig("SE1-0001")
	CurrentGame.state.garage.erase(sold)
	spare.checkCurrentAndOwned()
	check("a template no longer owned (sold) is forgotten, and Paste is disabled", not fleet.has_meta(meta) and paste[spare].disabled)
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
	var unfit = [tr("SYSTEM_TWIST"), "reactor.power %s" % CurrentGame.formatThousands(12.0)]
	var notCopiedAlways = []
	for key in spare._SHIP_COPY_PASTE_TEXT_NOT_COPIED_ALWAYS:
		notCopiedAlways.append(tr(key))
	var unfitLines = []
	for piece in unfit:
		unfitLines.append(tr(spare._SHIP_COPY_PASTE_TEXT_UNFIT) % piece)
	var settingsLines = [tr(spare._SHIP_COPY_PASTE_TEXT_TUNING), tr(spare._SHIP_COPY_PASTE_TEXT_TARGETING), tr(spare._SHIP_COPY_PASTE_TEXT_FILTERS)]
	var crewLine = tr(spare._SHIP_COPY_PASTE_TEXT_CREW) % "Ann, Bob"
	var question = tr(spare._SHIP_COPY_PASTE_TEXT_CONFIRM) % ["Hare", "Tortoise"]
	var repairsLine = tr(spare._SHIP_COPY_PASTE_TEXT_REPAIRS) % Tool.readableTimeSpan(7200)

	# The confirmation dialog
	press(copy[template])
	var stateBefore = JSON.print(CurrentGame.state)
	var templateBefore = JSON.print(garageConfig("SE1-0001"))
	check("no dialog before the first Paste", spare.get_node_or_null(dialogName) == null)
	press(paste[spare])
	yield(idle(3), "completed")
	var dialog = spare.get_node_or_null(dialogName)
	check("Paste first brings the Equipment screen's prices up to date", equipment.repriced == 1, equipment.repriced)
	check("then opens a confirmation dialog as the game's own (a ConfirmationDialog without a title), the entry's Buy confirmation untouched", dialog is ConfirmationDialog and dialog.visible and dialog.window_title == "" and not spare.get_node("ConfirmationCenter/BuyPanel").visible and names(spare.get_node("ConfirmationCenter")) == ["BuyPanel", "SellPanel"])
	if not dialog is ConfirmationDialog:
		_free()
		return
	var ok = dialog.get_ok()
	var cancel = dialog.get_cancel()
	var title = spare._shipCopyPasteTitle
	var lists = spare._shipCopyPasteLists
	var summary = spare._shipCopyPasteSummary
	var prose = spare.get_node("HBox/Margin").get_font("font", "Label")
	check("in the entry's menu theme (the game's window frame), with the game's OK and CANCEL, Cancel focused", dialog.get_stylebox("panel", "WindowDialog") == load("res://menu/MenuTheme.tres").get_stylebox("panel", "WindowDialog") and ok.text == spare._SHIP_COPY_PASTE_OK and cancel.text == spare._SHIP_COPY_PASTE_CANCEL and dialog.get_focus_owner() == cancel, dialog.get_focus_owner())
	check("its question names the ship flown and the template, in the menu font", title.text == question and title.get_font("font") == spare.get_font("font"), title.text)
	var copied = [itemLine(spare, "SYSTEM_ARM", arm), itemLine(spare, "SYSTEM_ENGINE_B", engine), itemLine(spare, "SYSTEM_FUEL_50", fuel)] + settingsLines + [crewLine]
	check("Copied: each piece bought, as the Equipment screen names it, with its price; the tuning, the mineral targeting, the slots' mineral filters; the crew aboard", lists[0].text == bullets(spare, copied), lists[0].text)
	check("Not copied: what isn't sold here (the lidar the template lacks reads as the ship's default, the ammo it lacks as none), then what Paste never copies", lists[1].text == bullets(spare, unfitLines + notCopiedAlways), lists[1].text)
	var headings = [lists[0].get_parent().get_child(0).text, lists[1].get_parent().get_child(0).text]
	check("under their headings, side by side, in the Fleet screen's prose font (the entry's thumbnail margin's)", headings == [spare._SHIP_COPY_PASTE_TEXT_COPIED, spare._SHIP_COPY_PASTE_TEXT_NOT_COPIED] and lists[0].get_font("font") == prose and lists[1].get_font("font") == prose and prose != spare.get_font("font") and lists[0].get_global_rect().position.y == lists[1].get_global_rect().position.y and lists[0].get_global_rect().end.x <= lists[1].get_global_rect().position.x, headings)
	check("the summary: the equipment's price and the repair time, in the prose font", summary.text == PoolStringArray([tr(spare._SHIP_COPY_PASTE_TEXT_PRICE) % CurrentGame.formatThousands(total), repairsLine]).join("\n") and summary.get_font("font") == prose, summary.text)
	var screen = dialog.get_viewport_rect()
	var box = dialog.get_global_rect()
	check("each list as wide as its share of the screen (COLUMN_SHARE); the dialog on the screen, centered", abs(lists[0].rect_size.x - screen.size.x * spare._SHIP_COPY_PASTE_COLUMN_SHARE) < 1 and abs(lists[1].rect_size.x - lists[0].rect_size.x) < 1 and screen.encloses(box) and (box.position + box.size / 2 - screen.size / 2).length() <= 1, [lists[0].rect_size.x, box, screen])
	check("and at its least size: as tall as its content", abs(box.size.y - dialog.get_combined_minimum_size().y) < 1, [box.size, dialog.get_combined_minimum_size()])
	check("the entry keeps the list's width", fitsRow(spare, LIST_WIDTH, []), spare.rect_size.x)
	press(cancel)
	yield(idle(), "completed")
	check("Cancel closes it, the focus back on Paste", not dialog.visible and paste[spare].has_focus())
	check("and nothing changed", JSON.print(CurrentGame.state) == stateBefore)
	bindGameKeys()
	press(paste[spare])
	yield(idle(3), "completed")
	var cancels = fleet.cancels
	yield(tap(escKey()), "completed")
	yield(idle(), "completed")
	check("Esc closes the dialog only: the Fleet screen doesn't get it (Dealer.gd _input would close the screen)", not dialog.visible and fleet.cancels == cancels and JSON.print(CurrentGame.state) == stateBefore, fleet.cancels - cancels)
	yield(tap(escKey()), "completed")
	yield(idle(), "completed")
	check("(with the dialog closed, Esc reaches the Fleet screen)", fleet.cancels == cancels + 1)

	# Not enough money
	CurrentGame.money = total - 1
	press(paste[spare])
	yield(idle(3), "completed")
	check("above the player's money, OK is disabled and the summary says so", ok.disabled and summary.text.ends_with("\n" + tr(spare._SHIP_COPY_PASTE_TEXT_NO_MONEY)), summary.text)
	press(ok)
	check("and pressing it changes nothing", dialog.visible and JSON.print(CurrentGame.state) == stateBefore and CurrentGame.money == total - 1)
	press(cancel)
	yield(idle(), "completed")
	CurrentGame.money = 1000000

	# A plan that changed while the dialog showed
	press(paste[spare])
	yield(idle(3), "completed")
	for s in ["SYSTEM_FUEL_20", "SYSTEM_FUEL_50"]:
		items[s + "@fuel.capacity"].setValuesDiscount(2000)
	fuel = (4000 - 2000) * 1
	total = arm + engine + fuel
	copied[2] = itemLine(spare, "SYSTEM_FUEL_50", fuel)
	press(ok)
	check("a price changed since it showed: OK shows the new plan and pastes nothing", dialog.visible and lists[0].text == bullets(spare, copied) and summary.text.begins_with(tr(spare._SHIP_COPY_PASTE_TEXT_PRICE) % CurrentGame.formatThousands(total)) and not ok.disabled and JSON.print(CurrentGame.state) == stateBefore, summary.text)

	# Paste
	var config = CurrentGame.state.ship.config
	var moneyBefore = CurrentGame.money
	var logsBefore = CurrentGame.logs.size()
	var spareBefore = spareShip()
	var templateConfig = templateShip().config
	var validatedBefore = CurrentGame.validated.size()
	press(ok)
	yield(idle(), "completed")
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
	check("the dialog closes, the focus back on Paste", not dialog.visible and paste[spare].has_focus())

	# A refund: the template's piece is cheaper than the one fitted
	garageConfig("SE1-0001").config.propulsion.main = "SYSTEM_ENGINE_A"
	for s in ["SYSTEM_ENGINE_A", "SYSTEM_ENGINE_B"]:
		items[s + "@propulsion.main"].setValuesDiscount(8000)
	var refund = (8000 - 3000) * 2
	moneyBefore = CurrentGame.money
	var maintenance = CurrentGame.state.ship.maintaineceUntil
	press(paste[spare])
	yield(idle(3), "completed")
	check("a cheaper piece: listed with its refund, the summary shows the refund, and no repair time when the piece replaced isn't damaged", lists[0].text == bullets(spare, [tr(spare._SHIP_COPY_PASTE_TEXT_ITEM_REFUND) % ["SYSTEM_ENGINE_A", CurrentGame.formatThousands(refund)]] + settingsLines + [crewLine]) and summary.text == tr(spare._SHIP_COPY_PASTE_TEXT_REFUND) % CurrentGame.formatThousands(refund), [lists[0].text, summary.text])
	press(ok)
	yield(idle(), "completed")
	check("OK pays the refund, and the repair time stays", CurrentGame.money == moneyBefore + refund and config.propulsion.main == "SYSTEM_ENGINE_A" and CurrentGame.state.ship.maintaineceUntil == maintenance, [CurrentGame.money, moneyBefore + refund])

	# The same equipment: settings and crew only. The template has no crew list (the game keeps one only once the crew
	# changed while the ship was flown): its crew is unknown.
	garageConfig("SE1-0001").config.tuning.Hud.TUNE_MAX_VELOCITY = 60
	garageConfig("SE1-0001").config.erase("preferredCrew")
	moneyBefore = CurrentGame.money
	logsBefore = CurrentGame.logs.size()
	var cleared = player.cleared.size()
	validatedBefore = CurrentGame.validated.size()
	press(paste[spare])
	yield(idle(3), "completed")
	var crewUnknown = tr(spare._SHIP_COPY_PASTE_TEXT_CREW_UNKNOWN) % "Tortoise"
	check("the same equipment: only the settings copied, the template's unknown crew among what isn't, and nothing to buy", lists[0].text == bullets(spare, settingsLines) and lists[1].text == bullets(spare, unfitLines + [crewUnknown] + notCopiedAlways) and summary.text == tr(spare._SHIP_COPY_PASTE_TEXT_SAME) and not ok.disabled, [lists[0].text, lists[1].text, summary.text])
	press(ok)
	yield(idle(), "completed")
	check("OK buys nothing, logs nothing, adds no repair time", CurrentGame.money == moneyBefore and CurrentGame.logs.size() == logsBefore and player.cleared.size() == cleared and CurrentGame.state.ship.maintaineceUntil == maintenance)
	check("and copies the settings; with the template's crew unknown, the spare's crew list is left as it is, and nothing is put aboard", config.tuning.Hud.TUNE_MAX_VELOCITY == 60 and same(config.get("preferredCrew"), templateConfig.preferredCrew) and CurrentGame.validated.size() == validatedBefore, config.get("preferredCrew"))
	garageConfig("SE1-0001").config.preferredCrew = []
	press(paste[spare])
	yield(idle(3), "completed")
	check("a template whose crew list is empty: nobody aboard", lists[0].text == bullets(spare, settingsLines + [tr(spare._SHIP_COPY_PASTE_TEXT_CREW_NOBODY)]), lists[0].text)

	# Closing the Fleet screen with the dialog open
	fleet.visible = false
	check("closing the Fleet screen closes the dialog, and forgets the template", not dialog.visible and not fleet.has_meta(meta))
	fleet.visible = true
	yield(idle(), "completed")

	# The texts (i18n/en.po), also in a language without them (Godot's fallback, en)
	var keys = [spare._SHIP_COPY_PASTE_TIP_COPY, spare._SHIP_COPY_PASTE_TIP_TEMPLATE, spare._SHIP_COPY_PASTE_TIP_COPY_MODEL, spare._SHIP_COPY_PASTE_TIP_PASTE, spare._SHIP_COPY_PASTE_TIP_PASTE_NOTHING,spare._SHIP_COPY_PASTE_TEXT_CONFIRM, spare._SHIP_COPY_PASTE_TEXT_COPIED, spare._SHIP_COPY_PASTE_TEXT_NOT_COPIED, spare._SHIP_COPY_PASTE_TEXT_BULLET, spare._SHIP_COPY_PASTE_TEXT_ITEM_PRICE, spare._SHIP_COPY_PASTE_TEXT_ITEM_REFUND, spare._SHIP_COPY_PASTE_TEXT_TUNING, spare._SHIP_COPY_PASTE_TEXT_TARGETING, spare._SHIP_COPY_PASTE_TEXT_FILTERS, spare._SHIP_COPY_PASTE_TEXT_CREW, spare._SHIP_COPY_PASTE_TEXT_CREW_NOBODY, spare._SHIP_COPY_PASTE_TEXT_UNFIT, spare._SHIP_COPY_PASTE_TEXT_CREW_UNKNOWN, spare._SHIP_COPY_PASTE_TEXT_PRICE, spare._SHIP_COPY_PASTE_TEXT_REFUND, spare._SHIP_COPY_PASTE_TEXT_SAME, spare._SHIP_COPY_PASTE_TEXT_REPAIRS, spare._SHIP_COPY_PASTE_TEXT_NO_MONEY] + Array(spare._SHIP_COPY_PASTE_TEXT_NOT_COPIED_ALWAYS)
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
