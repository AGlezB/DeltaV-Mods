extends Node

func _init(modLoader = null):
	if modLoader != null:
		modLoader.installScriptExtension("res://DiveSkipTransit/Code.gd")
		modLoader.installScriptExtension("res://DiveSkipTransit/Station.gd")
