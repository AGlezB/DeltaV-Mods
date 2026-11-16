extends Node2D

# Stub of the player's ship (ships/ship-ctrl.gd) for the skip suite: what Game.gd (_ready, _respawn_ship, _process,
# interlunarToEnceladus), enceladus/Enceladus.gd (_on_DiveTarget_launch) and DiveSkipTransit reach. A Node2D, so
# nothing moves it between checks. Remass as the game's: drawReactiveMass, and getRemassRequiredForDv on a fixed mass
# with one thruster's exhaust velocity. The suite fills `reactors` with nodes of the game's reactor scripts and
# `thrusters` with harness/skip_thruster.gd nodes, keyed by name as the game's (each {node, vector}, the thruster's push
# in the ship's frame). The transit back records the remass and in-game time it was charged from in `events`.

signal setup()
signal exitingRing()
signal fastTraveling()
signal teleport(to, velocity)
signal instance()
signal shipPowerToggle(onoff)

var zone = ""
var preheat = false
var linear_velocity = Vector2(0, 0)
var autopilot = false
var autopilotDesiredVelocity = Vector2(0, 0)
var autopilotDesiredRotation = 0.0
var cutscene = false
var fastTravelDirection = 0
var frozen = null # the game's starts null (setFrozen)
var reactiveMass = 40000.0 # kg
var currentMass = 150.0 # t, as computeCurrentMass leaves it
var cargoMass = 0.0
var exhaustVelocity = 30.0 # the best thruster's specificImpulse, which getBestThrusterVe returns
var reactors = []
var thrusters = {}
var shipName = "Skip stub"
var interlunarRemass = 0.0 # what getInterlunarTransitRemass returns; Game.gd _ready charges it after setup
var interlunarTime = 0.0 # what getInterlunarTransitTime returns; Game.gd _ready charges it after setup
var transitRemass = 0.0 # the remass the transit back needs (getTransitRemassToEnceladus takes what is left of it)
var transitTime = 0.0 # what getTimeRequiredToBurnToEnceladus returns
var events = [] # what happened, in order; the suite shares it with the asteroid field

func getSystems():
	return {}

func getTimeRequiredToBurnToEnceladus() -> float:
	return transitTime

# As the game's, all of what it needs or the remass left; it also records that remass and the in-game time.
func getTransitRemassToEnceladus() -> float:
	events.append(["transit", reactiveMass, CurrentGame.state.get("time", 0.0)])
	return min(reactiveMass, transitRemass)

func getInterlunarTransitRemass(_extraMass = 0.0) -> float:
	return interlunarRemass

func getInterlunarTransitTime() -> float:
	return interlunarTime

func getShipName():
	return "Skip stub"

func isHelpless():
	return false

func temporaryCargoMass():
	return 0.0

func getBestThrusterVe() -> float:
	return exhaustVelocity

# As the game's (ships/ship-ctrl.gd).
func getRemassRequiredForDv(dv: float, extraMass = 0) -> float:
	if currentMass:
		var best = getBestThrusterVe()
		if not best:
			return 0.0
		var sm = currentMass * 1000 + cargoMass + temporaryCargoMass() + extraMass
		return max(sm, 0) * (1 - exp( - dv / (1000 * best)))
	else:
		return 0.0

# As the game's (ships/ship-ctrl.gd).
func drawReactiveMass(kg, really = true):
	var drawn = min(kg, reactiveMass)
	if really:
		reactiveMass -= drawn
	return drawn
