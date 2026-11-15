extends Node

# Installed here, in _init, not in _ready: ModLoader.gd runs this while the engine creates its autoload, before the
# engine loads the main scene (Boot.tscn), so the boot scene gets the extended script.
func _init(modLoader = null):
	if modLoader != null:
		modLoader.installScriptExtension("res://BootSkipLogos/Code.gd")
