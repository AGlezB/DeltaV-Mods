extends "res://harness/fleet_ship.gd"

# Stub of a stored ship (ships/ship-ctrl.gd) for the sale suite: a fleet ship whose systems are built from its config as
# the game's are (fillInSystems), each with the Repairs screen's prices and hours on its node and damage entries read
# from the config's `damage`, and the game's own formulas for a system's price, a slot's value and time, and the ship's
# value. The systems are those of a worked K37 derelict: a reactor and a HUD of the hull's own, a main hardpoint, 8
# thrusters and a main engine, priced by what is fitted (SPECS); the slots priced by their items have the Equipment
# screen's prices (NUMS).

# A system's node, with the Repairs screen's figures (ships/modules: repairReplacementPrice, repairFixPrice,
# repairFixTime, repairReplacementTime) and, in a slot, the slot's config key (`type`).
class Slotted:
	var type = ""
	var repairReplacementPrice = 0
	var repairFixPrice = 0
	var repairFixTime = 0
	var repairReplacementTime = 0

class Plain:
	var repairReplacementPrice = 0
	var repairFixPrice = 0
	var repairFixTime = 0
	var repairReplacementTime = 0

# The systems a slot can hold, by the slot's value: [price, fix price, fix hours, replacement hours].
const SPECS = {
	"SYSTEM_MWG": [70000, 1500, 6, 1],
	"SYSTEM_THRUSTER_MA350HO": [10000, 3500, 4, 1],
	"SYSTEM_THRUSTER_NDSTR": [1250, 200, 4, 1],
	"SYSTEM_MAIN_ENGINE_K37": [15000, 1000, 12, 4],
	"SYSTEM_MAIN_ENGINE_PNTR": [7000, 200, 8, 4],
}
# The hull's own systems: [node name, system name, price, fix price, fix hours, replacement hours].
const BUILT_IN = [
	["reactor", "SYSTEM_REACTOR", 80000, 5000, 48, 48],
	["Hud", "SYSTEM_HUD_TNTRL", 6000, 500, 4, 1],
]
# The slots with no system of their own: each value's price (Shipyard.gd getNumericValueOfConfig).
const NUMS = {
	"capacitor.capacity": {500.0: 25000, 1500.0: 90000},
	"turbine.power": {100.0: 30000, 200.0: 60000},
	"fuel.capacity": {15000.0: 6000, 30000.0: 12000},
	"reactor.power": {4.0: 80000},
	"autopilot.type": {"SYSTEM_AUTOPILOT_NONE": 0, "SYSTEM_AUTOPILOT_MK2": 27000},
	"lidar.type": {"SYSTEM_LIDAR_RADAR": 5000, "SYSTEM_LIDAR_DOPPLER": 15000},
	"hud.type": {"SYSTEM_NONE": 0, "SYSTEM_HUD_TNTRL": 4000},
}
const HULL = 17499.5 # the hull's value (ship-ctrl.gd getShipValue: its price over priceAdjust)
const DAMAGE_TYPES = ["a", "b", "c"] # each system's damage entries, each of capacity 1

var shipType = "fission"

# Set up as the game's ships are, once in the tree and not at once (ship-ctrl.gd defers setupShip until idle), so that
# what waits for a ship's setup, as ShipSaleAdvisor's trial ship does, waits here too.
func _init():
	setup = false

func _ready():
	call_deferred("_setUp")

func _setUp():
	setup = true
	emit_signal("setup")

func fillInSystems(_rolling = false):
	systems = {}
	for spec in BUILT_IN:
		var ref = Plain.new()
		_spec(ref, spec.slice(2, 5))
		_add(spec[0], spec[1], ref)
	_slotted("WeaponSlot", "weaponSlot.main.type")
	for i in 8:
		_slotted("thruster-%d" % i, "propulsion.rcs")
	_slotted("engine-main", "propulsion.main")

func _slotted(key, slot):
	var value = getConfigWithDefaults(slot)
	if not SPECS.has(value):
		return
	var ref = Slotted.new()
	ref.type = slot
	_spec(ref, SPECS[value])
	_add(key, value, ref)

func _spec(ref, spec):
	ref.repairReplacementPrice = spec[0]
	ref.repairFixPrice = spec[1]
	ref.repairFixTime = spec[2]
	ref.repairReplacementTime = spec[3]

# A system as getSystems lists it: its condition from its worst damage (the systems' getStatus), its damage entries as
# the Repairs screen reads them, and its damage key.
func _add(key, name, ref):
	var damage = []
	var worst = 0.0
	var stored = shipConfig.get("damage", {}).get(key, {})
	for t in DAMAGE_TYPES:
		var current = max(0.0, float(stored.get(t, 0)))
		damage.append({"type": t, "maxRaw": 1.0, "max": 1.0, "current": current, "name": t})
		worst = max(worst, current)
	systems[key] = {"name": name, "status": clamp(100 - 100 * worst, 0, 100), "ref": ref, "damage": damage, "key": key}

func getSystems():
	if systems.empty():
		fillInSystems()
	return systems.duplicate()

# As ship-ctrl.gd: the price times the condition squared, times 0.8 below 100 %.
func getSystemPrice(system):
	var pf = pow(system.status / 100, 2)
	var o = system.ref
	if o != null and "repairReplacementPrice" in o:
		if pf < 1:
			pf *= 0.8
		return o.repairReplacementPrice * pf
	return 0.0

func getSlotValue(type):
	var price = 0.0
	var any = false
	for s in getSystems().values():
		if "type" in s.ref and s.ref.type == type:
			price += getSystemPrice(s)
			any = true
	return price if any else -1.0

func getSlotTime(type):
	var time = 0.0
	var any = false
	for s in getSystems().values():
		if "type" in s.ref and s.ref.type == type and s.status < 100:
			time += s.ref.repairReplacementTime * 3600
			any = true
	return time if any else -1.0

func getNumberOfSlots(type):
	var n = 0
	for s in getSystems().values():
		if "type" in s.ref and s.ref.type == type:
			n += 1
	return n if n > 0 else 1

func getShipValue():
	fillInSystems()
	var total = HULL
	for s in systems.values():
		total += getSystemPrice(s)
	for slot in NUMS:
		total += NUMS[slot].get(getConfigWithDefaults(slot), 0)
	return total
