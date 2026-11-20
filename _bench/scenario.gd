extends Reference

# Builds the control scenario's ship from the game's own scenes (ships/ATK225.tscn and what it mounts): the
# Antonoff-Titan K225's hull, its excavator (the real claws, pinned and sprung, held open as a double tap holds them),
# the Rusatom-Antonoff MPU's walls inside the hold, the hold's two capture areas, the PDWs in the middle hardpoints and
# the MLF Haul Drones in the front bays. The THI containers in the other bays are only their hulls, where the docked
# pods sit (POD_SPOTS: the DockingArm that holds them isn't simulated).

const ATK225 = "res://ships/ATK225.tscn"
const STORAGE_POD = "res://ships/drone/StoragePod.tscn"
const MPU = "MineralProcessingUnit_FSO" # the Rusatom-Antonoff MPU's placeholder in ATK225.tscn
const HOLD_AREAS = ["CargoHoldArea", "CargoHoldAreaHull"]
const TURRET_HOLDERS = ["weapon-left", "weapon-right"] # middleLeft, middleRight
const PDW_SYSTEMS = {"ONMWG": ["SYSTEM_PDMWG-L", "SYSTEM_PDMWG-R"], "NDPT": ["SYSTEM_PDT-L", "SYSTEM_PDT-R"]}
const HAUL_HOLDERS = ["weapon-left-back", "weapon-right-back"] # leftBay1, rightBay1: the front bays
const HAUL_SYSTEM = "SYSTEM_DND_HAUL"
const POD_SPOTS = [Vector2(-113, -90), Vector2(113, -90), Vector2(-113, 123), Vector2(113, 123)]
const POD_ROTATION = PI
const SENSOR_GROWTH = 1.03 # the hull sensor's polygon is this much larger than the hull, to see a roid touching it

# -> {ship, plants, turrets}
static func buildShip(scenes, field, shipScript: Script, pdw: String, tuning: Dictionary, drones: bool) -> Dictionary:
	var atk = scenes.tree(ATK225)
	var ship = KinematicBody2D.new()
	ship.set_script(shipScript)
	ship.name = "Ship"
	ship.collision_layer = int(scenes.value(atk, "collision_layer", 1))
	ship.collision_mask = int(scenes.value(atk, "collision_mask", 1))
	ship.haulMinDistance = scenes.value(atk, "haulMinDistance", ship.haulMinDistance)
	ship.mass = scenes.value(atk, "mass", ship.mass)
	ship.droneGatheringSpotRotation = scenes.value(atk, "droneGatheringSpotRotation", 0.0)
	var ctrl = field._text("ships/ship-ctrl.gd")
	ship.maxMassAboard = field._scriptValue(ctrl, "maxMassAboard")
	ship.cargoBodyGraceTime = field._scriptValue(ctrl, "cargoBodyGraceTime")
	ship.tuning = tuning
	field.add_child(ship)
	field.ship = ship
	CurrentGame.playerShip = ship
	ship.physicsExclude.append(ship)

	var hullDesc = scenes.child(atk, "Collider")
	ship.add_child(scenes.build(hullDesc))
	var sensor = Area2D.new()
	sensor.name = "HullSensor"
	sensor.collision_layer = 0
	sensor.collision_mask = 1
	sensor.monitorable = false
	var poly = scenes.build(hullDesc)
	poly.scale *= SENSOR_GROWTH
	sensor.add_child(poly)
	ship.add_child(sensor)
	sensor.connect("body_entered", ship, "_on_HullSensor_body_entered")

	var mpu = scenes.child(atk, MPU)
	if mpu != null:
		ship.add_child(scenes.build(scenes.expand(mpu)))
	for name in HOLD_AREAS:
		var area = scenes.build(scenes.child(atk, name))
		ship.add_child(area)
		area.connect("body_entered", ship, "_on_CargoHoldArea_body_entered")
		area.connect("body_exited", ship, "_on_CargoHoldArea_body_exited")
	var podCollider = scenes.child(scenes.tree(STORAGE_POD), "Collider")
	for spot in POD_SPOTS:
		var pod = scenes.build(podCollider)
		pod.position = spot
		pod.rotation = POD_ROTATION
		ship.add_child(pod)

	var bumperDesc = scenes.child(atk, "Front Bumper")
	var bumper = scenes.build(bumperDesc)
	ship.add_child(bumper)
	scenes.connectSignals(bumperDesc, bumper)
	ship.excavator = bumper
	ship.firing.append(bumper)
	for claw in ["Claw Holder/Claw Left", "Claw Holder/Claw Right"]:
		var c = bumper.get_node_or_null(claw)
		if c != null:
			ship.physicsExclude.append(c)

	var turrets = []
	if pdw in PDW_SYSTEMS:
		for i in range(TURRET_HOLDERS.size()):
			var t = _mount(scenes, ship, atk, TURRET_HOLDERS[i], PDW_SYSTEMS[pdw][i])
			turrets.append(t)
			if not t.autoFire:
				ship.firing.append(t)
	var plants = []
	if drones:
		for holder in HAUL_HOLDERS:
			plants.append(_mount(scenes, ship, atk, holder, HAUL_SYSTEM))
	return {"ship": ship, "plants": plants, "turrets": turrets}

# A system on a hardpoint: the hardpoint's place and slot from ATK225.tscn, the system from WeaponSlot.tscn's
# placeholder with the ship's overrides.
static func _mount(scenes, ship, atk: Dictionary, holderName: String, system: String) -> Node:
	var holder = scenes.child(atk, holderName)
	var slot = Node2D.new()
	slot.set_script(load("res://bench/slot.gd"))
	slot.name = holderName
	slot.position = scenes.value(holder, "position", Vector2())
	slot.rotation = scenes.value(holder, "rotation", 0.0)
	slot.slot = scenes.value(holder, "slot", holderName)
	slot.type = system
	slot.key = holderName
	ship.config["weaponSlot.%s.type" % slot.slot] = system
	ship.add_child(slot)
	var desc = scenes.expand(scenes.child(holder, system))
	var node = scenes.build(desc)
	slot.add_child(node)
	scenes.connectSignals(desc, node)
	return node
