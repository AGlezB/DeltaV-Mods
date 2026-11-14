extends Node

# Stub of the game's CurrentGame autoload: what DockingArm.gd, CabinLight.gd and Tool.gd reach.

var traceMinerals = []
var adrenalineSum = 0.0 # what CabinLight.gd has added through adrenaline()

func adrenaline(amount):
	adrenalineSum += amount

func getPlayerShip():
	return null

func getAgendaMember(_agenda):
	return null
