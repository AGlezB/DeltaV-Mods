extends Node2D

# A ship's system for the power suite that isn't a weapon the switch changes: Tuning entries (getTuneables, as the
# game's systems describe them) and the slot name its Tuning is kept under, and no `system` (which a hardpoint and a
# turret hold their weapon as).

var slotName = ""
var tuneables = {}

func getTuneables():
	return tuneables
