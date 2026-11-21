extends Node

# CrewPerfectSort - sorts the crew lists at Enceladus Prime:
#   Hire screen:      by salary, then job.
#   Your Crew screen: by job, then salary (lowest first).
#
# The game's mod loader can extend a game script. The two extensions below sort
# each list right after the game has filled it.

func _init(modLoader = null):
	if modLoader != null:
		modLoader.installScriptExtension("res://CrewPerfectSort/HireableCrewSorted.gd")
		modLoader.installScriptExtension("res://CrewPerfectSort/CurrentCrewManagementSorted.gd")
