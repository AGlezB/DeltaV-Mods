extends Node2D

# Stub of a ship (ships/ship-ctrl.gd) for the callout suite: what hud/Hud.gd _ready and instance() reach (the geology
# suite's ship's signals and members, and its systems for the OMS tabs of DroneAltPriorities and GeologyByMass when they
# are loaded too), and what LidarContactCallout reads: the zone (Game.gd _respawn_ship sets "rings"), the Pilot tab's
# rows (identifiedShips: [transponder, shipName, object, marked, flags] by the object's hash, added and removed with
# the game's addIdentifiedShip and removeIdentifiedShip, which emit identifiedShipsChanged on a change), the ship's
# transponder, what the arm holds (temporaryCargo), the cutscene flag, who it is talking with and its LIDAR (`lidar`,
# harness/callout_lidar.gd). And what the game's comms line reads of the ship a line is from and to (Tool.gd
# getTranslationDictionary): its transponder, name and captain, as ship-ctrl.gd gives them.

signal damageImpact(power, point, delta)
signal damageThermal(power, point, delta)
signal damageEMP(power, point, delta)
signal instance()
signal playerControllChanged(how)
signal frozen(how)
signal systemsChanged(to)
signal setup()
signal identifiedShipsChanged()

var shipConfig = {}
var playerControlled = true
var preheat = false # true: the HUD boots at once, and its _ready builds the OMS
var frozen = false
var forceHud = false
var fullSimulation = false
var ageWithSeed = 0

var zone = "rings"
var identifiedShips = {}
var transponder = "PLR-1"
var temporaryCargo = []
var cutscene = false
var talkingWith = null
var lidar = null

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

func getSystems():
	return {}

func isValidMineralTarget(_object, _config):
	return true

func getTransponder():
	return transponder

# As ship-ctrl.gd's.
func getShipName():
	return CurrentGame.getShipNameByTransponder(transponder)

func getCrewMember(agenda = ""):
	return Namer.makeDetail("crew", hash(transponder + agenda))

# As ship-ctrl.gd's (without the IFF data): a new row, or a row's transponder, name or mark changed, emits
# identifiedShipsChanged; a mark is never taken back.
func addIdentifiedShip(ship: RigidBody2D, code: String, shipName: String = "", marker = false, flag = 1):
	if ship != self:
		var changed = false
		var h = hash(ship)
		if h in identifiedShips:
			if code and identifiedShips[h][0] != code:
				identifiedShips[h][0] = code
				changed = true
			if shipName and identifiedShips[h][1] != shipName:
				identifiedShips[h][1] = shipName
				changed = true
			identifiedShips[h][2] = ship
			if marker and identifiedShips[h][3] != marker:
				identifiedShips[h][3] = marker
				changed = true
			identifiedShips[h][4] = (identifiedShips[h][4] | flag)
		else:
			identifiedShips[h] = [code, shipName, ship, marker, flag]
			changed = true
		if changed:
			emit_signal("identifiedShipsChanged")

func removeIdentifiedShip(ship: RigidBody2D, flag = 1):
	var h = hash(ship)
	if h in identifiedShips:
		identifiedShips[h][4] = (identifiedShips[h][4] & ~ flag)
		if identifiedShips[h][4] == 0:
			identifiedShips.erase(h)
			emit_signal("identifiedShipsChanged")
