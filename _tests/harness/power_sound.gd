extends "res://sfx/PitchAdjustedAudio.gd"

# The ship's alarm player for the power suite (ships/ship-ctrl.gd playerAlert, the game's sfx/PitchAdjustedAudio.gd),
# and the Mechanic tab's click, without sound: each play is counted and sets the pitch as the game's play does (apply,
# which slows it with bullet time), but nothing plays, so `finished` comes only from the suite. A copy (duplicate) keeps
# this script, and counts its own plays.

var plays = 0

func play(_pos = 0.0):
	plays += 1
	apply()
