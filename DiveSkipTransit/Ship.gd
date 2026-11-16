extends "res://ships/ship-ctrl.gd"

# Every ship (ships/ship-ctrl.gd). Astrogation inside the ring is a cutscene: once a plotted course is complete,
# fastTravelTo emits fastTraveling (Game.gd _onFastTravel plays the "fasttravel" title card) and, while the autopilot
# holds the travel velocity towards the destination, waits, adds the travel time to the clock, waits, folds space to
# put the ship short of the destination (teleportTo: the world moves, not the ship), waits again and stops. While its
# setting is on, the mod takes those steps at once for the player's ship and charges what the waits would have cost:
# their in-game time and turbine remass, and the change to the travel velocity. Other ships, and the course to
# Enceladus (escapeTheRing, the exit cutscene), are left to the game.

# The settings (which skips are on), shared with the settings screen, and the code the skips share.
const DiveSkipTransit = preload("res://DiveSkipTransit/Settings.gd")
# The game's waits in fastTravelTo: before the jump (3.5 s, then 1.5 s once the clock has moved), and after it.
const _DST_ASTROGATION_BEFORE_JUMP = 5.0
const _DST_ASTROGATION_AFTER_JUMP = 1.5

# The game's fastTravelTo without its waits. The ship lands where the game's would be when the cutscene ends: the
# game's arrival point (short of the destination by the travel velocity's ten seconds, at most astrogationMinDistance),
# drifted on at the travel velocity for the wait after the jump. The cutscene flag is left alone: its setter would
# signal it on and off in the same frame.
func fastTravelTo(target):
	if not isPlayerControlled() or target.name == "DESTINATION_ENCELADUS" \
			or not DiveSkipTransit.shared().getValue("skipAstrogation"):
		return .fastTravelTo(target)
	trajectoryTarget = null
	autopilot = true
	var dvec = CurrentGame.getInRingVectorTowards(target.vector, CurrentGame.globalCoords(global_position))
	var time = dvec.length() / astrogationVelocity
	var velocity = dvec.normalized() * astrogationVelocity
	autopilotDesiredVelocity = velocity
	emit_signal("fastTraveling")
	DiveSkipTransit.chargeDv(self, (velocity - linear_velocity).length() / DiveSkipTransit.UNITS_PER_METRE)
	DiveSkipTransit.chargeSeconds(self, _DST_ASTROGATION_BEFORE_JUMP + _DST_ASTROGATION_AFTER_JUMP)
	trajectoryProgress = null
	CurrentGame.advanceTimeBySeconds(time)
	fastTravelDirection = -1
	linear_velocity = velocity
	var shortOf = velocity.normalized() * min(astrogationMinDistance, velocity.length() * 10)
	teleportTo(target.vector - shortOf + velocity * _DST_ASTROGATION_AFTER_JUMP)
	autopilotDesiredVelocity = Vector2(0, 0)
	aiImperativeDirection = Vector2(0, 0)
