extends "res://harness/callout_object.gd"

# An object of the field with a transponder, for the callout suite: getTransponder as ships/ship-ctrl.gd's ("" for a
# pirate, which broadcasts none), and the name and captain the game's comms line reads of a ship a line is from (Tool.gd
# getTranslationDictionary).

var transponder = ""

func getTransponder():
	return transponder

func getShipName():
	return CurrentGame.getShipNameByTransponder(transponder)

func getCrewMember(agenda = ""):
	return Namer.makeDetail("crew", hash(transponder + agenda))
