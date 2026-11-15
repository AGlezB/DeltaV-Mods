extends Node

# Counts the Esc / back presses no node handled, as the game's pause menu receives them (PauseLayer.gd
# _unhandled_input, which opens on `pause`).

var count = 0

func _unhandled_input(event):
	if event.is_pressed() and (event.is_action("ui_cancel") or event.is_action("pause")):
		count += 1
