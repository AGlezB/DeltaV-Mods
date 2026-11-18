extends Node

# Installed here, in _init, not in _ready: ModLoader.gd runs this while the engine creates its autoloads, and the
# engine creates CurrentGame (after ModLoader in the game's project.godot) from res://CurrentGame.gd after that, so the
# autoload gets the extension. None of the game scripts extended here preloads a scene, so installing them loads no
# script that a mod after this one extends (ships/Shipyard.gd, which preloads every ship scene, is left alone for that
# reason). The texts are a .po file loaded with load(), as the game loads its own: the mod loader's
# addTranslationsFromCSV reads nothing from a mod's zip.
func _init(modLoader = null):
	if modLoader != null:
		modLoader.installScriptExtension("res://CombatSimulator/CurrentGame.gd")
		modLoader.installScriptExtension("res://CombatSimulator/Code.gd")
		modLoader.installScriptExtension("res://CombatSimulator/PauseMenu.gd")
		modLoader.installScriptExtension("res://CombatSimulator/Hardpoint.gd")
		modLoader.installScriptExtension("res://CombatSimulator/Turret.gd")
		modLoader.installScriptExtension("res://CombatSimulator/HudRingMap.gd")
		modLoader.installScriptExtension("res://CombatSimulator/HudGravimetric.gd")
		modLoader.installScriptExtension("res://CombatSimulator/MassDriver.gd")
		TranslationServer.add_translation(load("res://CombatSimulator/i18n/en.po"))
