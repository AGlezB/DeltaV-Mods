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
# The cash reserve's range as the screens write it (floorText), a translation key of i18n/en.po.
const RANGE = "MARKETADVISOR_RANGE"

# One description per setting, in the order the settings screen lists them within their group. Each default is
# declared here only. `label` is a translation key of i18n/en.po, and so is `label` followed by SettingsUI.gd's
# DESCRIPTION_SUFFIX: the description the screen shows while the setting is selected. Where a setting has
# `descriptionArg`, its description has a %s for it, translated. `group`: the screen's group it is in (SettingsUI.gd
# GROUPS). `type` "bool" is a switch; "float" a slider, with its `min`, `max`, `step`, `unit` and `format` (for the
# value shown), and `shown`, the factor from the stored value to the one the screen shows (toShown): a fraction is
# stored, and shown as a percentage.
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
		"shown": 1,
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
		"shown": 1,
		"format": "%d",
		"group": "cash",
		"power": true,
	},
	# How far the cash may stray from the cash reserve, up or down, as a fraction of it, before the Trade button trades
	# (floorRange): small changes in the cash then don't make it sell ore at a bad price, or buy at a high one, only to
	# match the reserve exactly.
	"tolerance": {
		"label": "MARKETADVISOR_CASH_TOLERANCE",
		"default": 0.10,
		"type": "float",
		"min": 0.0,
		"max": 0.20,
		"step": 0.01,
		"unit": "%",
		"shown": 100,
		"format": "%d",
		"group": "cash",
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
}

# The layout of the saved entry. Renaming a saved key without a migration is a major version.
# 2: without alertInsurance and alertScrapwright, the Services entry's switches, which moved to ServiceNotifier. An
# entry that still has them loads without them, and loses them the next time it is written.
const FORMAT_VERSION = 2

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

# A slider's value as the screen shows it (its `shown`), and back.
func toShown(key, value):
	return value * SETTINGS[key].shown

func fromShown(key, shown):
	return shown / float(SETTINGS[key].shown)

# The cash reserve, in E$.
func floorCash() -> float:
	return getValue("cashAmount") * pow(10, getValue("cashPower"))

# The cash reserve's range, [low, high] in whole E$: the reserve less and plus its tolerance's share of it. The Trade
# button trades only once the cash is out of it, and brings the cash back to the reserve itself (Advisor.gd plan).
func floorRange() -> Array:
	var reserve = floorCash()
	var share = getValue("tolerance")
	return [int(round(reserve * (1.0 - share))), int(round(reserve * (1.0 + share)))]

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

# `amount` times ten to `power` as the screens show it (formatCash): "500K", or "5e5" with scientific notation on; "0"
# for none.
static func formatFloor(amount, power, scientific: bool) -> String:
	return formatCash(int(amount) * int(pow(10, int(power))), scientific)

# Whole E$ as the screens show them: with the largest of THOUSANDS_SUFFIXES that fits and no trailing zeros (450K,
# 46.5K, 1.2M, 10.17B), or with scientific notation on, as a number from 1 to 10 times a power of ten (4.5e5,
# 1.017e10); "0" for none.
static func formatCash(value, scientific: bool) -> String:
	var whole = int(value)
	if whole <= 0:
		return "0"
	var digits = str(whole)
	if scientific:
		var significant = digits.rstrip("0")
		var mantissa = significant.left(1)
		if significant.length() > 1:
			mantissa += "." + significant.substr(1, significant.length() - 1)
		return "%se%d" % [mantissa, digits.length() - 1]
	var thousands = int(min((digits.length() - 1) / 3, THOUSANDS_SUFFIXES.size() - 1))
	var cut = digits.length() - 3 * thousands
	var text = digits.left(cut)
	var fraction = digits.substr(cut, digits.length() - cut).rstrip("0")
	if fraction != "":
		text += "." + fraction
	return text + THOUSANDS_SUFFIXES[thousands]

# The cash reserve as the screens show it: its range (floorRange) as RANGE writes it, "450K - 550K", or its one value
# where the range has none to give (a tolerance of 0, or a reserve of 0).
func floorText() -> String:
	var scientific = getValue("scientific")
	var bounds = floorRange()
	if bounds[0] == bounds[1]:
		return formatCash(bounds[0], scientific)
	return tr(RANGE) % [formatCash(bounds[0], scientific), formatCash(bounds[1], scientific)]

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
