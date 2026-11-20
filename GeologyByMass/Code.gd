extends "res://ships/ship-ctrl.gd"

# GeologyByMass: judges an identified chunk by the mass of each mineral in it instead of its value, for every row of
# the Geologist tab, when the switch on the mod's OMS tab is on.
#
# The Geologist tab has one row per system with mineral targeting, each kept in that system's own config: which
# minerals it goes for and its Minimum value (hud/SystemMineralList.gd). Every system asks the ship whether a chunk
# passes its row (ships/ship-ctrl.gd isValidMineralTarget(object, config)): the HUD for its info boxes (hud/Hud.gd
# isValidMineralTarget, which hud/MineralMark.gd asks about once a second; a "no" shrinks the box), the AR-1500 arm
# (ships/modules/DockingArm.gd isValidTarget), the tug and haul drone plants (weapons/drone-plant.gd scanForTarget), the
# NT Mining Companion for its cradle's row and a ship's AI catching a chunk with its haul drones (ship-ctrl.gd). The
# game's rule, for the player's ship: an identified chunk passes when its estimated value is at least the row's Minimum
# value and it holds a mineral switched on in the row; a chunk not yet identified, when its LIDAR return reaches the
# row's albedo (GAME.md, Geologist).
#
# With the switch on, for the player's ship, an identified chunk passes a row when it holds, of some mineral switched
# on in that row, at least the base mass plus that mineral's extra mass (Settings.gd getBaseMass, getExtraMass); its
# value and the row's Minimum value no longer count. One set of masses serves every row. The masses are the info box's
# own (MineralMark.gd scanParent, with the geologist's error), which the box stores in the ship's identifiedObjects
# (identifyMinerals / identifyValue -> ship-ctrl.gd addIdentifiedObject). A chunk not yet identified, the switch off,
# a row without mineral targeting or another ship: the game decides.
#
# Stacking: the parent's _ready etc. are never called (Godot runs every level by itself); isValidMineralTarget falls
# through to the parent with `.isValidMineralTarget()`; new members start with `_`.

const GeologyByMass = preload("res://GeologyByMass/Settings.gd")

var _geologyByMassSettings = null

func isValidMineralTarget(object: RigidBody2D, config: Dictionary) -> bool:
	if not playerControlled or not ("minerals" in config and "minValue" in config):
		return .isValidMineralTarget(object, config)
	var identified = identifiedObjects.get(hash(object))
	if identified == null or not identified[0] is Dictionary:
		return .isValidMineralTarget(object, config)
	var settings = _geologyByMass()
	if not settings.isEnabled():
		return .isValidMineralTarget(object, config)
	var masses = identified[0]
	var base = settings.getBaseMass()
	for mineral in config.minerals:
		if mineral in masses and masses[mineral] >= base + settings.getExtraMass(mineral):
			return true
	return false

func _geologyByMass():
	if _geologyByMassSettings == null:
		_geologyByMassSettings = GeologyByMass.new(self)
	return _geologyByMassSettings
