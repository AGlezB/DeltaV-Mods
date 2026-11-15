extends Node

# Stub of the game's Settings autoload: what Arm.gd (cfg.display.lights, settingsChanged), Tool.gd (getFps),
# Boot.gd (firstBoot) and AnalogControlSlider.gd (getControlDeviceNr, while a slider has the focus) read.

signal settingsChanged

var cfg = {"display": {"lights": 1.0}}
var firstBoot = false # the game's is true only until user://settings.cfg exists (loadFromFile)

# The game sets this when it applies its fps setting (Settings.gd, 16 at 60 fps). Not every engine build has it.
func _ready():
	if Physics2DServer.has_method("set_collision_iterations"):
		Physics2DServer.call("set_collision_iterations", ceil((60.0 / float(getFps())) * 16))

func getFps() -> int:
	return Engine.iterations_per_second

func getControlDeviceNr():
	return 0
