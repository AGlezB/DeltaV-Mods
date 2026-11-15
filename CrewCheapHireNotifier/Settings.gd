extends Reference

# CrewCheapHireNotifier's settings model, shared by Code.gd, HireScreen.gd and SettingsUI.gd: one instance (shared())
# holds the current values, and the rule they define (isCheapHire). They are kept per save game, in the game's UI store (CurrentGame.state.ui, which
# CurrentGame.saveToFile writes with the rest of the state), under the mod's id from Mod.manifest.

signal settingsChanged()

# The most a job's crew limit can be, and its default: a limit no crew reaches in practice, so a job counts as full
# only once the player lowers its limit.
const CREW_LIMIT_MAX = 10

# One description per setting, in the order the settings screen lists them. Values are in the units the code uses;
# the screen shows them multiplied by `shown`. Each default is declared here only. `label` is a translation key of
# i18n/en.po. A setting with `perJob` holds one value for each job (jobs()), all sharing its default, range and step.
const SETTINGS = {
	"salaryThreshold": {
		"label": "CREWCHEAPHIRENOTIFIER_SALARY_THRESHOLD",
		"default": 1000,
		"min": 0,
		"max": 10000,
		"step": 500,
		"unit": "E$",
		"shown": 1,
	},
	"salaryTolerance": {
		"label": "CREWCHEAPHIRENOTIFIER_SALARY_TOLERANCE",
		"default": 0.10,
		"min": -0.5,
		"max": 1.0,
		"step": 0.05,
		"unit": "%",
		"shown": 100,
	},
	# How many crew members with a job you want: once you have that many, the job is full (isJobFull).
	"crewLimit": {
		"label": "CREWCHEAPHIRENOTIFIER_CREW_LIMIT",
		"default": CREW_LIMIT_MAX,
		"min": 0,
		"max": CREW_LIMIT_MAX,
		"step": 1,
		"unit": "",
		"shown": 1,
		"perJob": true,
	},
}

# The layout of the saved entry. Renaming a saved key without a migration is a major version.
# 1: one number per setting. 2: as 1, plus the crew limit as a dictionary by job key.
const FORMAT_VERSION = 2

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
		if isPerJob(key):
			cfg[key] = {}
			for job in jobs():
				cfg[key][job] = SETTINGS[key].default
		else:
			cfg[key] = SETTINGS[key].default

# The jobs a per-job setting has a value for, in the game's order (the settings screen sorts them by name): the
# occupations CurrentGame.randomizeAvailableCrewMember draws everyone for hire from (translation keys,
# CREW_OCCUPATION_*).
func jobs() -> Array:
	return CurrentGame.occupations.duplicate()

func isPerJob(key) -> bool:
	return SETTINGS[key].get("perJob", false)

# A per-job setting's value for `job`: the default for a job it holds no value for.
func getValue(key, job = null):
	if isPerJob(key):
		return cfg[key].get(job, SETTINGS[key].default)
	return cfg[key]

func setValue(key, value, job = null):
	value = _clamped(key, value)
	if value == getValue(key, job):
		return
	if isPerJob(key):
		cfg[key][job] = value
	else:
		cfg[key] = value
	saveToState()
	emit_signal("settingsChanged")

func toShown(key, value):
	return value * SETTINGS[key].shown

func fromShown(key, shown):
	return shown / float(SETTINGS[key].shown)

# The rule the settings define, shared by the station menu and the Hire screen. Your crew is everyone hired (active,
# benched or on leave: all of them draw wages), in CurrentGame.state.crew.

# How many of your crew have `occupation`.
func crewCount(occupation) -> int:
	var count = 0
	for memberName in CurrentGame.state.crew:
		if CurrentGame.state.crew[memberName].occupation == occupation:
			count += 1
	return count

# The salary of your best-paid crew member with `occupation`, or -1 with nobody in that job.
func bestPaid(occupation) -> float:
	var best = -1.0
	for memberName in CurrentGame.state.crew:
		var member = CurrentGame.state.crew[memberName]
		if member.occupation == occupation:
			best = max(best, member.salary)
	return best

# Whether you have as many crew members with `occupation` as its crew limit, or more.
func isJobFull(occupation) -> bool:
	return crewCount(occupation) >= getValue("crewLimit", occupation)

# The most a hire with `occupation` may earn and still count while the job isn't full: the higher of the salary
# threshold and the best-paid salary in that job changed by the salary tolerance, up when positive, down when negative.
# The tolerance never touches the threshold, a floor of its own whatever crew is hired. The factor stays positive.
func limitFor(occupation) -> float:
	var limit = float(getValue("salaryThreshold"))
	var best = bestPaid(occupation)
	if best >= 0:
		limit = max(limit, best * (1.0 + getValue("salaryTolerance")))
	return limit

# Whether a hire counts: a member of CurrentGame.getAvailableCrew() or a Hire screen entry (enceladus/CrewBio.gd);
# both have `occupation` and `salary`. In a job that isn't full, a salary at most limitFor (equal counts). In a full
# job, only a salary below your best-paid's in it, whatever the threshold and the tolerance say: a hire there would
# replace someone, and only a cheaper one saves money. A full job with nobody in it (a limit of 0) never counts.
func isCheapHire(member) -> bool:
	if isJobFull(member.occupation):
		var best = bestPaid(member.occupation)
		return best >= 0 and member.salary < best
	return member.salary <= limitFor(member.occupation)

# The defaults, overlaid by what this save game holds. A save made before the mod, or a new game, has nothing.
# A per-job setting is compared job by job: Godot 3 compares dictionaries by reference.
func loadFromState():
	var saved = CurrentGame.getUiValue(modId(), {})
	if not saved is Dictionary:
		saved = {}
	var changed = false
	for key in SETTINGS:
		var value = saved.get(key, SETTINGS[key].default)
		if isPerJob(key):
			for job in jobs():
				var jobValue = _clamped(key, _savedForJob(value, job))
				if jobValue != cfg[key].get(job):
					cfg[key][job] = jobValue
					changed = true
		else:
			value = _clamped(key, value)
			if value != cfg[key]:
				cfg[key] = value
				changed = true
	if changed:
		emit_signal("settingsChanged")

# A copy of a per-job setting's dictionary, so the save game's entry never shares the one this instance changes.
func saveToState():
	var saved = {"formatVersion": FORMAT_VERSION, "modVersion": modVersion()}
	for key in SETTINGS:
		saved[key] = cfg[key].duplicate() if isPerJob(key) else cfg[key]
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

# A saved or given value on a step of the setting and inside its range (a crew limit is a whole number); anything that
# is not a number gives the default (a save edited by hand can't break the code).
func _clamped(key, value):
	var setting = SETTINGS[key]
	if not (value is int or value is float):
		return setting.default
	return clamp(stepify(value, setting.step), setting.min, setting.max)

# What a save holds for one job of a per-job setting, still to be clamped: its dictionary by job key holds it, or
# nothing (null, so the default) when the save has no such dictionary.
func _savedForJob(saved, job):
	if saved is Dictionary:
		return saved.get(job)
	return null

func _manifestValue(section, key, default):
	if _manifest == null:
		_manifest = ConfigFile.new()
		_manifest.load(_folder().plus_file("Mod.manifest"))
	return _manifest.get_value(section, key, default)

# The mod's folder in the zip: res://<ModName>.
func _folder() -> String:
	return get_script().resource_path.get_base_dir()
