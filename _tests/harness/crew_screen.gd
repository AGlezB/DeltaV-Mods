extends Control

# Stub of the station's Crew screen (enceladus/Crew.gd): counts how often the menu's Crew entry opens it, through the
# method enceladus/Enceladus.tscn connects the entry's `pressed` to.

var opened = 0

func _on_Crew_pressed():
	opened += 1
