extends Node2D

# For the repairs suite: the player's ship for ShipRepairAdvisor's Park, built from its config as the game builds one
# (the Shipyard stub's createShipByConfig sets fullConfig and shipConfig; without them, CurrentGame.state.ship's is
# read): its systems from the pieces fitted (PIECES), their damage kept in the config by system key, as the game keeps
# it, so it survives the ship being built again; slot members (with a `type`) and the other systems; set up two physics
# frames after entering the tree; the game's getSystemPrice, getSlotValue, getSlotTime, getNumberOfSlots and
# clearDamageInSlot (ship-ctrl.gd), and what a trial ship is told (setDummy, setReactorState, preheat, cutscene).

signal setup()
signal damageChanged()
signal juryRigChanged()
signal systemPoll()

const PART = "res://harness/repairs_part.gd"
const SLOT_PART = "res://harness/repairs_slot_part.gd"
# slot -> piece -> its systems: [key, name, price, fix price, fix hours, replace hours, on the slot]. RCS_B's systems are
# worth less than the Equipment screen's price for it, as some of the game's are.
const PIECES = {
	"weaponSlot.main.type": {
		"SYSTEM_NONE": [],
		"SYSTEM_LASER": [["weaponSlot.main", "SYSTEM_LASER", 200000, 30000, 4, 1, true]],
		"SYSTEM_GUN": [["weaponSlot.main", "SYSTEM_GUN", 20000, 2000, 2, 1, true]],
	},
	"weaponSlot.left.type": {
		"SYSTEM_NONE": [],
		"SYSTEM_GUN": [["weaponSlot.left", "SYSTEM_GUN", 20000, 2000, 2, 1, true]],
	},
	"propulsion.rcs": {
		"RCS_A": [["rcs1", "RCS_A", 3000, 500, 1, 1, true], ["rcs2", "RCS_A", 3000, 500, 1, 1, true]],
		"RCS_B": [["rcs1", "RCS_B", 7958, 800, 1, 1, true], ["rcs2", "RCS_B", 7958, 800, 1, 1, true]],
	},
	"reactor.power": {
		"1": [["reactor", "SYSTEM_REACTOR", 50000, 5000, 8, 12, false]],
		"2": [["reactor", "SYSTEM_REACTOR", 120000, 12000, 8, 12, false]],
	},
	"hud.type": {
		"HUD_A": [["hud", "SYSTEM_HUD", 5000, 500, 2, 1, false]],
		"HUD_B": [["hud", "SYSTEM_HUD", 9000, 900, 2, 1, false]],
	},
	"lidar.type": {
		"LIDAR_A": [["lidar", "SYSTEM_LIDAR", 6000, 600, 2, 1, true]],
	},
}
# Systems on no slot.
const FIXED = [["cabin", "SYSTEM_CABIN", 10000, 1000, 2, 3, false]]
# What every damage can take (the game's systems: getDamageCapacity); the config keeps each damage as a number.
const CAPACITY = 1000.0

var fullConfig = null
var shipConfig = null
var madeTimestamp = 0
var transponder = ""
var faction = ""
var model = ""
var setup = false
var dummy = false
var preheat = true
var cutscene = false
var upgradeLimits = {} # none: every number of the Equipment screen fits (SystemShipUpgradeUI.gd isAvailable)
var refs = {}
var available = {}

func config() -> Dictionary:
	return shipConfig if shipConfig is Dictionary else CurrentGame.state.ship.config

func _ready():
	var list = FIXED.duplicate()
	for slot in PIECES:
		var value = getConfigWithDefaults(slot)
		if value == null:
			continue
		var piece = str(int(value)) if value is float or value is int else value
		list += PIECES[slot].get(piece, [])
	for entry in list:
		var ref = load(SLOT_PART if entry[6] else PART).new()
		ref.systemName = entry[1]
		ref.repairReplacementPrice = entry[2]
		ref.repairFixPrice = entry[3]
		ref.repairFixTime = entry[4]
		ref.repairReplacementTime = entry[5]
		if entry[6]:
			ref.type = _slotOf(entry[0])
		refs[entry[0]] = ref
	if setup:
		fillInSystems()
		return
	for i in 2:
		yield(get_tree(), "physics_frame")
	setup = true
	fillInSystems()
	emit_signal("setup")

func setDummy(how, _always = false):
	dummy = how

func setReactorState(_on):
	pass

func _slotOf(key):
	for slot in PIECES:
		for piece in PIECES[slot]:
			for entry in PIECES[slot][piece]:
				if entry[0] == key:
					return slot
	return ""

func damage() -> Dictionary:
	if not config().has("damage"):
		config().damage = {}
	return config().damage

func status(key) -> float:
	var worst = 0.0
	var d = damage().get(key, {})
	for type in d:
		worst = max(worst, float(d[type]) / CAPACITY)
	return clamp(100.0 - 100.0 * worst, 0.0, 100.0)

func getSystems(_always = false):
	return available.duplicate() if setup else {}

func fillInSystems(_rolling = false):
	available = {}
	for key in refs:
		var list = []
		var d = damage().get(key, {})
		for type in d:
			list.append({"type": type, "current": max(0.0, float(d[type])), "max": CAPACITY, "maxRaw": CAPACITY, "name": type})
		available[key] = {"name": refs[key].systemName, "status": status(key), "ref": refs[key], "damage": list, "key": key}
	emit_signal("systemPoll")

# As the game's.
func getSystemPrice(system):
	if not setup:
		return 0
	var pf = pow(system.status / 100, 2)
	var o = system.ref
	if o != null and "repairReplacementPrice" in o:
		if pf < 1:
			pf *= 0.8
		return o.repairReplacementPrice * pf
	return 0.0

func changeSystemDamage(key, type, delta, _capacity = null):
	var d = damage()[key]
	d[type] = max(0.0, float(d[type]) + delta)
	emit_signal("damageChanged")
	return d[type]

# As the game's getConfig and setConfig: a dotted key is a path in the nested config.
func getConfigWithDefaults(slot):
	var node = config()
	for k in slot.split("."):
		if not node is Dictionary or not node.has(k):
			return null
		node = node[k]
	return node

func setConfig(slot, value):
	var node = config()
	var path = slot.split(".")
	for i in path.size() - 1:
		if not node.get(path[i]) is Dictionary:
			node[path[i]] = {}
		node = node[path[i]]
	node[path[path.size() - 1]] = value

func _members(slot) -> Array:
	var out = []
	for key in refs:
		if "type" in refs[key] and refs[key].type == slot:
			out.append(key)
	return out

# As the game's: a slot's members' worth, or -1 for a slot without members (the Equipment screen then prices it by the
# fitted item).
func getSlotValue(slot) -> float:
	var members = _members(slot)
	if members.empty():
		return -1.0
	fillInSystems()
	var price = 0.0
	for key in members:
		price += getSystemPrice(available[key])
	return price

func getSlotTime(slot) -> float:
	var members = _members(slot)
	if members.empty():
		return -1.0
	var time = 0.0
	for key in members:
		if status(key) < 100:
			time += refs[key].repairReplacementTime * 3600
	return time

func getNumberOfSlots(slot):
	var n = _members(slot).size()
	return n if n > 0 else 1

# As the game's: a slot's members only.
func clearDamageInSlot(slot):
	for key in _members(slot):
		var d = damage().get(key, {})
		for type in d:
			d[type] = 0.0

func queryCapability(_slot, _system):
	return true

func getReactorPower():
	return 1000.0

func getTurbinePower(_x = false):
	return 1000.0
