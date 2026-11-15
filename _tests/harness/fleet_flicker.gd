extends Node

# Stub of the game's flicker effect (enceladus/Flicker.tscn) for the fleet suite's entries and items. It never
# finishes, so a Fleet entry keeps its live ship view (SystemBuyUI.gd stopUpdating would read the viewport's texture,
# which a headless run has none of).

signal animation_finished(name)

var supress = false
var flickers = 0

func flicker():
	flickers += 1
