extends "res://enceladus/Enceladus.gd"

# The station (enceladus/Enceladus.gd). Launching a dive (_on_DiveTarget_launch) plays the launch sequence:
# ExitPlayer's "LaunchSequence", then, once the ship has power (shipPowerToggle), Autopilot's "GoToRing", which ends
# in goToRing(). The game's own _physics_process cuts it short on cutscene_ff or pause (Space, Esc): it stops both
# players and calls goToRing(). While its setting is on, the mod does the same as soon as the sequence starts. The
# ship flown here is the station's, thrown away with the scene, so the cut costs the dive nothing; as with Esc, the
# station seconds the sequence would take don't pass.

# The settings (which skips are on), shared with the settings screen.
const DiveSkipTransit = preload("res://DiveSkipTransit/Settings.gd")

func _on_DiveTarget_launch():
	._on_DiveTarget_launch()
	if DiveSkipTransit.shared().getValue("skipLaunch") and nodeExitPlayer.is_playing():
		nodeExitPlayer.stop()
		nodeAutopilot.stop()
		goToRing()
