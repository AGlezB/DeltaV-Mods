extends Node2D

# For the repairs suite: the player's ship as the Repairs screen and its rows use it (ship-ctrl.gd): its systems
# (getSystems, fillInSystems, which counts its polls), each one's damage by type, a condition from the worst damage for
# what it can take, or from a share no damage explains (the arm's overheat, DockingArm.gd doComputeStatus), and the
# game's getSystemPrice and changeSystemDamage, which the rows' Fix and Replace call (SystemShipRepairUI.gd).

signal setup()
signal damageChanged()
signal juryRigChanged()
signal systemPoll()

const PART = "res://harness/repairs_part.gd"

var setup = true
var parts = {} # by key: {"ref", "damage": {type: [current, max]}, "stuck": the share of the condition no damage explains}
var available = {}
var polls = 0

func addPart(key, name, price, fixPrice, fixTime, replaceTime, damage, stuck = 0.0):
	var ref = load(PART).new()
	ref.systemName = name
	ref.repairReplacementPrice = price
	ref.repairFixPrice = fixPrice
	ref.repairFixTime = fixTime
	ref.repairReplacementTime = replaceTime
	parts[key] = {"ref": ref, "damage": damage, "stuck": stuck}
	fillInSystems()

func status(key) -> float:
	var worst = parts[key].stuck
	for type in parts[key].damage:
		var d = parts[key].damage[type]
		worst = max(worst, d[0] / d[1])
	return clamp(100.0 - 100.0 * worst, 0.0, 100.0)

func getSystems(_always = false):
	return available.duplicate()

func fillInSystems(_rolling = false):
	polls += 1
	available = {}
	for key in parts:
		var damage = []
		for type in parts[key].damage:
			var d = parts[key].damage[type]
			damage.append({"type": type, "current": max(0.0, d[0]), "max": d[1], "maxRaw": d[1], "name": type})
		available[key] = {"name": parts[key].ref.systemName, "status": status(key), "ref": parts[key].ref,
				"damage": damage, "key": key}
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

func changeSystemDamage(system, type, delta, _capacity = null):
	var d = parts[system].damage[type]
	d[0] += delta
	emit_signal("damageChanged")
	return d[0]
