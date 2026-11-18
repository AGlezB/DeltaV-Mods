extends RigidBody2D

# A ship for the combat suite (ships/CombatTestShip.tscn, which run.ps1 writes under ships/, where CombatSimulator looks
# for ship models), standing in for the game's (ships/*.tscn, ships/ship-ctrl.gd): the members CombatSimulator's arena
# sets and reads, with ship-ctrl.gd's names, exports and defaults (the dialog trees are empty paths, as a scene that sets
# none leaves them); `exitedToEnceladus` reset as the ship enters the tree, as ship-ctrl.gd's _enter_tree resets it; its
# config read as ship-ctrl.gd reads it (the gravimetric readout asks for its scanner); `removal`, which Tool.remove
# emits; `setup`, true at once (the readout waits for the signal otherwise). And what the dialog's ship list
# (CombatSimulator/ShipList.gd) asks of a ship whose picture it draws, as DealerNotifier's: setDummy, setReactorState,
# setConfig, `dummy` and `cutscene`.

signal removal
signal setup
signal configChanged(key, value)

export var shipName = "SHIP_TRTL"
export var hailable = true
export var talkWhenInCargoHold = false
export var talkWhenDocksToPlayer = false
export (NodePath) var dialogTree
export (NodePath) var farewellDialogTree

var zone = ""
var test = false
var playerControlled = false
var preheat = false
var ai = false
var faction = ""
var transponder = ""
var model = ""
var madeTimestamp = 0
var fullConfig = {}
var shipConfig = {}
var exitedToEnceladus = false
var setup = true
var dummy = false
var cutscene = false
var reactorOn = true

func _enter_tree():
	exitedToEnceladus = false

func setDummy(how, _always = false):
	dummy = how

func setReactorState(on):
	reactorOn = on

func setConfig(key, value):
	var c = shipConfig
	var path = key.split(".")
	for n in range(path.size() - 1):
		if not c.get(path[n]) is Dictionary:
			c[path[n]] = {}
		c = c[path[n]]
	c[path[path.size() - 1]] = value

func isPlayerControlled():
	return playerControlled

func getConfig(key, default = null):
	var c = shipConfig
	for k in key.split("."):
		if not c is Dictionary or not k in c:
			return default
		c = c[k]
	return c
