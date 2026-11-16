extends Node2D

# Stub of the ring scene's asteroid field (AsteroidField.tscn, AsteroidSpawner.gd) for the skip suite: the ship is
# added to it, and the "exit" animation calls its despawnAllAsteroids, which this records in `events` (the suite gives
# it the log the ship records in too).

var events = []

func despawnAllAsteroids():
	events.append("despawnAllAsteroids")
