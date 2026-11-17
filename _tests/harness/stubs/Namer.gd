extends Node

# Stub of the game's Namer autoload (namer/Namer.gd): Tool.gd's crew-name helpers, story/body.gd (a body's name) and
# CurrentGame.gd's generateShipNameFromTransponder reach it. The game's draws names from lists by the seed; this one
# gives fixed ones, as the game's: makeDetail a first name, a last name and a gender, make a ship name.

func makeDetail(_kind, _seed = 0):
	return ["Ann", "Bell", "female"]

func make(kind, nameSeed = 0):
	return "%s %d" % [kind, nameSeed]
