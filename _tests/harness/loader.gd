extends Node

# The harness's ModLoader autoload. Loads mods the way the game's ModLoader.gd does, at the same moment: in _init,
# while the engine creates the autoloads and before it loads the main scene. It mounts each zip with
# load_resource_pack, runs every modmain*.gd entry with new(self), and offers installScriptExtension and
# addTranslationsFromCSV exactly as the game does. The zips come from --mod-zips=<zip>;<zip>, in the order given (the
# game sorts by MOD_PRIORITY, then path; the suites can test any order).

var loaded = [] # the mods' folder names, in load order
var ok = true # false when a mod could not be loaded; main.gd then quits with 100

func _init():
	var zips = []
	for a in OS.get_cmdline_args():
		if a.begins_with("--mod-zips="):
			zips = Array(a.substr(len("--mod-zips=")).split(";", false))
	ok = loadMods(zips)

func loadMods(zips: Array) -> bool:
	var mains = []
	for zip in zips:
		if not ProjectSettings.load_resource_pack(zip, true):
			printerr("HARNESS ERROR: cannot mount %s" % zip)
			return false
		var unzip = load("res://vendor/gdunzip.gd").new()
		unzip.load(zip)
		for entry in unzip.files:
			var file = entry.get_file().to_lower()
			if file.begins_with("modmain") and file.ends_with(".gd"):
				mains.append("res://" + entry)
				loaded.append(entry.split("/")[0])
	for path in mains:
		var script = ResourceLoader.load(path)
		if script == null:
			printerr("HARNESS ERROR: cannot load %s" % path)
			return false
		add_child(script.new(self))
	return true

func installScriptExtension(childScriptPath: String):
	var childScript = ResourceLoader.load(childScriptPath)
	childScript.new()
	var parentScript = childScript.get_base_script()
	var parentScriptPath = parentScript.resource_path
	print("Installing script extension: %s <- %s" % [parentScriptPath, childScriptPath])
	childScript.take_over_path(parentScriptPath)

# As the game's: the header row names the locales after the key column, one Translation per locale, one message per
# row, up to the first empty line.
func addTranslationsFromCSV(csvPath: String):
	var file = File.new()
	file.open(csvPath, File.READ)
	var translations = []
	var line = file.get_csv_line()
	for i in range(1, line.size()):
		var translation = Translation.new()
		translation.locale = line[i]
		translations.append(translation)
	while not file.eof_reached():
		line = file.get_csv_line()
		if line.size() == 1 and line[0] == "":
			break
		for i in range(1, line.size()):
			translations[i - 1].add_message(line[0], line[i])
	file.close()
	for translation in translations:
		TranslationServer.add_translation(translation)
