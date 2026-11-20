extends KinematicBody2D

# The bench's ship: the parts of the game's ship (ships/ship-ctrl.gd) that its systems call, on a body that flies a
# fixed course (an ideal NDCI Autopilot: constant heading, constant velocity; moved every physics frame with
# sync_to_physics, so it pushes what it meets as a ship of far greater mass would). Energy, ammo deliveries and drone
# parts never run out, and nothing takes damage: the bench measures the drones, not the ship's budget. The target bus,
# the mineral filter and the hold's capture follow ship-ctrl.gd (lines cited at each). A body taken in leaves the
# simulation (removeOnCapture): the drones' job ends at the intake, and an MPU that keeps chunks (the Antonoff Ore
# Purifier) or processes them slowly would fill the hold within a run. Otherwise the hold keeps what it takes.

signal dummyChanged(how)
signal tuningChanged()
signal juryRigChanged()
signal damageChanged()
signal damageImpact(power, point, delta)
signal damageThermal(power, point, delta)
signal captured(body)
signal released(body) # a chunk the hold had taken in left it again
signal rockHit(body)

var linear_velocity = Vector2() # the course's velocity (px/s)
var mass = 150.0 # t: the ship's scene mass (scenario.gd), what a projectile hitting it reads
var config = {} # flat keys, as getConfig reads them ("weaponSlot.leftBay1.type")
var tuning = {} # by tuning key; a key missing here gives the game's default
var haulMinDistance = 400
var droneGatheringSpotRotation = 0.0
var maxMassAboard = 100
var cargoBodyGraceTime = 0.2
var dummy = false
var cutscene = false
var ageWithSeed = 0
var powerBalance = 1e12
var massDriverAmmo = 1e9
var droneParts = 1e9
var dronePartsUsed = 0.0
var droneQueue = []
var autopilotVelocityOffsetTarget = null
var physicsExclude = []
var externalSystems = []
var identifiedObjects = {}
var cargo = []
var excavator = null
var firing = [] # systems the ship keeps firing (the PDWs' fire command held, the excavator held open)
var removeOnCapture = true # a body taken in leaves the simulation (the drones' job ends at the intake), or stays

var _systemTargets = {}
var _systemTargetsLut = {}
var _cargoEnterQueue = {}
var _cargoEnterCount = {}

func _ready():
	set("motion/sync_to_physics", true)

func _physics_process(delta):
	position += linear_velocity * delta
	powerBalance = 1e12
	for s in firing:
		if is_instance_valid(s):
			s.fire(1)
	_processCargoBodyEntry(delta)

func isPlayerControlled() -> bool:
	return true

func isRealShip() -> bool:
	return false

func getConfig(key, default = null):
	return config.get(key, default)

func setConfig(key, value):
	config[key] = value

func getTunedValue(_system, tune, default):
	return tuning.get(tune, default)

func getSystemDamage(_key = null, _type = null):
	return 0.0

func changeSystemDamage(_key, _type, _amount, _capacity = null):
	return 0.0

func getCrewAdjustedJuryRigFactorForSystem(_key, _type):
	return 1.0

func drawEnergy(energy):
	return energy

func drawAmmo(kg, _really = true):
	return kg

func addAmmoCapacity(_kg):
	pass

func addDronesCapacity(_kg):
	pass

func drawDrones(kg, really = true):
	if really:
		dronePartsUsed += kg
	return kg

func apply_impulse(_offset, _impulse):
	pass

func youHit(_towards, _amount):
	pass

func getSystemsFiredBy(command: String, _one = false):
	return [excavator] if command == "x" and excavator != null else []

func aiGetDispositionTowards(_other):
	return {"support": 0.0, "hostility": 0.0, "fear": 0.0}

# The target bus (ship-ctrl.gd addSystemTarget / clearSystemTarget / isValidSystemTarget, 5547-5587): one system per
# target, so two plants never take the same chunk.
func addSystemTarget(systemN: Node, targetN: Node) -> bool:
	var system = hash(systemN)
	var target = hash(targetN)
	if not _systemTargets.has(target):
		if system in _systemTargetsLut and _systemTargetsLut[system] != target:
			if _systemTargets.get(_systemTargetsLut[system]) == system:
				_systemTargets.erase(_systemTargetsLut[system])
		_systemTargets[target] = system
		_systemTargetsLut[system] = target
		return true
	return _systemTargets[target] == system

# As the game's, which hashes the stored target hash again, so the entry it means to erase stays (ship-ctrl.gd 5560).
func clearSystemTarget(systemN: Node) -> bool:
	var system = hash(systemN)
	if system in _systemTargetsLut:
		var targetN = _systemTargetsLut[system]
		_systemTargets.erase(hash(targetN))
		_systemTargetsLut.erase(system)
		return true
	return false

func removeSystemTarget(systemN: Node, targetN: Node) -> bool:
	var system = hash(systemN)
	var target = hash(targetN)
	if _systemTargets.has(target) and _systemTargets[target] == system:
		_systemTargets.erase(target)
		_systemTargetsLut.erase(system)
		return true
	_systemTargetsLut.erase(system)
	return false

func isValidSystemTarget(systemN: Node, targetN: Node) -> bool:
	var target = hash(targetN)
	if _systemTargets.has(target):
		return _systemTargets[target] == hash(systemN)
	return true

# The player's branch of ship-ctrl.gd isValidMineralTarget (813-836).
func isValidMineralTarget(object: RigidBody2D, mineralConfig: Dictionary) -> bool:
	if "minerals" in mineralConfig and "minValue" in mineralConfig:
		var al = (object.lidarResponse if "lidarResponse" in object else 1.0) / 4.0
		var h = hash(object)
		if h in identifiedObjects:
			var i = identifiedObjects[h]
			if al >= mineralConfig.get("albedo", 0.0) / 100.0:
				if i[1] and (i[1] < mineralConfig.minValue):
					return false
			else:
				if i[1] < mineralConfig.minValue:
					return false
			for k in mineralConfig.minerals:
				if k in i[0]:
					return true
			return false
		return al >= mineralConfig.get("albedo", 0.0) / 100.0
	return true

# ship-ctrl.gd addIdentifiedObject (764-771): [minerals by kg, value, where, the object].
func addIdentifiedObject(object: RigidBody2D, minerals: Dictionary, value: float):
	identifiedObjects[hash(object)] = [minerals, value, object.global_position, object]

func removeIdentifiedObject(object):
	identifiedObjects.erase(hash(object))

# The hold (ship-ctrl.gd 5109-5117, 5187-5290): a body that stays in one of the hold's areas for cargoBodyGraceTime is
# taken in, once per area it is in.
func _on_CargoHoldArea_body_entered(body):
	if not body in _cargoEnterQueue:
		_cargoEnterQueue[body] = 0.0
	_cargoEnterCount[body] = _cargoEnterCount.get(body, 0) + 1

func _on_CargoHoldArea_body_exited(body):
	if body in _cargoEnterQueue:
		_cargoEnterCount[body] -= 1
		if _cargoEnterCount[body] <= 0:
			_cargoEnterQueue.erase(body)
			_cargoEnterCount.erase(body)
	else:
		_processExitingCargoBay(body)

func _processCargoBodyEntry(delta):
	for body in _cargoEnterQueue.keys():
		_cargoEnterQueue[body] += delta
		if _cargoEnterQueue[body] > cargoBodyGraceTime:
			_processEnteringCargoBay(body)
			_cargoEnterCount[body] -= 1
			if _cargoEnterCount[body] <= 0:
				_cargoEnterQueue.erase(body)
				_cargoEnterCount.erase(body)

func _processEnteringCargoBay(body):
	if not is_instance_valid(body) or body == self or body.get_parent() != get_parent():
		return
	if "equipment" in body and body.equipment:
		return
	if body.mass > maxMassAboard:
		return
	if autopilotVelocityOffsetTarget == body:
		autopilotVelocityOffsetTarget = null
	var first = not cargo.has(body)
	if first:
		cargo.append(body)
	if "inCargoHold" in body:
		body.inCargoHold += 1
	removeIdentifiedObject(body)
	droneQueue.erase(body)
	if first:
		emit_signal("captured", body)
	if removeOnCapture:
		cargo.erase(body)
		get_parent().kill(body)

func _processExitingCargoBay(body):
	if not is_instance_valid(body):
		cargo.erase(body)
		return
	if body == self or body.get_parent() != get_parent():
		return
	if cargo.has(body) and "inCargoHold" in body:
		if body.inCargoHold > 0:
			body.inCargoHold -= 1
		if body.inCargoHold <= 0:
			cargo.erase(body)
			emit_signal("released", body)

# A roid touching the hull ahead of the ship's middle while closing in: the course is too fast for the PDWs.
func _on_HullSensor_body_entered(body):
	if body.is_in_group("asteroid") and not ("fracturing" in body and body.fracturing):
		var local = to_local(body.global_position)
		var closing = (body.linear_velocity - linear_velocity).dot((global_position - body.global_position).normalized())
		if local.y < 0 and closing > 0:
			emit_signal("rockHit", body)
