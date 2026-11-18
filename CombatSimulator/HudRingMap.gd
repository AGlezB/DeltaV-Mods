extends "res://hud/Video.gd"

# CombatSimulator's extension of the HUD's ring map (hud/Video.gd), which the game hides outside the rings: its
# _process sets `visible` from the ship's zone, and the arena's ship stays in the "sim" zone (CombatLayer.gd). On that
# ship (Settings.gd SHIP_META) it shows, as in a dive. NOTIFICATION_PROCESS reaches _notification after every level of
# _process has run, so this has the last word.

const CombatSimulator = preload("res://CombatSimulator/Settings.gd")

func _notification(what):
	if what == NOTIFICATION_PROCESS and ship != null and is_instance_valid(ship) \
			and ship.has_meta(CombatSimulator.SHIP_META):
		visible = true
