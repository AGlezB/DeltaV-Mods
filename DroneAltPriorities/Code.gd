extends "res://weapons/drone-plant.gd"

# DroneAltPriorities: which chunk the player's MPI Tug drones and MLF Haul Drones work on first, when the switch on the
# mod's OMS tab is on.
#
# Each plant works on one target at a time, and every scanEvery seconds it picks again (scanForTarget). The game's
# rule: the USV-GOT recon drone's priority queue first; otherwise, among the chunks in the plant's reach that pass its
# filters (its Geologist-tab row, the ship's target bus, the Tuning range), haul plants take the one with the most
# mass x |desired - velocity|^2 / distance, tug plants the most mass x speed^2. That sends the drones after heavy, fast
# chunks they rarely stop before they leave, a new pick throws away the drones in flight (DroneLaunchManager.gd
# _setTargetNode), and the bias meant to keep a plant on its target never applies (scanForTarget clears `target`
# before reading it). So light, valuable chunks, Be above all, escape while the drones are busy.
#
# With the switch on, the queue and which chunks are eligible stay the game's; only the choice among them changes. Each
# chunk gets three criteria, from what the player sees: its ore value (the base price per kg of the best ore the
# geologist found in it), its ore mass (the kg of ore found), and, for haul plants, how close it is to the haul drones'
# gathering spot ahead of the excavator (1 there, 0 at the plant's reach). Each criterion is divided by the best
# eligible chunk's, plus SCORE_FLOOR, raised to its weight (Settings.gd), and multiplied: weight 0 ignores a criterion,
# and with value and mass at the same weight the score follows the chunk's ore value. A chunk the geologist hasn't
# identified has no value or mass yet: while either counts, it comes after the identified ones, by intake. The current
# target keeps its place unless another scores more than 1 + KEEP_TARGET_MARGIN times as much; equal scores go to the
# game's rule.
# The ranking, the criteria and the defaults were chosen on the drone bench (_bench\README.md), which simulates the
# game's own drone plants.
#
# Stacking: the parent's _ready etc. are never called (Godot runs every level by itself); scanForTarget falls through
# to the parent with `.scanForTarget()` where the mod doesn't apply (maintenance drones, other ships, switch off); new
# members start with `_`.

const DroneAltPriorities = preload("res://DroneAltPriorities/Settings.gd")

# What a criterion at 0 counts as, so that one missing figure doesn't zero a chunk's whole score.
const SCORE_FLOOR = 0.01
# The current target keeps its place unless another chunk scores more than (1 + this) times as much.
const KEEP_TARGET_MARGIN = 1.0

var _droneAltPrioritiesSettings = null

func scanForTarget(delta):
	if not (droneFunction in ["tug", "haul"]) or ship == null or not ship.isPlayerControlled() or not _droneAltPriorities().isEnabled():
		return .scanForTarget(delta)
	scanProcess += delta
	if scanProcess <= scanEvery:
		# Between picks, as the game: a target taken into the hold is dropped.
		if Tool.claim(target):
			var inHold = "inCargoHold" in target and target.inCargoHold
			Tool.release(target)
			if inHold:
				target = null
		return
	var dmin = getRangeMin() * 10
	var dmax = getRangeMax() * 10
	scanProcess = 0
	var previous = target
	target = null
	if _dapFromQueue():
		return
	var space = ship.get_parent()
	var eligible = []
	for t in getPossibleTargets():
		if not Tool.claim(t):
			continue
		var check = _dapCheck(t, space, dmin, dmax)
		if check != null:
			eligible.append(_dapCriteria(t, check))
		Tool.release(t)
	target = _dapChoose(eligible, previous)

func _droneAltPriorities():
	if _droneAltPrioritiesSettings == null:
		_droneAltPrioritiesSettings = DroneAltPriorities.new(ship)
	return _droneAltPrioritiesSettings

# The USV-GOT's priority queue, as the game's scanForTarget takes it: the first queued object that still needs work.
func _dapFromQueue() -> bool:
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
				check = t.mass * pow((desiredVelicityFor(t) - t.linear_velocity).length(), 2) / dist
			else:
				var v = t.linear_velocity.length()
				ok = v >= minVelocityToTarget
				check = t.mass * pow(v, 2)
		Tool.release(t)
		if ok and check > minEnergyToTarget:
			target = t
			return true
	return false

# The game's filters for the plant's function; the game's score when the object is eligible, null when it isn't.
func _dapCheck(t, space, dmin, dmax):
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
		check = t.mass * pow((desiredVelicityFor(t) - t.linear_velocity).length(), 2) / dist
	else:
		check = t.mass * pow(t.linear_velocity.length(), 2)
	return check if check > minEnergyToTarget else null

# A chunk's criteria, in Settings.gd WEIGHTS order: ore value, ore mass, intake. Only ore counts: the minerals the HUD
# can mark (CurrentGame.traceMinerals), not the water around them.
func _dapCriteria(t, check) -> Dictionary:
	var value = 0.0
	var ore = 0.0
	var identified = ship.identifiedObjects.get(hash(t))
	if identified != null and identified[0] is Dictionary:
		for mineral in identified[0]:
			if mineral in CurrentGame.traceMinerals:
				ore += float(identified[0][mineral])
				value = max(value, CurrentGame.mineralPrices.get(mineral, 0.0))
	var intake = 0.0
	if droneFunction == "haul" and excavator != null:
		var spot = excavator.global_position + haulGatherSpot.rotated(excavator.global_rotation)
		intake = 1.0 - clamp(t.global_position.distance_to(spot) / max(1.0, getRangeMax() * 10), 0, 1)
	return {"target": t, "check": check, "criteria": [value, ore, intake]}

func _dapChoose(eligible: Array, previous):
	if eligible.empty():
		return null
	var settings = _droneAltPriorities()
	var weights = []
	for key in settings.keys():
		weights.append(settings.getWeight(key))
	var best = []
	for i in weights.size():
		best.append(0.0)
		for e in eligible:
			best[i] = max(best[i], e.criteria[i])
	var pick = null
	var pickScore = -INF
	var pickCheck = -INF
	for e in eligible:
		var score = 1.0
		for i in weights.size():
			var share = e.criteria[i] / best[i] if best[i] > 0 else 0.0
			score *= pow(share + SCORE_FLOOR, weights[i])
		if e.target == previous:
			score *= 1.0 + KEEP_TARGET_MARGIN
		if score > pickScore or (score == pickScore and e.check > pickCheck):
			pick = e.target
			pickScore = score
			pickCheck = e.check
	return pick
