extends Node

# Stand-in of what the OMS Mechanic tab's list (hud/SystemList.gd) reads its ship through, for the power suite: the
# first of its parents with getSensorReadout (the HUD, in the game), whose `ship` its update reads. The list's _ready
# takes this node's parent as its ship; the suite then points the list and this node at the ship under test.

var ship

func getSensorReadout(_sensor):
	return null
