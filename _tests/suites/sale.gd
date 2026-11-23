extends "res://harness/suite.gd"

# ShipSaleAdvisor: on the Fleet screen, Sell on a stored ship that would bring more cash once prepared shows the mod's
# dialog instead of the game's confirmation: Prepare (Fix clicks and slots taken down to their cheapest item, as the
# player would make them by hand, the ship then in maintenance), Sell (as it is) or Cancel. Shift+Click on an enabled
# Sell button, or its gamepad twin, opens the settings (the minimum gain), and a note at the bottom of the Fleet screen
# says so.
#
# First the advice alone (Advisor.gd, from plain data): the worked K37 derelict (build 4, 99.8 years, every damaged
# system at 65 %, one mechanic at experience 0, so a repair limit of 71 %), with full, partial and no insurance, too
# little cash, a minimum gain of 0 and a high one; the runs of clicks a piece at 0 % needs; a click that adds less than
# its price; an undamaged hardpoint piece; a damaged piece worth less than the cheapest item.
#
# Then the station: the game's SystemBuyUI.gd entries in the harness's stub of their scene, in a stub of the Fleet
# screen (harness/sale_fleet.gd) among the station's screens (the game's HidingMarginContainer.gd), next to a stub of the
# Equipment screen (harness/fleet_equipment.gd) holding the game's SystemShipUpgradeUI.gd items. The ships are that
# derelict (harness/sale_ship.gd, also the trial ship's scene in the Shipyard stub), stored in the CurrentGame stub's
# state. The mod's node names and texts are read from the mod, the gamepad twin's buttons from its Badge.gd.

const MOD = "ShipSaleAdvisor"
const ENTRY = "res://enceladus/SystemBuyUI.tscn"
const ITEM = "res://enceladus/SystemShipUpgradeUI.tscn"
const SHIP = "res://harness/sale_ship.gd"
const MODEL = "SALE" # the stub ship's model in the Shipyard stub
const H = 3600.0
const NOW = 5000 # the in-game time
const SCREEN_SIZE = Vector2(1920, 1080) # the window, which the dialog's width follows
const OLD_WIDTH_SHARE = 0.4 # the share of the screen the dialog's contents took before they followed their texts
# The Equipment screen's items: slot, system, price, and numVal where given.
const ITEMS = [
	["weaponSlot.main.type", "SYSTEM_NONE", 0],
	["weaponSlot.main.type", "SYSTEM_MWG", 70000],
	["propulsion.rcs", "SYSTEM_THRUSTER_NDSTR", 1250],
	["propulsion.rcs", "SYSTEM_THRUSTER_MA350HO", 10000],
	["propulsion.main", "SYSTEM_MAIN_ENGINE_PNTR", 7000],
	["propulsion.main", "SYSTEM_MAIN_ENGINE_K37", 15000],
	["capacitor.capacity", "SYSTEM_CAPACITOR_500", 25000, 500.0],
	["capacitor.capacity", "SYSTEM_CAPACITOR_1500", 90000, 1500.0],
	["turbine.power", "SYSTEM_TURBINE_100", 30000, 100.0],
	["turbine.power", "SYSTEM_TURBINE_200", 60000, 200.0],
	["fuel.capacity", "SYSTEM_FUEL_15000", 6000, 15000.0],
	["fuel.capacity", "SYSTEM_FUEL_30000", 12000, 30000.0],
	["reactor.power", "SYSTEM_RODS_4", 80000, 4.0],
	["autopilot.type", "SYSTEM_AUTOPILOT_NONE", 0],
	["autopilot.type", "SYSTEM_AUTOPILOT_MK2", 27000],
	["lidar.type", "SYSTEM_LIDAR_RADAR", 5000],
	["lidar.type", "SYSTEM_LIDAR_DOPPLER", 15000],
	["hud.type", "SYSTEM_NONE", 0],
	["hud.type", "SYSTEM_HUD_TNTRL", 4000],
]

var advisor # the mod's Advisor.gd
var settings # the mod's shared settings
var badge # the mod's Badge.gd
var screens
var fleet
var equipment
var list # the Fleet screen's entries
var sold = [] # the ships the entries' `sell` signal gave

# --- The advice ---

func value(price, status):
	var pf = pow(status / 100.0, 2)
	if pf < 1:
		pf *= 0.8
	return price * pf

func values(price, statuses):
	var out = []
	for s in statuses:
		out.append(value(price, s))
	return out

# The derelict as Advisor.gd's data: one click each to 82.5 %, the repair limit stopping the next.
func k37(money, insurance, minGain):
	var systems = {
		"reactor": {"slot": "", "values": values(80000, [65, 82.5]), "fixPrice": 5000, "fixTime": 48 * H},
		"torch": {"slot": "propulsion.main", "values": values(15000, [65, 82.5]), "fixPrice": 1000, "fixTime": 12 * H},
		"hud": {"slot": "", "values": values(6000, [65, 82.5]), "fixPrice": 500, "fixTime": 4 * H},
		"mwg": {"slot": "weaponSlot.main.type", "values": values(70000, [65, 82.5]), "fixPrice": 1500, "fixTime": 6 * H},
	}
	var thrusters = []
	for i in 8:
		var id = "t%d" % i
		systems[id] = {"slot": "propulsion.rcs", "values": values(10000, [65, 82.5]), "fixPrice": 3500, "fixTime": 4 * H}
		thrusters.append(id)
	var slots = {
		"weaponSlot.main.type": {"members": ["mwg"], "cost": 0, "time": 1 * H},
		"propulsion.rcs": {"members": thrusters, "cost": 1250 * 8, "time": 8 * H},
		"propulsion.main": {"members": ["torch"], "cost": 7000, "time": 4 * H},
		"capacitor.capacity": {"members": [], "refund": 65000, "time": 0},
		"turbine.power": {"members": [], "refund": 30000, "time": 0},
		"autopilot.type": {"members": [], "refund": 27000, "time": 0},
		"lidar.type": {"members": [], "refund": 10000, "time": 0},
		"fuel.capacity": {"members": [], "refund": 6000, "time": 0},
		"hud.type": {"members": [], "refund": 4000, "time": 0},
	}
	return {"markdown": 0.9, "money": money, "insurance": insurance, "minGain": minGain, "systems": systems, "slots": slots}

func near(a, b):
	return abs(a - b) < 0.05

func advice():
	# Partial insurance: the four clicks that add more than they cost, all paid by it; the thrusters' clicks (3,500 for
	# 2,065) never, even paid by the insurance.
	var p = advisor.plan(k37(1e6, 25000, 1000))
	check("advice: the clicks that add more than they cost", p.clicks.size() == 4 and p.clicks.get("reactor") == 1 and p.clicks.get("torch") == 1 and p.clicks.get("hud") == 1 and p.clicks.get("mwg") == 1, p.clicks)
	check("advice: the slots that refund at least the minimum gain's worth, in the data's order", p.strips == ["weaponSlot.main.type", "propulsion.rcs", "capacitor.capacity", "turbine.power", "autopilot.type", "lidar.type"], p.strips)
	check("advice: the insurance pays the clicks, nothing from cash", near(p.insuranceCost, 8000) and near(p.cashCost, 0), [p.insuranceCost, p.cashCost])
	check("advice: 3d 7h of maintenance", near(p.time, 79 * H), p.time / H)
	check("advice: the refunds and the gain", near(p.refund, 187155) and near(p.gain, 50495.85), [p.refund, p.gain])
	var full = advisor.plan(k37(1e6, 100000, 1000))
	check("advice: full insurance, the same clicks and gain (a click must add more than it costs, whoever pays)", full.clicks.size() == 4 and near(full.gain, 50495.85), [full.clicks, full.gain])
	# No insurance: the HUD's click (1,115 for 500 of cash) falls below the minimum gain.
	var none = advisor.plan(k37(1e6, 0, 1000))
	check("advice: no insurance, the clicks whose cash gain reaches the minimum", none.clicks.size() == 3 and not none.clicks.has("hud"), none.clicks)
	check("advice: no insurance, paid from cash, 3d 3h, the gain", near(none.cashCost, 7500) and near(none.time, 75 * H) and near(none.gain, 41880.75), [none.cashCost, none.time / H, none.gain])
	var short = advisor.plan(k37(2000, 0, 1000))
	check("advice: 2,000 E$ and no insurance pay the MWG's click only", short.clicks.size() == 1 and short.clicks.has("mwg") and near(short.cashCost, 1500), [short.clicks, short.cashCost])
	# A minimum gain of 0: every step that brings any cash, the main engine taken down once its click makes it refund.
	var any = advisor.plan(k37(1e6, 0, 0))
	check("advice: a minimum gain of 0 takes every step that brings cash", "fuel.capacity" in any.strips and "hud.type" in any.strips and "propulsion.main" in any.strips and any.clicks.has("hud"), [any.strips, any.clicks])
	check("advice: a high minimum gain, nothing", advisor.isEmpty(advisor.plan(k37(1e6, 0, 1e6))))
	# A piece at 0 %: its first click leaves it at 0 % and adds nothing; the run goes on to the clicks that pay best.
	var units = advisor._units(values(10000, [0, 0, 40, 70, 85]), 1000, H, 0.9)
	check("advice: a piece at 0 % fixed in one run of four clicks", units.size() == 1 and units[0].end == 4 and near(units[0].cost, 4000), units)
	var units2 = advisor._units(values(10000, [0, 20, 60, 80, 90]), 1000, H, 0.9)
	check("advice: a run ends at the click with the most per E$", units2.size() >= 1 and units2[0].end == 3, units2)
	var emp = advisor._units(values(70000, [0, 40, 70]), 10000, H, 0.9)
	check("advice: two clicks taken together where the first alone loses money", emp.size() == 1 and emp[0].end == 2 and near(emp[0].add, 24696) and near(emp[0].cost, 20000), emp)
	var data = {"markdown": 0.9, "money": 0, "insurance": 1e6, "minGain": 0,
		"systems": {"x": {"slot": "", "values": [1000.0, 2499.0], "fixPrice": 1500, "fixTime": H}}, "slots": {}}
	check("advice: a click adding less than its price is dropped, even paid by the insurance", advisor.isEmpty(advisor.plan(data)))
	data.systems.x.values = [1000.0, 2700.0]
	check("advice: a click adding more than its price is taken", advisor.plan(data).clicks.get("x") == 1)
	var hp = {"markdown": 0.9, "money": 0, "insurance": 0, "minGain": 0,
		"systems": {"arm": {"slot": "weaponSlot.main.type", "values": [56000.0], "fixPrice": 0, "fixTime": 0}},
		"slots": {"weaponSlot.main.type": {"members": ["arm"], "cost": 0, "time": 0}}}
	check("advice: an undamaged hardpoint piece taken off brings what the sale wouldn't pay of it", near(advisor.plan(hp).gain, 5600), advisor.plan(hp).gain)
	var kept = {"markdown": 0.9, "money": 0, "insurance": 0, "minGain": 0,
		"systems": {"e": {"slot": "propulsion.main", "values": [5070.0], "fixPrice": 1000, "fixTime": H}},
		"slots": {"propulsion.main": {"members": ["e"], "cost": 7000, "time": 4 * H}}}
	check("advice: a damaged piece worth less than the cheapest item is kept", advisor.isEmpty(advisor.plan(kept)))

# --- The station ---

func derelict(transponder, damaged = true):
	var damage = {}
	if damaged:
		damage = {"reactor": {"a": 0.35}, "Hud": {"a": 0.35}, "WeaponSlot": {"a": 0.35}, "engine-main": {"a": 0.35}}
		for i in 8:
			damage["thruster-%d" % i] = {"a": 0.35}
	return {"model": MODEL, "transponder": transponder, "madeIn": 0, "config": {
		"weaponSlot": {"main": {"type": "SYSTEM_MWG"}},
		"propulsion": {"rcs": "SYSTEM_THRUSTER_MA350HO", "main": "SYSTEM_MAIN_ENGINE_K37"},
		"capacitor": {"capacity": 1500.0}, "turbine": {"power": 200.0}, "fuel": {"capacity": 30000.0},
		"reactor": {"power": 4.0}, "autopilot": {"type": "SYSTEM_AUTOPILOT_MK2"}, "hud": {"type": "SYSTEM_HUD_TNTRL"},
		"damage": damage,
	}}

func makeStation():
	screens = MarginContainer.new()
	screens.name = "MarginContainer"
	screens.set_script(load("res://enceladus/HidingMarginContainer.gd"))
	screens.rect_size = SCREEN_SIZE
	add_child(screens)
	fleet = load("res://harness/sale_fleet.gd").new()
	fleet.name = "Owned"
	var vb = VBoxContainer.new()
	vb.name = "VB"
	fleet.add_child(vb)
	list = VBoxContainer.new()
	list.name = "Items"
	vb.add_child(list)
	screens.add_child(fleet)
	equipment = load("res://harness/fleet_equipment.gd").new()
	equipment.name = "Upgrades"
	equipment.visible = false
	var items = VBoxContainer.new()
	items.name = "Items"
	equipment.add_child(items)
	screens.add_child(equipment)
	for spec in ITEMS:
		var item = load(ITEM).instance()
		item.slot = spec[0]
		item.system = spec[1]
		item.price = spec[2]
		if spec.size() > 3:
			item.numVal = spec[3]
		items.add_child(item)

# An entry as Dealer.gd doAddShips makes one for a stored ship, its ship registered as CurrentGame.gd getOwnedShips
# keeps it (by a hash of its config).
func makeEntry(full):
	var ship = load(SHIP).new()
	ship.useConfig(full)
	CurrentGame.ownedShipInstances["hash-" + full.transponder] = ship
	var entry = load(ENTRY).instance()
	entry.ship = ship
	entry.owned = true
	entry.tradeIn = 0
	list.add_child(entry)
	entry.current = false
	entry.connect("sell", self, "_onSell")
	return entry

func _onSell(ship):
	sold.append(ship)

func dialogOf(entry):
	return entry.get_node_or_null(entry._SSA_DIALOG_NODE)

func shows(entry) -> bool:
	var dialog = dialogOf(entry)
	return dialog != null and dialog.visible

# Sell pressed, and the frames the trial ship takes.
func pressSell(entry):
	entry.get_node("HBox/Sell").emit_signal("pressed")
	yield(frames(20), "completed")

# The game's confirmation: its animation plays, or has shown its panel.
func gameConfirms(entry) -> bool:
	return entry.get_node("ConfirmationPlayer").is_playing() or entry.get_node("ConfirmationCenter/SellPanel").visible

func buttonTexts(dialog):
	var out = []
	for child in dialog.get_ok().get_parent().get_children():
		if child is Button:
			out.append(child.text)
	return out

func rowTexts(entry):
	var out = []
	for label in entry._ssaGrid.get_children():
		out.append(label.text)
	return out

func money(key, amount):
	return tr(key) % CurrentGame.formatThousands(amount)

func repairsAndUpgrades():
	var repairs = 0
	var upgrades = 0
	for entryLog in CurrentGame.logs:
		if entryLog[0] == "LOG_EVENT_REPAIR":
			repairs += 1
		elif entryLog[0] == "LOG_EVENT_UPGRADE":
			upgrades += 1
	return [repairs, upgrades]

func run():
	bindGameKeys()
	OS.window_size = SCREEN_SIZE
	yield(idle(2), "completed")
	if not hasMod(MOD):
		yield(control(), "completed")
		return
	advisor = load("res://%s/Advisor.gd" % MOD)
	settings = load("res://%s/Settings.gd" % MOD).shared()
	badge = load("res://%s/Badge.gd" % MOD)
	advice()
	var scene = PackedScene.new()
	scene.pack(load(SHIP).new())
	Shipyard.ships[MODEL] = scene
	CurrentGame.time = NOW
	CurrentGame.money = 1000000
	CurrentGame.repairLimit = 71.0
	CurrentGame.mechanics = 1
	CurrentGame.state.insurance = 25000
	CurrentGame.state.ship = {"model": MODEL, "transponder": "CUR-1", "config": {}}
	CurrentGame.state.garage = [derelict("K37-DER"), derelict("K37-TWO")]
	CurrentGame.state.ui[settings.modId()] = {"formatVersion": settings.FORMAT_VERSION, "modVersion": settings.modVersion(), "minGain": 2500.0}
	makeStation()
	var entry = makeEntry(CurrentGame.state.garage[0])
	var other = makeEntry(CurrentGame.state.garage[1])
	yield(frames(10), "completed")
	check("the save's minimum gain is loaded with the Fleet screen", settings.getValue("minGain") == 2500.0, settings.getValue("minGain"))
	settings.setValue("minGain", 1000)
	check("a change is stored in the save", CurrentGame.state.ui[settings.modId()].minGain == 1000.0, CurrentGame.state.ui[settings.modId()])
	yield(fleetNote(), "completed")
	yield(dialog(entry), "completed")
	yield(settingsScreen(entry, other), "completed")
	yield(prepare(entry), "completed")
	yield(others(), "completed")
	check("the entries' script keeps the game's path", entry.get_script().resource_path == "res://enceladus/SystemBuyUI.gd")

# Without the mod: Sell shows the game's confirmation, and the Fleet screen has no note.
func control():
	var scene = PackedScene.new()
	scene.pack(load(SHIP).new())
	Shipyard.ships[MODEL] = scene
	CurrentGame.time = NOW
	CurrentGame.state.insurance = 25000
	CurrentGame.state.ship = {"model": MODEL, "transponder": "CUR-1", "config": {}}
	CurrentGame.state.garage = [derelict("K37-DER")]
	makeStation()
	var entry = makeEntry(CurrentGame.state.garage[0])
	yield(frames(10), "completed")
	yield(pressSell(entry), "completed")
	check("control: Sell shows the game's confirmation", gameConfirms(entry))
	check("control: no note on the Fleet screen", fleet.get_node("VB").get_child_count() == 1)

# The note: once, at the bottom of the Fleet screen's column, its text following the control scheme.
func fleetNote():
	yield(frames(1), "completed")
	var vb = fleet.get_node("VB")
	var noteScript = load("res://%s/FleetNote.gd" % MOD)
	var count = 0
	for child in vb.get_children():
		if child.name == noteScript.NODE_NAME:
			count += 1
	var shown = vb.get_node_or_null(noteScript.NODE_NAME)
	check("note: one for all the entries, at the bottom of the Fleet screen", count == 1 and shown != null and shown.get_index() == vb.get_child_count() - 1, count)
	if shown == null:
		return
	var modName = settings.modName()
	var keyText = tr(noteScript.TEXT_KEYS) % [OS.get_scancode_string(KEY_SHIFT), modName]
	var padText = tr(noteScript.TEXT_PAD) % [badge.PAD_MODIFIER_NAME, badge.PAD_BUTTON_NAME, modName]
	var keyRead = shown.text
	Settings.controlScheme = Settings.control.gamepad
	var padRead = shown.text
	Settings.controlScheme = Settings.control.keyMouse
	check("note: Shift+Click with keyboard and mouse, the gamepad twin with a gamepad, and back", keyRead == keyText and padRead == padText and shown.text == keyText and tr(noteScript.TEXT_PAD) != noteScript.TEXT_PAD, [keyRead, padRead])

# The dialog: what Sell shows on the derelict, its layout, its buttons with the D-pad, and the ways it closes.
func dialog(entry):
	var sellButton = entry.get_node("HBox/Sell")
	check("dialog: Sell enabled on a stored ship out of maintenance", not sellButton.disabled)
	entry.get_node("HBox/Sell").emit_signal("pressed")
	check("dialog: Sell disabled while the offer is worked out", sellButton.disabled)
	yield(frames(20), "completed")
	var d = dialogOf(entry)
	check("dialog: shown instead of the game's confirmation", shows(entry) and not gameConfirms(entry))
	if d == null:
		return
	check("dialog: Sell enabled again", not sellButton.disabled)
	var host = fleet.get_node_or_null(entry._SSA_TRIAL_NODE)
	check("dialog: the trial ship is gone", host != null and host.get_child_count() == 0, host.get_child_count() if host else null)
	var offer = entry._ssaOffer
	check("dialog: the sale now is the game's, the sale after is the trial ship's", near(offer.saleNow, 351303.75) and near(offer.saleAfter, 214644.6), [offer.saleNow, offer.saleAfter])
	check("dialog: the gain", near(offer.gain, 50495.85), offer.gain)
	check("dialog: the line at its top", entry._ssaIntro.text == tr(entry._SSA_TEXT_INTRO))
	var rows = [
		tr(entry._SSA_TEXT_SALE_NOW), money(entry._SSA_TEXT_PLUS, 351303.75),
		tr(entry._SSA_TEXT_INSURANCE), money(entry._SSA_TEXT_MINUS, 8000),
		tr(entry._SSA_TEXT_CASH), money(entry._SSA_TEXT_ZERO, 0),
		tr(entry._SSA_TEXT_TIME), Tool.readableTimeSpan(79 * H),
		tr(entry._SSA_TEXT_GAIN), money(entry._SSA_TEXT_PLUS, 50495.85),
	]
	check("dialog: its rows, money signed", rowTexts(entry) == rows, rowTexts(entry))
	var gainColor = entry._ssaGrid.get_child(9).modulate
	var costColor = entry._ssaGrid.get_child(3).modulate
	var zeroColor = entry._ssaGrid.get_child(5).modulate
	check("dialog: money coming in in the Fleet screen's plus colour, going out in its minus colour, none uncoloured", gainColor == entry._ssaColor(false) and costColor == entry._ssaColor(true) and zeroColor == Color(1, 1, 1, 1), [gainColor, costColor, zeroColor])
	check("dialog: the warning, since preparing takes time", entry._ssaWarning.visible and entry._ssaWarning.text == tr(entry._SSA_TEXT_WARNING))
	check("dialog: Prepare, Sell and Cancel, in that order", buttonTexts(d) == [entry._SSA_TEXT_PREPARE, entry._SSA_TEXT_SELL, entry._SSA_CANCEL], buttonTexts(d))
	check("dialog: Cancel focused", d.get_cancel().has_focus())
	# Its layout: only as wide as its texts, the line at the top on two lines, the warning on one, each value a column
	# gap after its name, the rows centred, the dialog centred on the screen.
	yield(idle(4), "completed")
	var grid = entry._ssaGrid
	var box = grid.get_parent()
	var nameLabel = grid.get_child(0)
	var gap = grid.get_child(1).rect_position.x - (nameLabel.rect_position.x + nameLabel.rect_size.x)
	var font = entry._ssaProseFont if entry._ssaProseFont != null else nameLabel.get_font("font")
	check("dialog: the line at the top on two lines, the warning on one", entry._ssaIntro.get_line_count() == 2 and entry._ssaWarning.get_line_count() == 1, [entry._ssaIntro.get_line_count(), entry._ssaWarning.get_line_count()])
	check("dialog: each value a column gap after its name", abs(gap - ceil(font.get_height() * entry._SSA_COLUMN_GAP)) < 1.0, gap)
	check("dialog: the rows centred, narrower than the dialog", grid.rect_size.x < box.rect_size.x and abs(grid.rect_position.x - (box.rect_size.x - grid.rect_size.x) / 2) <= 1.0, [grid.rect_position, grid.rect_size, box.rect_size])
	check("dialog: narrower than before its contents followed their texts", box.rect_size.x < SCREEN_SIZE.x * OLD_WIDTH_SHARE, box.rect_size)
	var centre = d.rect_global_position + d.rect_size / 2
	check("dialog: centred on the screen", (centre - SCREEN_SIZE / 2).length() < 2.0, centre)
	# The D-pad goes along the buttons, and stops at the ends.
	yield(tapJoy(JOY_DPAD_LEFT), "completed")
	var first = d.get_focus_owner()
	yield(tapJoy(JOY_DPAD_LEFT), "completed")
	var second = d.get_focus_owner()
	yield(tapJoy(JOY_DPAD_LEFT), "completed")
	var third = d.get_focus_owner()
	yield(tapJoy(JOY_DPAD_RIGHT), "completed")
	var back = d.get_focus_owner()
	check("gamepad: the D-pad goes from Cancel to Sell to Prepare, stops there, and back to Sell", first == entry._ssaSellButton and second == d.get_ok() and third == d.get_ok() and back == entry._ssaSellButton, [first, second, third, back])
	# B closes the dialog only: the Fleet screen doesn't see it.
	var cancels = fleet.cancels
	yield(tapJoy(JOY_XBOX_B), "completed")
	yield(frames(2), "completed")
	check("gamepad: B closes the dialog, not the Fleet screen, and Sell has the focus again", not d.visible and fleet.visible and fleet.cancels == cancels and sellButton.has_focus(), [d.visible, fleet.cancels - cancels])
	yield(pressSell(entry), "completed")
	yield(tap(escKey()), "completed")
	yield(frames(2), "completed")
	check("dialog: Esc closes it, not the Fleet screen", not d.visible and fleet.visible and fleet.cancels == cancels, fleet.cancels - cancels)
	yield(pressSell(entry), "completed")
	press(d.get_cancel())
	yield(frames(2), "completed")
	check("dialog: Cancel closes it, Sell has the focus again, nothing changed", not d.visible and sellButton.has_focus() and CurrentGame.state.garage[0].config.weaponSlot.main.type == "SYSTEM_MWG")
	# The Fleet screen closing takes the dialog with it.
	yield(pressSell(entry), "completed")
	fleet.hide()
	yield(frames(2), "completed")
	check("dialog: closed with the Fleet screen", not d.visible)
	fleet.show()
	yield(frames(2), "completed")
	# Prepare on an offer that changed meanwhile shows the new one and applies nothing.
	yield(pressSell(entry), "completed")
	CurrentGame.state.insurance = 0
	press(d.get_ok())
	yield(frames(20), "completed")
	check("dialog: Prepare on a changed offer shows the new one and applies nothing", d.visible and rowTexts(entry)[3] == money(entry._SSA_TEXT_ZERO, 0) and CurrentGame.state.garage[0].config.weaponSlot.main.type == "SYSTEM_MWG", rowTexts(entry))
	CurrentGame.state.insurance = 25000
	press(d.get_cancel())
	yield(frames(2), "completed")

func press(button):
	button.emit_signal("pressed")

# The settings screen: Shift+Click on an enabled Sell button, or its gamepad twin, opens it; B or Esc closes it and
# brings the Fleet screen back with the Sell button highlighted.
func settingsScreen(entry, other):
	var sell = entry.get_node("HBox/Sell")
	var click = InputEventMouseButton.new()
	click.button_index = BUTTON_LEFT
	click.pressed = true
	click.shift = true
	sell.emit_signal("gui_input", click)
	yield(frames(5), "completed")
	var screen = screens.get_node_or_null(entry._SSA_SETTINGS_NODE)
	check("settings: Shift+Click on Sell makes the screen", screen != null)
	if screen == null:
		return
	yield(frames(60), "completed")
	check("settings: shown, the Fleet screen hidden, no dialog", screen.visible and not fleet.visible and not shows(entry))
	var rowName = tr(settings.SETTINGS.minGain.label)
	check("settings: the minimum gain's row", screen._rows.has(rowName), screen._rows.keys())
	check("settings: the highlighted row's description", screen._description.text == tr(settings.SETTINGS.minGain.label + screen.DESCRIPTION_SUFFIX), screen._description.text)
	screen._onTuningChanged(null, rowName, 4000.0, "")
	check("settings: a change is stored", settings.getValue("minGain") == 4000.0 and CurrentGame.state.ui[settings.modId()].minGain == 4000.0)
	settings.setValue("minGain", 1000)
	var cancels = fleet.cancels
	yield(tapJoy(JOY_XBOX_B), "completed")
	yield(frames(30), "completed")
	check("gamepad: B brings the Fleet screen back, Sell highlighted", fleet.visible and sell.has_focus() and fleet.cancels == cancels, [fleet.visible, sell.has_focus()])
	yield(frames(60), "completed")
	check("settings: hidden again", not screen.visible)
	# The gamepad twin, on the other entry's Sell: PAD_BUTTON while PAD_MODIFIER is held.
	var otherSell = other.get_node("HBox/Sell")
	otherSell.grab_focus()
	yield(tapJoy(badge.PAD_BUTTON), "completed")
	yield(frames(5), "completed")
	check("gamepad: PAD_BUTTON alone on the highlighted Sell does nothing", not screen.visible and fleet.visible and not shows(other))
	yield(holdJoy(badge.PAD_MODIFIER, true), "completed")
	yield(tapJoy(badge.PAD_BUTTON), "completed")
	yield(holdJoy(badge.PAD_MODIFIER, false), "completed")
	yield(frames(60), "completed")
	check("gamepad: PAD_MODIFIER+PAD_BUTTON on the highlighted Sell opens the settings, nothing sold or offered", screen.visible and not fleet.visible and sold.empty() and not shows(other))
	yield(tap(escKey()), "completed")
	yield(frames(90), "completed")
	check("settings: Esc brings the Fleet screen back, that Sell highlighted", fleet.visible and not screen.visible and otherSell.has_focus())
	# A disabled Sell button (the ship flown's) opens nothing.
	other.current = true
	yield(frames(2), "completed")
	otherSell.emit_signal("gui_input", click)
	yield(frames(60), "completed")
	check("settings: Shift+Click on a disabled Sell opens nothing", otherSell.disabled and not screen.visible)
	other.current = false
	yield(frames(2), "completed")

# Prepare: the derelict prepared as by hand, the Fleet screen listing its ships again.
func prepare(entry):
	CurrentGame.logs = []
	CurrentGame.xp = []
	var before = CurrentGame.money
	yield(pressSell(entry), "completed")
	var d = dialogOf(entry)
	press(d.get_ok())
	yield(frames(20), "completed")
	var full = CurrentGame.state.garage[0]
	var cfg = full.config
	check("prepare: the dialog closes", not d.visible)
	check("prepare: the slots taken down to their cheapest item", cfg.weaponSlot.main.type == "SYSTEM_NONE" and cfg.propulsion.rcs == "SYSTEM_THRUSTER_NDSTR" and cfg.capacitor.capacity == 500.0 and cfg.turbine.power == 100.0 and cfg.autopilot.type == "SYSTEM_AUTOPILOT_NONE" and cfg.lidar.type == "SYSTEM_LIDAR_RADAR", cfg)
	check("prepare: the slots not worth it kept", cfg.propulsion.main == "SYSTEM_MAIN_ENGINE_K37" and cfg.fuel.capacity == 30000.0 and cfg.hud.type == "SYSTEM_HUD_TNTRL")
	check("prepare: one Fix click halves the damage", near(cfg.damage.reactor.a, 0.175) and near(cfg.damage["engine-main"].a, 0.175) and near(cfg.damage.Hud.a, 0.175), cfg.damage)
	check("prepare: a slot taken down clears its pieces' damage", near(cfg.damage.WeaponSlot.a, 0.0) and near(cfg.damage["thruster-3"].a, 0.0), [cfg.damage.WeaponSlot, cfg.damage["thruster-3"]])
	check("prepare: in maintenance for the time shown", near(full.get("maintaineceUntil", 0), NOW + 79 * H), full.get("maintaineceUntil"))
	check("prepare: the refunds paid, the clicks paid by the insurance", near(CurrentGame.money - before, 187155) and near(CurrentGame.state.insurance, 17000), [CurrentGame.money - before, CurrentGame.state.insurance])
	check("prepare: logged as the Repairs and Equipment screens log, the mechanics' XP for each click", repairsAndUpgrades() == [8, 6] and CurrentGame.xp.size() == 4, [repairsAndUpgrades(), CurrentGame.xp])
	check("prepare: the old instance dropped, the Fleet screen lists its ships again", not CurrentGame.ownedShipInstances.has("hash-K37-DER") and fleet.added >= 1)
	# The prepared ship's entry: in maintenance, Sell disabled; once it is over, nothing left to offer.
	var prepared = makeEntry(full)
	yield(frames(10), "completed")
	check("prepare: in maintenance, Sell disabled", prepared.get_node("HBox/Sell").disabled)
	CurrentGame.time = NOW + 80 * H
	prepared.checkCurrentAndOwned()
	yield(pressSell(prepared), "completed")
	check("prepare: once maintenance is over, Sell shows the game's confirmation", not shows(prepared) and gameConfirms(prepared))
	CurrentGame.time = NOW

# The dialog's Sell, too little cash, a high minimum gain, and an offer with no maintenance.
func others():
	CurrentGame.state.garage.append(derelict("K37-THREE"))
	var entry = makeEntry(CurrentGame.state.garage.back())
	yield(frames(10), "completed")
	yield(pressSell(entry), "completed")
	check("others: the dialog on another derelict", shows(entry))
	if shows(entry):
		entry._ssaSellButton.emit_signal("pressed")
		yield(frames(5), "completed")
		check("others: the dialog's Sell sells the ship as it is, and closes", sold.size() == 1 and sold[0] == entry.ship and not dialogOf(entry).visible, sold)
	CurrentGame.state.insurance = 0
	CurrentGame.money = 2000
	CurrentGame.state.garage.append(derelict("K37-POOR"))
	var poor = makeEntry(CurrentGame.state.garage.back())
	yield(frames(10), "completed")
	yield(pressSell(poor), "completed")
	check("others: no insurance and 2,000 E$, only the click cash covers", shows(poor) and near(poor._ssaOffer.plan.cashCost, 1500) and rowTexts(poor)[3] == money(poor._SSA_TEXT_ZERO, 0) and rowTexts(poor)[5] == money(poor._SSA_TEXT_MINUS, 1500), rowTexts(poor) if shows(poor) else null)
	CurrentGame.money = 1000000
	CurrentGame.state.insurance = 25000
	settings.setValue("minGain", settings.SETTINGS.minGain.max)
	CurrentGame.state.garage.append(derelict("K37-HIGH"))
	var high = makeEntry(CurrentGame.state.garage.back())
	yield(frames(10), "completed")
	yield(pressSell(high), "completed")
	check("others: below the minimum gain, the game's confirmation", not shows(high) and gameConfirms(high))
	settings.setValue("minGain", 1000)
	# Undamaged: the slots taken down take no maintenance (getSlotTime counts damaged pieces only), so no warning.
	CurrentGame.state.garage.append(derelict("K37-NEW", false))
	var fresh = makeEntry(CurrentGame.state.garage.back())
	yield(frames(10), "completed")
	yield(pressSell(fresh), "completed")
	check("others: an offer with no maintenance has no warning", shows(fresh) and not fresh._ssaWarning.visible and near(fresh._ssaOffer.plan.time, 0))
	if shows(fresh):
		yield(idle(4), "completed")
		check("others: without the warning, the line at the top still on two lines", fresh._ssaIntro.get_line_count() == 2, fresh._ssaIntro.get_line_count())
		press(dialogOf(fresh).get_cancel())
		yield(frames(2), "completed")

# The game's bindings (its project.godot): ui_cancel is Esc, pause is Esc too; B is Godot's own ui_cancel button.
func bindGameKeys():
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
	for binding in [["ui_cancel", escKey()], ["pause", escKey()]]:
		if not InputMap.action_has_event(binding[0], binding[1]):
			InputMap.action_add_event(binding[0], binding[1])

func idle(count = 2):
	for i in count:
		yield(get_tree(), "idle_frame")

# A press and release of a key, as Input delivers a player's, in the idle part of a frame.
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

func joyButton(index):
	var event = InputEventJoypadButton.new()
	event.button_index = index
	return event

# A press and release of a gamepad button (JOY_*), then a frame: Input hands parsed events on at the next one.
func tapJoy(index):
	yield(tap(joyButton(index)), "completed")
	yield(get_tree(), "idle_frame")

# A gamepad button pressed, or released, and left so (Input.is_joy_button_pressed follows).
func holdJoy(index, pressed):
	yield(get_tree(), "idle_frame")
	var event = joyButton(index)
	event.pressed = pressed
	Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")
