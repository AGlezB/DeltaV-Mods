extends "res://harness/suite.gd"

# ArmAltPullBehavior holding a target, and feeding it, while the Eagle-Prospector-VP turns and accelerates. The ship takes
# the arm's impulses (with shipMass and the hull's turning inertia), and a strong autopilot flies the commanded turn
# rate and acceleration (its turning acceleration and acceleration capped high); the commanded turn rate ramps at a set
# rate. The arm's limits come from its own values: its strength at rest relative to the hull, F = max(thrust, mass x
# targetMassThrust) x maxVelocity / easeDistance; the fastest turn it can hold a target through at distance r from the
# ship's centre, sqrt(F (1/m + 1/M) / r); the most linear acceleration, F (1/m + 1/M); the most turning acceleration
# with the ship holding its heading, F (1/m + 1/M) / r. Cases name a share of the turn limit at the dock slot and of the
# linear limit.
# The harness moves its ship before the physics step and the chunk during it, so in the mod's view the ship is one frame
# ahead: the mod holds a chunk one frame of the ship's motion off the place it means (in the game both move in the same
# step). Distances are checked with that allowed for (the ship's speed at the place times a frame). Feeding while
# braking starts at 20 m/s forward, so the ship's speed stays moderate: at 33 m/s that frame is 5.5 world units, enough
# to put a chunk from beside the hull on a rotor's outer half in the harness alone.
# Cases beyond the arm's strength are notes, not checks: there the target sags, and may be lost.

const SPIN_ACCEL_CAP = 6.0 # rad/s^2, the autopilot's
const ACCEL_CAP = 400.0 # world units/s^2 (40 m/s^2), the autopilot's
const SETTLE = 4.0 # s into a manoeuvre before its steady part is measured
const AFTER = 10.0 # s after a manoeuvre before the target must be back at the dock slot
const DT = 1.0 / 60.0

var wmax = 0.0 # the turn limit at the dock slot, rad/s
var amax = 0.0 # the linear limit, world units/s^2

func run():
	if not hasMod("ArmAltPullBehavior"):
		note("hold: skipped, it needs ArmAltPullBehavior")
		return
	var probe = Rig.build(self, {"shipMass": shipMass})
	yield(get_tree(), "physics_frame")
	var arm = probe.arm
	var f = max(arm.thrust, chunkMass * arm.targetMassThrust) * arm.maxVelocity / arm.easeDistance
	var strength = f * (1.0 / chunkMass + 1.0 / shipMass)
	var slotR = (arm.areaDockSlot.global_position - probe.ship.global_position).length()
	var en = arm._entry()
	var closest = en[0] + Vector2(0, -1).rotated(arm.global_rotation) * (en[2] + arm._radius)
	var closestR = (closest - probe.ship.global_position).length()
	wmax = sqrt(strength / slotR)
	amax = strength
	note("ship %.2f t, chunk %.2f t; at the dock slot (%.1f m from the ship's centre): turn %.1f deg/s, turning acceleration %.2f rad/s^2, acceleration %.1f m/s^2; held closest (%.1f m): turn %.1f deg/s, turning acceleration %.2f rad/s^2" % [shipMass, chunkMass, slotR / 10.0, rad2deg(wmax), strength / slotR, amax / 10.0, closestR / 10.0, rad2deg(sqrt(strength / closestR)), strength / closestR])
	probe.field.queue_free()
	yield(get_tree(), "physics_frame")
	# holding, not feeding
	for s in [0.5, 0.75, 1.0]:
		yield(hold("turning at %d%%, spinning up at 0.3 rad/s^2" % int(s * 100), s, "turn", 0.0, 0.3, 8.0, "near"), "completed")
	for s in [1.2, 1.3]:
		yield(hold("turning at %d%%, spinning up at 0.15 rad/s^2 (held closest)" % int(s * 100), s, "turn", 0.0, 0.15, 14.0, "near"), "completed")
	for s in [0.5, 0.75, 1.0]:
		yield(hold("turning at %d%%, spinning up at 6 rad/s^2 (beyond the turning-acceleration limit)" % int(s * 100), s, "turn", 0.0, 6.0, 8.0, "back"), "completed")
	yield(hold("turning back and forth at 75%, reversing at 1 rad/s^2", 0.75, "flip", 0.0, 1.0, 12.0, "back"), "completed")
	yield(hold("turning back and forth at 100%, reversing at 0.3 rad/s^2", 1.0, "flip", 0.0, 0.3, 16.0, "back"), "completed")
	yield(hold("turning at 50% while accelerating forward at 50%", 0.5, "turn", 0.5, 0.3, 8.0, "near"), "completed")
	for s in [0.5, 0.95]:
		yield(hold("accelerating forward at %d%%" % int(s * 100), 0.0, "none", s, 1.0, 3.0, "near"), "completed")
		yield(hold("braking (accelerating backwards) at %d%%" % int(s * 100), 0.0, "none", - s, 1.0, 3.0, "near"), "completed")
		yield(hold("accelerating sideways at %d%%" % int(s * 100), 0.0, "side", s, 1.0, 3.0, "near"), "completed")
	yield(hold("accelerating forward at 120%", 0.0, "none", 1.2, 1.0, 3.0, "back"), "completed")
	yield(hold("braking at 120%", 0.0, "none", -1.2, 1.0, 3.0, "back"), "completed")
	for pair in [[0.5, 0.25], [0.5, 0.5], [0.5, 0.75], [0.75, 0.25], [0.75, 0.5], [1.0, 0.25]]:
		yield(hold("turning at %d%% while braking at %d%%" % [int(pair[0] * 100), int(pair[1] * 100)], pair[0], "turn", - pair[1], 0.3, 8.0, "back"), "completed")
	for pair in [[0.75, 0.75], [1.0, 0.5], [1.0, 0.75]]:
		yield(hold("turning at %d%% while braking at %d%% (beyond the arm's strength even held closest)" % [int(pair[0] * 100), int(pair[1] * 100)], pair[0], "turn", - pair[1], 0.3, 8.0, "note"), "completed")
	yield(hold("an 11 t target (over the mass limit), turning at 75%", 0.75, "turn", 0.0, 0.3, 8.0, "slot", 11.0), "completed")
	yield(hold("a 15 t target (over the mass limit), turning at 75% while braking at 50%", 0.75, "turn", -0.5, 0.3, 8.0, "note", 15.0), "completed")
	for s in [0.5, 0.75, 1.0]:
		yield(grab("grabbed ahead-left, then turning at %d%%" % int(s * 100), Vector2(-211, -259), s), "completed")
		yield(grab("grabbed off to the side, then turning at %d%%" % int(s * 100), Vector2(250, -200), s), "completed")
	# feeding
	var starts = [["ahead-left", Vector2(-211, -259)], ["near the corridor", Vector2(45, -215)], ["beside the hull", Vector2(120, -150)], ["where the logs start", Vector2(-260, -345)], ["far ahead, off to the side", Vector2(-120, -480)]]
	var motions = [["the ship still", 0.0, 0.0, Vector2()], ["turning at 50%", 0.5, 0.0, Vector2()], ["turning at 100%", 1.0, 0.0, Vector2()], ["braking at 50%", 0.0, -0.5, Vector2()], ["accelerating forward at 50%", 0.0, 0.5, Vector2()], ["turning at 50% while braking at 50%, from 20 m/s forward", 0.5, -0.5, Vector2(0, -200)]]
	for st in starts:
		for mo in motions:
			yield(feed(st[0] + ", " + mo[0], st[1], mo[1], mo[2], mo[3]), "completed")

# The turn rate (rad/s) and acceleration (ship frame) the ship is asked for at time t of a manoeuvre `length` s long.
func target(kind, turnShare, accelShare, t, length):
	var w = 0.0
	var a = Vector2()
	if t >= 0.0 and t < length:
		if kind == "turn":
			w = turnShare * wmax
		elif kind == "flip":
			w = turnShare * wmax * (1.0 if int(t / 8.0) % 2 == 0 else -1.0)
		a = Vector2(accelShare * amax, 0) if kind == "side" else Vector2(0, - accelShare * amax)
	return [w, a]

# One holding case: the target settled at the dock slot, then the manoeuvre for `length` s, then AFTER s of rest.
# `expect`: "near" = within a chunk's radius of the place the mod holds it at (_parkAt) once settled, and back at the
# dock slot after; "back" = kept, and back at the dock slot after; "slot" = held at the dock slot itself throughout
# (a target over the mass limit); "note" = only reported.
func hold(label, turnShare, kind, accelShare, ramp, length, expect, mass = null):
	var rig = Rig.build(self, {"shipMass": shipMass})
	var ship = rig.ship
	var arm = rig.arm
	var chunk = Rig.chunk(rig.field, arm.areaDockSlot.global_position - ship.global_position, chunkMass if mass == null else mass)
	yield(get_tree(), "physics_frame")
	if not arm.queue.has(chunk):
		arm.queue.append(chunk)
	arm.target = chunk
	arm.feed = 0.0
	var state = {"heading": 0.0, "vcmd": Vector2(), "w": 0.0}
	var t0 = null
	var i = 0
	var steady = 0.0 # beyond the allowance, from the place the mod holds it at
	var peak = 0.0
	var inMost = 0.0
	var lostAt = null
	var reach = 0.0
	var end = 0.0
	while true:
		var t = -100.0 if t0 == null else (i - t0) * DT
		var cmd = target(kind, turnShare, accelShare, t, length)
		state.w = move_toward(state.w, cmd[0], ramp * DT)
		fly(ship, state, state.w, cmd[1], DT)
		yield(get_tree(), "physics_frame")
		i += 1
		if t0 == null and arm.locked and arm.nodeArm.hasGrab():
			t0 = i + 120
		if arm.target != chunk and lostAt == null:
			lostAt = max(0.0, t)
		var slot = arm.areaDockSlot.global_position
		var allowance = _allowance(ship, slot)
		if t >= 0.0 and lostAt == null:
			peak = max(peak, (chunk.global_position - slot).length())
			inMost = max(inMost, (slot - arm._parkAt).length())
			reach = max(reach, (chunk.global_position - arm.global_position).length())
			if t >= SETTLE and t < length:
				steady = max(steady, (chunk.global_position - arm._parkAt).length() - allowance)
		if t >= length + AFTER:
			end = (chunk.global_position - slot).length() - allowance
			break
		if i > 9000:
			break
	var lost = lostAt != null
	var details = "settled %.2f m from where it is held, at most %.1f m from the dock slot, %.2f m from it after; held up to %.1f m in; out to %.1f m from the arm base (the game lets go at %.0f)%s" % [steady / 10.0, peak / 10.0, end / 10.0, inMost / 10.0, reach / 10.0, 2.0 * arm.scale.x * arm.nodeArm.scale.x * arm.nodeArm.armLength / 10.0, (", lost after %.1f s" % lostAt) if lost else ""]
	match expect:
		"near":
			check("hold: " + label + ": settles within a chunk's radius of where it is held, back at the dock slot after", not lost and steady <= VP.CHUNK_RADIUS and end <= VP.CHUNK_RADIUS, details)
		"back":
			check("hold: " + label + ": kept, back at the dock slot after", not lost and end <= VP.CHUNK_RADIUS, details)
		"slot":
			check("hold: " + label + ": held at the dock slot", not lost and inMost < 0.01 and steady <= VP.CHUNK_RADIUS and end <= VP.CHUNK_RADIUS, details)
		_:
			note("hold: " + label + ": " + details)
	rig.field.queue_free()
	yield(get_tree(), "physics_frame")

# A chunk grabbed away from the dock slot; once the arm holds it, the ship turns (spinning up at 0.3 rad/s^2): it must
# come to the place the mod holds it at and stay within a chunk's radius of it.
func grab(label, start, turnShare):
	var rig = Rig.build(self, {"shipMass": shipMass})
	var ship = rig.ship
	var arm = rig.arm
	var chunk = Rig.chunk(rig.field, start, chunkMass)
	yield(get_tree(), "physics_frame")
	if not arm.queue.has(chunk):
		arm.queue.append(chunk)
	arm.target = chunk
	arm.feed = 0.0
	var state = {"heading": 0.0, "vcmd": Vector2(), "w": 0.0}
	var heldAt = null
	var after = 0.0
	var lost = false
	var grabbed = null
	for i in 900:
		if grabbed == null and arm.locked and arm.nodeArm.hasGrab():
			grabbed = i
		state.w = move_toward(state.w, turnShare * wmax if grabbed != null else 0.0, 0.3 * DT)
		fly(ship, state, state.w, Vector2(), DT)
		yield(get_tree(), "physics_frame")
		if arm.target != chunk:
			lost = true
		var d = (chunk.global_position - arm._parkAt).length() - _allowance(ship, arm._parkAt)
		if heldAt == null and d < VP.CHUNK_RADIUS:
			heldAt = (i + 1) * DT
		elif heldAt != null:
			after = max(after, d)
	check("hold: " + label + ": comes to where it is held and stays within a chunk's radius", not lost and heldAt != null and after <= VP.CHUNK_RADIUS, "grabbed after %s s, there after %s s, then within %.2f m%s" % ["-" if grabbed == null else "%.2f" % (grabbed * DT), "-" if heldAt == null else "%.2f" % heldAt, after / 10.0, ", lost" if lost else ""])
	rig.field.queue_free()
	yield(get_tree(), "physics_frame")

# Feeding a chunk from `start` (ship coordinates), the ship at `cruise` to begin with; once the arm first locks on, the
# ship turns at turnShare (spinning up at 0.3 rad/s^2) and accelerates at accelShare (forward if positive). In when it
# first touches a rotor on its inner side; a touch on an outer half fails.
func feed(label, start, turnShare, accelShare, cruise):
	var rig = Rig.build(self, {"shipMass": shipMass})
	var ship = rig.ship
	var arm = rig.arm
	var chunk = Rig.chunk(rig.field, start, chunkMass, cruise)
	yield(get_tree(), "physics_frame")
	if not arm.queue.has(chunk):
		arm.queue.append(chunk)
	arm.target = chunk
	arm.feed = 1.0
	var rotors = Rig.rotorCentres()
	var state = {"heading": 0.0, "vcmd": cruise, "w": 0.0}
	ship.linear_velocity = cruise
	var lockedOnce = null
	var inAt = null
	var outer = false
	var lost = false
	for i in 900:
		if lockedOnce == null and arm.locked:
			lockedOnce = i
		var going = lockedOnce != null
		state.w = move_toward(state.w, turnShare * wmax if going else 0.0, 0.3 * DT)
		fly(ship, state, state.w, Vector2(0, - accelShare * amax) if going else Vector2(), DT)
		yield(get_tree(), "physics_frame")
		if arm.target != chunk:
			lost = true
			break
		var local = ship.global_transform.affine_inverse().xform(chunk.global_position)
		for centre in rotors:
			if inAt == null and local.distance_to(centre) <= VP.ROTOR_RADIUS + VP.CHUNK_RADIUS:
				inAt = (i + 1) * DT
				outer = sign(centre.x) * local.x > abs(centre.x)
		if inAt != null:
			break
	check("hold: feeding from " + label + ": in on a rotor's inner side", not lost and inAt != null and not outer, "in after %s s%s%s" % ["-" if inAt == null else "%.2f" % inAt, " on an OUTER HALF" if outer else "", ", lost" if lost else ""])
	rig.field.queue_free()
	yield(get_tree(), "physics_frame")

# How far the mod's one-frame-ahead view of the ship puts a target held at `point` off it: the ship's speed there times
# a frame (see the header).
func _allowance(ship, point: Vector2) -> float:
	var r = point - ship.global_position
	return (ship.linear_velocity + Vector2(- r.y, r.x) * ship.angular_velocity).length() * DT

# Moves the ship one frame: the arm's impulses, then the autopilot flying the turn rate `w` and acceleration `a` (ship
# frame), each capped.
func fly(ship, state, w, a, dt):
	var inertia = VP.SHIP_INERTIA_PER_TONNE * shipMass
	ship.linear_velocity += ship.impulses / shipMass
	ship.impulses = Vector2()
	ship.angular_velocity += ship.angImpulses / inertia
	ship.angImpulses = 0.0
	state.heading += w * dt
	var aw = a.rotated(ship.rotation)
	state.vcmd += aw * dt
	var acc = aw + (state.vcmd - ship.linear_velocity) * 20.0
	ship.linear_velocity += acc.limit_length(ACCEL_CAP) * dt
	var alpha = (w - ship.angular_velocity) * 30.0 + (state.heading - ship.rotation) * 60.0
	ship.angular_velocity += clamp(alpha, - SPIN_ACCEL_CAP, SPIN_ACCEL_CAP) * dt
	ship.position += ship.linear_velocity * dt
	ship.rotation += ship.angular_velocity * dt
