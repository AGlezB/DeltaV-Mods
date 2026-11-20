extends "res://weapons/drone-plant.gd"

# Stage 2's candidate ranking for DroneAltPriorities: the game's scanForTarget (weapons/drone-plant.gd) with the
# vanilla flow kept (the scan interval, the USV-GOT priority queue first, every filter and the energy threshold that
# decide which chunks are eligible) and only the choice among the eligible chunks replaced. Installed over the game's
# script by main.gd (--candidate), with its parameters from --params (Engine meta benchParams):
#   f       points: each criterion divided by the best eligible chunk's, weighted and summed;
#           exp: each criterion divided by the best's (plus EXP_FLOOR), raised to its weight, multiplied
#   spd     rel: the speed term is the chunk's speed relative to the ship; exit: how soon it leaves the plant's reach
#   ws, wv, wm, wi   the weights of speed, ore value (base price per kg of the identified ore), ore mass (identified
#           kg), intake (how close the chunk is to the haul drones' gathering spot ahead of the excavator)
#   margin  the current target keeps its place unless another scores more than (1 + margin) times as much
#   scan    seconds between a haul plant's scans (vanilla when absent)
#   unid    1: a chunk the geologist hasn't identified yet (not in the ship's identifiedObjects) goes before any
#           identified one, whatever the scores; the scores order the chunks within each group
# Ties go to the vanilla score. Only the player's tug and haul plants change; maintenance drones and other ships keep
# the game's.

const EXP_FLOOR = 0.01 # what a criterion at 0 counts as in exp, so one missing figure doesn't zero a chunk
const EXIT_MIN = 0.5 # s: a chunk about to leave counts as leaving in this time, so urgency stays finite
const FILLER = "H2O"

var _params = {}

func _ready():
	_params = Engine.get_meta("benchParams") if Engine.has_meta("benchParams") else {}
	if droneFunction == "haul" and _params.has("scan"):
		scanEvery = float(_params.scan)

func _param(key, default):
	return _params.get(key, default)

func scanForTarget(delta):
	if not (droneFunction in ["tug", "haul"]) or ship == null or not ship.isPlayerControlled():
		return .scanForTarget(delta)
	scanProcess += delta
	if scanProcess <= scanEvery:
		if Tool.claim(target):
			var rel = "inCargoHold" in target and target.inCargoHold
			Tool.release(target)
			if rel:
				target = null
		return
	var dmin = getRangeMin() * 10
	var dmax = getRangeMax() * 10
	scanProcess = 0
	var previous = target
	target = null
	if _fromQueue():
		return
	var space = ship.get_parent()
	var eligible = []
	for t in getPossibleTargets():
		if not Tool.claim(t):
			continue
		var check = _eligible(t, space, dmin, dmax)
		if check != null:
			eligible.append(_features(t, check))
		Tool.release(t)
	target = _choose(eligible, previous)

# The USV-GOT's priority queue, as the game's scanForTarget takes it: the first queued object that still needs work.
func _fromQueue() -> bool:
	if not ship.droneQueue:
		return false
	for t in ship.droneQueue:
		if not Tool.claim(t):
			continue
		var dist = global_position.distance_to(t.global_position)
		var ok = dist <= laserRange and not (sanbus and not ship.isValidSystemTarget(self, t))
		if ok and droneFunction == "haul" and t == ship.autopilotVelocityOffsetTarget:
			ok = false
		var check = 0.0
		if ok:
			if droneFunction == "haul":
				var desired = desiredVelicityFor(t)
				check = t.mass * pow((desired - t.linear_velocity).length(), 2) / dist
			else:
				var v = t.linear_velocity.length()
				ok = v >= minVelocityToTarget
				check = t.mass * pow(v, 2)
		Tool.release(t)
		if ok and check > minEnergyToTarget:
			target = t
			return true
	return false

# The game's filters for the plant's function; the vanilla score when the object is eligible, null when not.
func _eligible(t, space, dmin, dmax):
	if t.get_parent() != space:
		return null
	if "inCargoHold" in t and t.inCargoHold:
		return null
	if not t is RigidBody2D:
		return null
	if droneFunction == "haul" and t == ship.autopilotVelocityOffsetTarget:
		return null
	var dist = global_position.distance_to(t.global_position)
	if dist > dmax or dist < dmin:
		return null
	if droneFunction == "tug" and t.linear_velocity.length() < minVelocityToTarget:
		return null
	if sanbus and not ship.isValidSystemTarget(self, t):
		return null
	if mineralTargetting and not ship.isValidMineralTarget(t, mineralConfig):
		return null
	var check
	if droneFunction == "haul":
		var desired = desiredVelicityFor(t)
		check = t.mass * pow((desired - t.linear_velocity).length(), 2) / dist
	else:
		check = t.mass * pow(t.linear_velocity.length(), 2)
	return check if check > minEnergyToTarget else null

func _features(t, check) -> Dictionary:
	var rel = t.linear_velocity - ship.linear_velocity
	var speed = rel.length()
	if _param("spd", "rel") == "exit":
		speed = 1.0 / max(_exitTime(t.global_position - global_position, rel), EXIT_MIN)
	var value = 0.0
	var mass = 0.0
	var identified = ship.identifiedObjects.get(hash(t))
	if identified != null:
		for m in identified[0]:
			if m != FILLER:
				mass += float(identified[0][m])
				value = max(value, CurrentGame.mineralPrices.get(m, 0.0))
	var intake = 0.0
	if excavator != null and droneFunction == "haul":
		var spot = excavator.global_position + haulGatherSpot.rotated(excavator.global_rotation)
		intake = 1.0 - clamp(t.global_position.distance_to(spot) / max(1.0, getRangeMax() * 10), 0, 1)
	return {"t": t, "check": check, "f": [speed, value, mass, intake], "unidentified": identified == null}

# Seconds until a point at offset d from the plant, moving at u relative to it, leaves the plant's reach.
func _exitTime(d: Vector2, u: Vector2) -> float:
	var reach = min(laserRange, getRangeMax() * 10)
	var a = u.dot(u)
	var c = d.dot(d) - reach * reach
	if c >= 0:
		return 0.0
	if a <= 0.000001:
		return INF
	var b = 2.0 * d.dot(u)
	return (-b + sqrt(b * b - 4.0 * a * c)) / (2.0 * a)

func _choose(eligible: Array, previous):
	if eligible.empty():
		return null
	var weights = [float(_param("ws", 0)), float(_param("wv", 0)), float(_param("wm", 0)), float(_param("wi", 0))]
	var best = [0.0, 0.0, 0.0, 0.0]
	for e in eligible:
		for i in range(4):
			best[i] = max(best[i], e.f[i])
	var multiply = _param("f", "points") == "exp"
	var margin = float(_param("margin", 0))
	var unidentifiedFirst = float(_param("unid", 0)) > 0
	var pick = null
	var pickScore = -INF
	var pickCheck = -INF
	var pickGroup = -1
	for e in eligible:
		var group = 1 if unidentifiedFirst and e.unidentified else 0
		if group < pickGroup:
			continue
		if group > pickGroup:
			pick = null
			pickScore = -INF
			pickCheck = -INF
			pickGroup = group
		var score = 1.0 if multiply else 0.0
		for i in range(4):
			var n = e.f[i] / best[i] if best[i] > 0 else 0.0
			if multiply:
				score *= pow(n + EXP_FLOOR, weights[i])
			else:
				score += weights[i] * n
		if e.t == previous:
			score *= 1.0 + margin
		if score > pickScore or (score == pickScore and e.check > pickCheck):
			pick = e.t
			pickScore = score
			pickCheck = e.check
	return pick
