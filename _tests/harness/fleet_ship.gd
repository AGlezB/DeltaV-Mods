extends Node2D

# Stub of an owned ship (ships/ship-ctrl.gd) for the fleet suite: what a Fleet entry (enceladus/SystemBuyUI.gd), an
# Equipment item (enceladus/SystemShipUpgradeUI.gd) and ShipCopyPaste reach. The config accessors are the game's,
# without the mutex; clearDamageInSlot records the slot instead of clearing the systems' damage.

signal setup()
signal damageChanged()

var setup = true
var shipName = "SHIP_TEST" # the model's key, which the entry shows
var transponder = ""
var model = ""
var madeTimestamp = 0
var value = 1000000.0 # what getShipValue gives
var fullConfig = {}
var shipConfig = {}
var dummy = false
var preheat = false
var cutscene = false
var defaultLidar = "SYSTEM_LIDAR_DOPPLER" # ship-ctrl.gd's
var upgradeLimits = {}
var slots = {} # how many systems each slot has (getNumberOfSlots); 1 where not given
var cleared = [] # the slots clearDamageInSlot was given, in order

# The ship of a full config, as Shipyard.gd createShipByConfig keeps it: by reference.
func useConfig(full: Dictionary):
	fullConfig = full
	shipConfig = full.config
	transponder = full.get("transponder", "")
	model = full.get("model", "")

func getConfig(key, default = null, c = shipConfig):
	for k in key.split("."):
		c = nestedGet(c, k)
	if c == null:
		return default
	return c

func nestedGet(from, key):
	if from == null:
		return null
	if key in from:
		return from[key]
	return null

func setConfig(key, value, c = shipConfig):
	var path = key.split(".")
	for n in range(path.size() - 1):
		var k = path[n]
		if not (k in c):
			c[k] = {}
		c = c[k]
	c[path[path.size() - 1]] = value

func getConfigWithDefaults(key):
	match key:
		"lidar.type":
			return getConfig(key, defaultLidar)
		_:
			return getConfig(key)

func clearDamageInSlot(slot):
	cleared.append(slot)

func getNumberOfSlots(slot):
	return slots.get(slot, 1)

func queryCapability(_key, _system):
	return true

func setReactorState(_on):
	pass

func setDummy(how, _always = false):
	dummy = how

func getShipValue():
	return value

func getShipName():
	return CurrentGame.getShipNameByTransponder(transponder)

func getSystems():
	return {}

func canBeSold():
	return fullConfig.get("maintaineceUntil", 0) <= CurrentGame.getInGameTimestamp()

func getReactorPower():
	return 100.0

func getTurbinePower(_withCapacitor = false):
	return 1000.0
