extends Reference

# MarketAdvisor's settings model, shared by StationMenu.gd, SettingsUI.gd and Code.gd: one instance (shared()) holds the
# current values. They are kept per save game, in the game's UI store (CurrentGame.state.ui, which
# CurrentGame.saveToFile writes with the rest of the state), under the mod's id from Mod.manifest, as
# CrewCheapHireNotifier's are: each save has its own money, and so its own floor. The same entry holds the tonnes the
# Trade button bought to keep cash in (parked), which aren't a setting.

signal settingsChanged()

# The mineral cash is kept in, by the name the game gives it (CurrentGame.mineralPrices), unless every mineral is
# traded (tradeAll).
const MAIN_MINERAL = "Be"
# What ends a number for each power of a thousand: 10^3 is K, 10^6 M, 10^9 B.
const THOUSANDS_SUFFIXES = ["", "K", "M", "B"]

# One description per setting, in the order the settings screen lists them within their group. Each default is
# declared here only. `label` is a translation key of i18n/en.po, and so is `label` followed by SettingsUI.gd's
# DESCRIPTION_SUFFIX: the description the screen shows while the setting is selected. Where a setting has `labelArg`
# or `service`, both texts have a %s for it, translated; where it has `descriptionArg`, only the description has. `group`:
# the screen's group it is in (SettingsUI.gd GROUPS). `type` "bool" is a switch; "float" a slider, with its `min`, `max`,
# `step`, `unit` and `format` (for the value shown).
const SETTINGS = {
	# The cash reserve in scientific notation (5e5) instead of thousands (500K).
	"scientific": {
		"label": "MARKETADVISOR_SCIENTIFIC",
		"default": false,
		"type": "bool",
		"group": "cash",
	},
	# The cash reserve is this amount times ten to the power below (floorCash), so any floor from 10K to 9B is a few
	# steps of two sliders. 10 would be 1 at the next power up.
	"cashAmount": {
		"label": "MARKETADVISOR_CASH_AMOUNT",
		"default": 5,
		"type": "float",
		"min": 0,
		"max": 9,
		"step": 1,
		"unit": "",
		"format": "%d",
		"group": "cash",
	},
	# The screen shows it as the power of ten it stands for (formatFloor of 1).
	"cashPower": {
		"label": "MARKETADVISOR_CASH_POWER",
		"default": 5,
		"type": "float",
		"min": 4,
		"max": 9,
		"step": 1,
		"unit": "",
		"format": "%d",
		"group": "cash",
		"power": true,
	},
	# Whether cash is kept in every mineral the market trades instead of MAIN_MINERAL alone (parkingMinerals).
	"tradeAll": {
		"label": "MARKETADVISOR_TRADE_ALL",
		"default": false,
		"type": "bool",
		"group": "trade",
		"descriptionArg": MAIN_MINERAL,
	},
	# Whether the ore in storage beyond the parked tonnes is sold too, on its best day of the stay.
	"sellOre": {
		"label": "MARKETADVISOR_SELL_ORE",
		"default": true,
		"type": "bool",
		"group": "trade",
	},
	# The alert marks on the station menu's Services entry: `service` is the serviceName of the game's row for it
	# (enceladus/Services.tscn), and its translation key, the name the game shows.
	"alertInsurance": {
		"label": "MARKETADVISOR_ALERT_INSURANCE",
		"default": true,
		"type": "bool",
		"group": "services",
		"service": "SERVICE_JAMESON",
	},
	"alertScrapwright": {
		"label": "MARKETADVISOR_ALERT_SCRAPWRIGHT",
		"default": true,
		"type": "bool",
		"group": "services",
		"service": "SERVICE_SALVAGE_LICENCE",
	},
}

# The layout of the saved entry. Renaming a saved key without a migration is a major version.
const FORMAT_VERSION = 1

var cfg = {}
# The tonnes the Trade button bought to keep cash in and hasn't sold back, by mineral; null for a save that has no
# record yet.
var parked = null
var _manifest = null

# The one instance, kept as metadata of this script: Godot 3 has no static variables, and every script that preloads
# this file gets the same cached resource.
static func shared():
	var script = load("res://MarketAdvisor/Settings.gd")
	if not script.has_meta("shared"):
		script.set_meta("shared", script.new())
	return script.get_meta("shared")

func _init():
	for key in SETTINGS:
		cfg[key] = SETTINGS[key].default

func getValue(key):
	return cfg[key]

func setValue(key, value):
	value = _valid(key, value)
	if value == cfg[key]:
		return
	cfg[key] = value
	saveToState()
	emit_signal("settingsChanged")

# The parked tonnes by mineral, or null where the save has none yet.
func getParked():
	return parked

# Stored with the save, without settingsChanged: it isn't a setting.
func setParked(tonnes: Dictionary):
	parked = tonnes.duplicate()
	saveToState()

# The cash reserve, in E$.
func floorCash() -> float:
	return getValue("cashAmount") * pow(10, getValue("cashPower"))

# The minerals cash is kept in, out of `minerals` (the market's, in its order): MAIN_MINERAL alone, or with tradeAll,
# all of them, MAIN_MINERAL first.
func parkingMinerals(minerals: Array) -> Array:
	var out = []
	if MAIN_MINERAL in minerals:
		out.append(MAIN_MINERAL)
	if getValue("tradeAll"):
		for m in minerals:
			if not m in out:
				out.append(m)
	return out

# `amount` times ten to `power` as the screens show it: "500K", or "5e5" with scientific notation on; "0" for none.
static func formatFloor(amount, power, scientific: bool) -> String:
	var a = int(amount)
	var p = int(power)
	if a == 0:
		return "0"
	if scientific:
		return "%de%d" % [a, p]
	var thousands = int(min(p / 3, THOUSANDS_SUFFIXES.size() - 1))
	return "%d%s" % [a * int(pow(10, p - 3 * thousands)), THOUSANDS_SUFFIXES[thousands]]

# The current cash reserve, as formatFloor shows it.
func floorText() -> String:
	return formatFloor(getValue("cashAmount"), getValue("cashPower"), getValue("scientific"))

# The defaults, overlaid by what this save game holds. A save made before the mod, or a new game, has nothing: no
# parked tonnes either (null).
func loadFromState():
	var saved = CurrentGame.getUiValue(modId(), {})
	if not saved is Dictionary:
		saved = {}
	var changed = false
	for key in SETTINGS:
		var value = _valid(key, saved.get(key, SETTINGS[key].default))
		if value != cfg[key]:
			cfg[key] = value
			changed = true
	parked = null
	if saved.get("parked") is Dictionary:
		parked = {}
		for m in saved.parked:
			var tonnes = saved.parked[m]
			if tonnes is int or tonnes is float:
				parked[str(m)] = int(max(0, tonnes))
	if changed:
		emit_signal("settingsChanged")

func saveToState():
	var saved = {"formatVersion": FORMAT_VERSION, "modVersion": modVersion()}
	for key in SETTINGS:
		saved[key] = cfg[key]
	if parked != null:
		saved["parked"] = parked.duplicate()
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

# A switch's value is a bool; a slider's a number, snapped to its step and kept in its range (the save writes numbers
# back as floats). Anything else gives the default (a save edited by hand can't break the code).
func _valid(key, value):
	var setting = SETTINGS[key]
	if setting.type == "float":
		if not (value is int or value is float):
			return setting.default
		return clamp(stepify(float(value), setting.step), setting.min, setting.max)
	if value is bool:
		return value
	return setting.default

func _manifestValue(section, key, default):
	if _manifest == null:
		_manifest = ConfigFile.new()
		_manifest.load(_folder().plus_file("Mod.manifest"))
	return _manifest.get_value(section, key, default)

# The mod's folder in the zip: res://<ModName>.
func _folder() -> String:
	return get_script().resource_path.get_base_dir()
