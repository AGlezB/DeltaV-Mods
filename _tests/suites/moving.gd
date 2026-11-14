extends "res://harness/suite.gd"

# ArmAltPullBehavior bringing a chunk in on the Eagle-Prospector-VP while the ship moves: the 16 cases of the
# claude.ai tests (real_move.gd). The ship is held in place by an autopilot, cruises at 10, 20 or 40 m/s, or turns
# at 20 deg/s for 2 s; the player feeds (holds the excavator key) or not; two start points are where the user's
# in-game logs started. The ship is moved by hand: every frame it takes the arm's impulses (with shipMass and the
# hull's turning inertia), then a PD autopilot (acceleration limited) holds its course.
# Expectations: "in" = goes in between the rotors without touching them; "dock" = the game takes it to the dock
# slot; "forward-dock" = the mod first moves it straight forward, clear of the hull, then the game docks it.

var cruise = Vector2() # the ship's course, world units per second (10 = 1 m)
var turn = 0.0 # turning rate while turning (frames 31-149), rad/s
var fixedShip = false # the ship does not move at all (still.gd)
var dockLimit = 60.0 # how close to the dock slot counts as docked
var forwardTolerance = 0.5 # how far the first pull's direction may stray sideways from straight forward

func run():
	if not hasMod("ArmAltPullBehavior"):
		note("moving: skipped, it needs ArmAltPullBehavior")
		return
	var aheadLeft = Vector2(-211, -259) # from the user's video
	var logsDock = Vector2(-220, -362) # where the user's logs started, not feeding
	var logsIn = Vector2(-260, -345) # and feeding
	var besideHull = Vector2(120, -150)
	var closeBesideHull = Vector2(58, -130)
	var nearCorridor = Vector2(45, -215)

	cruise = Vector2()
	turn = 0.0
	yield(pull("ahead-left (the video), held in place", aheadLeft, 0.0, 420, "dock"), "completed")
	yield(pull("where the logs start, held in place", logsDock, 0.0, 420, "dock"), "completed")
	yield(pull("where the logs start, held in place", logsIn, 1.0, 720, "in"), "completed")
	yield(pull("close beside the hull, held in place", closeBesideHull, 0.0, 420, "forward-dock"), "completed")
	# Time limits (s) on the feeding cases behind the red line beside the hull: ArmAltPullBehavior 1.5.0's times + 25 %,
	# all below 1.4.0's, so a slow-down fails.
	for start in [["ahead-left (the video)", aheadLeft, INF], ["beside the hull", besideHull, 6.0], ["close beside the hull", closeBesideHull, 5.7], ["near the corridor", nearCorridor, 3.6]]:
		yield(pull(start[0] + ", held in place", start[1], 1.0, 660, "in", start[2]), "completed")
	cruise = Vector2(0, -100)
	yield(pull("where the logs start, cruising at 10 m/s", logsDock, 0.0, 420, "dock"), "completed")
	yield(pull("where the logs start, cruising at 10 m/s", logsIn, 1.0, 720, "in"), "completed")
	cruise = Vector2(0, -200)
	yield(pull("ahead-left (the video), cruising at 20 m/s", aheadLeft, 0.0, 420, "dock"), "completed")
	yield(pull("beside the hull, cruising at 20 m/s", besideHull, 1.0, 660, "in", 6.1), "completed")
	cruise = Vector2(0, -400)
	yield(pull("ahead-left (the video), cruising at 40 m/s", aheadLeft, 1.0, 660, "in"), "completed")
	yield(pull("close beside the hull, cruising at 40 m/s", closeBesideHull, 0.0, 420, "forward-dock"), "completed")
	cruise = Vector2(0, -200)
	turn = deg2rad(20)
	yield(pull("ahead-left (the video), cruising at 20 m/s and turning 20 deg/s for 2 s", aheadLeft, 0.0, 480, "dock"), "completed")
	yield(pull("beside the hull, cruising at 20 m/s and turning 20 deg/s for 2 s", besideHull, 1.0, 720, "in", 6.7), "completed")
	cruise = Vector2()
	turn = 0.0

# One case: a chunk at `start` (ship coordinates), the arm's target from the first frame, `feed` 1 = feeding.
# `maxSeconds`: for "in", how soon it must be in.
func pull(label, start, feed, frameCount, expect, maxSeconds = INF):
	var rig = Rig.build(self, {"shipMass": shipMass})
	var ship = rig.ship
	var arm = rig.arm
	var chunk = Rig.chunk(rig.field, start, caseChunkMass())
	yield(get_tree(), "physics_frame")
	if not arm.queue.has(chunk):
		arm.queue.append(chunk)
	arm.target = chunk
	arm.feed = feed
	var rotors = Rig.rotorCentres()
	var tipY = (rotors[0].y + rotors[1].y) / 2.0
	var gap = abs(rotors[1].x - rotors[0].x) / 2.0
	var modFrames = 0
	var handbacks = 0
	var wasMod = false
	var firstMod = null
	var xAtRotors = null
	var inAfter = null # seconds until the chunk crossed the rotors' line
	var dockedAfter = null # seconds until it first came within dockLimit of the dock slot
	var minClear = INF
	var lastY = start.y
	ship.linear_velocity = cruise
	ship.angular_velocity = 0.0
	chunk.linear_velocity = cruise
	var hold = ship.position
	var heading = 0.0
	var inertia = VP.SHIP_INERTIA_PER_TONNE * shipMass
	for i in frameCount:
		var dt = 1.0 / 60.0
		if fixedShip:
			ship.impulses = Vector2()
			ship.angImpulses = 0.0
		else:
			ship.linear_velocity += ship.impulses / shipMass
			ship.impulses = Vector2()
			ship.angular_velocity += ship.angImpulses / inertia
			ship.angImpulses = 0.0
			hold += cruise * dt
			var acc = - 4.0 * (ship.position - hold) - 4.0 * (ship.linear_velocity - cruise)
			ship.linear_velocity += acc.limit_length(150.0) * dt
			var wc = turn if i > 30 and i < 150 else 0.0
			heading += wc * dt
			var alpha = - 4.0 * (ship.rotation - heading) - 4.0 * (ship.angular_velocity - wc)
			ship.angular_velocity += clamp(alpha, -2.0, 2.0) * dt
			ship.position += ship.linear_velocity * dt
			ship.rotation += ship.angular_velocity * dt
		yield(get_tree(), "physics_frame")
		var offset = arm._outside()
		if offset != null:
			modFrames += 1
			if firstMod == null:
				firstMod = offset.rotated(- ship.rotation)
		if wasMod and offset == null:
			handbacks += 1
		wasMod = offset != null
		var local = ship.global_transform.affine_inverse().xform(chunk.global_position)
		if xAtRotors == null and local.y >= tipY and lastY < tipY:
			xAtRotors = local.x
			inAfter = (i + 1) / 60.0
		if dockedAfter == null and chunk.global_position.distance_to(arm.areaDockSlot.global_position) < dockLimit:
			dockedAfter = (i + 1) / 60.0
		lastY = local.y
		# clearance to the rotors while the chunk is not in line with the gap between them
		if abs(local.x) >= gap:
			for centre in rotors:
				minClear = min(minClear, local.distance_to(centre) - VP.ROTOR_RADIUS - VP.CHUNK_RADIUS)
	var end = ship.global_transform.affine_inverse().xform(chunk.global_position)
	var docked = chunk.global_position.distance_to(arm.areaDockSlot.global_position)
	var what = "%s, %s" % [label, "feeding" if feed > 0 else "not feeding"]
	var timing = ""
	if expect == "in":
		timing = "in after %s s, " % ("%.2f" % inAfter if inAfter != null else "-")
	else:
		timing = "docked after %s s, " % ("%.2f" % dockedAfter if dockedAfter != null else "-")
	var details = timing + "end (%.1f, %.1f), %.1f from the dock slot, mod frames %d, handed back %d, x at the rotors %s, closest to a rotor %.1f" % [end.x, end.y, docked, modFrames, handbacks, xAtRotors, minClear]
	match expect:
		"in":
			var inTime = maxSeconds == INF or (inAfter != null and inAfter <= maxSeconds)
			check(what + ": goes in between the rotors without touching them" + ("" if maxSeconds == INF else " within %.1f s" % maxSeconds), xAtRotors != null and abs(xAtRotors) < gap and minClear > 0 and handbacks <= 1 and end.y > -50 and inTime, details)
		"dock":
			check(what + ": the game takes it to the dock slot", docked < dockLimit and handbacks <= 1, details)
		"forward-dock":
			check(what + ": straight forward clear of the hull, then the game docks it", firstMod != null and abs(firstMod.x) < forwardTolerance and docked < dockLimit and handbacks == 1, "first offset %s, %s" % [firstMod, details])
	rig.field.queue_free()
	yield(get_tree(), "physics_frame")

func caseChunkMass():
	return chunkMass
