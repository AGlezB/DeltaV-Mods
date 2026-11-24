extends Node

# The texts are a .po file loaded with load(), as the game loads its own (project.godot, locale/translations). The
# mod loader's addTranslationsFromCSV reads nothing from a mod's zip: a file in a zip reports its end before the first
# read, and get_csv_line checks for the end first. The facing lock's key is an input action of the mod's own
# (Shared.gd).
func _init(modLoader = null):
	if modLoader != null:
		modLoader.installScriptExtension("res://TurretLockableFacing/Code.gd")
		modLoader.installScriptExtension("res://TurretLockableFacing/MechanicTab.gd")
		TranslationServer.add_translation(load("res://TurretLockableFacing/i18n/en.po"))
		load("res://TurretLockableFacing/Shared.gd").addKey()
