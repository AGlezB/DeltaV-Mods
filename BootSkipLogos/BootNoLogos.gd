extends "res://Boot.gd"

# Boot.gd is the script of the game's first scene (Boot.tscn): a 22 s animation of the logos that calls go() at its
# end, and go() switches to the title screen, where the save slots are. The game already calls go() early when a key
# or mouse button is pressed (_unhandled_input), except on the first launch (Settings.firstBoot, true until the
# settings file exists), so that the photosensitivity warning is seen once. The mod calls go() as soon as the scene
# is ready, under the same condition. If the title screen is not loaded yet, go() waits for it (Loader.gd, goNow),
# as it does for a key press. In screensaver mode Boot.gd calls go() itself.
func _ready():
	if mode == "game" and not Settings.firstBoot:
		go()
