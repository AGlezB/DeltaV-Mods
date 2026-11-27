extends "res://harness/suite.gd"

# ShipCopyPaste: on the Fleet screen, Copy on another ship of the current ship's model opens a confirmation dialog that
# makes the current ship like it, with a switch per part where the two ships differ: the settings (tuning, mineral
# targeting, slot configs), the crew aboard, and the equipment, bought at the Equipment screen's prices. The entries are
# the game's SystemBuyUI.gd in a stub of its scene (with the game's confirmation animations), under a stub of the Fleet
# screen (harness/fleet_screen.gd), next to a stub of the Equipment screen (harness/fleet_equipment.gd) holding the
# game's SystemShipUpgradeUI.gd items; the ships are harness/fleet_ship.gd, the current one with equipment that has
# Tuning settings (harness/fleet_system.gd, harness/fleet_slot_system.gd), and the game's state is the CurrentGame
# stub's. The mod's node names and texts are read from the mod. The control checks run on the game's own SystemBuyUI.gd.

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

# The current ship's equipment with Tuning settings, as getSystems() lists it: its name, its slotName ("" for one not
# on a slot) and its settings (type, default, step).
const SYSTEMS = [
	["Hud", "", {"TUNE_MAX_VELOCITY": {"type": "float", "default": 40, "step": 1}, "TUNE_ACC": {"type": "float", "default": 2.8647889, "step": 0.1}, "TUNE_FBW": {"type": "bool", "default": true}}],
	["Main", "weaponSlot.main.type_SYSTEM_DRILL", {"TUNE_ARM_POWER_LIMIT": {"type": "float", "default": 50, "step": 10}}],
	["Left", "weaponSlot.left.type_SYSTEM_GUN", {"TUNE_LASER_POWER": {"type": "float", "default": 3, "step": 1}}],
]

var screens # the station's screens: the Fleet screen, the ship market and the Equipment screen
var fleet
var market
var equipment
var player # the player's ship
var items = {} # the Equipment screen's items by system and slot

# The ship copied, in repair.
func copiedShip() -> Dictionary:
	return {"model": MODEL, "transponder": "SE1-0001", "madeIn": 100, "faction": "player", "maintaineceUntil": NOW + 9000, "config": {
		"weaponSlot": {
			"main": {"type": "SYSTEM_ARM", "config": {"minerals": ["Pt"], "minValue": 5, "albedo": 0.1}},
			"left": {"type": "SYSTEM_GUN", "config": {"minerals": ["W"]}},
		},
		"propulsion": {"main": "SYSTEM_ENGINE_B", "rcs": "SYSTEM_RCS_A"},
		"fuel": {"capacity": 50000.0, "initial": 100.0},
		"reactor": {"power": 8.0},
		"hud": {"type": "SYSTEM_HUD_A", "config": {"minerals": ["Pt", "Pd"], "minValue": 3000, "albedo": 0.2, "AGlezB.GeologyByMass": {"enabled": true}}},
		"tuning": {"Hud": {"TUNE_MAX_VELOCITY": 50}, "weaponSlot": {"main": {"type_SYSTEM_ARM": {"TUNE_ARM_POWER_LIMIT": 70}}, "left": {"type_SYSTEM_GUN": {"TUNE_LASER_POWER": 3}}}},
		"preferredCrew": ["Ann", "Bob"],
		"damage": {"Main_SYSTEM_ARM": {"wear": 0.5}},
		"processedCargo": {"Fe": 10.0},
	}}

# The spare, the current ship: lidar and ammo entries the copied ship lacks, which read the same as its missing ones.
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
	var other = copiedShip()
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

# The player's ship's equipment with Tuning settings (SYSTEMS), as getSystems() gives it.
func makeSystems():
	for spec in SYSTEMS:
		var system = load("res://harness/fleet_slot_system.gd" if spec[1] != "" else "res://harness/fleet_system.gd").new()
		if spec[1] != "":
			system.slotName = spec[1]
		system.tuneables = spec[2].duplicate(true)
		player.add_child(system)
		player.systems[spec[0]] = {"name": spec[0], "ref": system}

# An entry as Dealer.gd doAddShips makes one: a ship of the config (the current one's a copy, as
# CurrentGame.getOwnedShips builds it), `owned` and `tradeIn` set before it enters the list, `current` after.
func makeEntry(list, full: Dictionary, owned: bool, isCurrent: bool, scene = ENTRY):
	var ship = load("res://harness/fleet_ship.gd").new()
	ship.useConfig(full)
	var entry = load(scene).instance()
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

# Opens the entry's dialog with Copy, closing it with Cancel first if it shows.
func open(entry):
	var dialog = entry.get_node_or_null(entry._SHIP_COPY_PASTE_DIALOG_NODE)
	if dialog != null and dialog.visible:
		press(dialog.get_cancel())
		yield(idle(), "completed")
	press(entry.get_node("HBox/" + entry._SHIP_COPY_PASTE_COPY_NODE))
	yield(idle(3), "completed")

# Each row of the dialog: "switch:on" or "switch:off" where it shows its switch, "label:<text>" where its label.
func states(entry) -> Dictionary:
	var out = {}
	for part in entry._shipCopyPasteRows:
		var value = entry._shipCopyPasteRows[part].get_node("HBoxContainer/Value")
		var state = entry._shipCopyPasteStates[part]
		out[part] = ("switch:" + ("on" if value.pressed else "off")) if value.visible else ("label:" + state.text)
	return out

func allOn() -> Dictionary:
	return {"settings": "switch:on", "crew": "switch:on", "equipment": "switch:on"}

# A row's switch, flipped as a click flips it.
func toggle(entry, part, on):
	entry._shipCopyPasteRows[part].get_node("HBoxContainer/Value").pressed = on

func valueNode(entry, part):
	return entry._shipCopyPasteRows[part].get_node("HBoxContainer/Value")

# The dialog's equipment list: [name, value] per line.
func listed(entry) -> Array:
	var out = []
	var kids = entry._shipCopyPasteList.get_children()
	for i in range(0, kids.size(), 2):
		out.append([kids[i].text, kids[i + 1].text])
	return out

# A line of the list as the dialog writes it: the name bulleted, and the value as is.
func line(entry, name: String, value: String) -> Array:
	return [tr(entry._SHIP_COPY_PASTE_TEXT_BULLET) % tr(name), value]

# A line of money: a cost (from 0 up) negative, a refund positive.
func money(entry, name: String, price: float) -> Array:
	var text = entry._SHIP_COPY_PASTE_TEXT_COST if price >= 0 else entry._SHIP_COPY_PASTE_TEXT_GAIN
	return line(entry, name, tr(text) % CurrentGame.formatThousands(abs(price)))

# The dialog's layout: the rows and the list only as wide as they need, centered under the question, which fits on one
# line; the gap between names and values.
func checkWidths(entry, label):
	var parts = entry._shipCopyPasteParts
	var title = entry._shipCopyPasteTitle
	var font = entry._shipCopyPasteProseFont if entry._shipCopyPasteProseFont != null else entry._shipCopyPasteList.get_font("font", "Label")
	var gap = int(ceil(font.get_height() * entry._SHIP_COPY_PASTE_COLUMN_GAP))
	var seps = [entry._shipCopyPasteList.get_constant("hseparation")]
	for part in entry._shipCopyPasteRows:
		seps.append(entry._shipCopyPasteRows[part].get_node("HBoxContainer").get_constant("separation"))
	var centers = [parts.get_global_rect().get_center().x, title.get_global_rect().get_center().x]
	check(label + ": the rows and the list only as wide as they need (COLUMN_GAP between names and values), centered under the question", abs(parts.rect_size.x - parts.get_combined_minimum_size().x) < 1 and abs(centers[0] - centers[1]) <= 1 and seps == [gap, gap, gap, gap], [parts.rect_size.x, parts.get_combined_minimum_size().x, centers, seps, gap])
	check(label + ": the question on one line, as wide as it needs or as the rows", title.get_line_count() == 1 and abs(title.rect_size.x - max(parts.rect_size.x, entry._shipCopyPasteLineWidth(title, title.text))) < 1, [title.get_line_count(), title.rect_size.x, parts.rect_size.x])

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

# A press and release of a gamepad button (JOY_*), as Input delivers a player's: the actions it is bound to follow
# (Godot's defaults: the D-pad moves the focus), then the focused control gets it. Input hands parsed events on at the
# next frame, so this waits for it.
func tapJoy(button):
	var event = InputEventJoypadButton.new()
	event.button_index = button
	yield(tap(event), "completed")
	yield(get_tree(), "idle_frame")

func pixels(icon: Texture) -> PoolByteArray:
	return icon.get_data().get_data()

func run():
	var mod = hasMod(MOD)
	CurrentGame.time = NOW
	CurrentGame.money = 1000000
	CurrentGame.state.ship = spareShip()
	CurrentGame.state.garage = [copiedShip(), otherModelShip()]
	CurrentGame.state.shipNames = {"SE1-0001": "Tortoise", "SE1-0002": "Hare"}
	# The crew the ships' lists name, hired (the game's state.crew, by full name).
	CurrentGame.state.crew = {"Ann": {"fullName": "Ann"}, "Bob": {"fullName": "Bob"}, "Cid": {"fullName": "Cid"}}
	player = load("res://harness/fleet_ship.gd").new()
	player.useConfig(CurrentGame.state.ship)
	# Before the items are made: each caches its slot's count the first time it is priced (SystemShipUpgradeUI.gd
	# getNumber), until the next playerShipChanged.
	player.slots["propulsion.main"] = 2
	makeSystems()
	CurrentGame.playerShip = player
	makeScreens()
	var list = fleet.get_node("Items")
	var spare = makeEntry(list, CurrentGame.state.ship.duplicate(true), true, true)
	var copied = makeEntry(list, CurrentGame.state.garage[0], true, false)
	var other = makeEntry(list, CurrentGame.state.garage[1], true, false)
	var sale = makeEntry(market.get_node("Items"), saleShip(), false, false)
	yield(idle(3), "completed")
	if not mod:
		check("control: Fleet entries get no Copy", names(spare.get_node("HBox")) == GAME_BOX and names(copied.get_node("HBox")) == GAME_BOX, names(spare.get_node("HBox")))
		check("control: nor does the market's entry", names(sale.get_node("HBox")) == GAME_BOX)
		check("control: the entry's confirmation has only the game's panels, and the entry no dialog", names(spare.get_node("ConfirmationCenter")) == ["BuyPanel", "SellPanel"] and spare.get_child_count() == load(ENTRY).instance().get_child_count())
		_free()
		return

	var copyName = spare._SHIP_COPY_PASTE_COPY_NODE
	var spacerName = spare._SHIP_COPY_PASTE_SPACER_NODE
	var dialogName = spare._SHIP_COPY_PASTE_DIALOG_NODE
	var entries = [spare, copied, other]
	var copy = {}
	var spacer = {}
	for e in entries:
		copy[e] = e.get_node_or_null("HBox/" + copyName)
		spacer[e] = e.get_node_or_null("HBox/" + spacerName)

	# The buttons
	check("the market's entry gets nothing", names(sale.get_node("HBox")) == GAME_BOX, names(sale.get_node("HBox")))
	var expected = GAME_BOX.duplicate()
	expected.insert(GAME_BOX.find("Use"), spacerName)
	expected.insert(GAME_BOX.find("Use"), copyName)
	var placed = true
	for e in entries:
		placed = placed and names(e.get_node("HBox")) == expected
	check("every Fleet entry gets Copy, then a spacer, right before Use", placed, names(spare.get_node("HBox")))
	var use = spare.get_node("HBox/Use")
	var likeUse = true
	for e in entries:
		likeUse = likeUse and copy[e] is Button and copy[e].flat == use.flat and copy[e].shortcut_in_tooltip == use.shortcut_in_tooltip and copy[e].has_node("SmoothScrollTo")
	check("Copy is a copy of Use (flat, its smooth scrolling)", likeUse)
	var spacerNode = spacer[spare]
	check("Copy on the other ships' entries; on the current ship's, the spacer in its place, of Copy's size, the mouse and the focus passing by", copy[copied].visible and copy[other].visible and not copy[spare].visible and spacerNode.visible and not spacer[copied].visible and not spacer[other].visible and spacerNode.rect_min_size == copy[spare].get_combined_minimum_size() and spacerNode.rect_min_size.x > 0 and spacerNode.mouse_filter == Control.MOUSE_FILTER_IGNORE and spacerNode.focus_mode == Control.FOCUS_NONE, [spacerNode.rect_min_size, copy[spare].get_combined_minimum_size()])
	yield(idle(), "completed")
	var columns = []
	for e in entries:
		columns.append([e.get_node("HBox/V").get_global_rect().position.x, e.get_node("HBox/Use").get_global_rect().position.x])
	check("the details and Use at the same x on every entry, the current ship's too", columns[0] == columns[1] and columns[1] == columns[2], columns)
	# The row's buttons closer together: Copy, Use and Sell share copies of the theme's styles with side margins that put
	# their icons ICON_GAP apart, the row's separation counted. A Button takes its least size from `normal` and draws its
	# icon at its state's style's offset, so every state keeps the same margins.
	var buttons = [copy[copied], copied.get_node("HBox/Use"), copied.get_node("HBox/Sell")]
	var tightStyles = spare._SHIP_COPY_PASTE_TIGHT_STYLES
	var theme = load("res://menu/MenuTheme.tres")
	var shared = true
	for style in tightStyles:
		var tight = buttons[1].get_stylebox(style)
		var normal = buttons[1].get_stylebox("normal")
		for button in buttons:
			shared = shared and button.has_stylebox_override(style) and button.get_stylebox(style) == tight
		shared = shared and tight != theme.get_stylebox(style, "Button") and tight.content_margin_left == normal.content_margin_left and tight.content_margin_right == normal.content_margin_right
	check("Copy, Use and Sell share copies of the theme's normal, hover, pressed and disabled styles, with the same side margins in each (the icon doesn't move on hover or when disabled)", shared)
	var gaps = []
	for i in [0, 1]:
		var a = buttons[i]
		var b = buttons[i + 1]
		var end = a.get_global_rect().position.x + a.get_stylebox("normal").content_margin_left + a.icon.get_width()
		gaps.append(b.get_global_rect().position.x + b.get_stylebox("normal").content_margin_left - end)
	check("the icons of Copy and Use, and of Use and Sell, ICON_GAP apart, the row's separation counted", gaps == [float(spare._SHIP_COPY_PASTE_ICON_GAP), float(spare._SHIP_COPY_PASTE_ICON_GAP)], [gaps, spare._SHIP_COPY_PASTE_ICON_GAP])
	var untouched = true
	for style in tightStyles:
		var kept = theme.get_stylebox(style, "Button")
		var fresh = ResourceLoader.load(kept.resource_path, "", true)
		untouched = untouched and kept.content_margin_left == fresh.content_margin_left and kept.content_margin_right == fresh.content_margin_right
		for nodeName in ["Use", "Buy", "Sell"]:
			untouched = untouched and not sale.get_node("HBox/" + nodeName).has_stylebox_override(style)
	check("the theme's styles keep their margins, and the market's entry its buttons' styles", untouched)
	check("Copy enabled on the other ship of the current ship's model, with its tooltip", not copy[copied].disabled and copy[copied].hint_tooltip == spare._SHIP_COPY_PASTE_TIP_COPY)
	check("disabled on a ship of another model, the tooltip saying so", copy[other].disabled and copy[other].hint_tooltip == spare._SHIP_COPY_PASTE_TIP_COPY_MODEL)
	var useIcon = use.icon
	var useData = useIcon.get_data() if useIcon != null else null
	check("the Use button shows the game's icon, whose pixels can be read", useIcon is Texture and useData is Image, useIcon)
	if useData is Image:
		var colours = inks(useData)
		var copyIcon = copy[spare].icon
		check("Copy's icon has the Use icon's size and flags", copyIcon.get_size() == useIcon.get_size() and copyIcon.flags == useIcon.flags, [copyIcon.get_size(), useIcon.get_size()])
		check("the Use icon has light and dark pixels", colours[0] != null and colours[1] != null, colours)
		check("Copy's icon is drawn in its colours: light strokes with a dark edge (the means of its light and dark pixels), and differs from it", colours[1] != null and drawnIn(copyIcon, colours) and pixels(copyIcon) != useData.get_data(), colours)
	switchTo(copied, spare)
	yield(idle(), "completed")
	check("switched to the copied ship: its entry gets the spacer, the old current ship's Copy, enabled", spacerNode.visible == false and copy[spare].visible and not copy[spare].disabled and not copy[copied].visible and spacer[copied].visible)
	switchTo(spare, copied)
	yield(idle(), "completed")
	check("switched back: as before", spacerNode.visible and not copy[spare].visible and copy[copied].visible and not copy[copied].disabled and not spacer[copied].visible)

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
	var repairs = line(spare, spare._SHIP_COPY_PASTE_TEXT_REPAIRS, Tool.readableTimeSpan(7200))
	var question = tr(spare._SHIP_COPY_PASTE_TEXT_CONFIRM) % ["Hare", "Tortoise"]
	var sameLabel = "label:" + tr(spare._SHIP_COPY_PASTE_TEXT_SAME)

	# The comparisons
	var noList = spare._shipCopyPasteCrew(null)
	check("a ship without a crew list has no crew", noList is Array and noList.empty(), noList)
	check("values compare by what they hold: arrays in any order, ints as floats", spare._shipCopyPasteEqual({"a": [1, "b"]}, {"a": ["b", 1.0]}))
	check("a key more differs, and so does another element or count", not spare._shipCopyPasteEqual({"a": 1}, {"a": 1, "b": 1}) and not spare._shipCopyPasteEqual([1, 2], [1, 3]) and not spare._shipCopyPasteEqual([1, 1, 2], [1, 2, 2]))
	var tuned = spare._shipCopyPasteTuning({"tuning": {"a": {"type_X": {"t": 1}, "type_Y": {"t": 2}}}}, {"tuning": {}}, {"a.type": "X"})
	check("a piece kept that the ship flown has no Tuning entries for loses the copied ship's; the others stay", not tuned.a.has("type_X") and tuned.a.has("type_Y"), tuned)
	tuned = spare._shipCopyPasteTuning({"tuning": {"a": {"type_X": {"t": 1}}}}, {"tuning": {"a": {"type_X": {"t": 5}}}}, {"a.type": "X"})
	check("a piece kept keeps its own Tuning entries", tuned.a.type_X.t == 5, tuned)

	# The confirmation dialog
	var stateBefore = JSON.print(CurrentGame.state)
	var copiedBefore = JSON.print(garageConfig("SE1-0001"))
	var uses = []
	copied.connect("use", self, "_recordUse", [uses])
	press(copy[other])
	press(copy[spare])
	yield(idle(3), "completed")
	check("a disabled or hidden Copy (another model, the current ship) opens nothing", spare.get_node_or_null(dialogName) == null and other.get_node_or_null(dialogName) == null and copied.get_node_or_null(dialogName) == null)
	press(copy[copied])
	yield(idle(3), "completed")
	var dialog = copied.get_node_or_null(dialogName)
	check("Copy first brings the Equipment screen's prices up to date", equipment.repriced == 1, equipment.repriced)
	check("then opens a confirmation dialog as the game's own (a ConfirmationDialog without a title), a child of the copied ship's entry, the entry's Buy confirmation untouched", dialog is ConfirmationDialog and dialog.visible and dialog.window_title == "" and not copied.get_node("ConfirmationCenter/BuyPanel").visible and names(copied.get_node("ConfirmationCenter")) == ["BuyPanel", "SellPanel"])
	check("Copy doesn't switch ships (no `use`)", uses.empty())
	if not dialog is ConfirmationDialog:
		_free()
		return
	var ok = dialog.get_ok()
	var cancel = dialog.get_cancel()
	var title = copied._shipCopyPasteTitle
	var parts = copied._shipCopyPasteParts
	var prose = copied.get_node("HBox/Margin").get_font("font", "Label")
	check("in the entry's menu theme (the game's window frame), with the game's OK and CANCEL, Cancel focused", dialog.get_stylebox("panel", "WindowDialog") == load("res://menu/MenuTheme.tres").get_stylebox("panel", "WindowDialog") and ok.text == spare._SHIP_COPY_PASTE_OK and cancel.text == spare._SHIP_COPY_PASTE_CANCEL and dialog.get_focus_owner() == cancel, dialog.get_focus_owner())
	check("its question names the ship flown and the copied ship, in the menu font", title.text == question and title.get_font("font") == copied.get_font("font"), title.text)
	var order = []
	for c in parts.get_parent().get_children():
		order.append(c.get_class())
	for c in parts.get_children():
		order.append(c.name if c.name.begins_with(MOD) else c.get_class())
	check("the question, then Ship settings, Crew aboard and Equipment, the list under it", order == ["Label", "VBoxContainer", MOD + "Settings", MOD + "Crew", MOD + "Equipment", "GridContainer"], order)
	var rowNames = []
	var rowsLikeTuning = true
	for part in copied._shipCopyPasteRows:
		var row = copied._shipCopyPasteRows[part]
		rowNames.append(row.get_node("HBoxContainer/Name").text)
		rowsLikeTuning = rowsLikeTuning and not row.get_node("HBoxContainer/Reset").visible and not row.get_node("HBoxContainer/Name").clip_text
	check("each row the game's Tuning switch, named by the mod's text, without its reset button, the name never clipped", rowNames == spare._SHIP_COPY_PASTE_ROWS.values() and rowsLikeTuning, rowNames)
	check("every part differs: a switch on each row, on", same(states(copied), allOn()), states(copied))
	var bought = [money(spare, "SYSTEM_ARM", arm), money(spare, "SYSTEM_ENGINE_B", engine), money(spare, "SYSTEM_FUEL_50", fuel), money(spare, spare._SHIP_COPY_PASTE_TEXT_TOTAL, total), repairs]
	check("under Equipment: each piece bought, as the Equipment screen names it, with its price (the lidar the copied ship lacks reads as the ship's default, the ammo it lacks as none), then the total and the repair time", listed(copied) == bought, listed(copied))
	var kids = copied._shipCopyPasteList.get_children()
	var minus = spare._SHIP_COPY_PASTE_COLOR_MINUS_FALLBACK
	check("the costs in the Fleet screen's colour for a cost, the repair time uncoloured, the values right-aligned, in the prose font", kids[1].modulate == minus and kids[7].modulate == minus and kids[9].modulate == Color.white and kids[1].align == Label.ALIGN_RIGHT and kids[0].get_font("font") == prose and prose != copied.get_font("font"), [kids[1].modulate, kids[9].modulate])
	yield(idle(3), "completed")
	var rightEdges = [kids[1].get_global_rect().end.x, valueNode(copied, "settings").get_global_rect().end.x, valueNode(copied, "equipment").get_global_rect().end.x]
	check("the values' right edge lines up with the switches'", abs(rightEdges[0] - rightEdges[1]) < 2 and abs(rightEdges[1] - rightEdges[2]) < 2, rightEdges)
	var screen = dialog.get_viewport_rect()
	var box = dialog.get_global_rect()
	check("the dialog on the screen, centered, at its least size", screen.encloses(box) and (box.position + box.size / 2 - screen.size / 2).length() <= 1 and (box.size - dialog.get_combined_minimum_size()).length() < 1, [box, screen])
	checkWidths(copied, "the dialog")
	check("the entry keeps the list's width", fitsRow(copied, LIST_WIDTH, []), copied.rect_size.x)
	press(cancel)
	yield(idle(), "completed")
	check("Cancel closes it, the focus back on Copy", not dialog.visible and copy[copied].has_focus())
	check("and nothing changed", JSON.print(CurrentGame.state) == stateBefore)
	bindGameKeys()
	yield(open(copied), "completed")
	var cancels = fleet.cancels
	yield(tap(escKey()), "completed")
	yield(idle(), "completed")
	check("Esc closes the dialog only: the Fleet screen doesn't get it (Dealer.gd _input would close the screen)", not dialog.visible and fleet.cancels == cancels and JSON.print(CurrentGame.state) == stateBefore, fleet.cancels - cancels)
	yield(tap(escKey()), "completed")
	yield(idle(), "completed")
	check("(with the dialog closed, Esc reaches the Fleet screen)", fleet.cancels == cancels + 1)

	# Not enough money: only while the equipment is switched on
	CurrentGame.money = total - 1
	yield(open(copied), "completed")
	check("above the player's money, with the equipment on, OK reads Insufficient funds and is disabled", ok.text == spare._SHIP_COPY_PASTE_TEXT_NO_MONEY and ok.disabled, ok.text)
	press(ok)
	check("and pressing it changes nothing", dialog.visible and JSON.print(CurrentGame.state) == stateBefore and CurrentGame.money == total - 1)
	toggle(copied, "equipment", false)
	check("the equipment switched off: OK reads OK again, enabled", ok.text == spare._SHIP_COPY_PASTE_OK and not ok.disabled, ok.text)
	press(cancel)
	yield(idle(), "completed")
	CurrentGame.money = 1000000

	# The D-pad, and a switch turned off that gets the focus again
	yield(open(copied), "completed")
	check("reopened, every switch is on again", same(states(copied), allOn()), states(copied))
	var path = []
	for i in 3:
		yield(tapJoy(JOY_DPAD_UP), "completed")
		path.append(dialog.get_focus_owner())
	for i in 3:
		yield(tapJoy(JOY_DPAD_DOWN), "completed")
		path.append(dialog.get_focus_owner())
	var want = [valueNode(copied, "equipment"), valueNode(copied, "crew"), valueNode(copied, "settings"), valueNode(copied, "crew"), valueNode(copied, "equipment"), cancel]
	check("the D-pad goes up from Cancel through the switches, and back down to Cancel", path == want, path)
	check("walking the switches changes none", same(states(copied), allOn()), states(copied))
	toggle(copied, "settings", false)
	valueNode(copied, "equipment").grab_focus()
	valueNode(copied, "settings").grab_focus()
	yield(idle(), "completed")
	check("a switch turned off stays off when it gets the focus again (the Tuning switch sends its value then)", states(copied).settings == "switch:off" and copied._shipCopyPasteRows.settings.tune.current == false, states(copied))
	press(cancel)
	yield(idle(), "completed")

	# A plan that changed while the dialog showed
	yield(open(copied), "completed")
	for s in ["SYSTEM_FUEL_20", "SYSTEM_FUEL_50"]:
		items[s + "@fuel.capacity"].setValuesDiscount(2000)
	fuel = (4000 - 2000) * 1
	total = arm + engine + fuel
	bought[2] = money(spare, "SYSTEM_FUEL_50", fuel)
	bought[3] = money(spare, spare._SHIP_COPY_PASTE_TEXT_TOTAL, total)
	press(ok)
	check("a price changed since it showed: OK shows the new plan and pastes nothing", dialog.visible and listed(copied) == bought and not ok.disabled and JSON.print(CurrentGame.state) == stateBefore, listed(copied))

	# Every part pasted
	var config = CurrentGame.state.ship.config
	var moneyBefore = CurrentGame.money
	var logsBefore = CurrentGame.logs.size()
	var spareBefore = spareShip()
	var copiedConfig = copiedShip().config
	var validatedBefore = CurrentGame.validated.size()
	press(ok)
	yield(idle(), "completed")
	check("OK buys the differing pieces at the shown total", CurrentGame.money == moneyBefore - total, [CurrentGame.money, moneyBefore - total])
	check("each fitted as the Equipment screen fits it: the slot's damage cleared, its value set", player.cleared == ["weaponSlot.main.type", "propulsion.main", "fuel.capacity"] and config.weaponSlot.main.type == "SYSTEM_ARM" and config.propulsion.main == "SYSTEM_ENGINE_B" and same(config.fuel.capacity, 50000.0), player.cleared)
	check("pieces already the same left as they are", config.propulsion.rcs == "SYSTEM_RCS_A" and config.weaponSlot.left.type == "SYSTEM_GUN" and same(config.reactor.power, 8.0) and config.lidar.type == "SYSTEM_LIDAR_DOPPLER" and same(config.ammo.capacity, 0.0) and config.hud.type == "SYSTEM_HUD_A")
	check("the repair time grows by the pieces' replacement time, counted from now, not the copied ship's", CurrentGame.state.ship.get("maintaineceUntil") == NOW + 7200, CurrentGame.state.ship.get("maintaineceUntil"))
	var logged = CurrentGame.logs.back() if CurrentGame.logs.size() == logsBefore + 1 else []
	check("the purchase is logged as the Equipment screen logs it", logged.size() == 2 and logged[0] == "LOG_EVENT_UPGRADE" and same(logged[1], {"LOG_EVENT_DETAILS_COST": -total, "SYSTEM_ARM": -arm, "SYSTEM_ENGINE_B": -engine, "SYSTEM_FUEL_50": -fuel}), logged)
	check("the tuning is the copied ship's (a value the spare tuned and the copied ship didn't is gone)", same(config.tuning, copiedConfig.tuning), config.tuning)
	check("the mineral targeting is the copied ship's, other mods' entries in it too", same(config.hud.config, copiedConfig.hud.config))
	check("the slot configs are the copied ship's", same(config.weaponSlot.main.config, copiedConfig.weaponSlot.main.config) and same(config.weaponSlot.left.config, copiedConfig.weaponSlot.left.config))
	check("the crew list is the copied ship's", same(config.preferredCrew, copiedConfig.preferredCrew))
	check("and the game puts it aboard at once (validateEmployment, after the list is written), not only when the docked ship is rebuilt", CurrentGame.validated.size() == validatedBefore + 1 and same(CurrentGame.validated.back(), copiedConfig.preferredCrew), CurrentGame.validated)
	var full = CurrentGame.state.ship
	check("identity, damage, cargo and consumables are the spare's", full.transponder == "SE1-0002" and full.model == MODEL and full.madeIn == 200 and full.faction == "player" and same(config.damage, spareBefore.config.damage) and same(config.currentCargo, spareBefore.config.currentCargo) and same(config.processedCargo, spareBefore.config.processedCargo) and same(config.fuel.initial, 20000.0))
	check("the copied ship is untouched", JSON.print(garageConfig("SE1-0001")) == copiedBefore)
	config.hud.config.minValue = -1
	check("(changing the pasted mineral targeting leaves the copied ship's)", garageConfig("SE1-0001").config.hud.config.minValue == 3000)
	config.hud.config.minValue = copiedConfig.hud.config.minValue
	check("then, as after a switch, the Fleet screen's shipChanged and addShips", fleet.changed == 1 and fleet.added == 1, [fleet.changed, fleet.added])
	check("the dialog closes, the focus back on Copy", not dialog.visible and copy[copied].has_focus())

	# A refund: the copied ship's piece is cheaper than the one fitted. A Tuning value stored on the ship flown only, as
	# the Tuning screen stores what it shows (the default, snapped to its step), reads the same as none.
	garageConfig("SE1-0001").config.propulsion.main = "SYSTEM_ENGINE_A"
	for s in ["SYSTEM_ENGINE_A", "SYSTEM_ENGINE_B"]:
		items[s + "@propulsion.main"].setValuesDiscount(8000)
	var refund = (8000 - 3000) * 2
	config.tuning.Hud.TUNE_ACC = 2.9
	moneyBefore = CurrentGame.money
	var maintenance = CurrentGame.state.ship.maintaineceUntil
	yield(open(copied), "completed")
	kids = copied._shipCopyPasteList.get_children()
	check("a cheaper piece: listed with its refund, positive, in the Fleet screen's colour for a gain, then the total; no repair time when the piece replaced isn't damaged", listed(copied) == [money(spare, "SYSTEM_ENGINE_A", -refund), money(spare, spare._SHIP_COPY_PASTE_TEXT_TOTAL, -refund)] and kids[1].modulate == spare._SHIP_COPY_PASTE_COLOR_PLUS_FALLBACK, listed(copied))
	check("the settings read Same where the Tuning screen shows the same, and so does the crew", same(states(copied), {"settings": sameLabel, "crew": sameLabel, "equipment": "switch:on"}), states(copied))
	press(ok)
	yield(idle(), "completed")
	check("OK pays the refund, and the repair time stays", CurrentGame.money == moneyBefore + refund and config.propulsion.main == "SYSTEM_ENGINE_A" and CurrentGame.state.ship.maintaineceUntil == maintenance, [CurrentGame.money, moneyBefore + refund])

	# The settings differ only in the Tuning entries of the piece the equipment buys: with the equipment off, that piece
	# isn't fitted, and they read the same.
	config.weaponSlot.main.type = "SYSTEM_DRILL"
	garageConfig("SE1-0001").config.tuning.weaponSlot.main.type_SYSTEM_ARM.TUNE_ARM_POWER_LIMIT = 80
	yield(open(copied), "completed")
	var armOnly = [money(spare, "SYSTEM_ARM", arm), money(spare, spare._SHIP_COPY_PASTE_TEXT_TOTAL, arm), repairs]
	check("the piece bought tuned otherwise on the copied ship: the settings differ", same(states(copied), {"settings": "switch:on", "crew": sameLabel, "equipment": "switch:on"}) and listed(copied) == armOnly, [states(copied), listed(copied)])
	toggle(copied, "equipment", false)
	check("the equipment switched off: the settings read Same, the list stays, and with nothing switched on OK is disabled", same(states(copied), {"settings": sameLabel, "crew": sameLabel, "equipment": "switch:off"}) and listed(copied) == armOnly and ok.disabled, states(copied))
	toggle(copied, "equipment", true)
	check("switched on again: the settings' switch is back, on", states(copied).settings == "switch:on" and not ok.disabled, states(copied))
	press(cancel)
	yield(idle(), "completed")

	# The equipment off and the settings on: the pieces kept keep their own Tuning entries and slot configs.
	garageConfig("SE1-0001").config.tuning.Hud.TUNE_MAX_VELOCITY = 60
	garageConfig("SE1-0001").config.tuning.weaponSlot.main["type_SYSTEM_DRILL"] = {"TUNE_ARM_POWER_LIMIT": 90}
	garageConfig("SE1-0001").config.weaponSlot.main.config = {"minerals": ["Pd"]}
	config.tuning.weaponSlot.main["type_SYSTEM_DRILL"] = {"TUNE_ARM_POWER_LIMIT": 20}
	var mainBefore = config.weaponSlot.main.config.duplicate(true)
	yield(open(copied), "completed")
	toggle(copied, "equipment", false)
	check("the equipment switched off, the settings still differ (another setting)", states(copied).settings == "switch:on", states(copied))
	moneyBefore = CurrentGame.money
	logsBefore = CurrentGame.logs.size()
	var cleared = player.cleared.size()
	validatedBefore = CurrentGame.validated.size()
	press(ok)
	yield(idle(), "completed")
	var tuning = garageConfig("SE1-0001").config.tuning.duplicate(true)
	tuning.weaponSlot.main["type_SYSTEM_DRILL"] = {"TUNE_ARM_POWER_LIMIT": 20}
	check("OK with the equipment off buys nothing, logs nothing, adds no repair time", CurrentGame.money == moneyBefore and CurrentGame.logs.size() == logsBefore and player.cleared.size() == cleared and CurrentGame.state.ship.maintaineceUntil == maintenance and config.weaponSlot.main.type == "SYSTEM_DRILL")
	check("the tuning is the copied ship's, with the ship's own entries for the piece it keeps", same(config.tuning, tuning), config.tuning)
	check("the slot whose piece is kept keeps its config", same(config.weaponSlot.main.config, mainBefore), config.weaponSlot.main.config)
	check("the crew, the same, isn't put aboard again", CurrentGame.validated.size() == validatedBefore)

	# Pieces the Equipment screen doesn't sell, or doesn't make available
	garageConfig("SE1-0001").config.weaponSlot.left.type = "SYSTEM_TWIST"
	garageConfig("SE1-0001").config.reactor.power = 12.0
	yield(open(copied), "completed")
	kids = copied._shipCopyPasteList.get_children()
	var unfit = tr(spare._SHIP_COPY_PASTE_TEXT_UNFIT)
	check("a piece that can't be fitted: Incompatible equipment in place of the switch", states(copied).equipment == "label:" + tr(spare._SHIP_COPY_PASTE_TEXT_INCOMPATIBLE), states(copied))
	check("the list holds only those pieces, each with the reason, uncoloured: a system by its name, a number by its slot", listed(copied) == [line(spare, "SYSTEM_TWIST", unfit), line(spare, "reactor.power %s" % CurrentGame.formatThousands(12.0), unfit)] and kids[1].modulate == Color.white, listed(copied))
	yield(idle(3), "completed")
	checkWidths(copied, "incompatible equipment")
	check("with nothing else to paste, OK is disabled", ok.disabled and states(copied).settings == sameLabel and states(copied).crew == sameLabel, states(copied))
	press(cancel)
	yield(idle(), "completed")
	garageConfig("SE1-0001").config.weaponSlot.left.type = "SYSTEM_GUN"
	garageConfig("SE1-0001").config.reactor.power = 8.0

	# The crew. The game drops someone fired from the current ship's list only (CurrentGame.gd fireCrewmember).
	garageConfig("SE1-0001").config.preferredCrew = ["Ann", "Gone"]
	yield(open(copied), "completed")
	check("a copied crew list that names someone fired since differs", states(copied).crew == "switch:on", states(copied))
	toggle(copied, "equipment", false)
	validatedBefore = CurrentGame.validated.size()
	press(ok)
	yield(idle(), "completed")
	check("OK puts aboard only those still in your crew", same(config.preferredCrew, ["Ann"]) and CurrentGame.validated.size() == validatedBefore + 1 and same(CurrentGame.validated.back(), ["Ann"]), config.preferredCrew)
	garageConfig("SE1-0001").config.erase("preferredCrew")
	yield(open(copied), "completed")
	check("a copied ship without a crew list has no crew: with someone aboard, the crew's switch", states(copied).crew == "switch:on", states(copied))
	toggle(copied, "equipment", false)
	validatedBefore = CurrentGame.validated.size()
	press(ok)
	yield(idle(), "completed")
	var nobody = config.get("preferredCrew")
	check("OK leaves an empty crew list, put aboard", nobody is Array and nobody.empty() and CurrentGame.validated.size() == validatedBefore + 1, nobody)
	yield(open(copied), "completed")
	check("with nobody aboard either, the crew reads Same", states(copied).crew == sameLabel, states(copied))
	press(cancel)
	yield(idle(), "completed")
	config.preferredCrew = ["Ann", "Bob"]
	garageConfig("SE1-0001").config.preferredCrew = ["Bob", "Ann"]
	yield(open(copied), "completed")
	check("the same crew in another order reads Same", states(copied).crew == sameLabel, states(copied))

	# A long question wraps at MAX_WIDTH_SHARE of the screen, and the rows stay as narrow as they were
	var narrow = parts.rect_size.x
	var long = "Make a ship with a name long enough to pass half of the screen on one line like another ship with a long name too?"
	title.text = long
	copied._shipCopyPasteWidths(long)
	copied._shipCopyPasteDialogFit()
	yield(idle(3), "completed")
	var most = floor(title.get_viewport_rect().size.x * copied._SHIP_COPY_PASTE_MAX_WIDTH_SHARE)
	check("a long question wraps at the screen's share, the rows as narrow as before", abs(title.rect_min_size.x - max(most, parts.rect_size.x)) < 1 and title.get_line_count() > 1 and abs(parts.rect_size.x - narrow) < 1, [title.rect_min_size.x, most, title.get_line_count(), parts.rect_size.x, narrow])
	press(cancel)
	yield(idle(), "completed")

	# Everything the same
	var copiedFull = garageConfig("SE1-0001")
	var at = CurrentGame.state.garage.find(copiedFull)
	var sameFull = CurrentGame.state.ship.duplicate(true)
	sameFull.transponder = "SE1-0001"
	CurrentGame.state.garage[at] = sameFull
	yield(open(copied), "completed")
	check("the same ship: Same on every row, no list, OK disabled", same(states(copied), {"settings": sameLabel, "crew": sameLabel, "equipment": sameLabel}) and not copied._shipCopyPasteList.visible and ok.disabled, states(copied))
	press(cancel)
	yield(idle(), "completed")
	CurrentGame.state.garage[at] = copiedFull

	# An empty slot holds the slot's default item, as the Equipment screen counts it (Upgrades.gd
	# updatePricesAndAvailability): None on one ship and nothing on the other are the same.
	var none = items["SYSTEM_NONE@weaponSlot.left.type"]
	none.default = true
	var copiedLeft = garageConfig("SE1-0001").config.weaponSlot.left.duplicate(true)
	garageConfig("SE1-0001").config.weaponSlot.left = {"type": "SYSTEM_NONE"}
	var spareLeft = config.weaponSlot.left.duplicate(true)
	config.weaponSlot.erase("left")
	player.useConfig(CurrentGame.state.ship)
	var plan = spare._shipCopyPastePlan(garageConfig("SE1-0001"), player, equipment.get_node("Items").get_children())
	check("an empty slot and its default item (None) count as the same: the slot doesn't differ", not plan.differing.has("weaponSlot.left.type"), plan.differing.keys())
	garageConfig("SE1-0001").config.weaponSlot.erase("left")
	config.weaponSlot.left = {"type": "SYSTEM_NONE"}
	player.useConfig(CurrentGame.state.ship)
	plan = spare._shipCopyPastePlan(garageConfig("SE1-0001"), player, equipment.get_node("Items").get_children())
	check("and the other way round", not plan.differing.has("weaponSlot.left.type"), plan.differing.keys())
	none.default = false
	garageConfig("SE1-0001").config.weaponSlot.left = copiedLeft
	config.weaponSlot.left = spareLeft
	player.useConfig(CurrentGame.state.ship)

	# The copied ship sold, or the Fleet screen closed, while the dialog shows
	yield(open(copied), "completed")
	var sold = garageConfig("SE1-0001")
	CurrentGame.state.garage.erase(sold)
	copied.checkCurrentAndOwned()
	check("the copied ship no longer owned (sold): Copy disabled, and the dialog closes", copy[copied].disabled and not dialog.visible)
	CurrentGame.state.garage.insert(0, sold)
	copied.checkCurrentAndOwned()
	yield(open(copied), "completed")
	fleet.visible = false
	check("closing the Fleet screen closes the dialog", not dialog.visible)
	fleet.visible = true
	yield(idle(), "completed")

	# The texts (i18n/en.po), also in a language without them (Godot's fallback, en)
	var keys = [spare._SHIP_COPY_PASTE_TIP_COPY, spare._SHIP_COPY_PASTE_TIP_COPY_MODEL, spare._SHIP_COPY_PASTE_TEXT_CONFIRM, spare._SHIP_COPY_PASTE_TEXT_BULLET, spare._SHIP_COPY_PASTE_TEXT_SAME, spare._SHIP_COPY_PASTE_TEXT_INCOMPATIBLE, spare._SHIP_COPY_PASTE_TEXT_UNFIT, spare._SHIP_COPY_PASTE_TEXT_COST, spare._SHIP_COPY_PASTE_TEXT_GAIN, spare._SHIP_COPY_PASTE_TEXT_TOTAL, spare._SHIP_COPY_PASTE_TEXT_REPAIRS, spare._SHIP_COPY_PASTE_TEXT_NO_MONEY] + spare._SHIP_COPY_PASTE_ROWS.values()
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

	# With a gamepad: an entry with the game's tooltip node (SystemBuyUI.tscn has one), which takes in the entry's
	# buttons a node per frame from its _ready on, Copy among them, since the entry adds it in its own _ready. The
	# tooltip then shows when a button gets the focus, as on hover, so the D-pad shows why Copy is disabled.
	var pad = makeEntry(list, otherModelShip(), true, false, "res://harness/dealer_entry.tscn")
	yield(idle(60), "completed")
	var tooltips = pad.get_node("PlaySoundsOnTheseButtons")
	var padCopy = pad.get_node("HBox/" + copyName)
	check("gamepad: the entry's tooltip node takes Copy in", tooltips.tooltips.has(padCopy), tooltips.tooltips.keys())
	padCopy.grab_focus()
	check("gamepad: a disabled Copy shows why when it gets the focus", padCopy.disabled and tooltips.tooltipPosition.visible and tooltips.tooltipLabel.text == pad._SHIP_COPY_PASTE_TIP_COPY_MODEL, tooltips.tooltipLabel.text)
	var padUse = pad.get_node("HBox/Use")
	padUse.grab_focus()
	yield(tapJoy(JOY_DPAD_LEFT), "completed")
	var left = pad.get_focus_owner()
	yield(tapJoy(JOY_DPAD_RIGHT), "completed")
	var right = pad.get_focus_owner()
	check("gamepad: the D-pad goes from Use to Copy and back", left == padCopy and right == padUse, [left, right])
	padUse.release_focus()

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
