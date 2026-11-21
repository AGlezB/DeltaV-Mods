extends Reference

# DroneAltPriorities's settings for one ship, shared by Code.gd (each of the ship's tug and haul plants), OmsScreen.gd
# and SettingsUI.gd: the switch at the top of the mod's OMS tab and the weight of each criterion. They live where the
# game keeps the HUD's Geologist tab settings, the ship's config "hud.config" (hud/Hud.gd _ready: its mineralConfig),
# under the mod's id from Mod.manifest, and are changed in place, as Hud.gd setMinValue changes the Minimum value. So
# they are saved, loaded and carried with the ship exactly as the game's own are, and every plant of the ship reads the
# same entry the tab writes. Reading never writes: a ship that never had the mod's entry gets the defaults.

# The switch: on, the ship's tug and haul plants pick their chunks by the weights below; off, as the game does. The
# default is declared here only.
const ENABLED = {
	"label": "DRONEALTPRIORITIES_ENABLED",
	"default": false,
}

# The weights, in the tab's order: how much each criterion counts when a plant picks a chunk (Code.gd). Stored as the
# exponent Code.gd raises the criterion to (0 ignores it), shown as % (`shown`: the factor from the stored value to the
# one shown). `label` names the row, and `label` + SettingsUI.gd DESCRIPTION_SUFFIX is its tooltip. Each value is
# declared here only.
#   value   the price per kg of the best ore the geologist found in the chunk
#   mass    the kg of ore the geologist found in it
#   intake  how close the chunk is to the haul drones' gathering spot ahead of the excavator (haul plants only)
const WEIGHTS = [
	{
		"key": "value",
		"label": "DRONEALTPRIORITIES_VALUE",
		"default": 1.0,
		"min": 0.0,
		"max": 2.0,
		"step": 0.25,
		"shown": 100.0,
		"unit": "%",
	},
	{
		"key": "mass",
		"label": "DRONEALTPRIORITIES_MASS",
		"default": 1.0,
		"min": 0.0,
		"max": 2.0,
		"step": 0.25,
		"shown": 100.0,
		"unit": "%",
	},
	{
		"key": "intake",
		"label": "DRONEALTPRIORITIES_INTAKE",
		"default": 0.5,
		"min": 0.0,
		"max": 2.0,
		"step": 0.25,
		"shown": 100.0,
		"unit": "%",
	},
]

# The layout of the saved entry. Renaming a saved key without a migration is a major version.
const FORMAT_VERSION = 1

const HUD_CONFIG = "hud.config" # the HUD's mineralConfig in the ship's config (Hud.gd getSlotName("config"))

var _ship # the ship whose settings these are
var _manifest = null

func _init(ship):
	_ship = ship

# Whether the ship keeps settings: once its HUD has made its mineralConfig (Hud.gd _ready, a HUD with mineral
# targeting), which the mod's entry goes into.
func available() -> bool:
	return _config() != null

func isEnabled() -> bool:
	var saved = _saved().get("enabled", ENABLED.default)
	return saved if saved is bool else ENABLED.default

func setEnabled(how):
	how = bool(how)
	if not available() or how == isEnabled():
		return
	_entry().enabled = how

# The description of a weight (WEIGHTS), by key; null for an unknown key.
func weight(key):
	for desc in WEIGHTS:
		if desc.key == key:
			return desc
	return null

func keys() -> Array:
	var list = []
	for desc in WEIGHTS:
		list.append(desc.key)
	return list

func getWeight(key) -> float:
	return _clamped(_savedWeights().get(key), weight(key))

func setWeight(key, value):
	var desc = weight(key)
	if desc == null:
		return
	value = _clamped(value, desc)
	if not available() or value == getWeight(key):
		return
	_entry().weights[key] = value

# What the tab shows for a weight, and back.
func toShown(key, value) -> float:
	return value * weight(key).shown

func fromShown(key, shown) -> float:
	return shown / weight(key).shown if shown is int or shown is float else shown

# Every setting back to its default: the entry goes, so the ship reads as one that never had it.
func reset():
	var config = _config()
	if config != null:
		config.erase(modId())

func modId() -> String:
	return str(_manifestValue("mod_information", "id", _folder().get_file()))

func modName() -> String:
	return str(_manifestValue("mod_information", "name", _folder().get_file()))

func modVersion() -> String:
	return "%d.%d.%d" % [
		_manifestValue("version", "version_major", 0),
		_manifestValue("version", "version_minor", 0),
		_manifestValue("version", "version_bugfix", 0)]

# The ship's hud.config, or null before its HUD made it (or for a ship without one).
func _config():
	if not is_instance_valid(_ship) or not _ship.has_method("getConfig"):
		return null
	var config = _ship.getConfig(HUD_CONFIG)
	return config if config is Dictionary and config.has("minerals") else null

# The saved entry, to read from; empty when there is none.
func _saved() -> Dictionary:
	var config = _config()
	if config == null:
		return {}
	var saved = config.get(modId())
	return saved if saved is Dictionary else {}

func _savedWeights() -> Dictionary:
	var weights = _saved().get("weights")
	return weights if weights is Dictionary else {}

# The entry to write to: every value as it reads now, stamped with this format and the mod's version, stored in
# hud.config in place of the old one.
func _entry() -> Dictionary:
	var weights = {}
	for key in keys():
		weights[key] = getWeight(key)
	var entry = {
		"formatVersion": FORMAT_VERSION,
		"modVersion": modVersion(),
		"enabled": isEnabled(),
		"weights": weights,
	}
	_config()[modId()] = entry
	return entry

# A saved or given weight on a step of its slider (`desc`) and inside its range; anything that is not a number gives
# the default (a save edited by hand can't break the code). The save is JSON, so numbers come back as floats.
func _clamped(value, desc) -> float:
	if desc == null:
		return 0.0
	if not (value is int or value is float):
		value = desc.default
	return float(clamp(stepify(value, desc.step), desc.min, desc.max))

func _manifestValue(section, key, default):
	if _manifest == null:
		_manifest = ConfigFile.new()
		_manifest.load(_folder().plus_file("Mod.manifest"))
	return _manifest.get_value(section, key, default)

# The mod's folder in the zip: res://<ModName>.
func _folder() -> String:
	return get_script().resource_path.get_base_dir()
