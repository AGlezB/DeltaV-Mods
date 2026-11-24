extends Node2D

# Stub of a turret's weapon (the node at its weaponPath: weapons/massdriver.gd, weapons/emp.gd) for the turret suite:
# what the game's PDT.gd reads of it, and the power it was last fired with (last), which PDT.gd passes on every physics
# frame it runs.

var systemName = "SYSTEM_TEST"
var command = "w"
var slotName = ""
var last = null

func fire(power):
	last = power
