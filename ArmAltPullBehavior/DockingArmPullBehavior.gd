extends "res://ships/modules/DockingArm.gd"

# Systems that take targets in, tried in this order (see _entry).
const ENTRY_SYSTEMS = ["SYSTEM_GRINDER", "SYSTEM_EXCAVATOR"]

# The red line is this many chunk radii ahead of the front of the rotors / claws, so the chunk itself,
# not only its centre, stays clear of them (more than 1.0 leaves a margin of error).
const CHUNK_RADIUS_CLEARENCE_FACTOR = 4.0
# Where a mineral chunk's largest size is read from. All the game's mineral scenes
# (res://asteroids/mineral-*.tscn) have the same collision circle (radius 10.4048), and the game
# scales a chunk by 1.0 at most (`scaleMax` of mineral.gd), so one scene is enough.
const CHUNK_SCENE = "res://asteroids/mineral-fe-1.tscn"
# The radius found in all those scenes, used if the scene cannot be read (the game changed).
const CHUNK_RADIUS_FALLBACK = 10.4048

var _active = false # a salvage arm on a ship
var _radius = 0.0 # a mineral chunk's radius
var _clearance = 0.0 # how far ahead of the rotors / claws the red line is
var _sweep = null # a circle with the radius _clearance, swept along a path to test it against the hull
var _maxThrust = 0.0 # the arm's own, as maxThrust is switched off while the mod pulls the target
var _gamePull = false # the game's own pull is in charge (see _outside)
var _lastTarget = null

func _ready():
	_active = systemName == "SYSTEM_SALVAGE_ARM" and ship != null
	if _active:
		_maxThrust = maxThrust
		_radius = _readChunkRadius()
		if _radius <= 0.0:
			_radius = CHUNK_RADIUS_FALLBACK
		_clearance = CHUNK_RADIUS_CLEARENCE_FACTOR * _radius
		_sweep = CircleShape2D.new()
		_sweep.radius = _clearance

# Radius of the chunk's collision circle, read from the scene file without creating the chunk
# (0 if it cannot be read).
func _readChunkRadius() -> float:
	var scene = load(CHUNK_SCENE)
	if scene == null:
		return 0.0
	var state = scene.get_state()
	for i in state.get_node_count():
		if state.get_node_name(i) == "Collision":
			for j in state.get_node_property_count(i):
				if state.get_node_property_name(i, j) == "shape":
					var shape = state.get_node_property_value(i, j)
					return shape.radius if shape is CircleShape2D else 0.0
	return 0.0

# Where targets may be brought in: an opening in the red line, and a corridor as wide as the opening
# that runs on from it towards the ship, along the direction the arm faces (its local up).
# The opening is measured from tip to tip, between the points of the two rotors / claws of the ship's
# grinder or excavator that reach farthest ahead. The red line is the front of the rotors / claws moved
# forward by _clearance. The rotors and claws move (the beak opens), so this is measured every time.
# Returns [tip (the middle of the two), half the width of the opening, how far ahead of the tip the
# red line is], or null for a ship without a grinder or excavator with two rotors / claws (the
# OCP-209, for one): the mod leaves such ships to the game.
func _entry():
	var axis = Vector2(0, -1).rotated(global_rotation)
	var lateral = axis.rotated(PI / 2)
	for system in ENTRY_SYSTEMS:
		var s = ship.hasSystem(system)
		if s != null and "ref" in s and Tool.ov(s.ref):
			var a = s.ref.get("grinder1node") if system == "SYSTEM_GRINDER" else s.ref.find_node("Claw Left", true, false)
			var b = s.ref.get("grinder2node") if system == "SYSTEM_GRINDER" else s.ref.find_node("Claw Right", true, false)
			if Tool.ov(a) and Tool.ov(b):
				var tip = (a.global_position + b.global_position) / 2.0
				var fa = _frontPoint(a, axis)
				var fb = _frontPoint(b, axis)
				var half = abs((fa - fb).dot(lateral)) / 2.0
				var front = max(0.0, max((fa - tip).dot(axis), (fb - tip).dot(axis)))
				return [tip, half, front + _clearance]
	return null

# The point of a rotor or claw that reaches farthest ahead (along the axis), from its collision
# shapes (its own position if it has none).
func _frontPoint(part, axis: Vector2) -> Vector2:
	var best = part.global_position
	var bestAhead = - INF
	for c in part.get_children():
		var points = []
		if c is CollisionPolygon2D:
			for p in c.polygon:
				points.append(c.global_transform.xform(p))
		elif c is CollisionShape2D and c.shape is CircleShape2D:
			points.append(c.global_position + axis * c.shape.radius * c.global_scale.x)
		elif c is CollisionShape2D and c.shape is RectangleShape2D:
			for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				points.append(c.global_transform.xform(k * c.shape.extents))
		for p in points:
			if p.dot(axis) > bestAhead:
				best = p
				bestAhead = p.dot(axis)
	return best

# The game pulls a target in a straight line to its dock slot, well ahead of the red line, and only
# while the player feeds (the excavator command, `feed`) does it also push the target in along the
# direction the arm faces, through the opening. The mod takes a target over where that would drag it
# across the rotors / claws or the hull:
# - While feeding, the feed pushes a target straight back, so one that is not in line with the
#   opening (the corridor) would reach the red line outside the corridor, too fast to be stopped
#   before the rotors / claws. Any target outside the corridor, ahead of the red line or behind it,
#   is pulled straight to the middle of the opening (where the red line meets the corridor), and
#   handed back once it is in the corridor and no longer moving sideways faster than the pull itself
#   does a little (a chunk's radius, or half the opening if that is less) from the middle. The feed
#   then carries it straight in.
# - While not feeding, the game only takes a target out to the dock slot, which is safe from ahead of
#   the red line and from the corridor. Behind the red line and outside the corridor, the target is
#   left to the game as soon as the straight line to the dock slot is clear of the hull (see
#   _hitsHull).
# Where the straight line to the opening is not clear of the hull, the target is pulled straight
# forward instead, in the direction the arm faces, at least to a chunk's radius past the red line and
# on until that line is clear. Where the opening is narrower than a chunk (a closed beak, no
# corridor), or while not feeding, it is pulled straight forward to a chunk's radius past the red line,
# and a closed beak holds it there until it opens.
# The game takes a target back from the mod only once it is a little (as above) outside the corridor
# and, while not feeding, a chunk's radius behind the red line, so a target near the line or the
# corridor's edge is not handed back and forth.
# `entry` is _entry()'s result (it is measured here if not given).
# Returns the offset from the place the target is pulled to (the pull goes against it), or null while
# the game's pull is in charge or the ship is not covered by the mod.
func _outside(entry = null):
	if not Tool.ov(target):
		return null
	if entry == null:
		entry = _entry()
		if entry == null:
			return null
	var axis = Vector2(0, -1).rotated(global_rotation)
	var lateral = axis.rotated(PI / 2)
	var off = target.global_position - entry[0]
	var ahead = off.dot(axis) - entry[2] # how far ahead of the red line
	var outside = abs(off.dot(lateral)) - entry[1] # how far outside the corridor
	var open = entry[1] >= _radius
	var margin = min(_radius, entry[1] / 2.0)
	var feeding = feed > 0
	if target != _lastTarget:
		_lastTarget = target
		_gamePull = open and outside <= 0
		if not feeding and not _gamePull:
			_gamePull = ahead >= 0 or not _hitsHull(target.global_position, areaDockSlot.global_position)
	elif _gamePull:
		if (not open or outside > margin) and (feeding or (ahead < - _radius and _hitsHull(target.global_position, areaDockSlot.global_position))):
			_gamePull = false
	elif feeding:
		var sideways = abs((target.linear_velocity - _shipVelocityAt(target.global_position)).dot(lateral))
		_gamePull = open and outside <= 0 and sideways <= margin / easeDistance * maxVelocity
	else:
		_gamePull = ahead >= 0 or (open and outside <= 0) or not _hitsHull(target.global_position, areaDockSlot.global_position)
	if _gamePull:
		return null
	if feeding and open:
		var middle = entry[0] + axis * entry[2]
		if not _hitsHull(target.global_position, middle):
			return target.global_position - middle
		return - axis * max(_radius - ahead, _radius)
	return axis * (ahead - _radius)

# Whether a circle as big as the room the red line keeps (_clearance, CHUNK_RADIUS_CLEARENCE_FACTOR
# chunk radii), moved in a straight line from `from` to `to`, touches the ship's hull (the ship's own
# collision shapes) anywhere on the way, the start included.
func _hitsHull(from: Vector2, to: Vector2) -> bool:
	var start = Transform2D(0.0, from)
	for owner in ship.get_shape_owners():
		if not ship.is_shape_owner_disabled(owner):
			var xf = ship.global_transform * ship.shape_owner_get_transform(owner)
			for i in ship.shape_owner_get_shape_count(owner):
				if _sweep.collide_with_motion(start, to - from, ship.shape_owner_get_shape(owner, i), xf, Vector2()):
					return true
	return false

# The original pull, but towards the place given by _outside() instead of the dock slot, with the same
# thrust. `rel` is the ship's velocity at the target (see _shipVelocityAt) relative to the target's.
# Returns the impulse before its
# cost (see _cost).
# The game's formula aims at where the target is now, so it overshoots: by several metres at the dock
# slot, which does no harm there, but next to the rotors / claws it would. So this aims at where the
# target will be a moment later (`lead`): the time that makes the formula critically damped, worked
# out from the arm's own values (how fast it wants the target to move per unit of distance,
# maxVelocity / easeDistance, and how hard it pushes per unit of speed difference, thrust or
# targetMassThrust per mass, over easeDistance). The target then slows down in time and stops at the
# place.
func _pullTo(side: Vector2, rel: Vector2, delta) -> Vector2:
	var push = max(thrust, target.mass * targetMassThrust) / target.mass / easeDistance
	var want = maxVelocity / easeDistance
	var lead = max(0.0, (2.0 * sqrt(want / push) - 1.0) / want)
	side -= rel * lead
	var vd = rel - side.normalized() * clamp(side.length() / easeDistance, 0, 1) * maxVelocity
	var vadj = clamp((rel.length() - maxVelocity) / (maxVelocityConsidered - maxVelocity), 0, 1)
	var force = lerp(max(thrust, target.mass * targetMassThrust), fullThrust, vadj)
	return vd.normalized() * min(_maxThrust, force * vd.length() / easeDistance) * delta

# What the game's own pull costs (DockingArm.gd), for an impulse of size `scalar`: the energy it
# draws, capped by the arm's power limit; wear, which grows with the square of the power used; and
# the weakening of a worn or overheated arm. The last two only where the game applies them
# (damageModel, set for the salvage arm), with the game's own chance per frame (wearChance).
# Returns the size of the impulse that is actually delivered.
func _cost(scalar: float, rel: Vector2, delta) -> float:
	var p = scalar * powerDraw * max(stallDrawVelocityEquivalent, rel.length()) / 10
	if p <= 0:
		return 0.0
	var pl = getPowerLimit() * 1000.0
	var pg = ship.drawEnergy(min(p, pl * delta) if pl > 0 else p)
	if damageModel:
		if randf() < wearChance:
			var wpd = pow((pg / delta) / powerLimit, 2) * delta * powerLimit if powerLimit else pg
			ship.changeSystemDamage(key, "wear", wpd * powerWearRatio / wearChance, getDamageCapacity("wear"))
		scalar = lerp(scalar * randf(), scalar, wearCache) * overheatCache
	return scalar * pg / p

# The ship's velocity at `point`, as a point fixed to the ship: its own velocity plus what its turning
# adds there. The game's pull measures the target against its dock slot instead, 33.75 m ahead of the
# arm base; when the ship turns, that point moves far faster than a target close to the ship, and a
# target pulled to match it is flung away.
func _shipVelocityAt(point: Vector2) -> Vector2:
	var r = point - ship.global_position
	return ship.linear_velocity + Vector2(- r.y, r.x) * ship.angular_velocity

# Runs before the original _physics_process. Does nothing for a ship the mod does not cover (see
# _entry), so the game's own handling applies.
# While the mod pulls the target (see _outside), the original pull is switched off (maxThrust 0) and
# replaced by _pullTo, which costs what the game's pull would (_cost): energy, wear and weakening.
func _physics_process(delta):
	if not _active or delta <= 0:
		return
	var entry = _entry()
	if entry == null:
		maxThrust = _maxThrust
		return
	var side = _outside(entry)
	maxThrust = _maxThrust if side == null else 0.0
	if side != null and enabled and locked and not hardLocked and nodeArm.hasGrab() and Tool.claim(ship):
		if Tool.claim(target):
			var tv = target.linear_velocity
			var rel = _shipVelocityAt(target.global_position) - (tv if tv != null else Vector2())
			var impulse = _pullTo(side, rel, delta)
			if impulse.length() > 0:
				impulse *= _cost(impulse.length(), rel, delta) / impulse.length()
			target.apply_central_impulse(impulse)
			ship.apply_impulse(target.global_position - ship.global_position, - impulse)
			Tool.release(target)
		Tool.release(ship)
