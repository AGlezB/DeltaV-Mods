extends Node2D

# Stub of a ship (ships/ship-ctrl.gd) for the geology suite: what hud/Hud.gd _ready and instance() reach (the same
# signals and members), its config with the game's dotted keys (getConfig / setConfig: "hud.config" is the HUD's
# mineralConfig), the identified chunks (identifiedObjects: [kg by mineral, value, position, object] by the object's
# hash, as addIdentifiedObject stores them), and isValidMineralTarget, which records each call and returns `answer`
# instead of the game's rule.

signal damageImpact(power, point, delta)
signal damageThermal(power, point, delta)
signal damageEMP(power, point, delta)
signal instance()
signal playerControllChanged(how)
signal frozen(how)

var shipConfig = {}
var identifiedObjects = {}
var playerControlled = true
var preheat = false # true: the HUD boots at once, and its _ready builds the OMS
var frozen = false
var forceHud = false
var fullSimulation = false
var ageWithSeed = 0

var answer = true # what isValidMineralTarget returns
var calls = [] # each isValidMineralTarget call: [object, config]

func isPlayerControlled():
	return playerControlled

func getConfig(key, default = null):
	var c = shipConfig
	for k in key.split("."):
		if not (c is Dictionary and k in c):
			return default
		c = c[k]
	return default if c == null else c

func setConfig(key, value):
	var c = shipConfig
	var path = key.split(".")
	for n in range(path.size() - 1):
		if not path[n] in c:
			c[path[n]] = {}
		c = c[path[n]]
	c[path[path.size() - 1]] = value

func isValidMineralTarget(object, config):
	calls.append([object, config])
	return answer
