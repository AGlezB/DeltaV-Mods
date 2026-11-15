extends Node

func _init(_modLoader = null):
	add_child(preload("res://CrewHighlightJobAndSalary/Code.gd").new())
