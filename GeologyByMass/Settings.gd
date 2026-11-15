extends Reference

# GeologyByMass's settings for one HUD (hud/Hud.gd), shared by Code.gd and SettingsUI.gd: the switch at the top of the
# mod's OMS tab and the least mass for each mineral. They live where the game keeps that HUD's Geologist tab settings,
# its mineralConfig (Hud.gd _ready: the ship's config "hud.config"), under the mod's id from Mod.manifest, and are
# changed in place, as Hud.gd setMinValue changes the Minimum value. So they are saved, loaded and carried with the
# ship exactly as the game's own are. Reading never writes: a ship that never had the mod's entry gets the defaults.

# The switch: on, the masses below decide which identified chunks keep their full info box, in place of the Geologist
# tab's Minimum value. The default is declared here only.
const ENABLED = {
	"label": "GEOLOGYBYMASS_ENABLED",
	"default": false,
}

# One slider per mineral: the least mass of it, in kg as the geologist estimates it, for an identified chunk to keep
# its full info box. One description for every mineral's slider; each value is declared here only.
const MIN_MASS = {
	"label": "GEOLOGYBYMASS_MIN_MASS",
	"default": 0,
	"min": 0,
	"max": 5000,
	"step": 50,
	"unit": "kg",
}

# The layout of the saved entry. Renaming a saved key without a migration is a major version.
const FORMAT_VERSION = 1

var _hud # the HUD whose settings these are
var _manifest = null

func _init(hud):
	_hud = hud

# Whether the HUD keeps settings: as Hud.gd setMinValue, only with mineral targeting, and once its _ready has loaded
# mineralConfig from the ship.
func available() -> bool:
	return _hud.mineralTargetting and _hud.mineralConfig is Dictionary and _hud.mineralConfig.has("minerals")

# The minerals with a slider, in the Geologist tab's order: those the HUD can switch on there. That tab lists
# CurrentGame.mineralPrices and disables, for a system with onlyMinerals (the HUD), every mineral not in
# CurrentGame.traceMinerals (hud/SystemMineralList.gd updateSystems).
func minerals() -> Array:
	var only = "onlyMinerals" in _hud and _hud.onlyMinerals
	var list = []
	for mineral in CurrentGame.mineralPrices:
		if not only or CurrentGame.traceMinerals.has(mineral):
			list.append(mineral)
	return list

func isEnabled() -> bool:
	var saved = _saved().get("enabled", ENABLED.default)
	return saved if saved is bool else ENABLED.default

func setEnabled(how):
	how = bool(how)
	if not available() or how == isEnabled():
		return
	_entry().enabled = how

# Any mineral, also one without a slider: the default unless the entry holds a value for it.
func getMinMass(mineral) -> float:
	var masses = _saved().get("minMass", {})
	if not masses is Dictionary:
		return _clampedMass(null)
	return _clampedMass(masses.get(mineral))

func setMinMass(mineral, kg):
	kg = _clampedMass(kg)
	if not available() or kg == getMinMass(mineral):
		return
	_entry().minMass[mineral] = kg

func modId() -> String:
	return str(_manifestValue("mod_information", "id", _folder().get_file()))

func modName() -> String:
	return str(_manifestValue("mod_information", "name", _folder().get_file()))

func modVersion() -> String:
	return "%d.%d.%d" % [
		_manifestValue("version", "version_major", 0),
		_manifestValue("version", "version_minor", 0),
		_manifestValue("version", "version_bugfix", 0)]

# The saved entry, to read from; empty when there is none.
func _saved() -> Dictionary:
	if not available():
		return {}
	var saved = _hud.mineralConfig.get(modId())
	return saved if saved is Dictionary else {}

# The entry to write to: every value as it reads now, stamped with this format and the mod's version, stored in
# mineralConfig in place of the old one.
func _entry() -> Dictionary:
	var masses = {}
	var saved = _saved().get("minMass", {})
	if saved is Dictionary:
		for mineral in saved:
			masses[mineral] = _clampedMass(saved[mineral])
	var entry = {
		"formatVersion": FORMAT_VERSION,
		"modVersion": modVersion(),
		"enabled": isEnabled(),
		"minMass": masses,
	}
	_hud.mineralConfig[modId()] = entry
	return entry

# A saved or given mass on a step of the slider and inside its range; anything that is not a number gives the default
# (a save edited by hand can't break the code). The save is JSON, so numbers come back as floats.
func _clampedMass(value) -> float:
	if not (value is int or value is float):
		value = MIN_MASS.default
	return float(clamp(stepify(value, MIN_MASS.step), MIN_MASS.min, MIN_MASS.max))

func _manifestValue(section, key, default):
	if _manifest == null:
		_manifest = ConfigFile.new()
		_manifest.load(_folder().plus_file("Mod.manifest"))
	return _manifest.get_value(section, key, default)

# The mod's folder in the zip: res://<ModName>.
func _folder() -> String:
	return get_script().resource_path.get_base_dir()
