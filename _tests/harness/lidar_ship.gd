extends Node2D

# Stub of the game's ship for hud/LIDAR.gd: what its _ready reaches (connectToShip, onSetup, getBleepSound). The
# tuning works as in ships/ship-ctrl.gd: getTunedValue / setTunedValue, which emits tuningChanged. Also for
# hud/HardwareLabel.gd (the hud suite): getConfigWithDefaults.

signal setup
signal tuningChanged
signal shipPowerToggle(how)

var lidar = null
var tuning = {}

func getLidarType():
	return "SYSTEM_LIDAR_DOPPLER"

# As ships/ship-ctrl.gd, where getLidarType() is the same getConfig("lidar.type", defaultLidar).
func getConfigWithDefaults(key):
	match key:
		"lidar.type":
			return getLidarType()
		_:
			return null

func isPlayerControlled():
	return true

func getTunedValue(system, tune, default):
	return tuning.get("%s.%s" % [system, tune], default)

func setTunedValue(system, tune, value = null):
	tuning["%s.%s" % [system, tune]] = value
	emit_signal("tuningChanged")
