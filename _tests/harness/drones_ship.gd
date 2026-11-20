extends "res://harness/geology_ship.gd"

# Stub of a ship (ships/ship-ctrl.gd) for the drones suite: the geology suite's (the config with the game's dotted keys,
# where "hud.config" is the HUD's mineralConfig; what hud/Hud.gd reaches; the identified chunks), plus what
# weapons/drone-plant.gd reaches: its Tuning (getTunedValue), the USV-GOT's priority queue (droneQueue), the target
# bus (isValidSystemTarget, refusing what another system has), the plant's Geologist-tab filter (isValidMineralTarget,
# refusing what the suite lists, and recording each call), the excavator (getSystemsFiredBy("x")) and, for the
# maintenance drones, the ship's damaged systems (getSystems).

var linear_velocity = Vector2()
var droneQueue = []
var autopilotVelocityOffsetTarget = null
var haulMinDistance = 400
var droneGatheringSpotRotation = 0.0
var cutscene = false
var firedBy = {} # getSystemsFiredBy results by key ("x": the excavator)
var tuned = {} # getTunedValue results by "<system>.<tune>"
var refusedByBus = [] # objects another system of the ship has taken
var refusedByFilter = [] # objects the plant's Geologist-tab row turns down
var systems = {} # getSystems(): {key: {"key", "damage": [{"current", "maxRaw"}]}}
var dronesCapacity = 0

func getTunedValue(system, tune, default):
	return tuned.get("%s.%s" % [system, tune], default)

func addDronesCapacity(amount):
	dronesCapacity += amount

func getSystemsFiredBy(key):
	return firedBy.get(key, [])

func isValidSystemTarget(_system, object):
	return not refusedByBus.has(object)

func isValidMineralTarget(object, config):
	calls.append([object, config])
	return not refusedByFilter.has(object)

func addSystemTarget(_system, _object):
	pass

func clearSystemTarget(_system):
	pass

func getSystems():
	return systems

func aiGetDispositionTowards(_object):
	return {"support": 0.0}
