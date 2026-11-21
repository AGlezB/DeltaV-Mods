extends Reference

# GeologyByMass's settings for one ship, shared by Code.gd (the ship's rule), OmsScreen.gd and SettingsUI.gd (the
# mod's OMS tab): the switch at the top of the tab, the base mass and each mineral's extra mass on top of it. They live
# where the game keeps the HUD's Geologist tab settings, the ship's config "hud.config" (hud/Hud.gd _ready: its
# mineralConfig), under the mod's id from Mod.manifest, and are changed in place, as Hud.gd setMinValue changes the
# Minimum value. So they are saved, loaded and carried with the ship exactly as the game's own are, and the rule reads
# the same entry the tab writes. Reading never writes: a ship that never had the mod's entry gets the defaults.

# The switch: on, the masses below decide which identified chunks pass every row of the Geologist tab (the info boxes,
# the arm, the drones), in place of each row's Minimum value. The default is declared here only.
const ENABLED = {
	"label": "GEOLOGYBYMASS_ENABLED",
	"default": false,
}

# The base slider: the least mass of every mineral, in kg as the geologist estimates it, for an identified chunk to
# pass a row; each mineral's extra mass is added to it. `label` names its row, and `label` + SettingsUI.gd
# DESCRIPTION_SUFFIX is its tooltip. Each value is declared here only.
const BASE_MASS = {
	"label": "GEOLOGYBYMASS_BASE_MASS",
	"default": 0,
	"min": 0,
	"max": 5000,
	"step": 50,
	"unit": "kg",
}

# One slider per mineral: the mass of it needed on top of the base, in kg. `label` is its tooltip. One description for
# every mineral's slider; each value is declared here only.
const EXTRA_MASS = {
	"label": "GEOLOGYBYMASS_EXTRA_MASS",
	"default": 0,
	"min": 0,
	"max": 5000,
	"step": 50,
	"unit": "kg",
}

# The layout of the saved entry. Renaming a saved key without a migration is a major version. Format 1 (the first
# release's) had no base and kept each mineral's least mass in "minMass", which reads as its extra mass.
const FORMAT_VERSION = 2

const HUD_CONFIG = "hud.config" # the HUD's mineralConfig in the ship's config (Hud.gd getSlotName("config"))

var _ship # the ship whose settings these are
var _manifest = null

func _init(ship):
	_ship = ship

# Whether the ship keeps settings: once its HUD has made its mineralConfig (Hud.gd _ready, a HUD with mineral
# targeting), which the mod's entry goes into.
func available() -> bool:
	return _config() != null

# The minerals with a slider, in the order of the Geologist tab's columns: every mineral of the market
# (CurrentGame.mineralPrices, hud/SystemMineralList.gd), Water too. The HUD's row can switch on only the ores
# (CurrentGame.traceMinerals, for a system with onlyMinerals); the arm's and the drones' rows can switch on any.
func minerals() -> Array:
	return CurrentGame.mineralPrices.keys()

func isEnabled() -> bool:
	return _enabledIn(_saved())

func setEnabled(how):
	how = bool(how)
	if not available() or how == isEnabled():
		return
	_entry().enabled = how

# The least mass of `mineral` for a chunk to pass a row: the base plus the mineral's extra mass.
func getMinMass(mineral) -> float:
	return getBaseMass() + getExtraMass(mineral)

func getBaseMass() -> float:
	return _baseIn(_saved())

func setBaseMass(kg):
	kg = _clamped(kg, BASE_MASS)
	if not available() or kg == getBaseMass():
		return
	_entry().baseMass = kg

# Any mineral, also one without a slider: the default unless the entry holds a value for it.
func getExtraMass(mineral) -> float:
	return _clamped(_savedExtra().get(mineral), EXTRA_MASS)

# The rule Code.gd judges by, with the saved entry read once: null with the switch off, else the base mass and the
# saved extra masses by mineral (read each with extraMassIn). The rule runs for every target the arm and the drones
# look at, and every read of the ship's config takes its lock.
func massRule():
	var saved = _saved()
	if not _enabledIn(saved):
		return null
	return {"base": _baseIn(saved), "extra": _extraIn(saved)}

# A mineral's extra mass in a rule from massRule, as getExtraMass reads it.
func extraMassIn(rule: Dictionary, mineral) -> float:
	return _clamped(rule.extra.get(mineral), EXTRA_MASS)

func setExtraMass(mineral, kg):
	kg = _clamped(kg, EXTRA_MASS)
	if not available() or kg == getExtraMass(mineral):
		return
	_entry().extraMass[mineral] = kg

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

# The saved extra masses by mineral; format 1's "minMass" where the entry has no "extraMass".
func _savedExtra() -> Dictionary:
	return _extraIn(_saved())

# The switch, the base mass and the extra masses in a saved entry (`saved`, from _saved).
func _enabledIn(saved: Dictionary) -> bool:
	var enabled = saved.get("enabled", ENABLED.default)
	return enabled if enabled is bool else ENABLED.default

func _baseIn(saved: Dictionary) -> float:
	return _clamped(saved.get("baseMass"), BASE_MASS)

func _extraIn(saved: Dictionary) -> Dictionary:
	var masses = saved.get("extraMass", saved.get("minMass"))
	return masses if masses is Dictionary else {}

# The entry to write to: every value as it reads now, stamped with this format and the mod's version, stored in
# hud.config in place of the old one.
func _entry() -> Dictionary:
	var masses = {}
	var saved = _savedExtra()
	for mineral in saved:
		masses[mineral] = _clamped(saved[mineral], EXTRA_MASS)
	var entry = {
		"formatVersion": FORMAT_VERSION,
		"modVersion": modVersion(),
		"enabled": isEnabled(),
		"baseMass": getBaseMass(),
		"extraMass": masses,
	}
	_config()[modId()] = entry
	return entry

# A saved or given mass on a step of its slider (`desc`) and inside its range; anything that is not a number gives the
# default (a save edited by hand can't break the code). The save is JSON, so numbers come back as floats.
func _clamped(value, desc) -> float:
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
