extends Reference

# Builds what the arm works in, the way the game nests it: a field (the ships' parent; DockingArm.gd only takes
# targets that are the ship's siblings) holding the Eagle-Prospector-VP stub, its weapon slot with the AR-1500
# arm (the game's DockingArm.gd, extended by whatever mods were loaded), and its grinder.
# The grinder's rotors are plain nodes with their collision shapes: the mods read the shapes, nothing collides
# with them (as in the claude.ai tests). The hull does collide (the ship is a StaticBody2D).

const VP = preload("res://harness/vp_data.gd")

# Returns {"field", "ship", "slot", "arm", "grinder"}. `options`: "shipMass" (t), "grinder" (false = a ship
# without one), "systemName" (another arm type).
static func build(parent: Node, options = {}) -> Dictionary:
	var field = Node2D.new()
	field.name = "Field"
	var ship = StaticBody2D.new()
	ship.set_script(load("res://harness/ship.gd"))
	ship.name = "Ship"
	ship.mass = options.get("shipMass", VP.SHIP_MASS)
	field.add_child(ship)
	var hull = CollisionPolygon2D.new()
	hull.name = "Collider"
	hull.polygon = PoolVector2Array(VP.HULL)
	ship.add_child(hull)

	var grinder = null
	if options.get("grinder", true):
		grinder = Node2D.new()
		grinder.set_script(load("res://harness/grinder.gd"))
		grinder.name = "Grinder"
		grinder.position = VP.GRINDER_POSITION
		ship.add_child(grinder)
		var rotors = []
		for i in VP.GRINDER_ARMS.size():
			var holder = Node2D.new()
			holder.name = ["ArmLeft", "RightArm"][i]
			holder.position = VP.GRINDER_ARMS[i][0]
			holder.rotation = VP.GRINDER_ARMS[i][1]
			grinder.add_child(holder)
			var rotor = Node2D.new()
			rotor.name = "Grinder"
			rotor.position = VP.ROTOR_POSITION
			holder.add_child(rotor)
			var shape = CollisionShape2D.new()
			shape.shape = CircleShape2D.new()
			shape.shape.radius = VP.ROTOR_RADIUS
			rotor.add_child(shape)
			rotors.append(rotor)
		grinder.grinder1node = rotors[0]
		grinder.grinder2node = rotors[1]
		ship.systems["SYSTEM_GRINDER"] = {"name": "SYSTEM_GRINDER", "status": 100.0, "ref": grinder}

	var slot = Node2D.new()
	slot.set_script(load("res://harness/weapon_slot.gd"))
	slot.name = "WeaponSlot"
	slot.position = VP.WEAPON_SLOT_POSITION
	ship.add_child(slot)
	ship.systems["SYSTEM_SALVAGE_ARM"] = {"name": "SYSTEM_SALVAGE_ARM", "status": 100.0, "ref": slot}

	var arm = _arm(options.get("systemName", "SYSTEM_SALVAGE_ARM"))
	slot.add_child(arm)
	parent.add_child(field)
	return {"field": field, "ship": ship, "slot": slot, "arm": arm, "grinder": grinder}

# The arm's node tree as DockingArm.tscn + SalvageArm.tscn build it (the names DockingArm.gd and Arm.gd look up).
static func _arm(systemName) -> Node2D:
	var arm = Node2D.new()
	arm.set_script(load("res://ships/modules/DockingArm.gd"))
	arm.name = "WeaponSlot_SYSTEM_SALVAGE_ARM"
	arm.position = VP.ARM_POSITION
	arm.scale = VP.ARM_SCALE
	for property in VP.ARM_PROPERTIES:
		arm.set(property, VP.ARM_PROPERTIES[property])
	arm.idleAtReady = 0.0
	arm.systemName = systemName

	var area = Area2D.new()
	area.name = "DockArea"
	area.position = VP.DOCK_AREA_POSITION
	area.collision_mask = VP.DOCK_AREA_MASK
	arm.add_child(area)
	var areaShape = CollisionShape2D.new()
	areaShape.position = VP.DOCK_AREA_SHAPE_POSITION
	areaShape.shape = RectangleShape2D.new()
	areaShape.shape.extents = VP.DOCK_AREA_EXTENTS
	area.add_child(areaShape)

	var dockSlot = Node2D.new()
	dockSlot.name = "DockSlot"
	dockSlot.position = VP.DOCK_SLOT_POSITION
	arm.add_child(dockSlot)
	var joint = PinJoint2D.new()
	joint.name = "Joint"
	dockSlot.add_child(joint)
	var restSlot = Node2D.new()
	restSlot.name = "RestSlot"
	restSlot.position = VP.REST_SLOT_POSITION
	arm.add_child(restSlot)
	for sound in ["Lock", "Release", "Transfer", "Actuation"]:
		var player = AudioStreamPlayer.new()
		player.name = sound
		arm.add_child(player)

	var sections = Node2D.new()
	sections.set_script(load("res://ships/modules/Arm.gd"))
	sections.name = "Arm"
	sections.rotation = VP.ARM_NODE_ROTATION
	sections.maxVelocity = VP.ARM_NODE_MAX_VELOCITY
	sections.flickerLights = false
	arm.add_child(sections)
	for part in ["Target", "A"]:
		var node = Node2D.new()
		node.name = part
		sections.add_child(node)
	var b = Node2D.new()
	b.name = "B"
	sections.get_node("A").add_child(b)
	var tip = Node2D.new()
	tip.name = "Arm"
	b.add_child(tip)
	var spotlight = Node2D.new()
	spotlight.set_script(load("res://harness/spotlight.gd"))
	spotlight.name = "Spotlight"
	b.add_child(spotlight)
	var blink = AnimationPlayer.new()
	blink.name = "BP"
	sections.add_child(blink)
	return arm

# A mineral chunk: a rigid body with the chunk's collision circle, no gravity or damping, in the field.
static func chunk(field: Node, position: Vector2, mass: float, velocity = Vector2()) -> RigidBody2D:
	var body = RigidBody2D.new()
	body.name = "Chunk"
	body.gravity_scale = 0
	body.linear_damp = 0
	body.angular_damp = 0
	body.mass = mass
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = VP.CHUNK_RADIUS
	body.add_child(shape)
	body.position = position
	body.linear_velocity = velocity
	field.add_child(body)
	return body

# The rotors' centres in ship coordinates, from the same transforms the rig uses.
static func rotorCentres() -> Array:
	var centres = []
	for a in VP.GRINDER_ARMS:
		centres.append(VP.GRINDER_POSITION + a[0] + VP.ROTOR_POSITION.rotated(a[1]))
	return centres
