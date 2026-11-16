extends Node2D

# Stub of a thruster (sfx/thruster.gd) for the skip suite: what DiveSkipTransit and ship-ctrl.gd getBestThrusterVe read
# of one. The game's getThrust gives `thrust / 10` while untuned, getChoke a factor from the thruster's damage, and
# getFuelLeft null unless the thruster burns a fuel of its own; specificImpulse is the exhaust velocity in km/s.

var thrust = 0.0
var specificImpulse = 0.0
var choke = 1.0
var enabled = true

func getThrust(_force = false):
	return thrust / 10

func getChoke():
	return choke

func getFuelLeft():
	return null
