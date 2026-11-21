extends Reference

# CombatSimulator's settings model, shared by Code.gd, SettingsUI.gd and CombatLayer.gd: one instance (shared()) holds
# what the next run spawns and how. The settings are kept per save game, in the game's UI store (CurrentGame.state.ui,
# which CurrentGame.saveToFile writes with the rest of the state), under the mod's id from Mod.manifest. Below them,
# what the scripts of the mod share: the marks the arena leaves on its ships, and the ship models it offers.

signal settingsChanged()

# One description per setting, in the order the dialog lists them within their group (SettingsUI.gd GROUPS). Each
# default is declared here only. `label` is a translation key of i18n/en.po, and so is `label` followed by
# DESCRIPTION_SUFFIX: the description the dialog shows while the setting is selected. `type` "bool" is
# a switch: no range, unit or conversion; "float" a slider, with its `min`, `max` and `step` (as stored), `unit`,
# `shown` (the factor from the stored value to the one shown: a fraction shown as %) and `format` (for the value
# shown); "choice" one of the ship models (models()), stored as its key in Shipyard.ships.
const SETTINGS = {
	# The enemies' model (CombatLayer.gd builds them as the game builds that model when it attacks).
	"ship": {
		"label": "COMBATSIMULATOR_SHIP",
		"default": "TRTL",
		"type": "choice",
		"group": "enemies",
	},
	"number": {
		"label": "COMBATSIMULATOR_NUMBER",
		"default": 1,
		"type": "float",
		"min": 1,
		"max": 3,
		"step": 1,
		"unit": "",
		"shown": 1,
		"format": "%d",
		"group": "enemies",
	},
	# On: all the enemies on one bearing, CombatLayer.gd GROUP_SPACING apart; off: each on a bearing of its own.
	"grouped": {
		"label": "COMBATSIMULATOR_GROUPED",
		"default": true,
		"type": "bool",
		"group": "enemies",
	},
	# The closest an enemy spawns, in m; the farthest is CombatLayer.gd SPAWN_SPREAD more.
	"distance": {
		"label": "COMBATSIMULATOR_DISTANCE",
		"default": 1000,
		"type": "float",
		"min": 100,
		"max": 4000,
		"step": 100,
		"unit": "m",
		"shown": 1,
		"format": "%d",
		"group": "enemies",
	},
	# On: the enemies' weapons fire nothing (Hardpoint.gd, Turret.gd).
	"disabledWeapons": {
		"label": "COMBATSIMULATOR_DISABLED_WEAPONS",
		"default": false,
		"type": "bool",
		"group": "enemies",
	},
	# The red channel of the ring map wherever the field asks (CombatMap.gd).
	"chaos": {
		"label": "COMBATSIMULATOR_CHAOS",
		"default": 0.5,
		"type": "float",
		"min": 0.0,
		"max": 1.0,
		"step": 0.1,
		"unit": "",
		"shown": 1,
		"format": "%.1f",
		"group": "area",
	},
	# The blue channel of the ring map wherever the field asks (CombatMap.gd).
	"density": {
		"label": "COMBATSIMULATOR_DENSITY",
		"default": 0.5,
		"type": "float",
		"min": 0.0,
		"max": 1.0,
		"step": 0.1,
		"unit": "",
		"shown": 1,
		"format": "%.1f",
		"group": "area",
	},
	# The share of its tanks' capacity your ship starts with.
	"remass": {
		"label": "COMBATSIMULATOR_REMASS",
		"default": 0.75,
		"type": "float",
		"min": 0.2,
		"max": 1.0,
		"step": 0.05,
		"unit": "%",
		"shown": 100,
		"format": "%d",
		"group": "ship",
	},
}

# The layout of the saved entry. Renaming a saved key without a migration is a major version.
# 1: the settings above.
const FORMAT_VERSION = 1

# Metadata the arena sets on the player's ship it builds (the HUD and mass driver extensions act only on it), and on
# the enemies whose weapons it disabled (Hardpoint.gd, Turret.gd).
const SHIP_META = "CombatSimulatorShip"
const DISARMED_META = "CombatSimulatorDisarmed"
# World units in a metre: the game shows 10 world units as 1 m.
const UNITS_PER_METRE = 10.0
# Where the ship scenes are: a model in Shipyard.ships whose scene is elsewhere isn't a ship (the habitat, OBONTO,
# story/habitat/Habitat.tscn) and isn't offered.
const SHIP_SCENES = "res://ships/"
# The translation keys of i18n/en.po that name a model the game leaves unnamed (its scene keeps ship-ctrl.gd's
# default shipName, SHIP_TRTL, or names a key the game's texts lack, as the racing drone's SHIP_DRONE): this prefix,
# the model's key, and for its description DESCRIPTION_SUFFIX after that.
const MODEL_NAME_PREFIX = "COMBATSIMULATOR_MODEL_"
# Ends a translation key to make that of its description: a setting's label, as the game's Tuning screen makes them
# (Tuning.gd tuningChanged), a ship's name, as the Dealer does (Dealer.gd displayShip), and the names above. Shared by
# the dialog (SettingsUI.gd) and its ship list (ShipList.gd).
const DESCRIPTION_SUFFIX = "_DESC"
# The game's Tuning groups (enceladus/Tuning/TuningItems.tscn), which the dialog's settings and its ship list are built
# from.
const GAME_TUNING_ITEMS = "res://enceladus/Tuning/TuningItems.tscn"

var cfg = {}
var _models = null # the ship models offered, worked out once
var _names = {} # each model's shipName, read from its scene once
var _manifest = null

# The one instance, kept as metadata of this script: Godot 3 has no static variables, and every script that preloads
# this file gets the same cached resource.
static func shared():
	var script = load("res://CombatSimulator/Settings.gd")
	if not script.has_meta("shared"):
		script.set_meta("shared", script.new())
	return script.get_meta("shared")

func _init():
	for key in SETTINGS:
		cfg[key] = _valid(key, SETTINGS[key].default)

func getValue(key):
	return cfg[key]

func setValue(key, value):
	value = _valid(key, value)
	if typeof(value) == typeof(cfg[key]) and value == cfg[key]:
		return
	cfg[key] = value
	saveToState()
	emit_signal("settingsChanged")

func toShown(key, value):
	return value * SETTINGS[key].shown

func fromShown(key, shown):
	return shown / float(SETTINGS[key].shown)

# The defaults, overlaid by the save's entry. A value the entry lacks or holds wrong keeps its default.
func loadFromState():
	var saved = CurrentGame.getUiValue(modId(), {})
	if not saved is Dictionary:
		saved = {}
	var changed = false
	for key in SETTINGS:
		var value = _valid(key, saved.get(key, SETTINGS[key].default))
		if typeof(value) != typeof(cfg[key]) or value != cfg[key]:
			cfg[key] = value
			changed = true
	if changed:
		emit_signal("settingsChanged")

func saveToState():
	var saved = {"formatVersion": FORMAT_VERSION, "modVersion": modVersion()}
	for key in SETTINGS:
		saved[key] = cfg[key]
	CurrentGame.setUiValue(modId(), saved)

# The ship models offered, by their keys in Shipyard.ships: every ship the game has a scene for under SHIP_SCENES,
# each series together (Shipyard.gd getShipAlias folds a variant into its base model), the series and the models in
# each in the game's order.
func models() -> Array:
	if _models == null:
		var ships = Shipyard.get("ships")
		if not ships is Dictionary:
			return []
		var series = []
		var bySeries = {}
		for model in ships:
			var scene = ships[model]
			if not scene is PackedScene or not scene.resource_path.begins_with(SHIP_SCENES):
				continue
			var base = Shipyard.getShipAlias(model)
			if not bySeries.has(base):
				bySeries[base] = []
				series.append(base)
			bySeries[base].append(model)
		_models = []
		for base in series:
			_models += bySeries[base]
	return _models

# The model a model is a variant of (Shipyard.gd getShipAlias folds a variant into its base model), or itself.
func series(model) -> String:
	return str(Shipyard.getShipAlias(model))

# The translation key of a model's name: the mod's own where i18n/en.po has one, else its scene's shipName.
func modelName(model) -> String:
	var own = MODEL_NAME_PREFIX + model
	if tr(own) != own:
		return own
	return _shipName(model)

# The translation key of a model's description, as the Dealer shows it (<shipName>_DESC), or the mod's own.
func modelDescription(model) -> String:
	return modelName(model) + DESCRIPTION_SUFFIX

func modId() -> String:
	return str(_manifestValue("mod_information", "id", _folder().get_file()))

func modName() -> String:
	return str(_manifestValue("mod_information", "name", _folder().get_file()))

func modVersion() -> String:
	return "%d.%d.%d" % [
		_manifestValue("version", "version_major", 0),
		_manifestValue("version", "version_minor", 0),
		_manifestValue("version", "version_bugfix", 0)]

# A switch's value is a bool; a slider's a number, snapped to its step and kept in its range (the save's JSON gives
# floats back); a choice one of the models offered. Anything else gives the default (a save edited by hand can't break
# the code).
func _valid(key, value):
	var setting = SETTINGS[key]
	match setting.type:
		"float":
			if not (value is int or value is float):
				return setting.default
			return clamp(stepify(float(value), setting.step), setting.min, setting.max)
		"bool":
			return value if value is bool else setting.default
		_:
			return value if value is String and value in models() else setting.default

# The scene's own shipName (its root's, then that of the scene it inherits from). A scene that leaves it to the ship's
# script has none there: then one ship is instanced, never added to the tree, read and freed (as DealerNotifier's
# Settings.gd _shipNames does).
func _shipName(model) -> String:
	if not _names.has(model):
		var name = ""
		var ships = Shipyard.get("ships")
		var scene = ships.get(model) if ships is Dictionary else null
		if scene is PackedScene:
			var value = _sceneValue(scene, "shipName")
			if value == null:
				var ship = scene.instance()
				if "shipName" in ship:
					value = ship.shipName
				ship.free()
			name = str(value) if value else model
		_names[model] = name
	return _names[model]

# The value a scene gives its root's `property`, or the value the scene it inherits from gives it, or null.
func _sceneValue(scene: PackedScene, property: String):
	while scene != null:
		var state = scene.get_state()
		if state.get_node_count() == 0:
			return null
		for i in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == property:
				return state.get_node_property_value(0, i)
		scene = state.get_node_instance(0)
	return null

func _manifestValue(section, key, default):
	if _manifest == null:
		_manifest = ConfigFile.new()
		_manifest.load(_folder().plus_file("Mod.manifest"))
	return _manifest.get_value(section, key, default)

# The mod's folder in the zip: res://<ModName>.
func _folder() -> String:
	return get_script().resource_path.get_base_dir()
