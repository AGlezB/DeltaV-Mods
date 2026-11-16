extends Node2D

# Stub of the player's ship (ships/ship-ctrl.gd) for the skip suite: what Game.gd (_ready, _respawn_ship, _process),
# enceladus/Enceladus.gd (_on_DiveTarget_launch) and DiveSkipTransit reach. A Node2D, so nothing moves it between
# checks. Remass as the game's: drawReactiveMass, and getRemassRequiredForDv on a fixed mass with one thruster's
# exhaust velocity. The suite fills `reactors` with nodes of the game's reactor scripts.

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
var interlunarRemass = 0.0 # what getInterlunarTransitRemass returns; Game.gd _ready charges it after setup
var interlunarTime = 0.0 # what getInterlunarTransitTime returns; Game.gd _ready charges it after setup

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
