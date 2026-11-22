extends Node

# CrewPerfectSort - sorts the crew lists:
#   Hire screen:      by salary, then job.
#   Your Crew screen: by job, then salary (lowest first).
#   The derelict conversation's choice of who goes on EVA: as Your Crew.
#
# The game's mod loader can extend a game script. The three extensions below sort each list where the game makes it:
# the two screens right after the game has filled them, the EVA choice where the game picks a crew member by number.

func _init(modLoader = null):
	if modLoader != null:
		modLoader.installScriptExtension("res://CrewPerfectSort/HireableCrewSorted.gd")
		modLoader.installScriptExtension("res://CrewPerfectSort/CurrentCrewManagementSorted.gd")
		modLoader.installScriptExtension("res://CrewPerfectSort/EvaCrewSorted.gd")
