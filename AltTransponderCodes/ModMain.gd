extends Node

# Installed here, in _init, not in _ready: ModLoader.gd runs this while the engine creates its autoloads, and the
# engine creates CurrentGame (after ModLoader in the game's project.godot) from res://CurrentGame.gd after that, so the
# autoload gets the extension. Code.gd first: NewGamePlusScreen.gd reaches its member through CurrentGame.
func _init(modLoader = null):
	if modLoader != null:
		modLoader.installScriptExtension("res://AltTransponderCodes/Code.gd")
		modLoader.installScriptExtension("res://AltTransponderCodes/NewGamePlusScreen.gd")
