extends Control

# Stub of the game's HUD (hud/Hud.gd) for hud/LIDAR.gd, which takes its first parent with getSensorReadout as its
# reader. registerSubsystem records what the Tuning screen would list.

var ship = null
var subsystems = {}

func getSensorReadout():
	return null

func getShip():
	return ship

func registerSubsystem(key, config):
	subsystems[key] = config
