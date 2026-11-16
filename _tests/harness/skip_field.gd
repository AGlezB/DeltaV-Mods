extends Node2D

# Stub of the ring scene's asteroid field (AsteroidField.tscn, AsteroidSpawner.gd) for the skip suite: the ship is
# added to it; the "exit" animation calls its despawnAllAsteroids, and Game.gd sendHelp spawns the rescue ship through
# spawnByBlueprint, which always finds room here. Both are recorded in `events` (the suite gives it the log the ship
# records in too).

var events = []

func despawnAllAsteroids():
	events.append("despawnAllAsteroids")

func spawnByBlueprint(blueprint, _where, _a, _b):
	events.append("spawnByBlueprint")
	add_child(blueprint)
	return true
