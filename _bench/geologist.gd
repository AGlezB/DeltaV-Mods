extends Node

# The geologist, as the game's HUD runs one (hud/AutopilotOverlay.gd geologistMineralMarkers, hud/MineralMark.gd):
# every mineralMarkersEvery seconds it takes the next chunk, round robin, from the "unidentified" group, and marks it
# if it is a mineral within the geologist's range. A mark waits a random delay, then plays PopIn: at its
# identifyMinerals key the chunk's minerals go into the ship's identifiedObjects, at its identifyValue key its value,
# both off by the mark's one random error. Range and error follow the crew stats (CurrentGame.gd deriveStats:
# CREW_STATS_GEOLOGIST_RANGE, CREW_STATS_GEOLOGIST_PREDICTION). Prices are the game's base prices (no market drift).
# The bench draws from its own RandomNumberGenerator, so the marks don't disturb the game scripts' draws.

var ship
var field
var talent = 0.5
var experience = 0.5
var rng = RandomNumberGenerator.new()

var every = 0.5 # AutopilotOverlay.gd mineralMarkersEvery
var markerMax = 200 # AutopilotOverlay.gd mineralMarkerMax
var delay = 0.0 # MineralMark.gd delay
var random = 0.5 # MineralMark.gd random
var mineralsAt = 1.56 # MineralMark.tscn PopIn: identifyMinerals
var valueAt = 4.24 # MineralMark.tscn PopIn: identifyValue
var prices = {}

var _clock = 0.0
var _pick = 0
var _marks = {}

func setup(gameRoot: String, scenes, fieldNode, shipNode, seedValue: int):
	field = fieldNode
	ship = shipNode
	rng.seed = seedValue
	var overlay = field._text("hud/AutopilotOverlay.gd")
	every = float(field._scriptValue(overlay, "mineralMarkersEvery"))
	markerMax = int(field._scriptValue(overlay, "mineralMarkerMax"))
	var mark = field._text("hud/MineralMark.gd")
	delay = float(field._scriptValue(mark, "delay"))
	random = float(field._scriptValue(mark, "random"))
	var scene = scenes.parse("res://hud/MineralMark.tscn")
	for id in scene.sub:
		var sub = scene.sub[id]
		if sub.type != "Animation":
			continue
		for key in sub.props:
			if key.ends_with("/keys") and "identifyMinerals" in sub.props[key]:
				var keys = str2var(sub.props[key])
				if keys is Dictionary:
					for n in range(keys.values.size()):
						match keys.values[n].get("method", ""):
							"identifyMinerals":
								mineralsAt = keys.times[n]
							"identifyValue":
								valueAt = keys.times[n]
	prices = field.mineralPrices
	ship.connect("captured", self, "_onCaptured")

func rangePx() -> float:
	return ((100.0 if experience > 0 else 0.0) + 1000.0 * experience) * 10.0

func accuracy() -> float:
	return 1.0 - clamp(0.1 * (1 - talent) + 0.9 * talent, 0, 1)

func _physics_process(delta):
	_clock += delta
	while _clock >= every:
		_clock -= every
		_tick()
	for chunk in _marks.keys():
		var m = _marks[chunk]
		if not is_instance_valid(chunk):
			_marks.erase(chunk)
			continue
		m.t += delta
		if m.stage == 0 and m.t >= m.wait + mineralsAt:
			ship.addIdentifiedObject(chunk, m.minerals, 0)
			m.stage = 1
		if m.stage == 1 and m.t >= m.wait + valueAt:
			ship.addIdentifiedObject(chunk, m.minerals, m.value)
			m.stage = 2

func _tick():
	var r = rangePx()
	if r <= 0:
		return
	var pickable = get_tree().get_nodes_in_group("unidentified")
	if pickable.size() > 0:
		_pick += 1
		var i = pickable[_pick % pickable.size()]
		if is_instance_valid(i) and "inCargoHold" in i and not i.inCargoHold and i.has_method("getComposition") \
				and "lidarResponse" in i and i.lidarResponse > 1.0 and not ("specialPrice" in i and i.specialPrice > 0) \
				and i.get_parent() == field and not _marks.has(i):
			if ship.global_position.distance_to(i.global_position) < r:
				_mark(i)
	while _marks.size() > markerMax:
		var lowest = null
		for c in _marks:
			if lowest == null or _marks[c].value < _marks[lowest].value:
				lowest = c
		_unmark(lowest)

func _mark(chunk):
	var error = 1 + (rng.randf() - 0.5) * 2 * accuracy()
	var minerals = {}
	var value = 0.0
	var comp = chunk.getComposition()
	for material in comp:
		minerals[material] = round(comp[material] * 1000 * error)
		value += prices.get(material, 0.0) * comp[material] * 1000
	_marks[chunk] = {"t": 0.0, "wait": delay + rng.randf() * random, "stage": 0, "minerals": minerals,
		"value": value * error}
	if chunk.is_in_group("unidentified"):
		chunk.remove_from_group("unidentified")
	if not chunk.is_connected("tree_exiting", self, "_unmark"):
		chunk.connect("tree_exiting", self, "_unmark", [chunk])

func _unmark(chunk):
	_marks.erase(chunk)
	if is_instance_valid(ship):
		ship.removeIdentifiedObject(chunk)
	if is_instance_valid(chunk) and chunk.is_inside_tree() and not chunk.inCargoHold and not chunk.is_in_group("unidentified"):
		chunk.add_to_group("unidentified")

func _onCaptured(body):
	if _marks.has(body):
		_unmark(body)

func identifiedCount() -> int:
	var n = 0
	for c in _marks:
		if _marks[c].stage >= 1:
			n += 1
	return n
