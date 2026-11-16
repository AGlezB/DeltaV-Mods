extends Node2D

# Stub of a thruster (sfx/thruster.gd) for the skip suite: what DiveSkipTransit reads of one. The game's getThrust
# gives `thrust / 10` while untuned, and getChoke a factor from the thruster's damage; specificImpulse is the exhaust
# velocity in km/s.

var thrust = 0.0
var specificImpulse = 0.0
var choke = 1.0

func getThrust(_force = false):
	return thrust / 10

func getChoke():
	return choke
