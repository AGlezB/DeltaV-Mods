extends "res://suites/moving.gd"

# ArmAltPullBehavior with the Eagle-Prospector-VP standing still and not moved by the arm: the 9 cases of the
# claude.ai tests (DVModTestHarness 1.0.0, arm/real.gd), with a 5 t chunk, 720 frames each, a tighter dock check
# (40) and "straight forward" within 0.01.

const STILL_CHUNK_MASS = 5.0

func run():
	if not hasMod("ArmAltPullBehavior"):
		note("still: skipped, it needs ArmAltPullBehavior")
		return
	fixedShip = true
	dockLimit = 40.0
	forwardTolerance = 0.01
	# Time limits (s) on the feeding cases behind the red line: ArmAltPullBehavior 1.5.0's times + 25 %, all below
	# 1.4.0's, so a slow-down fails.
	for start in [["close beside the hull", Vector2(58, -130), 5.6], ["beside the hull, behind the red line", Vector2(120, -150), 5.7], ["near the corridor, behind the red line", Vector2(45, -215), 3.6], ["ahead of the red line, off to the side", Vector2(150, -330), INF], ["far ahead, off to the side", Vector2(-120, -480), INF]]:
		yield(pull(start[0] + ", ship still", start[1], 1.0, 720, "in", start[2]), "completed")
	yield(pull("close beside the hull, ship still", Vector2(58, -130), 0.0, 720, "forward-dock"), "completed")
	for start in [["beside the hull, behind the red line", Vector2(120, -150)], ["near the corridor, behind the red line", Vector2(45, -215)], ["ahead of the red line, off to the side", Vector2(150, -330)]]:
		yield(pull(start[0] + ", ship still", start[1], 0.0, 720, "dock"), "completed")

func caseChunkMass():
	return STILL_CHUNK_MASS
