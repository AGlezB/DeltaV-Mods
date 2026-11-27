extends Reference

# ShipRepairAdvisor's settings model, shared by Code.gd and SettingsUI.gd: one instance (shared()) holds the current
# values. They are kept per save game, in the game's UI store (CurrentGame.state.ui, which CurrentGame.saveToFile writes
# with the rest of the state), under the mod's id from Mod.manifest.

signal settingsChanged()

# One description per setting, in the order the settings screen lists them. Each default is declared here only.
# `label` is a translation key of i18n/en.po, and so is `label` followed by SettingsUI.gd's DESCRIPTION_SUFFIX: the
# description the screen shows while the setting is selected. `type` "float" is a slider, with its `min`, `max`, `step`
# and `unit`, and `shown`, the factor from the stored value to the one the screen shows (toShown). Without a `format`,
# the screen writes the value with the game's thousands separators (TuningFloatValue.gd changed).
const SETTINGS = {
	# The condition, in %, the Repair button brings every damaged system up to (Advisor.gd plan). The least is what the
	# pre-flight inspection asks of each system (CurrentGame.getInspectionLimit; Enceladus.gd shipPassesInspection
	# fails a system below it). The default is where the OMS Mechanic tab and the HUD's ship readout turn a system
	# yellow (hud/SystemList.gd, hud/shipReadout.gd warnLevel): no damage of a system then passes a quarter of what it
	# can take, so the reactor doesn't vent (ships/Reactor.gd), the LIDAR sweeps at full speed (hud/LIDAR.gd), and
	# misfires and dropped beams stay rare (sfx/thruster.gd, weapons/laser.gd, weapons/emp.gd).
	"target": {
		"label": "SHIPREPAIRADVISOR_TARGET",
		"default": 75,
		"type": "float",
		"min": 70,
		"max": 100,
		"step": 1,
		"unit": "%",
		"shown": 1,
	},
}

# The estimates the settings screen shows under the target (SettingsUI.gd), for a system at a condition C, in %, from
# the game's equipment scripts (their default values). D = (100 − C) / 100 is the share of what the system can take
# that its worst damage has used up (every system's getStatus: 100 − 100 × max(damage / capacity)); each effect follows
# one of its three damages, d.
# - The failure rate: the share of the time in use a system fails outright. Each physics frame, with chance d², an
#   engine or exhaust weapon flames out (sfx/thruster.gd wear), a laser or microwave emitter fires nothing
#   (weapons/laser.gd pump, weapons/emp.gd wear). The estimate is the worst case, D², the damage behind it being the
#   system's worst, worked to FAILURE_DECIMALS.
# - The performance degradation: the output a system loses while it works: thrust (thruster.gd choke), beam energy
#   (laser.gd wear), the microwave emitter's spread on a target narrower than it (emp.gd focus), a mass driver's push
#   (weapons/massdriver.gd wear), a fission reactor's turbine power at its default target temperature (ships/Reactor.gd
#   turbine), the arm's pull (ships/modules/DockingArm.gd wear and overheat). Over three damages, each anywhere from
#   none up to the worst (the game draws them apart, CurrentGame.ageToDamageWithSeed, and a Fix halves them all), the
#   six average ESTIMATE_LOSS_LINEAR × D + ESTIMATE_LOSS_SQUARE × D²; the worst case is D, the reactor's power. The
#   estimate is the middle of the two: both rounded to LOSS_DECIMALS, averaged, rounded again.
# Each is rounded half up.
const ESTIMATE_LOSS_LINEAR = 1.0 / 9.0
const ESTIMATE_LOSS_SQUARE = 0.47
const FAILURE_DECIMALS = 2
const LOSS_DECIMALS = 1
# Added before rounding, in units of the last decimal, so that a value meant to be exactly halfway, a hair under it in
# floating point, rounds up.
const ESTIMATE_ROUNDING_GUARD = 0.000001

# The layout of the saved entry. Renaming a saved key without a migration is a major version.
const FORMAT_VERSION = 1

var cfg = {}
var _manifest = null

# The one instance, kept as metadata of this script: Godot 3 has no static variables, and every script that preloads
# this file gets the same cached resource.
static func shared():
	var script = load("res://ShipRepairAdvisor/Settings.gd")
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

# A slider's value as the screen shows it (its `shown`), and back.
func toShown(key, value):
	return value * SETTINGS[key].shown

func fromShown(key, shown):
	return shown / float(SETTINGS[key].shown)

# The estimated failure rate and performance degradation, in %, of a system at `condition`, in % (see
# ESTIMATE_LOSS_LINEAR).
static func failureRate(condition: float) -> float:
	var d = _damageShare(condition)
	return _roundHalfUp(100.0 * d * d, FAILURE_DECIMALS)

static func performanceLoss(condition: float) -> float:
	var d = _damageShare(condition)
	var average = 100.0 * (ESTIMATE_LOSS_LINEAR * d + ESTIMATE_LOSS_SQUARE * d * d)
	var worst = 100.0 * d
	var middle = (_roundHalfUp(average, LOSS_DECIMALS) + _roundHalfUp(worst, LOSS_DECIMALS)) / 2.0
	return _roundHalfUp(middle, LOSS_DECIMALS)

static func _damageShare(condition: float) -> float:
	return clamp((100.0 - condition) / 100.0, 0.0, 1.0)

static func _roundHalfUp(value: float, places: int) -> float:
	var scale = pow(10, places)
	return floor(value * scale + 0.5 + ESTIMATE_ROUNDING_GUARD) / scale

# The defaults, overlaid by what this save game holds. A save made before the mod, or a new game, has nothing.
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

# A slider's value is a number, snapped to its step and kept in its range (the save writes numbers back as floats).
# Anything else gives the default (a save edited by hand can't break the code).
func _valid(key, value):
	var setting = SETTINGS[key]
	if not (value is int or value is float):
		return setting.default
	return clamp(stepify(float(value), setting.step), setting.min, setting.max)

func _manifestValue(section, key, default):
	if _manifest == null:
		_manifest = ConfigFile.new()
		_manifest.load(_folder().plus_file("Mod.manifest"))
	return _manifest.get_value(section, key, default)

# The mod's folder in the zip: res://<ModName>.
func _folder() -> String:
	return get_script().resource_path.get_base_dir()
