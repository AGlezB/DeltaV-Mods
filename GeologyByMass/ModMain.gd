extends Node

# The texts are a .po file loaded with load(), as the game loads its own (project.godot, locale/translations). The
# mod loader's addTranslationsFromCSV reads nothing from a mod's zip: a file in a zip reports its end before the first
# read, and get_csv_line checks for the end first.
func _init(modLoader = null):
	if modLoader != null:
		modLoader.installScriptExtension("res://GeologyByMass/Code.gd")
		modLoader.installScriptExtension("res://GeologyByMass/OmsScreen.gd")
		modLoader.installScriptExtension("res://GeologyByMass/GeologistTab.gd")
		TranslationServer.add_translation(load("res://GeologyByMass/i18n/en.po"))
