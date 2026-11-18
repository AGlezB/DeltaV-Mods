extends "res://weapons/massdriver.gd"

# CombatSimulator's extension of the mass drivers (weapons/massdriver.gd). The game plays the reload sound when a shot
# leaves (_physics_process sets `fired`), only for the player's ship in the rings (isRealShip, next to the dive log).
# On the arena's ship (Settings.gd SHIP_META, "sim" zone) it plays here, without the log.
# NOTIFICATION_PHYSICS_PROCESS reaches _notification after every level of _physics_process has run.

const CombatSimulator = preload("res://CombatSimulator/Settings.gd")

var _csFired = false # `fired` at the last physics frame

func _notification(what):
	if what != NOTIFICATION_PHYSICS_PROCESS:
		return
	if fired and not _csFired and ship != null and is_instance_valid(ship) \
			and ship.has_meta(CombatSimulator.SHIP_META) and ship.isPlayerControlled():
		audioReloadNode.play()
	_csFired = fired
