extends "res://hud/GravimetricReadout.gd"

# CombatSimulator's extension of the HUD's gravimetric readout (hud/GravimetricReadout.gd), which the game hides
# outside the rings: its _physics_process (running only while the scanner is fitted) sets `visible` from the ship's
# zone, and the arena's ship stays in the "sim" zone (CombatLayer.gd). On that ship (Settings.gd SHIP_META) it shows,
# as in a dive. NOTIFICATION_PHYSICS_PROCESS reaches _notification after every level of _physics_process has run.

const CombatSimulator = preload("res://CombatSimulator/Settings.gd")

func _notification(what):
	if what == NOTIFICATION_PHYSICS_PROCESS and ship != null and is_instance_valid(ship) \
			and ship.has_meta(CombatSimulator.SHIP_META):
		visible = true
