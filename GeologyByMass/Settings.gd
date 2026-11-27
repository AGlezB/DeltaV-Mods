extends Reference

# GeologyByMass's settings for one ship, shared by Code.gd (the ship's rule), OmsScreen.gd and SettingsUI.gd (the
# mod's OMS tab): the switch at the top of the tab, the switch that turns every mineral on when a dive starts, and for
# each mineral a switch and the least mass. They live where the game keeps the HUD's Geologist tab settings, the
# ship's config "hud.config" (hud/Hud.gd _ready: its mineralConfig), under the mod's id from Mod.manifest, and are
# changed in place, as Hud.gd setMinValue changes the Minimum value. So they are saved, loaded and carried with the
# ship exactly as the game's own are, and the rule reads the same entry the tab writes. Reading never writes: a ship
# that never had the mod's entry gets the defaults.

# The switch: on, the mod's mineral switches and masses decide which identified chunks pass every row of the Geologist
# tab (the info boxes, the arm, the drones), in place of each row's mineral switches and Minimum value. The default is
# declared here only.
const ENABLED = {
	"label": "GEOLOGYBYMASS_ENABLED",
	"default": false,
}

# The switch above the minerals: on, every mineral's switch is turned on when a dive starts (diveStarted, from Code.gd),
# Water too, so a set narrowed during a dive doesn't carry over to the next. The default is declared here only.
const ALL_AT_DIVE = {
	"label": "GEOLOGYBYMASS_ALL_AT_DIVE",
	"default": false,
}

# One switch per mineral, in front of its name: on, the mineral counts for every row, in place of the rows' own
# switches. `label` is its tooltip. Its default is the game's own for a new row of the Geologist tab (mineralDefault).
const MINERAL_SWITCH = {
	"label": "GEOLOGYBYMASS_MINERAL_SWITCH",
}

# One slider per mineral: the least mass of it, in kg as the geologist estimates it, for an identified chunk to pass
# while the mineral's switch is on. `label` is its tooltip. One description for every mineral's slider; each value is
# declared here only.
const MIN_MASS = {
	"label": "GEOLOGYBYMASS_MIN_MASS",
	"default": 0,
	"min": 0,
	"max": 5000,
	"step": 50,
	"unit": "kg",
}

# The layout of the saved entry. Renaming a saved key without a migration is a major version. Format 1 (the first
# release's) kept each mineral's least mass in "minMass", as format 3 does; format 2 kept a base for every mineral in
# "baseMass" and each mineral's extra mass on top of it in "extraMass", whose sum reads as the least mass; neither had
# mineral switches, which read as their defaults.
const FORMAT_VERSION = 3

const HUD_CONFIG = "hud.config" # the HUD's mineralConfig in the ship's config (Hud.gd getSlotName("config"))

var _ship # the ship whose settings these are
var _manifest = null

func _init(ship):
	_ship = ship

# Whether the ship keeps settings: once its HUD has made its mineralConfig (Hud.gd _ready, a HUD with mineral
# targeting), which the mod's entry goes into.
func available() -> bool:
	return _config() != null

# The minerals with a switch and a slider, in the order of the Geologist tab's columns: every mineral of the market
# (CurrentGame.mineralPrices, hud/SystemMineralList.gd), Water too.
func minerals() -> Array:
	return CurrentGame.mineralPrices.keys()

func isEnabled() -> bool:
	return _enabledIn(_saved())

func setEnabled(how):
	how = bool(how)
	if not available() or how == isEnabled():
		return
	_entry().enabled = how

func isAllAtDive() -> bool:
	return _allAtDiveIn(_saved())

func setAllAtDive(how):
	how = bool(how)
	if not available() or how == isAllAtDive():
		return
	_entry().allAtDive = how

# At the start of a dive (Code.gd): with ALL_AT_DIVE on, every mineral's switch on. The switch at the top and the least
# masses stay as they are.
func diveStarted():
	if not available() or not isAllAtDive():
		return
	for mineral in minerals():
		setMineralOn(mineral, true)

# A mineral's switch before anything is stored: the game's own default for a new row, on for the trace minerals
# (CurrentGame.traceMinerals; Hud.gd, DockingArm.gd and drone-plant.gd _ready), so off for Water.
func mineralDefault(mineral) -> bool:
	return mineral in CurrentGame.traceMinerals

func isMineralOn(mineral) -> bool:
	return _switchIn(_saved(), mineral)

func setMineralOn(mineral, how):
	how = bool(how)
	if not available() or how == isMineralOn(mineral):
		return
	_entry().mineralOn[mineral] = how

# The least mass of `mineral` for a chunk to pass while its switch is on.
func getMinMass(mineral) -> float:
	return _massIn(_saved(), mineral)

func setMinMass(mineral, kg):
	kg = _clamped(kg, MIN_MASS)
	if not available() or kg == getMinMass(mineral):
		return
	_entry().minMass[mineral] = kg

# The rule Code.gd judges by, with the saved entry read once: null with the switch off, else the least mass of each
# mineral switched on, by mineral. The rule runs for every target the arm and the drones look at, and every read of the
# ship's config takes its lock.
func massRule():
	var saved = _saved()
	if not _enabledIn(saved):
		return null
	var rule = {}
	for mineral in minerals():
		if _switchIn(saved, mineral):
			rule[mineral] = _massIn(saved, mineral)
	return rule

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

# The switch, a mineral's switch and its least mass in a saved entry (`saved`, from _saved), of any format.
func _enabledIn(saved: Dictionary) -> bool:
	var enabled = saved.get("enabled", ENABLED.default)
	return enabled if enabled is bool else ENABLED.default

func _allAtDiveIn(saved: Dictionary) -> bool:
	var allAtDive = saved.get("allAtDive", ALL_AT_DIVE.default)
	return allAtDive if allAtDive is bool else ALL_AT_DIVE.default

func _switchIn(saved: Dictionary, mineral) -> bool:
	var switches = saved.get("mineralOn")
	var on = switches.get(mineral) if switches is Dictionary else null
	return on if on is bool else mineralDefault(mineral)

func _massIn(saved: Dictionary, mineral) -> float:
	var extra = saved.get("extraMass")
	if extra is Dictionary:
		return _clamped(_clamped(saved.get("baseMass"), MIN_MASS) + _clamped(extra.get(mineral), MIN_MASS), MIN_MASS)
	var masses = saved.get("minMass")
	return _clamped(masses.get(mineral) if masses is Dictionary else null, MIN_MASS)

# The entry to write to: every value as it reads now, every mineral's included, stamped with this format and the mod's
# version, stored in hud.config in place of the old one.
func _entry() -> Dictionary:
	var saved = _saved()
	var masses = {}
	var switches = {}
	for mineral in minerals():
		masses[mineral] = _massIn(saved, mineral)
		switches[mineral] = _switchIn(saved, mineral)
	var entry = {
		"formatVersion": FORMAT_VERSION,
		"modVersion": modVersion(),
		"enabled": _enabledIn(saved),
		"allAtDive": _allAtDiveIn(saved),
		"minMass": masses,
		"mineralOn": switches,
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
