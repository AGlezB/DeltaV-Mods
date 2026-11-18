extends Node2D

# Stub of the ring scene's asteroid field (AsteroidField.tscn, AsteroidSpawner.gd) for the combat suite: what
# CombatSimulator's arena sets and calls, with the game's names, defaults and signatures. Its _ready reads the map and
# reseeds the random numbers as the game's does; nothing spawns. It records the minSpawnRadius of each spawnProperThings
# call (`spawns`), the handleMood calls (`moods`), its _process frames (`processed`; the game's advances in-game time
# there), traceSpawns as _ready found it, and each spawnByBlueprint call (`blueprints`: [spot, spawnPointRandomness]).
# spawnByBlueprint places the ship at the spot itself (the game's moves it by up to spawnPointRandomness when rocks are
# in the way) and sets its zone, as the game's; it refuses as many spots as the script's metadata `refuse` says when the
# field is made, as the game's does a spot a rock takes.

export var seedWord = "Delta-v: Rings"
export var zone = "rings"
export var spawnEvery = 0.02
export var minSpawnRadius = 15000
export var cutsceneSpawnRadius = 800
export (int, LAYERS_2D_PHYSICS) var oddityIntersectionTest = 3
export (int, LAYERS_2D_PHYSICS) var asteroidIntersectionTest = 3
export (NodePath) var map
export var traceSpawns = true

var mapInstance
var focusObject
var spawns = []
var moods = 0
var processed = 0
var tracedAtReady = null
var blueprints = []
var refuse = 0

func _init():
	var script = get_script()
	if script.has_meta("refuse"):
		refuse = script.get_meta("refuse")
		script.set_meta("refuse", 0)

func _ready():
	tracedAtReady = traceSpawns
	if map:
		mapInstance = get_node(map)
	seed(seedWord.hash())

func _process(_delta):
	processed += 1

func handleMood(_delta):
	moods += 1

func spawnProperThings(_delta):
	spawns.append(minSpawnRadius)

func spawnByBlueprint(instance: RigidBody2D, spot, _chaos, spawnPointRandomness = 0.0, _initialLinearVelocity = Vector2(0, 0), _initialAngularVelocity = 0.0, _tries = 3):
	blueprints.append([spot, spawnPointRandomness])
	if refuse > 0:
		refuse -= 1
		return false
	instance.global_position = spot
	instance.global_rotation = rand_range(0, PI * 2)
	if "zone" in instance:
		instance.zone = zone
	add_child(instance)
	return true
