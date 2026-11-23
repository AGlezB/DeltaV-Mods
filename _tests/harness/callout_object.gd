extends RigidBody2D

# An object of the field for the callout suite, with what LidarContactCallout reads of one, and no transponder (no
# getTransponder): a reward of its own (specialPrice and specialName, as an oddity has them: CurrentGame.isOddity),
# whether it is in a hold (inCargoHold, as a chunk has it) and whether it is dead (dead, as a ship has it). Static, so
# its place stays where the suite puts it.

var specialPrice = 0
var specialName = ""
var inCargoHold = false
var dead = false

func _init():
	mode = MODE_STATIC
