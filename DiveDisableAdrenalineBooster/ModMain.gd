extends Node

func _init(modLoader = null):
	if modLoader != null:
		modLoader.installScriptExtension("res://DiveDisableAdrenalineBooster/CabinLightDisabled.gd")
