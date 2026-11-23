extends "res://harness/suite.gd"

# ShipRepairAdvisor: a row at the bottom of the Repairs screen with the Repair button, which brings every damaged system
# up to the target condition the cheapest way, a table of that target and what the button costs and takes, and the Park
# button, which puts every slot of the Equipment screen on its cheapest piece and every system at the mod's park
# target, after a confirmation. Both press only the game's own buttons, and only those the game has enabled.
# Shift+Click on Repair, or its gamepad twin, opens the settings (the target condition).
#
# First the estimates the settings screen shows (Settings.gd), against the suite's own working of their formulas, and
# the plans alone (Advisor.gd, from plain data, its systems built by the Repairs screen's rules as Code.gd predicts
# them): Repair's (Fixes, Fixes then Replace, Replace, beyond repair, the repair limit, damage no repair clears, money
# for some Replaces, who pays, the order of the presses) and Park's (the Fixes before a trade-in, the order of the
# purchases, what is missing, an out-and-back, the repairs to its target).
#
# Then the station: the game's Repairs screen (enceladus/Repairs.tscn, Repairs.gd) and its rows
# (SystemShipRepairUI.tscn, SystemShipRepairUI.gd) among the station's screens (the game's HidingMarginContainer.gd).
# Repair on harness/repairs_ship.gd, a ship of five systems; Park on harness/repairs_park_ship.gd, a ship built from its
# config (also the trial ship's scene in the Shipyard stub), beside a stub of the Equipment screen
# (harness/repairs_equipment.gd, the game's pricing and buy, in groups of harness/repairs_group.gd holding the game's
# SystemShipUpgradeUI.gd items) and of the Fleet screen (harness/repairs_fleet.gd, its colours for money). The mod's
# texts, node names and limits are read from the mod, the gamepad twin's buttons from its Badge.gd. Keys and buttons are
# sent as real input events, with the game's bindings.

const MOD = "ShipRepairAdvisor"
const REPAIRS = "res://enceladus/Repairs.tscn"
const GAME_SCRIPT = "res://enceladus/Repairs.gd"
const ITEM = "res://enceladus/SystemShipUpgradeUI.tscn"
const SHIP = "res://harness/repairs_ship.gd"
const PARK_SHIP = "res://harness/repairs_park_ship.gd"
const EQUIPMENT = "res://harness/repairs_equipment.gd"
const GROUP = "res://harness/repairs_group.gd"
const FLEET = "res://harness/repairs_fleet.gd"
const MODEL = "PARKTEST" # the Park ship's model in the Shipyard stub
const H = 3600.0
# The station's Repairs screen (enceladus/Enceladus.tscn): its least width, its size flags and its frame.
const STATION_WIDTH = 1024
const STATION_PANEL = "res://menu/PanelWithHugeShadow.tres"
# The game's highest repair limit (CurrentGame.gd getRepairLimit), which is also where the rows stop offering Replace
# (SystemShipRepairUI.gd isReplaceable).
const GAME_REPAIR_CAP = 99.5
# The target condition the suite's Repair runs work towards first, and the one it sets later.
const TARGET = 75
const HIGHER_TARGET = 95
const SLIDER_TARGET = 90
const WHITE = Color(1, 1, 1, 1)

var advisor # the mod's Advisor.gd
var settings # the mod's shared settings
var settingsScript # the mod's Settings.gd
var badgeScript # the mod's Badge.gd
var screens
var repairs
var ship

func run():
	bindGameKeys()
	if not hasMod(MOD):
		yield(control(), "completed")
		return
	advisor = load("res://%s/Advisor.gd" % MOD)
	settingsScript = load("res://%s/Settings.gd" % MOD)
	settings = settingsScript.shared()
	badgeScript = load("res://%s/Badge.gd" % MOD)
	estimates()
	advice()
	parkAdvice()
	yield(repairButton(), "completed")
	yield(freeStation(), "completed")
	yield(parkButton(), "completed")
	yield(freeStation(), "completed")

# --- The estimates ---

func roundHalfUp(value, places):
	var scale = pow(10, places)
	return floor(value * scale + 0.5 + settingsScript.ESTIMATE_ROUNDING_GUARD) / scale

# For every condition the setting can take: the failure rate, the worst damage's square, and the degradation, the middle
# of the three damages' average loss and the worst case (Settings.gd's header), each rounded half up.
func estimates():
	var S = settingsScript
	var setting = S.SETTINGS.target
	var wrong = []
	var between = true
	var distinct = true
	for c in range(int(setting.min), int(setting.max) + 1):
		var d = (100.0 - c) / 100.0
		var average = roundHalfUp(100.0 * (S.ESTIMATE_LOSS_LINEAR * d + S.ESTIMATE_LOSS_SQUARE * d * d), S.LOSS_DECIMALS)
		var worst = roundHalfUp(100.0 * d, S.LOSS_DECIMALS)
		var failure = roundHalfUp(100.0 * d * d, S.FAILURE_DECIMALS)
		var loss = roundHalfUp((average + worst) / 2.0, S.LOSS_DECIMALS)
		if abs(S.failureRate(c) - failure) > 0.0001 or abs(S.performanceLoss(c) - loss) > 0.0001:
			wrong.append([c, S.failureRate(c), failure, S.performanceLoss(c), loss])
		between = between and S.performanceLoss(c) >= average - 0.0001 and S.performanceLoss(c) <= worst + 0.0001
		if c < setting.max and abs(S.failureRate(c) - S.failureRate(c + 1)) < 0.0001:
			distinct = false
	check("estimates: the failure rate and the degradation at every condition the setting can take", wrong.empty(), wrong)
	check("estimates: the degradation between the average loss and the worst case", between)
	check("estimates: neighbouring conditions have different failure rates", distinct)
	check("estimates: none at 100 %", S.failureRate(100) == 0.0 and S.performanceLoss(100) == 0.0, [S.failureRate(100), S.performanceLoss(100)])

# --- The plans ---

func value(p, s):
	var pf = pow(s / 100.0, 2)
	if pf < 1:
		pf *= 0.8
	return p * pf

# A system as Code.gd gives it to the plan: worst damage `w` (of its capacity), price `p`, fix price `f`, the crew's
# repair limit `limit`, a share of the condition no repair clears `stuck`; each Fix click halves the damage, the row's
# rules (SystemShipRepairUI.gd shouldBeFixed, isReplaceable, replacementPrice, isFubar) decide each step.
func system(w, p, f, limit = GAME_REPAIR_CAP, stuck = 0.0, fixTime = 4.0, replaceTime = 1.0):
	var steps = []
	var fubar = w > 1.5
	for k in 21:
		var wk = w * pow(0.5, k)
		var s = clamp(100.0 - 100.0 * max(wk, stuck), 0.0, 100.0)
		var rp = max(0.0, p - value(p, s))
		var fub = wk > 1.5
		var fix = (not fub) and s < limit and rp > f
		var rep = s < GAME_REPAIR_CAP and (fub or p >= 0)
		steps.append({"status": s, "fix": fix, "replace": rep, "replacePrice": rp, "value": value(p, s)})
		if not fix:
			break
	return {
		"steps": steps, "fixPrice": float(f), "fixTime": fixTime * H, "replaceTime": replaceTime * H,
		"unfixable": fubar, "replaced": 100.0 * (1.0 - stuck),
	}

func data(systems, target = 75.0, money = 1e9, insurance = 0.0):
	return {"target": target, "money": money, "insurance": insurance, "systems": systems}

func near(a, b, eps = 0.5):
	return abs(float(a) - float(b)) <= eps

func advice():
	# Fix alone reaches the target: 40 % -> 70 -> 85, two clicks, cheaper than any Replace.
	var p = advisor.plan(data({"a": system(0.6, 3000, 500)}))
	check("plan: Fix alone, two clicks", p.systems.a.fixes == 2 and not p.systems.a.replace and near(p.cost, 1000) and p.short == 0, p)
	check("plan: their maintenance time", near(p.time, 8 * H), p.time)
	# Fixes then Replace cheaper than Fixes alone (target 95: five clicks, 10,000, against two and a Replace, 9,195).
	p = advisor.plan(data({"a": system(0.9, 10000, 2000)}, 95.0))
	check("plan: Fixes then Replace where that costs less", p.systems.a.fixes == 2 and p.systems.a.replace and near(p.cost, 9195) and p.systems.a.phase == advisor.PHASE_PAID_REPLACE, p)
	# Replace now: 72 %, the repair limit at 71 stops Fix.
	p = advisor.plan(data({"a": system(0.28, 3000, 500, 71.0)}))
	check("plan: Replace now where the repair limit stops Fix", p.systems.a.fixes == 0 and p.systems.a.replace and near(p.cost, 3000 - value(3000, 72)), p)
	p = advisor.plan(data({"a": system(1.6, 3000, 500)}, 75.0, 0.0, 0.0))
	check("plan: beyond repair, Replace without money, the cash ending below zero", p.systems.a.replace and p.systems.a.phase == advisor.PHASE_UNFIXABLE_REPLACE and near(p.cost, 3000) and near(p.cashAfter, -3000), p)
	p = advisor.plan(data({"a": system(0.28, 3000, 500, 71.0)}, 75.0, 0.0, 0.0))
	check("plan: the repair limit below the target and no money for Replace, nothing to do, one short", advisor.isEmpty(p) and p.short == 1, p)
	p = advisor.plan(data({"a": system(0.5, 3000, 500, 71.0)}, 80.0, 0.0, 0.0))
	check("plan: no money for Replace, Fixes as far as they go", p.systems.a.fixes == 1 and not p.systems.a.replace and p.short == 1 and not p.systems.a.reaches, p)
	p = advisor.plan(data({"a": system(0.1, 3000, 500, GAME_REPAIR_CAP, 0.4)}))
	check("plan: damage no repair clears keeps it below the target, nothing to do", advisor.isEmpty(p) and p.short == 1, p)
	p = advisor.plan(data({"a": system(0.28, 3000, 500, 71.0), "b": system(0.28, 10000, 2000, 71.0)}, 75.0, 2000.0, 0.0))
	check("plan: money for one of two Replaces, the cheaper kept", p.systems.has("a") and p.systems.a.replace and not p.systems.has("b") and p.short == 1 and p.replaces == 1, p)
	p = advisor.plan(data({"a": system(0.28, 3000, 500, 71.0), "b": system(0.28, 10000, 2000, 71.0)}, 75.0, 1000.0, 7000.0))
	check("plan: cash and insurance together pay both", p.replaces == 2 and p.short == 0, p)
	var one = {"a": system(0.6, 3000, 500)}
	p = advisor.plan(data(one, 75.0, 5000.0, 2000.0))
	check("plan: the insurance pays first, all of it", near(p.insuranceCost, 1000) and near(p.cashCost, 0) and near(p.cashAfter, 5000), p)
	p = advisor.plan(data(one, 75.0, 5000.0, 300.0))
	check("plan: the insurance pays what it holds, the cash the rest", near(p.insuranceCost, 300) and near(p.cashCost, 700), p)
	p = advisor.plan(data(one, 75.0, 5000.0, 0.0))
	check("plan: no insurance, the cash pays", near(p.insuranceCost, 0) and near(p.cashCost, 1000), p)
	p = advisor.plan(data(one, 75.0, 5000.0, -100.0))
	check("plan: an insurance below zero paid from the cash with the repairs", near(p.insuranceCost, 0) and near(p.cashCost, 1100), p)
	p = advisor.plan(data(one, 75.0, 200.0, 0.0))
	check("plan: Fixes need no money, the cash ending below zero", p.systems.a.fixes == 2 and near(p.cashAfter, -800), p)
	p = advisor.plan(data({"a": system(0.2, 3000, 500)}))
	check("plan: nothing to do", advisor.isEmpty(p) and p.short == 0 and p.repaired == 0, p)
	# The presses: the paid Replaces' systems first, their Fixes before their Replace; then beyond repair; then Fixes alone.
	p = advisor.plan(data({"paid": system(0.9, 10000, 2000), "fubar": system(1.6, 3000, 500), "plain": system(0.6, 3000, 500)}, 95.0))
	var pr = advisor.presses(p)
	check("presses: a paid Replace's Fixes first", pr.size() == 1 and pr.get("paid") == "fix", [pr, p])
	p.systems.paid.fixes = 0
	pr = advisor.presses(p)
	check("presses: then its Replace", pr.size() == 1 and pr.get("paid") == "replace", pr)
	p.systems.erase("paid")
	pr = advisor.presses(p)
	check("presses: then the Replaces beyond repair", pr.size() == 1 and pr.get("fubar") == "replace", pr)
	p.systems.erase("fubar")
	pr = advisor.presses(p)
	check("presses: the Fixes alone last", pr.size() == 1 and pr.get("plain") == "fix", pr)
	p = advisor.plan(data({"a": system(0.6, 3000, 500)}, 100.0))
	check("plan: at 100 %, which Fix can't reach, Replace", p.systems.a.replace, p)
	p = advisor.plan(data({"a": system(0.35, 3000, 2000)}, 90.0))
	check("plan: Fix disabled once Replace costs no more, Replace instead", p.systems.a.replace, p)

func slot(id, net, time = 0.0, members = [], back = null):
	var entry = {"slot": id, "net": float(net), "time": float(time), "members": members}
	if back != null:
		entry.back = true
		entry.backNet = float(back)
	return entry

func parkData(slots = [], trades = {}, repair = {}, money = 1e9, insurance = 0.0, unreachable = []):
	return {"money": money, "insurance": insurance, "slots": slots, "trades": trades,
			"repair": {"target": 100.0, "money": 0.0, "insurance": 0.0, "systems": repair}, "unreachable": unreachable}

func parkAdvice():
	# A 200,000 E$ laser at 60 % trades in for 57,600; one Fix (30,000) takes it to 80 % (102,400), a second adds only
	# 27,200 for another 30,000: one Fix, and the refund grows by its gain.
	var laser = system(0.4, 200000, 30000)
	var p = advisor.park(parkData([slot("hp", 1000 - 57600, H, ["laser"])], {"laser": laser}))
	check("park plan: one Fix before the trade-in, where it pays", p.fixes.get("laser") == 1, p.fixes)
	check("park plan: the refund grows by the Fix's gain", near(p.cashCost, 30000 + 1000 - 102400), p.cashCost)
	check("park plan: the time of the Fix and the purchase", near(p.time, 4 * H + H), p.time)
	p = advisor.park(parkData([slot("hp", 1000 - 57600, 0, ["laser"])], {"laser": system(0.4, 200000, 50000)}))
	check("park plan: no Fix where it costs more than it adds", p.fixes.empty() and near(p.cashCost, 1000 - 57600), p)
	p = advisor.park(parkData([slot("hp", -57600, 0, ["laser"])], {"laser": system(0.4, 200000, 2000)}))
	var best = 0
	var bestGain = 0.0
	var steps = system(0.4, 200000, 2000).steps
	for k in range(1, steps.size()):
		var gain = steps[k].value - steps[0].value - k * 2000.0
		if gain > bestGain + advisor.PRECISION:
			best = k
			bestGain = gain
	check("park plan: the number of Fixes with the most gained", p.fixes.get("laser") == best and best > 1, [p.fixes, best])
	var order = [slot("s1", 5000), slot("s2", -3000), slot("s3", 1000), slot("s4", -100)]
	p = advisor.park(parkData(order))
	check("park plan: the refunds first, in the screen's order, then the costs, cheapest first", p.purchases == ["s2", "s4", "s3", "s1"], p.purchases)
	check("park plan: nothing missing", near(p.needed, 0), p.needed)
	check("park plan: the cash", near(p.cashCost, 5000 - 3000 + 1000 - 100), p.cashCost)
	p = advisor.park(parkData(order, {}, {}, 0.0))
	check("park plan: too little cash, what is missing when the dearest cost's turn comes", near(p.needed, 5000 - (3000 + 100 - 1000)), p.needed)
	p = advisor.park(parkData([slot("rcs", 700, H, [], -800)], {}, {}, 700.0))
	check("park plan: out and back, the second purchase a refund right after the first", p.purchases == ["rcs"] and near(p.cashCost, -100) and near(p.needed, 0), p)
	p = advisor.park(parkData([slot("rcs", 700, H, [], -800)], {}, {}, 600.0))
	check("park plan: out and back needs the first purchase's cash", near(p.needed, 100), p.needed)
	var repair = {"ok": system(0.6, 3000, 500), "stuck": system(0.1, 3000, 500, GAME_REPAIR_CAP, 0.4)}
	p = advisor.park(parkData([], {}, repair, 1e9, 0.0, ["reactor"]))
	check("park plan: a repair to 100 % replaces", p.repair.systems.has("ok") and p.repair.systems.ok.replace, p.repair)
	check("park plan: a system no way brings there left alone and listed, with those given", not p.repair.systems.has("stuck") and p.unreachable.has("stuck") and p.unreachable.has("reactor"), p.unreachable)
	var dear = {"a": system(0.28, 3000, 500, 71.0)}
	p = advisor.park(parkData([], {}, dear, 0.0, 0.0))
	var price = 3000 - value(3000, 72)
	check("park plan: a paid Replace kept without the money", p.repair.systems.has("a") and p.repair.systems.a.replace, p.repair)
	check("park plan: what is missing at it", near(p.needed, price), [p.needed, price])
	p = advisor.park(parkData([], {}, dear, 0.0, price))
	check("park plan: the insurance covers it", near(p.needed, 0) and near(p.insuranceCost, price) and near(p.cashCost, 0), p)
	p = advisor.park(parkData([slot("hp", -5000)], {}, dear, 0.0, 0.0))
	check("park plan: a refund first pays for it", near(p.needed, 0) and near(p.cashCost, -5000 + price), p)
	p = advisor.park(parkData([slot("hp", 1000 - 57600, 0, ["laser"])], {"laser": laser}, {}, 0.0, 10000.0))
	check("park plan: Fixes from the insurance first, purchases from the cash", near(p.insuranceCost, 10000) and near(p.cashCost, 20000 + 1000 - 102400), p)
	p = advisor.park(parkData())
	check("park plan: nothing to do", advisor.isParkEmpty(p) and near(p.time, 0) and near(p.cashCost, 0), p)
	p = advisor.park(parkData([], {}, {}, 1e9, 0.0, ["reactor"]))
	check("park plan: only systems no way brings there is nothing to do", advisor.isParkEmpty(p) and p.unreachable == ["reactor"], p)
	p = advisor.plan(data({"a": system(0.28, 3000, 500, 71.0)}, 75.0, 0.0, 0.0))
	check("plan: Repair's own plan still drops a Replace it can't pay, and lists nothing", advisor.isEmpty(p) and p.unreachable.empty(), p)

# --- The station ---

# The station's screens with the Repairs screen among them, as enceladus/Enceladus.tscn has it (shown later).
func makeStation():
	screens = MarginContainer.new()
	screens.set_script(load("res://enceladus/HidingMarginContainer.gd"))
	screens.rect_size = get_viewport().get_visible_rect().size
	add_child(screens)
	repairs = load(REPAIRS).instance()
	repairs.rect_min_size = Vector2(STATION_WIDTH, 0)
	repairs.size_flags_horizontal = Control.SIZE_SHRINK_END
	repairs.visible = false
	repairs.add_stylebox_override("panel", load(STATION_PANEL))
	screens.add_child(repairs)

func freeStation():
	if screens != null:
		screens.queue_free()
	if is_instance_valid(ship):
		ship.queue_free()
	screens = null
	repairs = null
	ship = null
	CurrentGame.playerShip = null
	yield(frames(2), "completed")

# The Repair ship: a thruster at 40 %, a HUD at 70 %, a reactor beyond repair, a laser at 90 % and an arm at 60 % from
# what no repair clears.
func repairShip():
	ship = load(SHIP).new()
	add_child(ship)
	ship.addPart("thruster", "SYSTEM_THRUSTER", 3000, 500, 4, 1, {"wear": [0.6 * 3600, 3600], "bent": [0.1 * 3600, 3600]})
	ship.addPart("hud", "SYSTEM_HUD", 6000, 500, 4, 1, {"sensors": [0.3 * 40000, 40000]})
	ship.addPart("reactor", "SYSTEM_REACTOR", 80000, 5000, 48, 48, {"leak": [1.6 * 9600, 9600]})
	ship.addPart("laser", "SYSTEM_LASER", 150000, 30000, 12, 1, {"wear": [0.1 * 18000, 18000]})
	ship.addPart("arm", "SYSTEM_SALVAGE_ARM", 74000, 20000, 8, 2, {"wear": [0.1 * 9000, 9000]}, 0.4)
	CurrentGame.playerShip = ship
	CurrentGame.mechanics = 1
	CurrentGame.repairLimit = GAME_REPAIR_CAP
	CurrentGame.money = 100000
	CurrentGame.state.insurance = 50000
	CurrentGame.state.ship = {"config": {}}
	CurrentGame.time = 0
	CurrentGame.xp = []

func values() -> Array:
	var out = []
	for v in repairs._sraValues:
		out.append(v.text)
	return out

func money(amount):
	return tr(repairs._SRA_MONEY) % CurrentGame.formatThousands(amount)

func percent(value):
	return tr(repairs._SRA_PERCENT) % str(value)

func time(seconds):
	return Tool.readableTimeSpan(seconds, true)

func waitDone(limit = 3000):
	for i in limit:
		if not repairs._sraRunning:
			break
		yield(get_tree(), "physics_frame")
	yield(frames(4), "completed")

# How far the frame of `button` ends from the panel's frame at the right and at the bottom (each frame drawn its
# stylebox's expand margin outside its rect).
func gaps(button) -> Array:
	var style = repairs.get_stylebox("panel")
	var expandRight = style.get("expand_margin_right") if style.get("expand_margin_right") != null else 0.0
	var expandBottom = style.get("expand_margin_bottom") if style.get("expand_margin_bottom") != null else 0.0
	var buttonRect = button.get_global_rect()
	var panelRect = repairs.get_global_rect()
	return [panelRect.end.x + expandRight - buttonRect.end.x, panelRect.end.y + expandBottom - buttonRect.end.y]

# Without the mod: the game's screen, its rows, and nothing at its bottom.
func control():
	repairShip()
	makeStation()
	repairs.show()
	yield(frames(12), "completed")
	var rows = []
	for row in repairs.systemsBox.get_children():
		if row.has_method("shouldBeFixed"):
			rows.append(row)
	var scene = load(REPAIRS).instance()
	var margin = scene.get_node("MarginContainer").get_constant("margin_bottom")
	scene.free()
	check("control: the game's rows, one per system", rows.size() == ship.parts.size(), rows.size())
	check("control: nothing of the mod at the bottom of the screen, the list's margin as the scene sets it", repairs.get_node_or_null(MOD) == null and not repairs.has_method("_sraRepair") and repairs.get_node("MarginContainer").get_constant("margin_bottom") == margin)
	yield(freeStation(), "completed")

# The Repair button: the row, its table, its layout and badge, a run to the target, the settings and their screen, a
# higher target, the cash's warning colour, and the gamepad twin.
func repairButton():
	repairShip()
	makeStation()
	check("the screen gets the extension, its script keeping the game's path", repairs.has_method("_sraRepair") and repairs.get_script().resource_path == GAME_SCRIPT)
	repairs.show()
	yield(frames(12), "completed")
	var rows = repairs._sraRows()
	check("a row per system", rows.size() == ship.parts.size(), rows.size())
	if rows.empty():
		return
	var tableNode = repairs._sraTargetValue.get_parent()
	var setting = settingsScript.SETTINGS.target
	check("the table's first line, the target condition named as the setting, at its default for a save without the mod's entry", tableNode.get_child(0).text == setting.label and repairs._sraTargetValue.text == percent(int(setting.default)), repairs._sraTargetValue.text)
	settings.setValue("target", TARGET)
	yield(frames(2), "completed")
	check("the target's value follows the setting", repairs._sraTargetValue.text == percent(TARGET), repairs._sraTargetValue.text)
	check("the table: what the insurance pays, what the cash pays, both, the maintenance time", values() == [money(50000), money(31500), money(81500), time(60 * H)], values())
	var names = []
	for i in range(2, tableNode.get_child_count(), 2):
		names.append(tableNode.get_child(i).text)
	check("the table's names, in order", names == repairs._SRA_TABLE, names)
	var smallFont = load(badgeScript.SMALL_FONT_THEME).get_font("font", "Label")
	check("the table in the badges' small font", repairs._sraValues[0].get_font("font") == smallFont and repairs._sraTargetValue.get_font("font") == smallFont)
	check("the values aligned right", repairs._sraValues[0].align == Label.ALIGN_RIGHT and repairs._sraTargetValue.align == Label.ALIGN_RIGHT)
	check("the cash in the normal colour while it stays above zero", repairs._sraValues[1].modulate == WHITE)
	check("Repair enabled, named by the mod's text", not repairs._sraButton.disabled and repairs._sraButton.text == repairs._SRA_REPAIR and tr(repairs._SRA_REPAIR) != repairs._SRA_REPAIR)
	check("Park disabled without the Equipment screen", repairs._sraParkButton.disabled)
	# The layout: the row at the bottom of the panel, as wide as the header, the list ending above it.
	var row = repairs._sraRow
	var list = repairs.get_node("MarginContainer")
	var bottom = repairs.rect_size.y - repairs.get_stylebox("panel").get_margin(MARGIN_BOTTOM)
	check("the row at the bottom of the panel", near(row.rect_position.y + row.rect_size.y, bottom, 1.0), [row.rect_position.y + row.rect_size.y, bottom])
	check("the list of rows ending where the row begins", list.get_constant("margin_bottom") == int(ceil(row.get_combined_minimum_size().y)), [list.get_constant("margin_bottom"), row.get_combined_minimum_size().y])
	check("the row as wide as the header", near(row.rect_size.x, repairs.get_node("HeaderWithMoney").rect_size.x, 1.0), [row.rect_size.x, repairs.get_node("HeaderWithMoney").rect_size.x])
	var parkGaps = gaps(repairs._sraParkButton)
	check("Park, which ends the row, as far from the panel's frame at the bottom as at the right", near(parkGaps[0], parkGaps[1], 1.0) and parkGaps[1] > 0, parkGaps)
	# The Shift badge inside Repair.
	var badge = repairs._sraShiftBadge
	var repairRect = repairs._sraButton.get_global_rect()
	var badgeRect = badge.get_global_rect() if badge != null else Rect2()
	var inset = repairs._sraButton.get_stylebox("normal").get_margin(MARGIN_LEFT)
	check("the Shift badge inside Repair, at its left as far in as the button keeps its text, centred top to bottom", badge != null and badge.get_parent() == repairs._sraButton and shiftBadge(repairs._sraButton) == badge and near(badgeRect.position.x - repairRect.position.x, inset, 1.0) and near(badgeRect.get_center().y, repairRect.get_center().y, 1.0) and repairRect.encloses(badgeRect), [badgeRect, repairRect, inset])
	check("Repair makes room for it, its text at the right, never under the badge", repairs._sraButton.align == Button.ALIGN_RIGHT and near(repairRect.size.x, repairs._sraButton.get_minimum_size().x + badge.get_combined_minimum_size().x + inset, 1.0), [repairRect.size.x, repairs._sraButton.get_minimum_size().x, badge.get_combined_minimum_size().x, inset])
	check("the badge lets the mouse through to Repair", badge.mouse_filter == Control.MOUSE_FILTER_PASS)
	check("the badge wears Repair's frame and font colour", badge.get_stylebox("panel") == repairs._sraButton.get_stylebox("normal") and badge._label.get_color("font_color") == repairs._sraButton.get_color("font_color"))
	var tableRect = tableNode.get_global_rect()
	var separation = tableNode.get_parent().get_constant("separation")
	check("the table right before Repair, at its own width", abs(tableRect.end.x + separation - repairRect.position.x) <= 1.0 and tableRect.position.x > repairs.get_global_rect().position.x + 100, [tableRect, repairRect, separation])
	var last = rows[rows.size() - 1]
	check("D-pad: down from the last row's buttons to Repair", last.fixButton.focus_neighbour_bottom == repairs._sraButton.get_path() and last.replaceButton.focus_neighbour_bottom == repairs._sraButton.get_path())
	check("D-pad: up from Repair to the last row's Fix", repairs._sraButton.focus_neighbour_top == last.fixButton.get_path())
	# The badge's tooltip, at the bottom of the screen, goes above the badge.
	var tips = repairs._sraTooltips
	check("the row's own tooltip node shows the badge's tooltip", tips != null and badgeTip(repairs._sraButton, tips) == tr(repairs._SRA_SETTINGS_TOOLTIP) % [OS.get_scancode_string(KEY_SHIFT), settings.modName()] and repairs._sraButton.hint_tooltip == "", badgeTip(repairs._sraButton, tips))
	if tips != null:
		tips.showTooltip(badge)
		repairs.set_process(true)
		yield(frames(5), "completed")
		var tipTop = tips.tooltipPosition.position.y
		var tipHeight = tips.tooltipContainer.rect_size.y
		var badgeTop = badge.get_global_transform_with_canvas().origin.y
		check("the tooltip inside the screen", tipTop >= 0 and tipTop + tipHeight <= get_viewport().get_visible_rect().size.y + 0.5, [tipTop, tipHeight])
		check("the tooltip above the badge", tipTop + tipHeight <= badgeTop + 0.5, [tipTop, tipHeight, badgeTop])
		tips.hideTooltip(badge)
		yield(frames(2), "completed")
		check("once hidden, its placing stops", not repairs.is_processing())
		shiftBadgeTipChecks("tooltip", repairs._sraButton, last.fixButton, tips, tr(repairs._SRA_SETTINGS_TOOLTIP) % [OS.get_scancode_string(KEY_SHIFT), settings.modName()], tr(repairs._SRA_SETTINGS_TOOLTIP_PAD) % [badgeScript.PAD_BUTTON_NAME, badgeScript.PAD_MODIFIER_NAME, settings.modName()])
	# Repair: the thruster and the HUD fixed to the target, the reactor replaced, the laser above it and the arm, held back
	# by what no repair clears, left alone; the insurance first, the presses each giving the mechanics their XP.
	repairs._sraButton.emit_signal("pressed")
	check("Repair works, disabling both buttons", repairs._sraRunning and repairs._sraButton.disabled and repairs._sraParkButton.disabled)
	yield(waitDone(), "completed")
	check("Repair done", not repairs._sraRunning)
	check("the thruster fixed past the target", near(ship.status("thruster"), 85, 0.01), ship.status("thruster"))
	check("the HUD fixed past the target", near(ship.status("hud"), 85, 0.01), ship.status("hud"))
	check("the reactor, beyond repair, replaced", near(ship.status("reactor"), 100, 0.01), ship.status("reactor"))
	check("the laser, above the target, untouched", near(ship.status("laser"), 90, 0.01), ship.status("laser"))
	check("the arm, held below it by what no repair clears, untouched", near(ship.status("arm"), 60, 0.01), ship.status("arm"))
	check("the cash and the insurance as the table said", near(CurrentGame.money, 100000 - 31500) and near(CurrentGame.getInsurance(), 0), [CurrentGame.money, CurrentGame.getInsurance()])
	check("the maintenance as the table said", near(CurrentGame.state.ship.get("maintaineceUntil", 0), 60 * H), CurrentGame.state.ship.get("maintaineceUntil", 0))
	check("the mechanics' XP for each press", CurrentGame.xp.size() == 4, CurrentGame.xp.size())
	check("the table at zero, Repair disabled", values() == [money(0), money(0), money(0), time(0)] and repairs._sraButton.disabled, values())
	# Shift+Click on the disabled button opens the settings in the screen's place.
	for pressed in [true, false]:
		var ev = InputEventMouseButton.new()
		ev.pressed = pressed
		ev.button_index = BUTTON_LEFT
		ev.shift = true
		ev.position = badge.get_global_rect().get_center()
		ev.global_position = ev.position
		get_tree().input_event(ev)
	yield(frames(45), "completed")
	var screen = repairs._sraSettingsScreen
	check("Shift+Click on the badge of the disabled Repair opens the settings in the screen's place", screen != null and screen.visible and not repairs.visible, screen)
	if screen == null:
		return
	check("the settings titled as the screen", screen.get_node("VB/HeaderWithMoney/MarketLabel").text == repairs.get_node(repairs._SRA_HEADER_TITLE).text)
	var group = screen._items.get_child(0)
	check("the settings' group has no title", not group.get_node("Label").visible)
	var sliderRow = null
	for child in group.get_children():
		if "tuningItem" in child:
			sliderRow = child
	var failureLine = screen._failureValue.get_parent() if screen._failureValue != null else null
	var lossLine = screen._lossValue.get_parent() if screen._lossValue != null else null
	check("the estimates' rows right under the slider", sliderRow != null and failureLine != null and lossLine != null and failureLine.get_index() == sliderRow.get_index() + 1 and lossLine.get_index() == sliderRow.get_index() + 2)
	if sliderRow == null or failureLine == null or lossLine == null:
		return
	check("their names and unit", failureLine.get_node("Name").text == tr(screen.FAILURE_RATE) and lossLine.get_node("Name").text == tr(screen.PERFORMANCE_LOSS) and failureLine.get_node("Unit").text == setting.unit and lossLine.get_node("Unit").text == setting.unit, failureLine.get_node("Name").text)
	check("they take no focus, their reset buttons unseen", failureLine.get_node("Name").focus_mode == Control.FOCUS_NONE and failureLine.get_node("Reset").focus_mode == Control.FOCUS_NONE and lossLine.get_node("Reset").focus_mode == Control.FOCUS_NONE and lossLine.get_node("Reset").modulate.a == 0.0)
	check("the estimates at the target", estimatesShown(screen, TARGET), [screen._failureValue.text, screen._lossValue.text])
	sliderRow.get_node("HSlider").value = SLIDER_TARGET
	yield(frames(2), "completed")
	check("the estimates follow the slider", estimatesShown(screen, SLIDER_TARGET), [screen._failureValue.text, screen._lossValue.text])
	check("the slider stores the target", settings.getValue("target") == float(SLIDER_TARGET), settings.getValue("target"))
	check("the slider's description", screen._description.text == tr(setting.label + screen.DESCRIPTION_SUFFIX) and screen._description.text != setting.label + screen.DESCRIPTION_SUFFIX)
	settings.setValue("target", HIGHER_TARGET)
	yield(tap(escKey()), "completed")
	yield(frames(45), "completed")
	check("Esc closes the settings and brings the screen back", not screen.visible and repairs.visible)
	check("the table at the higher target", values() == [money(0), money(32000), money(32000), time(28 * H)] and repairs._sraTargetValue.text == percent(HIGHER_TARGET), [values(), repairs._sraTargetValue.text])
	check("the target kept in the save, under the manifest's id", same(CurrentGame.state.ui.get(settings.modId(), {}).get("target"), HIGHER_TARGET), CurrentGame.state.ui)
	var richMoney = CurrentGame.money
	CurrentGame.money = 100
	repairs._sraQueue()
	yield(frames(2), "completed")
	check("the cash in the rows' colour for a failed inspection while it would end below zero", repairs._sraValues[1].modulate == repairs._sraRows()[0].colorBad, repairs._sraValues[1].modulate)
	CurrentGame.money = richMoney
	repairs._sraQueue()
	yield(frames(2), "completed")
	check("and back to normal", repairs._sraValues[1].modulate == WHITE)
	repairs._sraButton.emit_signal("pressed")
	yield(waitDone(), "completed")
	var reached = true
	for key in ["thruster", "hud", "laser"]:
		reached = reached and ship.status(key) >= HIGHER_TARGET - 0.01
	check("Repair again: the thruster, the HUD and the laser at the higher target", reached, [ship.status("thruster"), ship.status("hud"), ship.status("laser")])
	# The gamepad twin: PAD_BUTTON on the highlighted Repair while PAD_MODIFIER is held opens the settings.
	repairs._sraButton.grab_focus()
	yield(holdJoy(badgeScript.PAD_MODIFIER, true), "completed")
	var pad = joyButton(badgeScript.PAD_BUTTON)
	pad.pressed = true
	repairs._sraButton.emit_signal("gui_input", pad)
	yield(holdJoy(badgeScript.PAD_MODIFIER, false), "completed")
	yield(frames(45), "completed")
	check("gamepad: the twin on the highlighted Repair opens the settings", screen.visible and not repairs.visible)
	yield(tapJoy(JOY_BUTTON_1), "completed")
	yield(frames(45), "completed")
	check("gamepad: B closes them, Repair highlighted again", not screen.visible and repairs.visible and repairs._sraButton.has_focus())

func estimatesShown(screen, condition) -> bool:
	return screen._failureValue.text == CurrentGame.formatThousandsWithDecimals(settingsScript.failureRate(condition), settingsScript.FAILURE_DECIMALS) \
			and screen._lossValue.text == CurrentGame.formatThousandsWithDecimals(settingsScript.performanceLoss(condition), settingsScript.LOSS_DECIMALS)

# --- Park ---

# As the game builds the player's ship again after a purchase: a new one from the config at once, which sets itself up a
# little later, then playerShipChanged (CurrentGame.gd setupPlayerShip, playerShipSetupDone; Enceladus.gd shipChanged).
func rebuild():
	var old = ship
	ship = load(PARK_SHIP).new()
	CurrentGame.playerShip = ship
	ship.connect("setup", CurrentGame, "emit_signal", ["playerShipChanged"])
	add_child(ship)
	if is_instance_valid(old):
		old.queue_free()

# Park pressed, and its confirmation once the trial ship has been read.
func openDialog():
	repairs._sraParkButton.emit_signal("pressed")
	for i in 120:
		yield(get_tree(), "physics_frame")
		if repairs._sraParkDialog != null and repairs._sraParkDialog.visible:
			break
	yield(frames(2), "completed")

func item(group, system, price, numVal = -1.0, isDefault = false):
	var node = load(ITEM).instance()
	node.system = system
	node.price = price
	node.numVal = numVal
	node.default = isDefault
	group.add_child(node)
	return node

func group(equipment, slot, visible = true, always = true):
	var node = VBoxContainer.new()
	node.set_script(load(GROUP))
	node.slot = slot
	node.always = always
	node.visible = visible
	equipment.add_child(node)
	return node

func lines(dialog) -> Array:
	var out = []
	var grid = dialog._lines
	for i in range(0, grid.get_child_count(), 2):
		out.append([grid.get_child(i).text, grid.get_child(i + 1).text, grid.get_child(i + 1).modulate])
	return out

func notes(dialog) -> Array:
	var out = []
	for note in dialog._notes.get_children():
		if not note.is_queued_for_deletion():
			out.append(note.text)
	return out

func signed(key, amount):
	return tr(key) % CurrentGame.formatThousands(amount)

# A condition as the confirmation names it: rounded down to the mod's decimals, so one just short of the target never
# reads as the target.
func conditionShown(status):
	var places = repairs._SRA_CONDITION_DECIMALS
	var scale = pow(10, places)
	return percent(("%." + str(places) + "f") % (floor(status * scale + repairs._SRA_CONDITION_GUARD) / scale))

# The Park ship: a laser at 60 % on the main hardpoint, RCS_A thrusters with one at 99.7 % (the cheapest, so bought out
# and back), the dearer reactor at 70 %, a HUD at 99.7 % (on a slot without members, so no button reaches it), the cabin
# at 80 % on no slot, the ammo capacity bought; the left hardpoint empty and not shown.
func parkShip():
	CurrentGame.money = 50000
	CurrentGame.state.insurance = 10000
	CurrentGame.mechanics = 1
	CurrentGame.repairLimit = GAME_REPAIR_CAP
	CurrentGame.time = 0
	var scene = PackedScene.new()
	var template = load(PARK_SHIP).new()
	scene.pack(template)
	template.free()
	Shipyard.ships[MODEL] = scene
	CurrentGame.state.ship = {"model": MODEL, "transponder": "PRK-1", "madeIn": 0, "config": {
		"weaponSlot": {"main": {"type": "SYSTEM_LASER"}}, "propulsion": {"rcs": "RCS_A"}, "reactor": {"power": 2.0},
		"hud": {"type": "HUD_A"}, "ammo": {"capacity": 1000.0},
		"damage": {
			"weaponSlot.main": {"wear": 400.0},
			"rcs1": {"wear": 3.0},
			"reactor": {"leak": 300.0},
			"hud": {"wear": 3.0},
			"cabin": {"wear": 200.0},
		},
	}}
	ship = load(PARK_SHIP).new()
	ship.setup = true
	add_child(ship)
	ship.fillInSystems()
	CurrentGame.playerShip = ship

func parkButton():
	parkShip()
	makeStation()
	var equipment = PanelContainer.new()
	equipment.set_script(load(EQUIPMENT))
	equipment.name = repairs._SRA_EQUIPMENT
	equipment.visible = false
	var hp = group(equipment, "weaponSlot.main.type", true, false)
	item(hp, "SYSTEM_NONE", 0, -1.0, true)
	item(hp, "SYSTEM_LASER", 200000)
	item(hp, "SYSTEM_GUN", 20000)
	var rcs = group(equipment, "propulsion.rcs")
	item(rcs, "RCS_A", 3000)
	item(rcs, "RCS_B", 8000)
	var reactor = group(equipment, "reactor.power")
	item(reactor, "REACTOR", 50000, 1.0)
	item(reactor, "REACTOR", 120000, 2.0)
	var hud = group(equipment, "hud.type")
	item(hud, "HUD_A", 5000)
	item(hud, "HUD_B", 9000)
	var ammo = group(equipment, "ammo.capacity")
	item(ammo, "AMMO", 0, 0.0, true)
	item(ammo, "AMMO", 4000, 1000.0)
	var left = group(equipment, "weaponSlot.left.type", false, false)
	item(left, "SYSTEM_NONE", 0, -1.0, true)
	var leftGun = item(left, "SYSTEM_GUN", 1)
	equipment.rebuild = funcref(self, "rebuild")
	screens.add_child(equipment)
	var fleet = Control.new()
	fleet.set_script(load(FLEET))
	fleet.name = repairs._SRA_FLEET
	fleet.visible = false
	screens.add_child(fleet)
	repairs.show()
	yield(frames(12), "completed")

	var rows = repairs._sraRows()
	check("park: a row per system", rows.size() == ship.refs.size(), rows.size())
	if rows.empty():
		return
	var park = repairs._sraParkButton
	var repair = repairs._sraButton
	check("park: Park named by the mod's text, enabled", park.text == repairs._SRA_PARK and tr(park.text) != park.text and not park.disabled)
	var parkRect = park.get_global_rect()
	var repairRect = repair.get_global_rect()
	check("park: Park right of Repair, as tall, at the same height", parkRect.position.x >= repairRect.end.x and near(parkRect.position.y, repairRect.position.y, 1.0) and near(parkRect.size.y, repairRect.size.y, 1.0), [parkRect, repairRect])
	check("park: the badge inside Repair, then Park", repairs._sraShiftBadge.get_parent() == repair and park.get_index() == repair.get_index() + 1)
	var parkGaps = gaps(park)
	check("park: Park as far from the panel's frame at the bottom as at the right", near(parkGaps[0], parkGaps[1], 1.0), parkGaps)
	var last = rows[rows.size() - 1]
	check("park: D-pad up from Park to the last row's Replace, down from it to Repair", park.focus_neighbour_top == last.replaceButton.get_path() and last.replaceButton.focus_neighbour_bottom == repair.get_path())
	repair.grab_focus()
	yield(tap(joyButton(JOY_DPAD_RIGHT)), "completed")
	check("park: D-pad right from Repair to Park", park.has_focus(), park.get_focus_owner())
	yield(tap(joyButton(JOY_DPAD_LEFT)), "completed")
	check("park: D-pad left back to Repair", repair.has_focus(), park.get_focus_owner())

	# The confirmation.
	var moneyBefore = CurrentGame.money
	yield(openDialog(), "completed")
	var dialog = repairs._sraParkDialog
	check("park: the confirmation shows", dialog != null and dialog.visible)
	if dialog == null:
		return
	var target = percent(int(round(repairs._SRA_PARK_TARGET)))
	check("park: no title, the game's OK and CANCEL, Cancel highlighted", dialog.window_title == "" and dialog.get_ok().text == dialog.OK_TEXT and dialog.get_cancel().text == dialog.CANCEL_TEXT and dialog.get_cancel().has_focus())
	check("park: the question, with the park target", dialog._question.text == tr(repairs._SRA_PARK_CONFIRM) % target and dialog._question.text != repairs._SRA_PARK_CONFIRM, dialog._question.text)
	var shown = lines(dialog)
	var plus = fleet.colorPlus
	var minus = fleet.colorMinus
	check("park: the lines' names, without 'cost'", shown.size() == 4 and shown[0][0] == tr(repairs._SRA_INSURANCE) and shown[1][0] == tr(repairs._SRA_CASH) and shown[2][0] == tr(repairs._SRA_TOTAL) and shown[3][0] == tr(repairs._SRA_TIME), shown)
	if shown.size() < 4:
		return
	check("park: the insurance going out, with - in the Fleet screen's colour for it", shown[0][1] == signed(repairs._SRA_MINUS, 10000) and shown[0][2] == minus, shown[0])
	check("park: the cash coming in, with + in the Fleet screen's colour for it", shown[1][1] == signed(repairs._SRA_PLUS, 125407) and shown[1][2] == plus, shown[1])
	check("park: the total", shown[2][1] == signed(repairs._SRA_PLUS, 115407) and shown[2][2] == plus, shown[2])
	check("park: the maintenance time, in the normal colour", shown[3][1] == time(39 * H) and shown[3][2] == WHITE, shown[3])
	# The repairs it shows are read on a trial ship of the parked config.
	var trialConfig = Shipyard.configs.back().config
	check("park: the trial ship has the pieces bought (the other thrusters, for the out-and-back)", trialConfig.propulsion.rcs == "RCS_B" and trialConfig.reactor.power == 1.0 and trialConfig.weaponSlot.main.type == "SYSTEM_NONE" and trialConfig.ammo.capacity == 0.0, trialConfig)
	check("park: and the slots' members without damage, the rest kept", trialConfig.damage["weaponSlot.main"].wear == 0.0 and trialConfig.damage.rcs1.wear == 0.0 and trialConfig.damage.reactor.leak == 300.0 and trialConfig.damage.cabin.wear == 200.0, trialConfig.damage)
	check("park: the trial ship gone, the ship and its state untouched", repairs.get_node(repairs._SRA_TRIAL_NODE).get_child_count() == 0 and ship.getConfigWithDefaults("reactor.power") == 2.0 and CurrentGame.state.ship.config.damage.rcs1.wear == 3.0)
	var hudName = tr(repairs._SRA_PARK_SYSTEM) % [tr("SYSTEM_HUD"), conditionShown(ship.status("hud"))]
	check("park: the HUD named, which no button brings to the target, at its condition rounded down", notes(dialog) == [tr(repairs._SRA_PARK_UNREACHABLE) % [target, hudName]] and conditionShown(ship.status("hud")) != target, notes(dialog))
	check("park: OK enabled", not dialog.get_ok().disabled)
	check("park: the confirmation on the screen", get_viewport().get_visible_rect().encloses(dialog.get_global_rect()), dialog.get_global_rect())
	yield(tap(escKey()), "completed")
	yield(idle(2), "completed")
	check("park: Esc closes the confirmation only, Park highlighted again", not dialog.visible and repairs.visible and park.has_focus())
	check("park: nothing changed", CurrentGame.money == moneyBefore and ship.getConfigWithDefaults("reactor.power") == 2.0)
	yield(openDialog(), "completed")
	yield(tapJoy(JOY_BUTTON_1), "completed")
	check("park: B closes it too", not dialog.visible and repairs.visible)

	# OK parks the ship.
	yield(openDialog(), "completed")
	var maintenanceBefore = CurrentGame.state.ship.get("maintaineceUntil", 0)
	dialog.get_ok().emit_signal("pressed")
	check("park: OK starts it, both buttons disabled", repairs._sraRunning and park.disabled and repair.disabled)
	yield(waitDone(), "completed")
	check("park: done", not repairs._sraRunning)
	var bought = equipment.bought
	check("park: the hardpoint empty", ship.getConfigWithDefaults("weaponSlot.main.type") == "SYSTEM_NONE")
	check("park: the cheapest reactor and ammo capacity", ship.getConfigWithDefaults("reactor.power") == 1.0 and ship.getConfigWithDefaults("ammo.capacity") == 0.0)
	check("park: the thrusters out and back, the second purchase refunding what the other ones' systems are worth", ship.getConfigWithDefaults("propulsion.rcs") == "RCS_A" and bought.size() == 5 and bought[3][1] == "RCS_B" and bought[4][1] == "RCS_A" and near(bought[4][2], 2 * 3000 - 2 * 7958, 1.0), bought)
	check("park: the refunds first", bought.size() == 5 and bought[0][1] == "SYSTEM_NONE" and bought[1][1] == 1.0 and bought[2][1] == 0.0, bought)
	check("park: the laser fixed once before its trade-in", bought.size() > 0 and near(bought[0][2], -102400, 1.0), bought)
	check("park: the empty slot not shown left alone", ship.getConfigWithDefaults("weaponSlot.left.type") == null and leftGun.price == 1)
	var full = true
	for key in ["rcs1", "rcs2", "reactor", "cabin"]:
		full = full and ship.status(key) == repairs._SRA_PARK_TARGET
	check("park: every other system at the park target", full, [ship.status("rcs1"), ship.status("rcs2"), ship.status("reactor"), ship.status("cabin")])
	check("park: the HUD as it was", near(ship.status("hud"), 99.7, 0.001), ship.status("hud"))
	check("park: the cash as the confirmation said (the cheaper reactor's repair, the other thrusters' worth)", near(CurrentGame.money, moneyBefore + 125406.62, 1.0), CurrentGame.money)
	check("park: the insurance spent", near(CurrentGame.getInsurance(), 0), CurrentGame.getInsurance())
	check("park: the maintenance as it said", near(CurrentGame.state.ship.maintaineceUntil - maintenanceBefore, 39 * H), CurrentGame.state.ship.maintaineceUntil - maintenanceBefore)
	check("park: the rows made for the new ship", repairs._sraRows().size() == ship.refs.size() and repairs._sraRows()[0].ship == ship, repairs._sraRows().size())
	check("park: Park disabled, with nothing left to do, and highlighted", park.disabled and park.has_focus())

	# A gun at 50 % on the hardpoint, the cabin at 75 %, the cash below zero.
	ship.setConfig("weaponSlot.main.type", "SYSTEM_GUN")
	CurrentGame.state.ship.config.damage["weaponSlot.main"] = {"wear": 500.0}
	CurrentGame.state.ship.config.damage["cabin"] = {"wear": 250.0}
	rebuild()
	yield(frames(10), "completed")
	CurrentGame.money = -20000
	CurrentGame.state.insurance = 0
	repairs._sraQueue()
	yield(frames(2), "completed")
	check("park: enabled again with something to do", not park.disabled)
	yield(openDialog(), "completed")
	check("park: too little money, the note says how much more", notes(dialog).size() == 2 and notes(dialog)[0] == tr(repairs._SRA_PARK_NEEDED) % money(16625), notes(dialog))
	check("park: and OK disabled", dialog.get_ok().disabled)
	dialog.get_cancel().emit_signal("pressed")
	yield(frames(2), "completed")
	check("park: Cancel closes it, nothing changed", not dialog.visible and CurrentGame.money == -20000 and ship.getConfigWithDefaults("weaponSlot.main.type") == "SYSTEM_GUN")
	CurrentGame.money = 100000
	yield(openDialog(), "completed")
	shown = lines(dialog)
	check("park: no insurance spent, without a sign or colour", shown[0][1] == signed(repairs._SRA_ZERO, 0) and shown[0][2] == WHITE, shown[0])
	check("park: the cash and the time", shown[1][1] == signed(repairs._SRA_PLUS, 3375) and shown[3][1] == time(10 * H), shown)
	maintenanceBefore = CurrentGame.state.ship.maintaineceUntil
	dialog.get_ok().emit_signal("pressed")
	yield(waitDone(), "completed")
	check("park: the cash and the maintenance as it said", near(CurrentGame.money, 103375, 1.0) and near(CurrentGame.state.ship.maintaineceUntil - maintenanceBefore, 10 * H), [CurrentGame.money, CurrentGame.state.ship.maintaineceUntil - maintenanceBefore])
	check("park: the gun traded in after two Fixes", near(bought.back()[2], -12250, 1.0) and ship.getConfigWithDefaults("weaponSlot.main.type") == "SYSTEM_NONE", bought.back())
	check("park: the cabin at the park target", ship.status("cabin") == repairs._SRA_PARK_TARGET, ship.status("cabin"))

	# The screen hiding closes the confirmation; without the Equipment screen, no Park.
	ship.setConfig("weaponSlot.main.type", "SYSTEM_GUN")
	repairs._sraQueue()
	yield(frames(2), "completed")
	yield(openDialog(), "completed")
	screens.hidefoka()
	yield(frames(45), "completed")
	check("park: the screen hiding closes the confirmation", not dialog.visible and not repairs.visible)
	repairs.show()
	yield(frames(12), "completed")
	screens.remove_child(equipment)
	equipment.queue_free()
	repairs._sraQueue()
	yield(frames(2), "completed")
	check("park: without the Equipment screen, Park disabled", park.disabled)

# --- Input ---

# The game's bindings (its project.godot): ui_cancel is Esc, B and Start; pause is Esc and Start.
func bindGameKeys():
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
	for binding in [["ui_cancel", escKey()], ["ui_cancel", joyButton(JOY_BUTTON_1)], ["ui_cancel", joyButton(JOY_START)], ["pause", escKey()], ["pause", joyButton(JOY_START)]]:
		if not InputMap.action_has_event(binding[0], binding[1]):
			InputMap.action_add_event(binding[0], binding[1])

func idle(count = 2):
	for i in count:
		yield(get_tree(), "idle_frame")

# A press and release, as Input delivers a player's, in the idle part of a frame; then two frames, as Input hands parsed
# events on at the next one.
func tap(event):
	yield(get_tree(), "idle_frame")
	for pressed in [true, false]:
		var e = event.duplicate()
		e.pressed = pressed
		Input.parse_input_event(e)
	yield(idle(2), "completed")

func escKey():
	var event = InputEventKey.new()
	event.scancode = KEY_ESCAPE
	return event

func joyButton(index):
	var event = InputEventJoypadButton.new()
	event.button_index = index
	return event

func tapJoy(index):
	yield(tap(joyButton(index)), "completed")

# A gamepad button pressed, or released, and left so (Input.is_joy_button_pressed follows).
func holdJoy(index, pressed):
	yield(get_tree(), "idle_frame")
	var event = joyButton(index)
	event.pressed = pressed
	Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")
