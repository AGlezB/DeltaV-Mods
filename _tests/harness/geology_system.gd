extends Node

# Stub of a ship's system with mineral targeting for the geology suite, as hud/SystemMineralList.gd reads it to build
# its row: an AR-1500 arm (ships/modules/DockingArm.gd, without onlyMinerals) or, with onlyMinerals, a cargo
# container's dock (ships/modules/StorageContainerDock.tscn). Its row as DockingArm.gd keeps it (mineralConfig), with
# the same setters and getters.

var mineralTargetting = true
var onlyMinerals = false
var mineralConfig = {"minerals": [], "minValue": 0.0, "albedo": 0.0}

func setMineralConfig(mineral: String, how: bool):
	if how:
		if not mineralConfig.minerals.has(mineral):
			mineralConfig.minerals.append(mineral)
	else:
		mineralConfig.minerals.erase(mineral)

func hasMineralEnabled(mineral) -> bool:
	return mineralConfig.minerals.has(mineral)

func setMinValue(value: float):
	mineralConfig.minValue = value

func getMinValue() -> float:
	return mineralConfig.get("minValue", 0.0)

func setAlbedo(value: float):
	mineralConfig.albedo = value

func getAlbedo() -> float:
	return mineralConfig.get("albedo", 0.0)
