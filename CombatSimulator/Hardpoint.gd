extends "res://ships/WeaponSlot.gd"

# CombatSimulator's extension of the hardpoints (ships/WeaponSlot.gd), for Disabled weapons: on an enemy the arena
# disarmed (Settings.gd DISARMED_META), whatever the AI or a turret fires through the hardpoint gets 0, the path the
# game takes for a switched-off hardpoint (fire). Its switch (`enabled`) stays on: switching it off would lower the
# ship's combat capacity (ships/ship-ctrl.gd getRealStatus counts switched-off systems), and with it the AI's will to
# fight.

const CombatSimulator = preload("res://CombatSimulator/Settings.gd")

func fire(p):
	if p != 0 and ship != null and is_instance_valid(ship) and ship.has_meta(CombatSimulator.DISARMED_META):
		return .fire(0)
	return .fire(p)
