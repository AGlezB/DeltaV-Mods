extends Reference

# MarketAdvisor's decision, kept apart from the screens so it can be tried on its own: given the market as the player
# sees it (the cash, the holdings, today's prices, and the chart's average and forecast prices) and the settings, the
# trades worth making now and those worth waiting for while the ship is in maintenance. Prices are E$ per kg, as the
# game keeps them (CurrentGame.getMineralMarketPricePerKg); holdings are whole tonnes, as the market's sliders trade them.
#
# Why these rules: buying and selling use the same price, with no fee (enceladus/MineralSellSlider.gd), and a price
# always drifts back towards its average (CurrentGame.gd getMineralPriceAdjustmentAt: 1 plus a deviation, and the
# player's own trading stops counting after 180 days). So cash is kept in the parking minerals furthest below their
# average and taken from those furthest above, and each part waits for a better day the chart shows inside the stay.
# What the Trade button bought to keep cash in (parked) is told apart from the ore brought back from dives, which is
# sold: a parking mineral can be both.

# How far below its average price a parking mineral's sale gets a warning, as a fraction of the average.
const WARN_BELOW_AVERAGE = 0.1

# `input`:
#   cash: the E$ in hand. floor: the cash reserve. low, high: its tolerance's range (Settings.gd floorRange): cash is
#     parked only above it, and parked tonnes sold only below it, either way back to the floor itself, so the next small
#     change in the cash, inside the range, trades nothing. parking: the minerals cash is kept in.
#   sellOre: whether stored ore is sold: what is held beyond the parked tonnes (all of it for a mineral that isn't a
#     parking one). minerals: every mineral, in the market's order.
#   held: whole tonnes by mineral. parked: the tonnes bought to keep cash in, by mineral (more than is held counts as
#     what is held). price: today's E$/kg by mineral. average: the chart's average E$/kg by parking mineral.
#   future: by mineral, the chart's forecast while the ship is in maintenance, [[timestamp, E$/kg], …], soonest first;
#     none means this is the last day to trade.
#   maxTonnes: the most of a mineral the market lets you hold. kgPerTonne: the kilograms a slider's tonne trades.
# Returns:
#   now: the trades to make now, one per mineral, sales first, each {mineral, from, to} in whole tonnes held (an ore
#     sale and a purchase of the same mineral make one trade). parked: the parked tonnes once `now` is done.
#   waits: the trades worth waiting for, each {mineral, when, sell}. cashAfter: the cash once `now` is done.
#   capped: there is cash to park, but every parking mineral is at maxTonnes. short: selling can't reach the range.
#   warnings: the parking minerals `now` sells more than WARN_BELOW_AVERAGE below their average.
static func plan(input: Dictionary) -> Dictionary:
	var start = input.held
	var held = {}
	var parked = {}
	for m in input.minerals:
		held[m] = int(start.get(m, 0))
		parked[m] = int(min(input.parked.get(m, 0), held[m])) if m in input.parking else 0
	var cash = float(input.cash)
	var kg = float(input.kgPerTonne)
	var waits = []
	var warnings = []
	var capped = false
	var short = false
	# What the ore left for a better day would fetch today.
	var pending = 0.0

	# Stored ore: sold today, unless the chart shows a higher price on a later day of the stay.
	if input.sellOre:
		for m in input.minerals:
			var stored = held[m] - parked[m]
			if stored < 1:
				continue
			var value = stored * kg * input.price[m]
			var best = _extreme(input.future.get(m, []), true)
			if best != null and best[1] > input.price[m]:
				waits.append({"mineral": m, "when": best[0], "sell": true})
				pending += value
			else:
				held[m] -= stored
				cash += value

	if cash > input.high:
		# Above the range, park the cash above the floor: the parking minerals cheapest against their average first,
		# each taking what the ones before it leave over, up to maxTonnes, so the last fills with its tonnes. Less than a
		# tonne of any of them to spare is nothing to do.
		var order = _byAverage(input, true)
		var spare = cash - input.floor
		var room = false
		var main = null
		for m in order:
			if held[m] < input.maxTonnes:
				room = true
				if main == null and spare >= kg * input.price[m]:
					main = m
		if not room:
			capped = spare >= _cheapestTonne(input, kg)
		elif main != null:
			var lowest = _extreme(input.future.get(main, []), false)
			if lowest != null and lowest[1] < input.price[main]:
				waits.append({"mineral": main, "when": lowest[0], "sell": false})
			else:
				for m in order:
					var perTonne = kg * input.price[m]
					var tonnes = int(min(floor(spare / perTonne), input.maxTonnes - held[m]))
					if tonnes > 0:
						held[m] += tonnes
						parked[m] += tonnes
						spare -= tonnes * perTonne
						cash -= tonnes * perTonne
	elif cash + pending < input.low:
		# Below the range, sell parked tonnes back up to the floor, unless the ore left for a better day brings the cash
		# into the range: the parking minerals dearest against their average first, in whole tonnes that don't
		# overshoot, keeping aside the one with the cheapest tonne; then that one's tonnes (and the next cheapest's, if
		# it runs out), so the cash lands within one of its tonnes above the floor.
		var order = _byAverage(input, false)
		var main = null
		for m in order:
			if parked[m] >= 1:
				main = m
				break
		if main == null:
			short = true
		else:
			var highest = _extreme(input.future.get(main, []), true)
			if highest != null and highest[1] > input.price[main]:
				waits.append({"mineral": main, "when": highest[0], "sell": true})
			else:
				var need = input.floor - cash - pending
				var topUp = _cheapestParked(input, parked, order)
				for m in order:
					if m == topUp:
						continue
					var perTonne = kg * input.price[m]
					var tonnes = int(min(floor(need / perTonne), parked[m]))
					if tonnes > 0:
						held[m] -= tonnes
						parked[m] -= tonnes
						need -= tonnes * perTonne
						cash += tonnes * perTonne
				while need > 0:
					var last = _cheapestParked(input, parked, order)
					if last == null:
						break
					var perTonne = kg * input.price[last]
					var tonnes = int(min(ceil(need / perTonne), parked[last]))
					held[last] -= tonnes
					parked[last] -= tonnes
					need -= tonnes * perTonne
					cash += tonnes * perTonne
				for m in order:
					if held[m] < start.get(m, 0) and input.price[m] < input.average.get(m, input.price[m]) * (1 - WARN_BELOW_AVERAGE):
						warnings.append(m)
				short = need > input.floor - input.low

	var sales = []
	var buys = []
	for m in input.minerals:
		var from = int(start.get(m, 0))
		if held[m] < from:
			sales.append({"mineral": m, "from": from, "to": held[m]})
		elif held[m] > from:
			buys.append({"mineral": m, "from": from, "to": held[m]})
	return {
		"now": sales + buys,
		"parked": parked,
		"waits": waits,
		"cashAfter": cash,
		"capped": capped,
		"short": short,
		"warnings": warnings,
	}

# The point of `points` with the highest price (or the lowest), or null without points.
static func _extreme(points: Array, highest: bool):
	var found = null
	for point in points:
		if found == null or (highest and point[1] > found[1]) or (not highest and point[1] < found[1]):
			found = point
	return found

# The parking minerals by today's price against their average, the cheapest first (or the dearest). A static function
# has no self for sort_custom, so each is inserted in place.
static func _byAverage(input: Dictionary, cheapestFirst: bool) -> Array:
	var order = []
	var ratio = {}
	for m in input.parking:
		var average = input.average.get(m, 0.0)
		ratio[m] = input.price[m] / average if average > 0 else 1.0
		var at = order.size()
		while at > 0 and (ratio[order[at - 1]] > ratio[m] if cheapestFirst else ratio[order[at - 1]] < ratio[m]):
			at -= 1
		order.insert(at, m)
	return order

# Of `order`, the mineral with parked tonnes left whose tonne costs least, or null.
static func _cheapestParked(input: Dictionary, parked: Dictionary, order: Array):
	var cheapest = null
	for m in order:
		if parked[m] >= 1 and (cheapest == null or input.price[m] < input.price[cheapest]):
			cheapest = m
	return cheapest

# The price of one tonne of the cheapest parking mineral.
static func _cheapestTonne(input: Dictionary, kg: float) -> float:
	var cheapest = INF
	for m in input.parking:
		cheapest = min(cheapest, kg * input.price[m])
	return cheapest
