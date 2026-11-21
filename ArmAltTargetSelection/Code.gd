# ArmAltTargetSelection - target selection for the AR-1500 salvage arm.
#
# Extends res://ships/modules/DockingArm.gd (script extension, see ModMain.gd). Only arms whose
# systemName is SYSTEM_SALVAGE_ARM on a ship are changed; station dock arms behave as in the game.
#
# What and why:
#  1. The game's dock area is a large rectangle, so the arm can pick targets it cannot reach. Its
#     shape is replaced with the area the arm can reach (_buildArea), which also takes in the strip
#     between the arm base and the game's area; targets there are taken only when there is nothing
#     else (switchTarget).
#  2. The game picks the first valid target in its queue, i.e. the one that entered the area first.
#     Here the best target is the one closest to the intake's centerline and entry point, i.e. the
#     one that is easiest to bring in (switchTarget).
#  3. The game keeps a target after the arm is switched off until the arm is retracted, and keeps
#     the old queue when it is switched on. Here the target is dropped at once, the queue is kept
#     empty while the arm is off, and it is rebuilt when the arm is switched on (_physics_process).
#
# Rules for stacking with other mods (see the README): never call the parent's _ready or
# _physics_process (Godot runs every level of them), call ordinary parent functions with .name(), and keep
# member names unique (everything here that is not an override starts with "_" or is documented).
extends "res://ships/modules/DockingArm.gd"

# Fraction of the reach by which the centre of the reach circle is moved in the direction the arm
# faces (see _buildArea). The part of the area that this puts beyond the reach is the buffer area:
# targets straight ahead of the arm may be that much farther away, thinning to nothing at the sides.
# The intake is ahead of the arm base, so it can still take in targets a little past the arm's
# nominal reach there. Tuned value.
const BUFFER_AREA_FACTOR = 0.10

# Weight of the distance to the intake's centerline in the target score. 1.0 = only the distance to
# the centerline counts, 0.5 = both equal, 0.0 = only the distance to the entry point.
# A high value prefers targets that are lined up with the intake over merely close ones. Tuned value.
const BALANCE = 0.75

# Number of straight segments along the arc of the area (see _buildArea). 16 keep the polygon within
# 0.25 m of the circle for the AR-1500.
const AREA_SEGMENTS = 16

# Systems that take targets in, tried in this order (see _intakePosition).
const INTAKES = ["SYSTEM_GRINDER", "SYSTEM_EXCAVATOR"]

var _targeting = false # this arm is a salvage arm on a ship, i.e. the mod applies to it
var _wasEnabled = true # `enabled` of the previous physics frame, to detect switching on
var _rear = 0.0 # how far ahead of the arm base the game's own dock area starts (7 m for the AR-1500)
var _targetingClaws = {} # each excavator's claws, by the excavator's instance id (see _targetingClawsOf)

func _ready():
	_targeting = systemName == "SYSTEM_SALVAGE_ARM" and ship != null
	if _targeting:
		_buildArea()

# Runs before the original _physics_process.
# - Switched off: once the target is released (the game releases it in the frame the arm is switched
#   off), it is dropped (the game keeps it until the arm is fully retracted) and the queue is kept
#   empty, so nothing stale is left in it.
# - Switched on: the queue is rebuilt from what is in the area now.
func _physics_process(delta):
	if not _targeting or delta <= 0:
		return
	if enabled and not _wasEnabled:
		queue.clear()
		for body in areaDockArea.get_overlapping_bodies():
			addToQueue(body)
	_wasEnabled = enabled
	if not enabled and not locked:
		if target != null:
			if Tool.multiClaim([target, ship]):
				ship.removeSystemTarget(self, target)
				Tool.multiRelease([target, ship])
			target = null
			forcedTarget = null
		queue.clear()

# Reach of the arm in world units: two arm sections of armLength, scaled by the nodes' scales
# (the game shows 10 units as 1 m).
func _reach() -> float:
	return 2.0 * scale.x * nodeArm.scale.x * nodeArm.armLength

# Replaces the shape of the dock area (areaDockArea) with the area the arm can reach, so the game's
# own checks (what enters the queue, when a target is lost) follow it: the reach circle, its centre
# moved BUFFER_AREA_FACTOR of the reach in the direction the arm faces (its local up; this adds the
# buffer area), cut by the line through the arm base across that direction. It is a polygon:
# AREA_SEGMENTS straight segments along the arc (a mineral chunk's radius is about 1 m, and a chunk
# is in the area as soon as its edge touches it), and that line.
# The game's area starts some way ahead of the arm base (7 m for the AR-1500). That edge is read
# first (_rear): the strip behind it is now in the area, but switchTarget takes targets there only
# when there is nothing else.
func _buildArea():
	var reach = _reach()
	var axis = Vector2(0, -1).rotated(global_rotation)
	_rear = INF
	for cs in areaDockArea.get_children():
		if cs is CollisionShape2D and cs.shape is RectangleShape2D:
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				_rear = min(_rear, (cs.global_transform.xform(corner * cs.shape.extents) - global_position).dot(axis))
	_rear = max(0.0, _rear) if _rear < INF else 0.0
	var centre = global_position + axis * BUFFER_AREA_FACTOR * reach
	var half = acos(- BUFFER_AREA_FACTOR) # the arc's ends, on the line through the base, as angles from the axis
	for cs in areaDockArea.get_children():
		if cs is CollisionShape2D:
			var toShape = cs.global_transform.affine_inverse()
			var points = PoolVector2Array()
			for i in range(AREA_SEGMENTS + 1):
				points.append(toShape.xform(centre + Vector2(reach, 0).rotated(axis.angle() + lerp(- half, half, float(i) / AREA_SEGMENTS))))
			cs.shape = ConvexPolygonShape2D.new()
			cs.shape.points = points

# Where targets go in: between the grinder's two rotors, or between the excavator's two claws
# (the ship's centre if it has neither, e.g. the OCP-209, whose arms feed into the middle of its side
# opening). The values come from the ship's own nodes, so every ship model is covered.
# ArmAltPullBehavior uses the same points for its opening, so the two mods agree.
func _intakePosition() -> Vector2:
	for system in INTAKES:
		var s = ship.hasSystem(system)
		if s != null and "ref" in s and Tool.ov(s.ref):
			var claws = _targetingClawsOf(s.ref) if system != "SYSTEM_GRINDER" else []
			var a = s.ref.get("grinder1node") if system == "SYSTEM_GRINDER" else claws[0]
			var b = s.ref.get("grinder2node") if system == "SYSTEM_GRINDER" else claws[1]
			if Tool.ov(a) and Tool.ov(b):
				return (a.global_position + b.global_position) / 2.0
	return ship.global_position

# An excavator's two claws, [left, right], each null if missing. The game calls switchTarget every physics frame while
# the arm has no target (DockingArm.gd _physics_process), and find_node searches the whole excavator, so they are found
# once per excavator, and again only if one found is gone.
func _targetingClawsOf(excavator) -> Array:
	var id = excavator.get_instance_id()
	var claws = _targetingClaws.get(id)
	if claws == null or (claws[0] != null and not Tool.ov(claws[0])) or (claws[1] != null and not Tool.ov(claws[1])):
		claws = [excavator.find_node("Claw Left", true, false), excavator.find_node("Claw Right", true, false)]
		_targetingClaws[id] = claws
	return claws

# Overrides the game's choice. Best = lowest weighted sum (BALANCE) of the distance to the intake's
# centerline and the distance to the entry point. The intake's centerline is the line through the
# entry point along the direction the arm faces (its local up): the ship's centerline for a grinder
# or excavator at the front, and the line across the ship's side opening for the OCP-209, whose arm
# mounts are turned. (The arm's `feedVelocity` is not used: it is tilted on the OCP-209.)
# A target in the strip between the arm base and the game's own area (closer than _rear ahead of the
# base) is taken only if no other target is valid. The reach needs no check here: the game drops
# whatever is not in the area (_buildArea). The game still keeps the current target until it is
# lost or taken in.
func switchTarget():
	if not _targeting:
		return .switchTarget()
	if not enabled:
		return null
	var entry = _intakePosition()
	var axis = Vector2(0, -1).rotated(global_rotation)
	var best = null
	var bestScore = INF
	var bestInStrip = true
	for t in queue.duplicate():
		if not isValidTarget(t):
			continue
		var inStrip = (t.global_position - global_position).dot(axis) < _rear
		var side = abs(axis.cross(t.global_position - entry))
		var dist = t.global_position.distance_to(entry)
		var score = BALANCE * side + (1.0 - BALANCE) * dist
		if (bestInStrip and not inStrip) or (inStrip == bestInStrip and score < bestScore):
			best = t
			bestScore = score
			bestInStrip = inStrip
	return best
