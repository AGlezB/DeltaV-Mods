extends Reference

# ServiceNotifier's settings model, shared by Code.gd and SettingsUI.gd: one instance (shared()) holds the current
# values, and the rule both use to tell which services the mod watches (kindOf). The values are kept per save game, in
# the game's UI store (CurrentGame.state.ui, which CurrentGame.saveToFile writes with the rest of the state), under the
# mod's id from Mod.manifest: each save has its own money and its own services bought.

signal settingsChanged()

# One description per setting. `label` is a translation key of i18n/en.po. A setting with `perService` holds one value
# for each service the mod watches, by the service's serviceName, all sharing its default. The services are the game's,
# read from the station's Services screen (Code.gd _snRows), not listed here: a service with no value stored gives the
# default.
const SETTINGS = {
	# Whether this service marks the station menu's Services entry while it can be bought. The label is the tooltip of
	# each service's switch.
	"alert": {
		"label": "SERVICENOTIFIER_SWITCH",
		"type": "bool",
		"default": true,
		"perService": true,
	},
}

# The kinds of service the mod watches (kindOf), in the order the settings screen groups them: each with its group's
# title and the description of its services, translation keys of i18n/en.po. `withCooldown`: the description has a %s
# for the service's cooldown, after the one for its name.
const KINDS = {
	# Services with a cooldown (enceladus/ServiceUI.gd cooldownHours), which can't be bought again until it is over.
	"cooldown": {
		"title": "SERVICENOTIFIER_GROUP_COOLDOWN",
		"description": "SERVICENOTIFIER_COOLDOWN_DESC",
		"withCooldown": true,
	},
	# Services that pay a faction compensation (enceladus/ServiceUIFactionChange.gd factionBased): their price follows
	# the faction's hostility and fear towards the player, which buying one sets to 0, so it costs nothing and can't be
	# bought until the faction is hostile or afraid again.
	"compensation": {
		"title": "SERVICENOTIFIER_GROUP_COMPENSATION",
		"description": "SERVICENOTIFIER_COMPENSATION_DESC",
		"withCooldown": false,
	},
}

# The layout of the saved entry. Renaming a saved key without a migration is a major version.
const FORMAT_VERSION = 1

var cfg = {}
var _manifest = null

# The one instance, kept as metadata of this script: Godot 3 has no static variables, and every script that preloads
# this file gets the same cached resource.
static func shared():
	var script = load("res://ServiceNotifier/Settings.gd")
	if not script.has_meta("shared"):
		script.set_meta("shared", script.new())
	return script.get_meta("shared")

# The kind of service a row of the Services screen (enceladus/ServiceUI.gd) offers, a key of KINDS, or "" for one the
# mod doesn't watch: a service that can be bought again right away (the hotels). A row with both a cooldown and a
# faction counts as a cooldown's.
static func kindOf(row) -> String:
	if "cooldownHours" in row and (row.cooldownHours is int or row.cooldownHours is float) and row.cooldownHours > 0:
		return "cooldown"
	if "factionBased" in row and str(row.factionBased) != "":
		return "compensation"
	return ""

func _init():
	for key in SETTINGS:
		cfg[key] = {} if isPerService(key) else SETTINGS[key].default

func isPerService(key) -> bool:
	return SETTINGS[key].get("perService", false)

# A per-service setting's value for `service` (its serviceName): the default for a service it holds no value for.
func getValue(key, service = null):
	if isPerService(key):
		return cfg[key].get(service, SETTINGS[key].default)
	return cfg[key]

# Stores and signals only a change; `service` is only for a per-service setting.
func setValue(key, value, service = null):
	value = _valid(key, value)
	if value == getValue(key, service):
		return
	if isPerService(key):
		cfg[key][service] = value
	else:
		cfg[key] = value
	saveToState()
	emit_signal("settingsChanged")

# The defaults, overlaid by what this save game holds. A save made before the mod, or a new game, has nothing. A
# per-service setting keeps every service saved with a valid value, so a service the screen doesn't show for a while
# keeps its own.
func loadFromState():
	var saved = CurrentGame.getUiValue(modId(), {})
	if not saved is Dictionary:
		saved = {}
	var changed = false
	for key in SETTINGS:
		var value = saved.get(key, SETTINGS[key].default)
		if isPerService(key):
			var values = {}
			if value is Dictionary:
				for service in value:
					if service is String and value[service] is bool:
						values[service] = value[service]
			if not _sameValues(values, cfg[key]):
				changed = true
			cfg[key] = values
		else:
			value = _valid(key, value)
			if value != cfg[key]:
				cfg[key] = value
				changed = true
	if changed:
		emit_signal("settingsChanged")

# Copies, so the save game's entry never shares what this instance changes.
func saveToState():
	var saved = {"formatVersion": FORMAT_VERSION, "modVersion": modVersion()}
	for key in SETTINGS:
		saved[key] = cfg[key].duplicate() if isPerService(key) else cfg[key]
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

# Every setting is a switch: anything that isn't a bool gives the default (a save edited by hand can't break the code).
func _valid(key, value):
	if value is bool:
		return value
	return SETTINGS[key].default

# Godot 3 compares dictionaries by reference.
func _sameValues(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k) or b[k] != a[k]:
			return false
	return true

func _manifestValue(section, key, default):
	if _manifest == null:
		_manifest = ConfigFile.new()
		_manifest.load(_folder().plus_file("Mod.manifest"))
	return _manifest.get_value(section, key, default)

# The mod's folder in the zip: res://<ModName>.
func _folder() -> String:
	return get_script().resource_path.get_base_dir()
