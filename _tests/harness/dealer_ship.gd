extends Node2D

# A ship model's scene for the dealer suite (harness/dealer/*.tscn), standing in for the game's (ships/*.tscn, with
# ships/ship-ctrl.gd): the names DealerNotifier reads (shipName and baseShipName, exported as ship-ctrl.gd's, with
# defaults of their own), and what a ship drawn in a Dealer entry's viewport goes through (SystemBuyUI.gd addShip):
# dummy, reactor, preheat, cutscene, and `setup`, signalled two physics frames after it enters the tree, as the game's
# comes after its placeholders load. Counts the instances made (the metadata `made` of this script), so a test sees
# that a name was read without making a ship.
#
# Its hardpoints are the game's (ships/WeaponSlot.gd, inline or as placeholders of weapons/WeaponSlot.tscn), so it has
# what they ask of their ship: its config (shipConfig, by reference, as Shipyard.gd createShipByConfig keeps it), read
# and written as ship-ctrl.gd does, and the count of what is still loading (changeExternalPlaceholders). Its
# placeholders are never loaded. Each ship that enters the tree records, in the metadata `drawn` of this script, its
# model, the config it enters the tree with (a copy) and its parent's instance id.

signal setup()

export var shipName = "TEST_SHIP_DEFAULT"
export var baseShipName = ""

var setup = false
var transponder = ""
var model = ""
var faction = ""
var madeTimestamp = 0
var fullConfig = {}
var shipConfig = {}
var dummy = false
var preheat = true
var cutscene = false
var reactorOn = true
var externalSystems = []
var externalPlaceholders = 0

func _init():
	var script = get_script()
	script.set_meta("made", (script.get_meta("made") if script.has_meta("made") else 0) + 1)

func _ready():
	var script = get_script()
	if not script.has_meta("drawn"):
		script.set_meta("drawn", [])
	script.get_meta("drawn").append({"model": model, "config": shipConfig.duplicate(true), "parent": get_parent().get_instance_id()})
	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	if is_inside_tree():
		setup = true
		emit_signal("setup")

func setDummy(how, _always = false):
	dummy = how

func setReactorState(on):
	reactorOn = on

func changeExternalPlaceholders(by: int):
	externalPlaceholders += by

func getConfig(key, default = null, c = shipConfig):
	for k in key.split("."):
		c = c.get(k) if c is Dictionary else null
	if c == null:
		return default
	return c

func setConfig(key, value, c = shipConfig):
	var path = key.split(".")
	for n in range(path.size() - 1):
		var k = path[n]
		if not (k in c):
			c[k] = {}
		c = c[k]
	c[path[path.size() - 1]] = value

func removeConfig(key):
	var c = shipConfig
	var path = key.split(".")
	for n in range(path.size() - 1):
		c = c.get(path[n]) if c is Dictionary else null
	if c is Dictionary:
		c.erase(path[path.size() - 1])
