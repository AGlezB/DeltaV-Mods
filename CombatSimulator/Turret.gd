extends "res://ships/modules/PDT.gd"

# CombatSimulator's extension of the turrets (ships/modules/PDT.gd), for Disabled weapons: on an enemy the arena
# disarmed (Settings.gd DISARMED_META), the turret still finds targets and aims, but fires nothing. A turret fires its
# weapon itself, through perhapsFire (with 1 when it fires on its own), and with the power it was last given (fire);
# both get 0. Its switch (`enabled`) stays on, as Hardpoint.gd explains.

const CombatSimulator = preload("res://CombatSimulator/Settings.gd")

func fire(f):
	return .fire(0 if _csDisarmed() else f)

func perhapsFire(f):
	return .perhapsFire(0 if _csDisarmed() else f)

func _csDisarmed() -> bool:
	return ship != null and is_instance_valid(ship) and ship.has_meta(CombatSimulator.DISARMED_META)
