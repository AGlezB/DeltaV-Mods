extends Node

# Stub of the game's Settings autoload: what Arm.gd (cfg.display.lights, settingsChanged), Tool.gd (getFps),
# Boot.gd (firstBoot), AnalogControlSlider.gd (getControlDeviceNr, while a slider has the focus), Hud.gd instance()
# (cfg.gameplay.tutorial) and DiveSkipTransit (focused, cfg.gameplay.streaming: the game's mute rule) read, and the
# game scripts the bench runs (_bench\): DroneLaunchManager.gd and asteroid.gd (cfg.display.particlesExplosion, the
# particle signals), the dust cloud (particlesForbidden); and the control scheme the mods' Shift badges follow
# (Badge.gd: controlScheme, control, controlSchemeChaged), set by the suites as menu/Mouse.gd sets the game's.

signal settingsChanged
signal particlesSettingsChanged
signal removeGpuParticles
signal controlSchemeChaged

# The game's (Settings.gd), whose getter gives this with Auto, the Controls setting's default.
enum control {
	gamepad,
	keyMouse,
	auto
}
var controlScheme = control.keyMouse setget _setControlScheme

func _setControlScheme(v):
	if controlScheme != v:
		controlScheme = v
		emit_signal("controlSchemeChaged")

var cfg = {"display": {"lights": 1.0, "particlesExplosion": 1.0}, "gameplay": {"tutorial": false, "streaming": false}}
var firstBoot = false # the game's is true only until user://settings.cfg exists (loadFromFile)
var focused = true # the game's follows the window's focus (_notification), and mutes the master bus without it
var particlesForbidden = false

# The game sets this when it applies its fps setting (Settings.gd, 16 at 60 fps). Not every engine build has it.
func _ready():
	if Physics2DServer.has_method("set_collision_iterations"):
		Physics2DServer.call("set_collision_iterations", ceil((60.0 / float(getFps())) * 16))

func getFps() -> int:
	return Engine.iterations_per_second

func getControlDeviceNr():
	return 0
