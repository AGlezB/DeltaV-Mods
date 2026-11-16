extends "res://enceladus/Enceladus.gd"

# The station (enceladus/Enceladus.gd): its fade-in on arrival and its launch sequence, each skipped while its setting
# is on. Neither costs anything: the station's clock runs either way (_physics_process), and the ship the launch flies
# is the station's, thrown away with the scene.

# The settings (which skips are on), shared with the settings screen, and the code the skips share.
const DiveSkipTransit = preload("res://DiveSkipTransit/Settings.gd")

# The base's _ready has run first (Godot runs every level's _ready, base first). Arriving at the station, its
# AnimationPlayer autoplays "FadeInCRT": the screen fades in, and the menu stays disabled until the animation calls
# Options.disable(false). The mod plays it through at once, so the menu is usable from the first frame.
func _ready():
	var player = get_node_or_null("AnimationPlayer")
	if player != null and player.current_animation == "FadeInCRT" \
			and DiveSkipTransit.shared().getValue("skipStationFadeIn"):
		DiveSkipTransit.playThrough(player, "FadeInCRT")

# Launching a dive plays the launch sequence: ExitPlayer's "LaunchSequence", then, once the ship has power
# (shipPowerToggle), Autopilot's "GoToRing", which ends in goToRing(). The game's own _physics_process cuts it short on
# cutscene_ff or pause (Space, Esc): it stops both players and calls goToRing(). The mod does the same as soon as the
# sequence starts; as with Esc, the station seconds the sequence would take don't pass.
func _on_DiveTarget_launch():
	._on_DiveTarget_launch()
	if DiveSkipTransit.shared().getValue("skipLaunch") and nodeExitPlayer.is_playing():
		nodeExitPlayer.stop()
		nodeAutopilot.stop()
		goToRing()
