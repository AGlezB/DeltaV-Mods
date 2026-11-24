extends Node2D

# Stub of a ship (ships/ship-ctrl.gd) for the turret suite: what the game's PDT.gd and SystemList.gd ask of it, and what
# TurretLockableFacing reads. Its config (getConfig, setConfig, by dotted key, as the game's) holds the tuning the mod
# keeps its angle in; drawEnergy gives all it is asked for and adds it up, so a suite sees what turning draws.

signal systemsChanged(how)
signal tuningChanged

var setup = true
var cutscene = false
var playerControlled = true
var systemsDict = {} # what getSystems gives: the Mechanic tab's rows
var energyDrawn = 0.0
var shipConfig = {}

func getConfig(key, default = null):
	var c = shipConfig
	for k in key.split("."):
		if c is Dictionary and k in c:
			c = c[k]
		else:
			return default
	return c

func setConfig(key, value):
	var c = shipConfig
	var path = key.split(".")
	for n in range(path.size() - 1):
		if not (path[n] in c):
			c[path[n]] = {}
		c = c[path[n]]
	c[path[path.size() - 1]] = value

func isPlayerControlled():
	return playerControlled

func drawEnergy(e):
	energyDrawn += e
	return e

func getTunedValue(slot, key, default):
	return default

func getSystems(always = false):
	return systemsDict

func soundAlert():
	pass

func getSystemJuryRig(system, type):
	return 0

func setSystemJuryRig(system, type, value):
	pass

func actionForEvent(command):
	return null
