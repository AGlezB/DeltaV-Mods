extends Node2D

# Stub of the game's ship for CabinLight.gd (the Adrenaline Booster): what it and DiveDisableAdrenalineBooster read.
# CabinLight.gd takes the first parent with a `preheat` member as its ship.

var preheat = false
var playerControlled = false
var externalSystems = []

func isPlayerControlled():
	return playerControlled

func drawEnergy(amount):
	return amount
