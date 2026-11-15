extends Reference

# CrewCheapHireNotifier's settings model, shared by Code.gd and SettingsUI.gd: one instance (shared()) holds the
# current values. They are kept per save game, in the game's UI store (CurrentGame.state.ui, which
# CurrentGame.saveToFile writes with the rest of the state), under the mod's id from Mod.manifest.

signal settingsChanged()

# One description per setting, in the order the settings screen lists them. Values are in the units the code uses;
# the screen shows them multiplied by `shown`. Each default is declared here only.
const SETTINGS = {
	"salaryThreshold": {
		"label": "Salary threshold",
		"default": 1000,
		"min": 0,
		"max": 10000,
		"step": 500,
		"unit": "E$",
		"shown": 1,
	},
	"salaryTolerance": {
		"label": "Salary tolerance",
		"default": 0.10,
		"min": 0.0,
		"max": 1.0,
		"step": 0.05,
		"unit": "%",
		"shown": 100,
	},
}

# The layout of the saved entry. Renaming a saved key without a migration is a major version.
const FORMAT_VERSION = 1

var cfg = {}
var _manifest = null

# The one instance, kept as metadata of this script: Godot 3 has no static variables, and every script that preloads
# this file gets the same cached resource.
static func shared():
	var script = load("res://CrewCheapHireNotifier/Settings.gd")
	if not script.has_meta("shared"):
		script.set_meta("shared", script.new())
	return script.get_meta("shared")

func _init():
	for key in SETTINGS:
		cfg[key] = SETTINGS[key].default

func getValue(key):
	return cfg[key]

func setValue(key, value):
	value = _clamped(key, value)
	if value == cfg[key]:
		return
	cfg[key] = value
	saveToState()
	emit_signal("settingsChanged")

func toShown(key, value):
	return value * SETTINGS[key].shown

func fromShown(key, shown):
	return shown / float(SETTINGS[key].shown)

# The defaults, overlaid by what this save game holds. A save made before the mod, or a new game, has nothing.
func loadFromState():
	var saved = CurrentGame.getUiValue(modId(), {})
	if not saved is Dictionary:
		saved = {}
	var changed = false
	for key in SETTINGS:
		var value = _clamped(key, saved.get(key, SETTINGS[key].default))
		if value != cfg[key]:
			cfg[key] = value
			changed = true
	if changed:
		emit_signal("settingsChanged")

func saveToState():
	var saved = {"formatVersion": FORMAT_VERSION, "modVersion": modVersion()}
	for key in SETTINGS:
		saved[key] = cfg[key]
	CurrentGame.setUiValue(modId(), saved)

func modId() -> String:
	return str(_manifestValue("mod_information", "id", _folder().get_file()))

func modName() -> String:
	return str(_manifestValue("mod_information", "name", _folder().get_file()))

func modVersion() -> String:
	return "%d.%d.%d" % [
		_manifestValue("version", "version_major", 0),
		_manifestValue("version", "version_minor", 0),
		_manifestValue("version", "version_bugfix", 0)]

# A saved or given value inside the setting's range; anything that is not a number gives the default (a save edited
# by hand can't break the code).
func _clamped(key, value):
	var setting = SETTINGS[key]
	if not (value is int or value is float):
		return setting.default
	return clamp(value, setting.min, setting.max)

func _manifestValue(section, key, default):
	if _manifest == null:
		_manifest = ConfigFile.new()
		_manifest.load(_folder().plus_file("Mod.manifest"))
	return _manifest.get_value(section, key, default)

# The mod's folder in the zip: res://<ModName>.
func _folder() -> String:
	return get_script().resource_path.get_base_dir()
