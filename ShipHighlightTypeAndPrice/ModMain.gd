extends Node

func _init(_modLoader = null):
	add_child(preload("res://ShipHighlightTypeAndPrice/Code.gd").new())
