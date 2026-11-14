extends Node

# Loads mods the way the game's ModLoader.gd does, but from the zips given on the command line, in the order
# given (the game sorts by MOD_PRIORITY, then path; the suites can test any order): mounts each zip with
# load_resource_pack, runs every modmain*.gd entry with new(self), and offers installScriptExtension exactly as
# the game does.

var loaded = [] # the mods' folder names, in load order

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
