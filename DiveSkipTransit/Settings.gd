extends Reference

# DiveSkipTransit's settings model, shared by StationMenu.gd, SettingsUI.gd, Station.gd and Code.gd: one instance
# (shared()) holds whether each skip is on. They are game-wide, a player's choice for every save, kept in a ConfigFile
# in user:// as the game keeps its own settings (Settings.gd loadFromFile / saveToFile), and written at every change.

signal settingsChanged()

# One description per setting, in the order the settings screen lists them. Each default is declared here only.
# `label` is a translation key of i18n/en.po. `type` "bool" is a switch: no range, unit or conversion.
const SETTINGS = {
	# The station's launch sequence (Station.gd).
	"skipLaunch": {
		"label": "DIVESKIPTRANSIT_SKIP_LAUNCH",
		"default": true,
		"type": "bool",
	},
	# The arrival cutscene in the ring (Code.gd).
	"skipArrival": {
		"label": "DIVESKIPTRANSIT_SKIP_ARRIVAL",
		"default": true,
		"type": "bool",
	},
	# The exit cutscene, diving back or at overspeed: the departure and the trip to the station (Code.gd).
	"skipExit": {
		"label": "DIVESKIPTRANSIT_SKIP_EXIT",
		"default": true,
		"type": "bool",
	},
}

# The layout of the saved section. Renaming a saved key without a migration is a major version.
const FORMAT_VERSION = 1

var cfg = {}
var filePath = "" # the settings file: user://<the mod's id>.cfg unless set otherwise
var _manifest = null

# The one instance, kept as metadata of this script: Godot 3 has no static variables, and every script that preloads
# this file gets the same cached resource. It starts from the settings file.
static func shared():
	var script = load("res://DiveSkipTransit/Settings.gd")
	if not script.has_meta("shared"):
		var settings = script.new()
		settings.loadFromFile()
		script.set_meta("shared", settings)
	return script.get_meta("shared")

func _init():
	for key in SETTINGS:
		cfg[key] = SETTINGS[key].default
	filePath = "user://%s.cfg" % modId()

func getValue(key):
	return cfg[key]

func setValue(key, value):
	value = _valid(key, value)
	if value == cfg[key]:
		return
	cfg[key] = value
	saveToFile()
	emit_signal("settingsChanged")

# The defaults, overlaid by the settings file, in a section named by the mod's id. Without the file (the mod's first
# run, or no setting changed yet), or without a value in it, a setting keeps its default.
func loadFromFile():
	var file = ConfigFile.new()
	var loaded = file.load(filePath) == OK
	var changed = false
	for key in SETTINGS:
		var value = SETTINGS[key].default
		if loaded:
			value = _valid(key, file.get_value(modId(), key, value))
		if value != cfg[key]:
			cfg[key] = value
			changed = true
	if changed:
		emit_signal("settingsChanged")

func saveToFile():
	var file = ConfigFile.new()
	var section = modId()
	file.set_value(section, "formatVersion", FORMAT_VERSION)
	file.set_value(section, "modVersion", modVersion())
	for key in SETTINGS:
		file.set_value(section, key, cfg[key])
	file.save(filePath)

func modId() -> String:
	return str(_manifestValue("mod_information", "id", _folder().get_file()))

func modName() -> String:
	return str(_manifestValue("mod_information", "name", _folder().get_file()))

func modVersion() -> String:
	return "%d.%d.%d" % [
		_manifestValue("version", "version_major", 0),
		_manifestValue("version", "version_minor", 0),
		_manifestValue("version", "version_bugfix", 0)]

# A switch's value is a bool: anything else gives the default (a settings file edited by hand can't break the code).
func _valid(key, value):
	if value is bool:
		return value
	return SETTINGS[key].default

func _manifestValue(section, key, default):
	if _manifest == null:
		_manifest = ConfigFile.new()
		_manifest.load(_folder().plus_file("Mod.manifest"))
	return _manifest.get_value(section, key, default)

# The mod's folder in the zip: res://<ModName>.
func _folder() -> String:
	return get_script().resource_path.get_base_dir()
