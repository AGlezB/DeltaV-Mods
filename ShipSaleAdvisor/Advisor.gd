extends Reference

# ShipSaleAdvisor's advice: how to prepare a ship for sale so that selling it brings the most cash, from plain data
# Code.gd reads from the game (the ship, the Equipment screen's items, the player's money and insurance, the crew's
# repair limit). Static functions of what the player can see; they touch neither the game nor the scene.
#
# Selling pays `markdown` of the ship's value (CurrentGame.shipSellMarkdown, Dealer.gd sell), while the Equipment
# screen refunds the whole value of the piece it replaces (Upgrades.gd updatePricesAndAvailability), and the Repairs
# screen's Fix raises a piece's value (enceladus/SystemShipRepairUI.gd doFixSystem). So a ship can be prepared:
# - a slot is taken down to its cheapest item when that refunds money: it brings the refund now, and the ship's value
#   loses the refunded piece and gains the cheap one, which sells at `markdown` of its price. Under the game's prices
#   (a new piece's value is its price, ship-ctrl.gd getSystemPrice and Shipyard.gd getNumericValueOfConfig), that
#   comes to (1 - markdown) of the refund;
# - a piece is fixed click by click, as the player clicks Fix: each click costs the piece's fix price, paid by the
#   insurance first, then from the cash (CurrentGame.gd changeMoney), and raises its value. A piece taken off brings
#   its whole value as its refund, so a click adds its whole value gain there; a piece that stays adds `markdown` of it.
#
# A click is planned only if what it adds is more than its price, whoever pays: insurance is money spent all the same.
# Each step (a slot taken down, a click) must bring at least `minGain` of cash, the click less the part of its price
# paid from cash, so that a step worth little isn't paid for with maintenance hours.
#
# The data (Code.gd _ssaGather):
# - markdown; money: the cash; insurance; minGain: in E$;
# - systems, by an id: `slot`, the Equipment screen's slot the piece is mounted in ("" for none: the reactor, the HUD),
#   `values`, its value after 0, 1, 2… Fix clicks (as many as the Repairs screen allows: below the repair limit, worth
#   fixing), `fixPrice` per click and `fixTime` per click, in seconds;
# - slots, by the slot's config key, for each slot whose cheapest available item isn't the one fitted (its refund may
#   still be negative: clicks can raise it): `members`, the ids of the systems mounted in it (empty where the Equipment
#   screen prices the slot by its items, a number or the lidar), with `cost`, the cheapest item's price for every slot
#   of the kind; or, without members, `refund`; and `time`, the maintenance the swap takes, in seconds (ship-ctrl.gd
#   getSlotTime: the damaged pieces' replacement time).

# How many times the slots taken down and the clicks are chosen again from each other: a click can make a slot worth
# taking down, and taking a slot down makes its pieces' clicks worth more.
const ROUNDS = 4
# The least difference in E$ the comparisons count, so that float error (1 - 0.9 is a hair under 0.1) neither drops a
# step worth exactly the minimum gain nor takes a click worth exactly its price.
const PRECISION = 0.01

# The plan for `data` (above):
# - clicks: Fix clicks per system id; strips: the slots taken down, in the order of data.slots, with refunds: each
#   one's refund;
# - refund: the refunds' sum, fixCost: the clicks' price, insuranceCost and cashCost: who pays it, time: the
#   maintenance in seconds;
# - gain: the cash it brings over selling the ship as it is, from the game's prices (Code.gd measures it on the
#   prepared ship itself).
static func plan(data: Dictionary) -> Dictionary:
	var strips = _strips(data, {})
	var chosen = null
	for i in ROUNDS:
		chosen = _chooseClicks(data, strips)
		var again = _strips(data, chosen.clicks)
		if _sameKeys(again, strips):
			break
		strips = again
		chosen = null
	if chosen == null:
		chosen = _chooseClicks(data, strips)
	var result = {
		"clicks": chosen.clicks,
		"strips": [],
		"refunds": {},
		"refund": 0.0,
		"fixCost": chosen.fixCost,
		"time": chosen.time,
	}
	for slot in data.slots:
		if strips.has(slot):
			var refund = _refund(data, slot, chosen.clicks)
			result.strips.append(slot)
			result.refunds[slot] = refund
			result.refund += refund
			result.time += max(0.0, data.slots[slot].time)
	result.insuranceCost = min(max(0.0, data.insurance), chosen.fixCost)
	result.cashCost = chosen.fixCost - result.insuranceCost
	result.gain = _gain(data, result)
	return result

# Whether the plan does anything.
static func isEmpty(plan: Dictionary) -> bool:
	return plan.strips.empty() and plan.clicks.empty()

# The slots worth taking down with `clicks` done: their refund is positive, and its share the sale doesn't take back
# reaches the minimum gain.
static func _strips(data: Dictionary, clicks: Dictionary) -> Dictionary:
	var out = {}
	for slot in data.slots:
		var refund = _refund(data, slot, clicks)
		if _more(refund, 0.0) and reaches((1.0 - data.markdown) * refund, data.minGain):
			out[slot] = true
	return out

# A slot's refund with `clicks` done: its pieces' values less the cheapest items' price, or the refund given.
static func _refund(data: Dictionary, slot: String, clicks: Dictionary) -> float:
	var entry = data.slots[slot]
	if entry.members.empty():
		return float(entry.refund)
	var value = 0.0
	for id in entry.members:
		value += _value(data, id, clicks.get(id, 0))
	return value - entry.cost

# A system's value after `count` clicks.
static func _value(data: Dictionary, id, count: int) -> float:
	var values = data.systems[id].values
	return float(values[int(clamp(count, 0, values.size() - 1))])

# The clicks, chosen as units (_units) best value per E$ first: the insurance pays the first ones, then the cash, as
# far as it goes. A unit that can't be paid, or wouldn't bring the minimum gain, ends its system's clicks.
static func _chooseClicks(data: Dictionary, strips: Dictionary) -> Dictionary:
	var units = {}
	var next = {}
	for id in data.systems:
		var system = data.systems[id]
		var share = 1.0 if strips.has(system.slot) else data.markdown
		units[id] = _units(system.values, system.fixPrice, system.fixTime, share)
		next[id] = 0
	var insurance = max(0.0, data.insurance)
	var cash = max(0.0, data.money)
	var clicks = {}
	var fixCost = 0.0
	var time = 0.0
	while true:
		var best = null
		var bestRatio = -1.0
		for id in units:
			var i = next[id]
			if i < 0 or i >= units[id].size():
				continue
			var unit = units[id][i]
			if not _more(unit.add, unit.cost):
				next[id] = -1
				continue
			var ratio = INF if unit.cost <= 0 else unit.add / unit.cost
			if ratio > bestRatio:
				bestRatio = ratio
				best = id
		if best == null:
			break
		var unit = units[best][next[best]]
		var fromInsurance = min(insurance, unit.cost)
		var fromCash = unit.cost - fromInsurance
		if _more(fromCash, cash) or not reaches(unit.add - fromCash, data.minGain):
			next[best] = -1
			continue
		insurance -= fromInsurance
		cash -= fromCash
		fixCost += unit.cost
		time += unit.time
		clicks[best] = unit.end
		next[best] += 1
	return {"clicks": clicks, "fixCost": fixCost, "time": time}

# A system's clicks in units, each the run of clicks from where the last one ended that adds the most per E$. A piece's
# condition is the shortfall of its worst damage from its capacity, which a click halves, and its value goes with the
# square of its condition (ship-ctrl.gd getSystemPrice): what a click adds grows until the worst damage is down to 2/3
# of its capacity, then shrinks, so a click that doesn't pay alone can pay with the next ones. The run's end with the
# most per E$ is also the one with the largest total of what the clicks add less their price, so taking units while
# they add more than they cost gives the best number of clicks. Each unit: `end`, the clicks done after it, `add`, the
# value it adds (`share` of the value gain), `cost` and `time`.
static func _units(values: Array, fixPrice: float, fixTime: float, share: float) -> Array:
	var units = []
	var start = 0
	while start < values.size() - 1:
		var best = null
		var bestRatio = -1.0
		for end in range(start + 1, values.size()):
			var add = share * (float(values[end]) - float(values[start]))
			var cost = fixPrice * (end - start)
			var ratio = INF if cost <= 0 else add / cost
			if add > 0 and ratio > bestRatio:
				bestRatio = ratio
				best = {"end": end, "add": add, "cost": cost, "time": fixTime * (end - start)}
		if best == null:
			break
		units.append(best)
		start = best.end
	return units

# The cash the plan brings over selling as it is: each piece that stays sells for `markdown` of what its clicks add;
# each slot taken down brings its refund now, and the sale takes `markdown` of its pieces' value as they are and gives
# `markdown` of the cheap items' price (a slot priced by its items: its refund and `markdown` of it back); less the cash
# the clicks take.
static func _gain(data: Dictionary, plan: Dictionary) -> float:
	var m = data.markdown
	var gain = -plan.cashCost
	var stripped = {}
	for slot in plan.strips:
		var entry = data.slots[slot]
		if entry.members.empty():
			gain += (1.0 - m) * plan.refunds[slot]
			continue
		var before = 0.0
		for id in entry.members:
			before += _value(data, id, 0)
			stripped[id] = true
		gain += plan.refunds[slot] + m * entry.cost - m * before
	for id in plan.clicks:
		if not stripped.has(id):
			gain += m * (_value(data, id, plan.clicks[id]) - _value(data, id, 0))
	return gain

static func _sameKeys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a:
		if not b.has(key):
			return false
	return true

# Whether `a` is more than `b`, and whether `gain` reaches `minimum`, by more than float error.
static func _more(a: float, b: float) -> bool:
	return a > b + PRECISION

static func reaches(gain: float, minimum: float) -> bool:
	return gain >= minimum - PRECISION
