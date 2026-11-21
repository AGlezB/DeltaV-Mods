extends "res://ships/modules/DockingArm.gd"

# Systems that take targets in, tried in this order (see _entry).
const ENTRY_SYSTEMS = ["SYSTEM_GRINDER", "SYSTEM_EXCAVATOR"]

# The red line is this many chunk radii ahead of the front of the rotors / claws. While feeding, a target that comes
# from the side or at a steep angle goes in on a straight path from there (see _pathAt); while not feeding, a target
# behind it beside the hull is moved forward first. It is also the room kept from the hull (see _hitsHull).
const CHUNK_RADIUS_CLEARENCE_FACTOR = 4.0
# Where a mineral chunk's largest size is read from. All the game's mineral scenes
# (res://asteroids/mineral-*.tscn) have the same collision circle (radius 10.4048), and the game
# scales a chunk by 1.0 at most (`scaleMax` of mineral.gd), so one scene is enough.
const CHUNK_SCENE = "res://asteroids/mineral-fe-1.tscn"
# The radius found in all those scenes, used if the scene cannot be read (the game changed).
const CHUNK_RADIUS_FALLBACK = 10.4048
# How fast, per second, the mod closes the difference between the speed it wants the target to move at (relative to
# the hull: along its path while feeding, towards the place it is held at otherwise) and the speed it moves at (see
# _pullTo). Near a place it is held at, the speed it wants slows down a quarter of this per second of distance, which
# brings it there without overshooting (critically damped). Tuned value.
const RESPONSE_RATE = 8.0
# Over how many seconds the ship's measured acceleration is smoothed (see _measureShip), so a knock on the hull does not
# jerk the target. Tuned value.
const ACCEL_SMOOTHING = 0.05
# The share of the arm's strength left over, after it holds the target against the ship's motion, that the target's own
# movement relative to the hull may use: to brake before the place it is held at, and against the sideways throw a
# turning ship gives a moving target (see _parkVelocity). Tuned value.
const BRAKE_SHARE = 0.5
# While the ship turns or accelerates backwards, a target lighter than this (in the game's mass units, tonnes: every
# mineral chunk, lifepod, AI core, drone and frozen body; no ship) is held closer to the ship than the dock slot (see
# _updateCloser). A heavier one, such as a ship, stays at the dock slot: brought closer, it would hit the ship holding
# it.
const CLOSER_MASS_LIMIT = 10.0
# The share of the arm's limits at which a light target is held all the way in (see _updateCloser): of the fastest turn
# it can hold the target through at the dock slot, and of the most backward acceleration it can make up for. Below 1,
# so the target moves in while the arm still has strength to spare: moving in while the ship turns takes a sideways
# push, and near the dock slot's limit there is none left. Tuned value.
const CLOSER_FULL_SHARE = 0.3
# How many seconds the place a target is held at takes to go back out to the dock slot once the ship stops turning and
# accelerating backwards (see _updateCloser), so a ship turning back and forth doesn't send the target out and in at
# every change. Tuned value.
const CLOSER_RELEASE_TIME = 4.0
# While feeding, a target outside the straight zone heads for the join point turned aside by this fraction of the angle
# it still has to come round to be in line with the steepest straight path (see _pathAt). 1 gives circles through the
# join point; less gives paths that are straighter far away and bend more near the join point. Tuned value: below it the
# last bend gets too tight for the arm, and targets touch a rotor's outer half (the author's path simulation, a 3 t
# chunk on the Eagle-Prospector-VP).
const TURN_FACTOR = 0.5
# How close to the join point, in chunk radii, a target that has come round to within the margin of the steepest
# straight path is taken along that path (see _pathAt).
const JOIN_DISTANCE_FACTOR = 2.0

var _active = false # a salvage arm on a ship
var _radius = 0.0 # a mineral chunk's radius
var _clearance = 0.0 # how far ahead of the rotors / claws the red line is
var _sweep = null # a circle with the radius _clearance, swept along a path to test it against the hull
var _body = null # a circle as big as a chunk, swept along the way a fed target is about to go (see _outside)
var _maxThrust = 0.0 # the arm's own, as maxThrust is switched off while the mod pulls the target
var _parking = false # not feeding: the target is held at the dock slot, not moved forward first (see _outside)
var _feedIn = false # feeding: the target is in line with the opening and pulled straight in (see _pathAt)
var _passThrough = false # the place _outside gives is only to be passed on the way, not stopped at (see _pullTo)
var _way = null # feeding: the path the target is on (see _pathAt), or null
var _lastTarget = null
var _shipSeen = false # the ship's velocity was read last frame (see _measureShip)
var _lastShipVelocity = Vector2()
var _lastImpulse = Vector2() # the impulse the mod gave the target last frame (the ship got the opposite)
var _shipAccel = Vector2() # the ship's acceleration from everything but the mod's own pull, smoothed
var _closer = 0.0 # how far the place the target is held at has moved in from the dock slot, 0 to 1 (see _updateCloser)
var _parkAt = Vector2() # not feeding: the place the target is held at (see _outside)
var _claws = {} # each excavator's claws, by the excavator's instance id (see _clawsOf)
var _drawn = 0.0 # the energy the mod's pull drew this physics frame (see _cost), shown as the arm's power

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
		_body = CircleShape2D.new()
		_body.radius = _radius

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
# red line is, how far ahead of the tip the front of the rotors / claws is], or null for a ship without a
# grinder or excavator with two rotors / claws (the OCP-209, for one): the mod leaves such ships to the game.
func _entry():
	var axis = Vector2(0, -1).rotated(global_rotation)
	var lateral = axis.rotated(PI / 2)
	for system in ENTRY_SYSTEMS:
		var s = ship.hasSystem(system)
		if s != null and "ref" in s and Tool.ov(s.ref):
			var claws = _clawsOf(s.ref) if system != "SYSTEM_GRINDER" else []
			var a = s.ref.get("grinder1node") if system == "SYSTEM_GRINDER" else claws[0]
			var b = s.ref.get("grinder2node") if system == "SYSTEM_GRINDER" else claws[1]
			if Tool.ov(a) and Tool.ov(b):
				var tip = (a.global_position + b.global_position) / 2.0
				var fa = _frontPoint(a, axis)
				var fb = _frontPoint(b, axis)
				var half = abs((fa - fb).dot(lateral)) / 2.0
				var front = max(0.0, max((fa - tip).dot(axis), (fb - tip).dot(axis)))
				return [tip, half, front + _clearance, front]
	return null

# An excavator's two claws, [left, right], each null if missing. _entry runs every physics frame and find_node searches
# the whole excavator, so they are found once per excavator, and again only if one found is gone.
func _clawsOf(excavator) -> Array:
	var id = excavator.get_instance_id()
	var claws = _claws.get(id)
	if claws == null or (claws[0] != null and not Tool.ov(claws[0])) or (claws[1] != null and not Tool.ov(claws[1])):
		claws = [excavator.find_node("Claw Left", true, false), excavator.find_node("Claw Right", true, false)]
		_claws[id] = claws
	return claws

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
# - While feeding, with an opening wide enough for a chunk, the mod always pulls the target, along the path
#   _pathAt gives for where it is: straight in where it can be, otherwise round and in, never stopping it.
#   Where a chunk moved that way for the red line's clearance would touch the hull, the target is pulled
#   straight forward instead, in the direction the arm faces, at least to a chunk's radius past the red line.
# - While not feeding, the mod holds the target at the dock slot, as the game would, but against the
#   ship's motion (see _pullTo); while the ship turns or brakes, a light target is held closer to the ship (see
#   _updateCloser), on the way from the dock slot to the middle of the opening a chunk's radius past the
#   red line. Behind the red line and outside the corridor, where the straight line to the place it is held
#   at comes too close to the hull (see _hitsHull), the target is pulled straight forward first, to a
#   chunk's radius past the red line, until that line is clear. Once held at the dock slot it goes
#   back to straight forward only when it is a little (a chunk's radius, or half the opening if that is
#   less) outside the corridor and a chunk's radius behind the red line, so a target near the line or the
#   corridor's edge does not switch back and forth.
# - Where the opening is narrower than a chunk (a closed beak), a fed target is pulled straight forward to a
#   chunk's radius past the red line and held there until the beak opens.
# `entry` is _entry()'s result (it is measured here if not given).
# Returns the offset from the place the target is pulled to (the pull goes against it; while feeding,
# the offset from the middle of the rotors / claws), or null if the ship is not covered by the mod.
func _outside(entry = null):
	_feedIn = false
	_passThrough = false
	_way = null
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
	if feeding and open:
		_lastTarget = target
		_parking = false
		var way = _pathAt(off, entry)
		if _hitsHull(target.global_position, target.global_position + way[0] * _clearance, _body):
			_passThrough = ahead < _radius
			return - axis * max(_radius - ahead, _radius)
		_way = way
		_feedIn = outside <= 0
		return off
	if feeding:
		# a closed beak holds it where it is pulled to
		_lastTarget = target
		_parking = false
		return axis * (ahead - _radius)
	# the place it is held at: the dock slot, or closer while the ship turns or brakes (see _updateCloser), towards the
	# middle of the opening a chunk's radius past the red line
	var hold = entry[0] + axis * (entry[2] + _radius)
	var centre = ship.global_position
	_parkAt = areaDockSlot.global_position
	if hold.distance_to(centre) < _parkAt.distance_to(centre):
		_parkAt = _parkAt.linear_interpolate(hold, _closer)
	var blocked = _hitsHull(target.global_position, _parkAt)
	if target != _lastTarget:
		_lastTarget = target
		_parking = ahead >= 0 or (open and outside <= 0) or not blocked
	elif _parking:
		if (not open or outside > margin) and ahead < - _radius and blocked:
			_parking = false
	else:
		_parking = ahead >= 0 or (open and outside <= 0) or not blocked
	if _parking:
		return target.global_position - _parkAt
	_passThrough = true
	return axis * (ahead - _radius)

# The path a fed target is on, from its offset from the middle of the rotors / claws (`off`) and _entry()'s result.
# Only the outer half of each rotor / claw (the side away from the opening) has to be kept clear: between them is
# where chunks go in. A chunk clears the near one's outer half if its centre passes at or inside the gate point, a
# chunk's radius ahead of that rotor's / claw's front point, so a chunk coming at an angle aims towards the opposite
# one, but no farther than the line through the opposite one's front point, or it would reach that one's outer half.
# The paths keep a margin inside both (a chunk's radius, or half the opening's half-width if that is less): the arm
# turns a chunk slowly, and a ship turning under its pull moves the opening sideways.
# - Between the rotors / claws already: straight in, along the direction the arm faces.
# - The straight zone: where a straight path into the opening passes inside the gate point, at most as steep as the
#   steepest one, from the gate point to the opposite side's line through the middle. The target goes straight in,
#   aiming at the middle, or along the line past the gate point when it comes in steeper.
# - Anywhere else (more to the side, or behind): the target heads for the join point, where the steepest straight
#   path crosses the red line, turned aside by TURN_FACTOR times the angle it still has to come round (seen from the
#   join point) to be in line with that path. The heading depends only on that angle, not on how far the target is,
#   so a path has the same shape at every distance, like a logarithmic spiral: nearly straight far away, bending more
#   and more near the join point, and arriving in line with the steepest straight path. Along it
#   sin(TURN_FACTOR * angle) stays proportional to distance^TURN_FACTOR (`k`), and the curvature is
#   (1 + TURN_FACTOR) * sin(TURN_FACTOR * angle) / distance. Close to the join point (JOIN_DISTANCE_FACTOR chunk
#   radii), within the margin of the steepest straight path, the target goes straight in past the gate point, as in
#   the straight zone, if that is no steeper than the steepest straight path; if it is, it keeps turning until the
#   join point, and past it goes straight to the opposite side's line.
# Returns [direction, curvature, direction to the centre of the bend, k, distance to the join point, the distance to
# it where the turned aim hands over to the straight path]; the curvature is 0 on a straight path.
func _pathAt(off: Vector2, entry) -> Array:
	var axis = Vector2(0, -1).rotated(global_rotation)
	var lateral = axis.rotated(PI / 2)
	var p = Vector2(off.dot(lateral), off.dot(axis)) # across, and ahead of the middle of the rotors / claws
	var half = entry[1]
	if abs(p.x) <= half and p.y <= 0.0:
		return [- axis, 0.0, Vector2(), 0.0, 0.0, 0.0]
	var gate = entry[3] + _radius
	var margin = min(_radius, half / 2.0)
	var s = sign(p.x)
	var opposite = - s * (half - margin) # the opposite side's line, moved in by the margin, through the middle
	var inside = s * (half - margin) # the gate point, moved in by the margin
	var e = Vector2(opposite - inside, - gate).normalized() # along the steepest straight path, inwards
	var join = Vector2(opposite + (inside - opposite) * entry[2] / gate, entry[2])
	var w = p - join
	var d = w.length()
	var straight = p.y > 0.0 and (s * p.x <= half - margin or s * p.x <= s * (opposite + (inside - opposite) * p.y / gate))
	var aim = null
	if not straight and s != 0.0 and p.y > 0.0 and w.dot(e) > - JOIN_DISTANCE_FACTOR * _radius and abs(e.x * p.y - e.y * (p.x - opposite)) < margin:
		# straight in past the gate point if that is no steeper than the steepest straight path; if it is, the target
		# keeps turning until the join point, and only past it goes straight to the opposite side's line
		var past = inside + (inside - p.x) * gate / (p.y - gate) if p.y > gate else opposite
		if s * past >= s * opposite:
			aim = Vector2(past, 0.0)
		elif w.dot(e) >= 0.0:
			aim = Vector2(opposite, 0.0)
	if not straight and aim == null and d < 0.001:
		aim = Vector2(opposite, 0.0)
	if straight or aim != null:
		if aim == null:
			if s == 0.0 or p.y <= gate or s * p.x * gate / p.y <= half - margin:
				aim = Vector2()
			else:
				aim = Vector2(inside + (inside - p.x) * gate / (p.y - gate), 0.0)
		var to = aim - p
		var dir = to.normalized() if to.length() > 0.001 else Vector2(0, -1)
		return [lateral * dir.x + axis * dir.y, 0.0, Vector2(), 0.0, 0.0, 0.0]
	var o = - e # the steepest straight path, outwards
	var n = Vector2(- e.y, e.x) # across it, away from the middle
	if n.x * s < 0:
		n = - n
	var r = w / d
	var angle = atan2(max(0.0, r.dot(n)), r.dot(o))
	var turn = TURN_FACTOR * angle
	var growing = - sin(angle) * o + cos(angle) * n # the way the angle grows
	var t = - cos(turn) * r - sin(turn) * growing
	var centre = t.dot(n) * o - t.dot(o) * n # the heading turns from across the path towards along it
	var k = sin(turn) / pow(d, TURN_FACTOR)
	# where the target comes within the margin of the steepest straight path, and goes on along it
	var lo = 0.05 * _radius
	var hi = d
	for i in 30:
		var mid = (lo + hi) / 2.0
		if mid * sin(asin(min(1.0, k * pow(mid, TURN_FACTOR))) / TURN_FACTOR) > margin:
			hi = mid
		else:
			lo = mid
	return [lateral * t.x + axis * t.y, (1.0 + TURN_FACTOR) * sin(turn) / d, lateral * centre.x + axis * centre.y, k, d, lo]

# The speed a fed target is pulled at: the feed's (feed times the length of feedVelocity), plus the game's own pull
# where that points in too (ahead of the dock slot), so never slower than the game would take it.
func _inwardSpeed() -> float:
	var axis = Vector2(0, -1).rotated(global_rotation)
	var fromSlot = target.global_position - areaDockSlot.global_position
	var gamePull = (fromSlot.normalized() * clamp(fromSlot.length() / easeDistance, 0, 1) * maxVelocity).dot(axis)
	return feed * feedVelocity.length() + max(0.0, gamePull)

# Whether a circle (`shape`, or one as big as the room the red line keeps: _clearance,
# CHUNK_RADIUS_CLEARENCE_FACTOR chunk radii), moved in a straight line from `from` to `to`, touches the ship's hull
# (the ship's own collision shapes) anywhere on the way, the start included.
func _hitsHull(from: Vector2, to: Vector2, shape = null) -> bool:
	var circle = _sweep if shape == null else shape
	var start = Transform2D(0.0, from)
	for owner in ship.get_shape_owners():
		if not ship.is_shape_owner_disabled(owner):
			var xf = ship.global_transform * ship.shape_owner_get_transform(owner)
			for i in ship.shape_owner_get_shape_count(owner):
				if circle.collide_with_motion(start, to - from, ship.shape_owner_get_shape(owner, i), xf, Vector2()):
					return true
	return false

# The original pull, with the same thrust, towards what _outside() gives instead of the dock slot. `rel` is the ship's
# velocity at the target (see _shipVelocityAt) relative to the target's. Returns the impulse before its cost (see
# _cost). The mod holds the target against the ship's motion: it works out the force the target needs and has the
# game's formula give it, by choosing the speed difference that makes the formula give that force.
# - What the target should do relative to the hull:
#   - Feeding (_way, see _pathAt): move along its path at the speed the pull in goes at (_inwardSpeed), but no faster
#     than the bend and the ship's turn leave room for in the arm's spare strength (see _roomFor): the bend's pull
#     towards its centre (the speed squared times the curvature; a bend tightens towards its end, so that is the
#     tightest curvature the target reaches in the time the arm takes to slow it, 1 over its push per unit of speed
#     difference) and the turn's sideways throw. The bend's pull is added to what the target needs.
#   - A place to hold the target at (the dock slot, a closed beak's hold point): the speed _parkVelocity wants. A place
#     only to be passed on the way (_passThrough: straight forward): maxVelocity towards it, cut by the turn's throw.
#   - Either way the target needs RESPONSE_RATE times the difference between that speed and its own.
# - What the ship's motion asks of it:
#   - The point of the hull under the target accelerates with the ship (_shipAccel, measured by _measureShip) and is
#     pulled towards the ship's centre as the ship turns (its turning speed squared times the distance). A target
#     moving relative to a turning hull is also thrown sideways (twice the turning speed times its speed). The target
#     needs all of that too.
#   - The ship's turning acceleration is left out, and so is the way the ship turns when the arm pushes it back at the
#     target: the ship's own control holds its heading against the arm, so a measured turning acceleration is mostly
#     that tug of war, and allowing for it pushes the target the wrong way. The turning speed itself is read as it
#     is, not worked out from changes, so its two terms above follow the ship at once.
#   - Pushing the target pushes the ship back (1 over its mass, see _forceFor); the force allows for it.
#   - The force is never more than the game's own pull could give at the target's speed relative to the hull: the
#     speed difference stays within that speed plus maxVelocity, plus feed times the length of feedVelocity while
#     feeding (the game's feed adds that much). Beyond that the ship moves faster than the arm can follow, and the
#     target falls behind until the ship's motion eases. Not feeding, the pull back towards the arm base gets the
#     arm's strength first, since the game lets go once the arm runs out of reach, so the target drifts out as slowly
#     as the arm allows; feeding, the push across the path does, so the target slows down on its path instead of
#     leaving it near the rotors / claws.
func _pullTo(side: Vector2, rel: Vector2, delta) -> Vector2:
	var mass = target.mass
	var push = max(thrust, mass * targetMassThrust) / mass / easeDistance
	var vadj = clamp((rel.length() - maxVelocity) / (maxVelocityConsidered - maxVelocity), 0, 1)
	var force = lerp(max(thrust, mass * targetMassThrust), fullThrust, vadj)
	var moving = - rel # the target's velocity relative to the hull under it
	var r = target.global_position - ship.global_position
	var spin = ship.angular_velocity
	var hull = _shipAccel - r * spin * spin
	var thrown = Vector2(- moving.y, moving.x) * 2.0 * spin
	# what is left of the arm's strength (at rest relative to the hull) once the target is held against the ship
	var spare = max(0.0, push * maxVelocity - hull.length())
	var u
	var bend = Vector2()
	var cap = rel.length() + maxVelocity
	if _way != null:
		var along = max(0.0, moving.dot(_way[0]))
		var tightest = 0.0
		if _way[1] > 0.0:
			tightest = max(_way[1], (1.0 + TURN_FACTOR) * _way[3] * pow(max(_way[5], _way[4] - along / push), TURN_FACTOR - 1.0))
		u = _way[0] * min(_inwardSpeed(), _roomFor(tightest, abs(spin), spare))
		bend = _way[2] * along * along * _way[1]
		cap += feed * feedVelocity.length()
	elif _passThrough:
		u = - side.normalized() * min(maxVelocity, _roomFor(0.0, abs(spin), BRAKE_SHARE * spare))
	else:
		u = _parkVelocity(side, spare, spin)
	var f = _forceFor(hull + thrown + bend + (u - moving) * RESPONSE_RATE, mass)
	var vd = f * easeDistance / force
	if vd.length() > cap:
		var first = Vector2()
		if _way != null:
			first = vd - _way[0] * vd.dot(_way[0])
		else:
			var back = global_position - target.global_position
			if back.length() > 0.001 and vd.dot(back) > 0.0:
				first = back.normalized() * vd.dot(back.normalized())
		vd = _shorten(vd, cap, first)
	return vd.normalized() * min(_maxThrust, force * vd.length() / easeDistance) * delta

# The fastest a target can move along a path whose curvature is `curve` while the ship turns at `spin`, with `spare`
# (an acceleration) of the arm's strength for the bend's pull (the speed squared times the curvature) and the turn's
# sideways throw (twice the turning speed times the speed).
func _roomFor(curve: float, spin: float, spare: float) -> float:
	if curve > 0.0:
		return (sqrt(spin * spin + curve * spare) - spin) / curve
	if spin > 0.0001:
		return spare / (2.0 * spin)
	return INF

# `vd` shortened to `cap`, keeping its part `first` (a part of vd) whole as far as the cap allows and giving the rest
# what is left; plain shortening if `first` is nothing.
func _shorten(vd: Vector2, cap: float, first: Vector2) -> Vector2:
	if first.length() < 0.001:
		return vd.normalized() * cap
	var kept = first.normalized() * min(first.length(), cap)
	var rest = vd - first
	var room = sqrt(max(0.0, cap * cap - kept.length_squared()))
	return kept + (rest.normalized() * min(rest.length(), room) if rest.length() > 0.001 else Vector2())

# The speed (relative to the hull) the mod wants a target to move at to come to rest at a place, from its offset from
# that place (`off`): towards it, slowing down a quarter of RESPONSE_RATE per second of distance near it, so it arrives
# without overshooting; never faster than maxVelocity, the game's own; never faster than it can brake from within
# BRAKE_SHARE of the arm's spare strength (`spare`, an acceleration), and, while the ship turns (`spin`), never so fast
# that the sideways throw of the turn (twice the turning speed times the speed) takes more than that share.
func _parkVelocity(off: Vector2, spare: float, spin: float) -> Vector2:
	var d = off.length()
	if d < 0.001:
		return Vector2()
	var share = BRAKE_SHARE * spare
	var speed = min(maxVelocity, min(d * RESPONSE_RATE / 4.0, sqrt(2.0 * share * d)))
	if abs(spin) > 0.0001:
		speed = min(speed, share / (2.0 * abs(spin)))
	return - off / d * speed

# The force on a target of mass `mass` that gives it the acceleration `want` relative to the hull under it: the ship
# gets the opposite force, which moves it back by 1 over its mass, so the force solves (1/mass + 1/ship's mass) f =
# want.
func _forceFor(want: Vector2, mass: float) -> Vector2:
	return want / (1.0 / mass + 1.0 / ship.mass)

# How far in from the dock slot a target is held while the ship turns or brakes (_closer, 0 to 1; see _outside):
# - In proportion to the ship's turning speed: all the way in at CLOSER_FULL_SHARE of the fastest turn the arm can hold
#   the target through at the dock slot. Held closer, the turn pulls it outwards less (its turning speed squared times
#   its distance from the ship's centre), and the turn's changes swing it less, so the arm keeps it through faster
#   turns. That turn rate is the square root of the arm's strength there (what the game's formula gives at a speed
#   difference of maxVelocity, a share 1/mass + 1/ship's mass of it moving the target relative to the hull) over the
#   dock slot's distance from the ship's centre.
# - Plus, in proportion to the ship's backward acceleration (its measured acceleration, _shipAccel, along the arm from
#   the dock slot towards the arm base): all the way in at CLOSER_FULL_SHARE of the arm's strength. That leaves the
#   target out in front of the ship, the way the turn pulls it, so the two add up; held closer, it has more of the
#   arm's reach to spare before the game lets go of it (at two arm lengths from the arm base, DockingArm.gd
#   _physics_process). Accelerating forwards doesn't bring it in: that pushes it towards the ship, where it needs room
#   ahead of the intake.
# _closer goes in at once and back out within CLOSER_RELEASE_TIME (`delta` is the frame's). A target of
# CLOSER_MASS_LIMIT or more stays at the dock slot.
func _updateCloser(delta):
	if not Tool.ov(target) or target.mass >= CLOSER_MASS_LIMIT:
		_closer = 0.0
		return
	var mass = target.mass
	var strength = max(thrust, mass * targetMassThrust) * maxVelocity / easeDistance * (1.0 / mass + 1.0 / ship.mass)
	var distance = areaDockSlot.global_position.distance_to(ship.global_position)
	var turning = abs(ship.angular_velocity) / (CLOSER_FULL_SHARE * sqrt(strength / distance)) if distance > 0.0 else 0.0
	var out = (areaDockSlot.global_position - global_position).normalized()
	var backwards = max(0.0, - _shipAccel.dot(out)) / (CLOSER_FULL_SHARE * strength)
	var want = clamp(turning + backwards, 0.0, 1.0)
	_closer = want if want > _closer else max(want, _closer - delta / CLOSER_RELEASE_TIME)

# Measures the ship's acceleration over the last frame (`delta`), from the change in its velocity, leaving out what the
# mod's own last impulse did to it (the ship got the opposite of it), so only the rest counts: its thrusters, knocks,
# another arm. Allowing for its own push too, the mod would push harder for every push it gave (an earlier version did,
# and flung targets away). Smoothed over ACCEL_SMOOTHING.
func _measureShip(delta):
	var velocity = ship.linear_velocity
	if _shipSeen:
		var accel = (velocity - _lastShipVelocity) / delta + _lastImpulse / ship.mass / delta
		_shipAccel = _shipAccel.linear_interpolate(accel, clamp(delta / ACCEL_SMOOTHING, 0.0, 1.0))
	_lastShipVelocity = velocity
	_shipSeen = true
	_lastImpulse = Vector2()

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
	_drawn = pg
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
	_measureShip(delta)
	_updateCloser(delta)
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
			_drawn = 0.0
			if impulse.length() > 0:
				impulse *= _cost(impulse.length(), rel, delta) / impulse.length()
			target.apply_central_impulse(impulse)
			ship.apply_impulse(target.global_position - ship.global_position, - impulse)
			_lastImpulse = impulse
			call_deferred("_showPower")
			Tool.release(target)
		Tool.release(ship)

# The arm's power, which its OMS entry shows (hud/SystemList.gd, through ship-ctrl.gd's status of the system): the
# game's _physics_process, which runs right after the mod's, sets it from what its own pull drew this frame
# (DockingArm.gd: power = newPower / 1000), nothing while the mod pulls. A deferred call runs once every physics
# callback of the step is done, so it shows what the mod's pull drew instead, as the game's formula would.
func _showPower():
	power = clamp(_drawn / 1000, 0, 1)
