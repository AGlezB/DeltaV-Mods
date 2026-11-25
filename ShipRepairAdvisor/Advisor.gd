extends Reference

# ShipRepairAdvisor's plan: how the Repair button brings every damaged system up to the target condition, the cheapest
# way, from plain data Code.gd reads from the Repairs screen's own rows (enceladus/SystemShipRepairUI.gd) and the
# player's money. Static functions of what the player can see; they touch neither the game nor the scene.
#
# Each row of the Repairs screen has two buttons:
# - Fix costs the system's fix price and halves each of its damages (doFixSystem). The row enables it while the system
#   isn't beyond repair, is below the crew's repair limit, and Replace costs more than Fix (shouldBeFixed). It needs no
#   money: it is paid by the insurance first, then from the cash, which can go below zero (CurrentGame.gd changeMoney).
# - Replace clears every damage, for the system's price less what it is still worth (replacementPrice), which falls as
#   its condition rises, so Fixes first can make it cheaper. The row enables it while cash and insurance together cover
#   its price, and always for a system beyond repair (isReplaceable).
#
# For each system below the target: the cheapest way that reaches it, then the one with the fewest hours, either Fixes
# alone or some Fixes and then Replace. Insurance counts as money: what it pays for one repair can't pay for the next.
# A system no way reaches is fixed as far as Fix raises it. Replaces that need money are kept, cheapest first, while
# their systems' whole cost fits in cash and insurance, and they are done before anything else, so each one can be paid
# when its button is pressed; a system that no longer fits falls back to Fixes alone. Systems beyond repair come next,
# then the Fixes alone. Cash may end below zero, from those two.
#
# The data (Code.gd _sraData):
# - target: the condition to reach, in %; money: the cash; insurance;
# - systems, by the row's system key: `steps`, the system after 0, 1, 2… Fix clicks, each with its `status` (in %),
#   `fix` (whether the row enables Fix there: the next step exists only then), `replace` (whether it enables Replace
#   there, money aside) and `replacePrice`; `fixPrice` and `fixTime` per click, `replaceTime`, in seconds;
#   `unfixable`: beyond repair now, so its Replace needs no money; `replaced`: the status Replace leaves it at (what no
#   repair clears stays);
# - reachOnly (optional, false by default): only ways that reach the target, for Park, whose systems must all get
#   there. A system no way reaches is left alone, in `unreachable`, instead of fixed as far as Fix raises it, and paid
#   Replaces are kept whatever the money: Park asks for all of it (park's `needed`).
#
# Park (park) puts every slot of the Equipment screen (enceladus/Upgrades.gd) on its cheapest piece and brings the
# systems of the repair data (Code.gd gives the slots' members only, whose condition a swap pays for) to its target, in
# three steps, each through the game's own buttons:
# 1. Fix clicks on the damaged pieces about to be traded in, where they raise what the piece trades in for by more than
#    they cost (the insurance counting as money, as above).
# 2. Purchases at the Equipment screen, from the cash alone (Upgrades.gd buy): the refunds first, in the screen's order,
#    then the costs, cheapest first. A slot whose cheapest piece is fitted but worn where the Repairs screen can't take
#    it is bought out and back: another piece, then the cheapest again, new.
# 3. The repairs of the systems left in place, with reachOnly.
# Parking is all or nothing: `needed` is the most money missing at a step the game allows only with the money for it
# (a purchase that costs, which needs that much cash; a Replace that needs money, which needs cash and insurance
# together to cover it).
#
# Park's data (Code.gd _sraParkInfo):
# - money, insurance;
# - slots: an Array, in the screen's order, of the slots needing a purchase, each with `slot`, `net` and `time` (the
#   piece to buy now: its net price, a refund below zero, and its maintenance time), `members` (the ids of the systems
#   mounted in the slot), and, for one bought out and back, `back` true and `backNet`, the second purchase's net;
# - trades: by system id, the members that may be fixed before they go, each as a system above, with every step's
#   `value`, what the piece trades in for there;
# - repair: plan's data for the systems left in place;
# - unreachable: the ids of the systems nothing brings to the target.

# Plan phases, in the order the Repair button works through them (presses).
const PHASE_PAID_REPLACE = 0
const PHASE_UNFIXABLE_REPLACE = 1
const PHASE_FIXES = 2
# The least difference the comparisons count, in E$ and in % of condition, so that float error neither takes a step
# that changes nothing nor misses a target reached exactly.
const PRECISION = 0.01
const STATUS_PRECISION = 0.01

# The plan for `data` (above):
# - systems: by system key, for each system the plan repairs, its `fixes` (Fix clicks), `replace` (whether Replace
#   follows them), `phase`, `reaches` (whether it ends at the target or better), `cost`;
# - repaired, fixes, replaces: how many systems, Fix clicks and Replaces; short: how many systems below the target stay
#   below it;
# - cost, and who pays it, insuranceCost and cashCost; cashAfter: the cash left; time: the maintenance, in seconds;
# - unreachable: with reachOnly, the ids of the systems no way reaches.
static func plan(data: Dictionary) -> Dictionary:
	var reachOnly = data.get("reachOnly", false)
	var chosen = {}
	var paid = []
	var unreachable = []
	for id in data.systems:
		var system = data.systems[id]
		if system.steps.empty() or _reaches(system.steps[0].status, data.target):
			continue
		var option = _cheapest(system, data.target)
		if option == null:
			if reachOnly:
				unreachable.append(id)
				continue
			option = _fallback(system, data.target)
		chosen[id] = option
		if option.replace and not system.unfixable:
			paid.append(id)
	if not reachOnly:
		var available = float(data.money) + float(data.insurance)
		var spent = 0.0
		for id in _byCost(paid, chosen):
			if spent + chosen[id].cost <= available + PRECISION:
				spent += chosen[id].cost
			else:
				chosen[id] = _fallback(data.systems[id], data.target)
	var result = {
		"systems": {},
		"repaired": 0,
		"fixes": 0,
		"replaces": 0,
		"short": unreachable.size(),
		"cost": 0.0,
		"time": 0.0,
		"unreachable": unreachable,
	}
	for id in chosen:
		var option = chosen[id]
		if not option.reaches:
			result.short += 1
		if option.fixes == 0 and not option.replace:
			continue
		var phase = PHASE_FIXES
		if option.replace:
			phase = PHASE_UNFIXABLE_REPLACE if data.systems[id].unfixable else PHASE_PAID_REPLACE
		result.systems[id] = {
			"fixes": option.fixes,
			"replace": option.replace,
			"phase": phase,
			"reaches": option.reaches,
			"cost": option.cost,
		}
		result.repaired += 1
		result.fixes += option.fixes
		result.replaces += 1 if option.replace else 0
		result.cost += option.cost
		result.time += option.time
	# changeMoney takes a repair from the insurance first, as far as it goes; an insurance below zero (a conversation
	# can leave it there) is paid from the cash with the first repair.
	var insurance = float(data.insurance)
	result.insuranceCost = clamp(insurance, 0.0, result.cost)
	result.cashCost = result.cost - result.insuranceCost
	if insurance < 0 and result.cost > 0:
		result.cashCost -= insurance
	result.cashAfter = float(data.money) - result.cashCost
	return result

# Whether the plan does anything.
static func isEmpty(plan: Dictionary) -> bool:
	return plan.systems.empty()

# The buttons to press now, one per system, by system key: "fix" while its Fixes aren't done, then "replace". Only the
# first phase with anything left: the Replaces that need money are pressed while the money set aside for them is still
# there, before the Replaces of systems beyond repair and the Fixes alone, which need none, spend it.
static func presses(plan: Dictionary) -> Dictionary:
	var phase = PHASE_FIXES + 1
	for id in plan.systems:
		phase = min(phase, plan.systems[id].phase)
	var out = {}
	for id in plan.systems:
		var system = plan.systems[id]
		if system.phase == phase:
			out[id] = "fix" if system.fixes > 0 else "replace"
	return out

# Park's plan for `data` (the header):
# - fixes: Fix clicks per system id, made before anything else; purchases: the slots to buy for, in the order to buy;
#   repair: plan's, for the systems left in place;
# - insuranceCost; cashCost (below zero for money coming in); time: the maintenance, in seconds;
# - needed: the most money missing at a step that needs it (0 when everything can be paid when its turn comes);
#   unreachable: the ids of the systems nothing brings to the target.
static func park(data: Dictionary) -> Dictionary:
	var fixes = {}
	var gains = {}
	var fixCost = 0.0
	var time = 0.0
	for id in data.trades:
		var trade = data.trades[id]
		var clicks = _tradeFixes(trade)
		if clicks > 0:
			fixes[id] = clicks
			gains[id] = float(trade.steps[clicks].value) - float(trade.steps[0].value)
			fixCost += clicks * float(trade.fixPrice)
			time += clicks * float(trade.fixTime)
	var refunds = []
	var costs = []
	for entry in data.slots:
		var net = float(entry.net)
		for id in entry.members:
			net -= gains.get(id, 0.0)
		var step = {"slot": entry.slot, "net": net, "time": float(entry.time), "back": null}
		if entry.get("back", false):
			step.back = float(entry.backNet)
		if net <= PRECISION:
			refunds.append(step)
		else:
			var at = costs.size()
			while at > 0 and costs[at - 1].net > net:
				at -= 1
			costs.insert(at, step)
	var money = {"cash": float(data.money), "insurance": float(data.insurance), "insuranceCost": 0.0, "cashCost": 0.0,
			"needed": 0.0}
	_payRepair(money, fixCost)
	var purchases = []
	for step in refunds + costs:
		purchases.append(step.slot)
		if step.net > PRECISION:
			money.needed = max(money.needed, step.net - money.cash)
		_payCash(money, step.net)
		time += step.time
		# The second purchase of one out and back is a refund, so it comes next (refunds first).
		if step.back != null:
			_payCash(money, step.back)
	var repairData = data.repair.duplicate()
	repairData.money = money.cash
	repairData.insurance = money.insurance
	repairData.reachOnly = true
	var repair = plan(repairData)
	# The repairs as presses makes them: the Replaces that need money first, cheapest first, each after its Fixes; then
	# the Replaces of systems beyond repair, which need none.
	var paid = []
	var free = []
	for id in repair.systems:
		if repair.systems[id].phase == PHASE_PAID_REPLACE:
			paid.append(id)
		else:
			free.append(id)
	for id in _byCost(paid, repair.systems) + free:
		var chosen = repair.systems[id]
		var clicksCost = chosen.fixes * float(data.repair.systems[id].fixPrice)
		_payRepair(money, clicksCost)
		if chosen.replace:
			var price = chosen.cost - clicksCost
			if chosen.phase == PHASE_PAID_REPLACE:
				money.needed = max(money.needed, price - (money.cash + money.insurance))
			_payRepair(money, price)
	return {
		"fixes": fixes,
		"purchases": purchases,
		"repair": repair,
		"insuranceCost": money.insuranceCost,
		"cashCost": money.cashCost,
		"time": time + repair.time,
		"needed": money.needed,
		"unreachable": data.unreachable + repair.unreachable,
	}

# Whether Park has anything to do.
static func isParkEmpty(park: Dictionary) -> bool:
	return park.fixes.empty() and park.purchases.empty() and isEmpty(park.repair)

# The Fix clicks before a piece is traded in: the number with the most gained on its trade-in less their price, the
# fewest on a tie, and none unless that is a gain. Each click must raise the condition; a step exists only where the
# row enables Fix (the data's header).
static func _tradeFixes(trade: Dictionary) -> int:
	var best = 0
	var bestGain = 0.0
	var steps = trade.steps
	for k in range(1, steps.size()):
		if not _raises(steps, k):
			break
		var gain = float(steps[k].value) - float(steps[0].value) - k * float(trade.fixPrice)
		if gain > bestGain + PRECISION:
			best = k
			bestGain = gain
	return best

# A repair's price paid as CurrentGame.gd changeMoney takes it: from the insurance as far as it goes, the rest from the
# cash (an insurance below zero adds to it, and is cleared).
static func _payRepair(money: Dictionary, amount: float):
	if amount <= 0:
		return
	var insurance = money.insurance
	if insurance >= amount:
		money.insurance -= amount
		money.insuranceCost += amount
	else:
		money.cash -= amount - insurance
		money.cashCost += amount - insurance
		money.insuranceCost += max(insurance, 0.0)
		money.insurance = 0.0

# A purchase, from the cash alone: a cost takes it, a refund (below zero) adds to it.
static func _payCash(money: Dictionary, amount: float):
	money.cash -= amount
	money.cashCost += amount

# The cheapest option that reaches the target, then the one with the fewest hours: Fixes alone, or j Fixes and then
# Replace (j stops where Fixes alone reach it, which costs less). Null when none does.
static func _cheapest(system: Dictionary, target: float):
	var best = _fixesTo(system, target)
	if not _reaches(system.replaced, target):
		return best
	var steps = system.steps
	for j in steps.size():
		if j > 0 and not _raises(steps, j):
			break
		if _reaches(steps[j].status, target):
			break
		if not steps[j].replace:
			continue
		var option = _option(j, true, j * system.fixPrice + float(steps[j].replacePrice),
				j * system.fixTime + system.replaceTime, true)
		if _better(option, best):
			best = option
	return best

# Fixes alone up to the target: the fewest clicks that reach it, each one raising the condition. Null when they don't.
static func _fixesTo(system: Dictionary, target: float):
	var steps = system.steps
	for k in range(1, steps.size()):
		if not _raises(steps, k):
			return null
		if _reaches(steps[k].status, target):
			return _option(k, false, k * system.fixPrice, k * system.fixTime, true)
	return null

# Where the target can't be reached, or its Replace can't be paid: Fixes alone up to the target if they get there,
# otherwise as many as raise the condition.
static func _fallback(system: Dictionary, target: float) -> Dictionary:
	var option = _fixesTo(system, target)
	if option != null:
		return option
	var steps = system.steps
	var k = 0
	while k + 1 < steps.size() and _raises(steps, k + 1):
		k += 1
	return _option(k, false, k * system.fixPrice, k * system.fixTime, _reaches(steps[k].status, target))

static func _option(fixes: int, replace: bool, cost: float, time: float, reaches: bool) -> Dictionary:
	return {"fixes": fixes, "replace": replace, "cost": cost, "time": time, "reaches": reaches}

static func _better(option: Dictionary, than) -> bool:
	if than == null or option.cost < than.cost - PRECISION:
		return true
	return option.cost <= than.cost + PRECISION and option.time < than.time

# Whether the click into step k raises the condition.
static func _raises(steps: Array, k: int) -> bool:
	return steps[k].status > steps[k - 1].status + STATUS_PRECISION

static func _reaches(status: float, target: float) -> bool:
	return status >= target - STATUS_PRECISION

# `ids` by their option's cost, cheapest first (a stable insertion sort: a static function has no object for
# sort_custom).
static func _byCost(ids: Array, chosen: Dictionary) -> Array:
	var out = []
	for id in ids:
		var at = out.size()
		while at > 0 and chosen[out[at - 1]].cost > chosen[id].cost:
			at -= 1
		out.insert(at, id)
	return out
