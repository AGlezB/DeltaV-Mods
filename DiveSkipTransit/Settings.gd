extends Reference

# DiveSkipTransit's settings model, shared by StationMenu.gd, SettingsUI.gd, Station.gd, Ship.gd and Code.gd: one
# instance (shared()) holds whether each skip is on. They are game-wide, a player's choice for every save, kept in a
# ConfigFile in user:// as the game keeps its own settings (Settings.gd loadFromFile / saveToFile), and written at
# every change. Below them, the code the skips share (static): playing a cutscene through at once, and charging what
# its seconds would have cost.

signal settingsChanged()

# One description per setting, in the order the settings screen lists them (a dive's). Each default is declared here
# only. `label` is a translation key of i18n/en.po. `type` "bool" is a switch: no range, unit or conversion. `remass`:
# skipping charges remass the cutscene would burn (the screen marks it).
const SETTINGS = {
	# The station's launch sequence (Station.gd).
	"skipLaunch": {
		"label": "DIVESKIPTRANSIT_SKIP_LAUNCH",
		"default": true,
		"type": "bool",
	},
	# The arrival cutscene in the ring (Code.gd): the braking and the turbines.
	"skipArrival": {
		"label": "DIVESKIPTRANSIT_SKIP_ARRIVAL",
		"default": true,
		"type": "bool",
		"remass": true,
	},
	# Astrogation inside the ring (Ship.gd, and its title card in Code.gd): the turbines, and the speed change.
	"skipAstrogation": {
		"label": "DIVESKIPTRANSIT_SKIP_ASTROGATION",
		"default": true,
		"type": "bool",
		"remass": true,
	},
	# The exit cutscene, diving back or at overspeed: the departure and the trip to the station (Code.gd); the burn and
	# the turbines.
	"skipExit": {
		"label": "DIVESKIPTRANSIT_SKIP_EXIT",
		"default": true,
		"type": "bool",
		"remass": true,
	},
	# The rescue cutscene, out of remass (Code.gd).
	"skipRescue": {
		"label": "DIVESKIPTRANSIT_SKIP_RESCUE",
		"default": true,
		"type": "bool",
	},
	# The game over cutscene after a meltdown (Code.gd).
	"skipGameOver": {
		"label": "DIVESKIPTRANSIT_SKIP_GAME_OVER",
		"default": true,
		"type": "bool",
	},
	# The station's fade-in on arrival, which keeps the menu disabled (Station.gd).
	"skipStationFadeIn": {
		"label": "DIVESKIPTRANSIT_SKIP_STATION_FADE_IN",
		"default": true,
		"type": "bool",
	},
}

# The layout of the saved section. Renaming a saved key without a migration is a major version.
# 1: launch, arrival, exit. 2: as 1, plus astrogation, rescue, game over and station fade-in.
const FORMAT_VERSION = 2

# The fission reactor, whose turbine burns remass every physics frame (ships/Reactor.gd _physics_process). The fusion
# reactor's (ships/modules/FusionReactor.gd) burns none.
const REACTOR_SCRIPT = "res://ships/Reactor.gd"
# World units in a metre: the game shows 10 world units as 1 m.
const UNITS_PER_METRE = 10.0
# Kilograms in a tonne: the game's ship masses are in t (ships/ship-ctrl.gd computeCurrentMass).
const KG_PER_TONNE = 1000.0

var cfg = {}
var filePath = "" # the settings file: user://<the mod's id>.cfg unless set otherwise
var _manifest = null

# The one instance, kept as metadata of this script: Godot 3 has no static variables, and every script that preloads
# this file gets the same cached resource. It starts from the settings file.
static func shared():
	var script = load("res://DiveSkipTransit/Settings.gd")
	if not script.has_meta("shared"):
		var settings = script.new()
		settings.loadFromFile()
		script.set_meta("shared", settings)
	return script.get_meta("shared")

func _init():
	for key in SETTINGS:
		cfg[key] = SETTINGS[key].default
	filePath = "user://%s.cfg" % modId()

func getValue(key):
	return cfg[key]

func setValue(key, value):
	value = _valid(key, value)
	if value == cfg[key]:
		return
	cfg[key] = value
	saveToFile()
	emit_signal("settingsChanged")

# The defaults, overlaid by the settings file, in a section named by the mod's id. Without the file (the mod's first
# run, or no setting changed yet), or without a value in it (a file from an older version), a setting keeps its
# default.
func loadFromFile():
	var file = ConfigFile.new()
	var loaded = file.load(filePath) == OK
	var changed = false
	for key in SETTINGS:
		var value = SETTINGS[key].default
		if loaded:
			value = _valid(key, file.get_value(modId(), key, value))
		if value != cfg[key]:
			cfg[key] = value
			changed = true
	if changed:
		emit_signal("settingsChanged")

func saveToFile():
	var file = ConfigFile.new()
	var section = modId()
	file.set_value(section, "formatVersion", FORMAT_VERSION)
	file.set_value(section, "modVersion", modVersion())
	for key in SETTINGS:
		file.set_value(section, key, cfg[key])
	file.save(filePath)

func modId() -> String:
	return str(_manifestValue("mod_information", "id", _folder().get_file()))

func modName() -> String:
	return str(_manifestValue("mod_information", "name", _folder().get_file()))

func modVersion() -> String:
	return "%d.%d.%d" % [
		_manifestValue("version", "version_major", 0),
		_manifestValue("version", "version_minor", 0),
		_manifestValue("version", "version_bugfix", 0)]

# Plays `player`'s animation `animName` through at once: its method keys are called in time order (keys at the same
# time in track order), the way the animation would call them, and before each, `charge` (a FuncRef, or null) is called
# with the seconds since the previous key, the stretch of the cutscene that key ends. Nothing is charged after the last
# key. Then a seek to the end, which calls no method keys, leaves the animation's last frame on screen.
static func playThrough(player: AnimationPlayer, animName: String, charge = null):
	var animation = player.get_animation(animName)
	if animation == null:
		return
	var keys = []
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_METHOD or not animation.track_is_enabled(track):
			continue
		for key in animation.track_get_key_count(track):
			var entry = [animation.track_get_key_time(track, key), animation.track_get_path(track),
					animation.method_track_get_name(track, key), animation.method_track_get_params(track, key)]
			# Inserted after the keys at the same time or earlier: a static function has no self for sort_custom.
			var at = keys.size()
			while at > 0 and keys[at - 1][0] > entry[0]:
				at -= 1
			keys.insert(at, entry)
	var root = player.get_node(player.root_node)
	var elapsed = 0.0
	for key in keys:
		if charge != null and key[0] > elapsed:
			charge.call_func(key[0] - elapsed)
		elapsed = max(elapsed, key[0])
		var node = root.get_node_or_null(key[1])
		if node != null:
			node.callv(key[2], key[3])
	player.seek(animation.length, true)

# The remass the ship's thrusters burn for a change of speed of `dv` m/s: the game's rocket equation
# (ships/ship-ctrl.gd getRemassRequiredForDv).
static func chargeDv(ship, dv):
	ship.drawReactiveMass(ship.getRemassRequiredForDv(dv))

# What `seconds` in the ring cost besides thrust: the in-game time (the asteroid field advances it every frame,
# AsteroidSpawner.gd _process), and the remass each fission reactor's turbine draws, turbineConsumption per second
# while the reactor is enabled or still at or above its coldLimit and the ship isn't frozen (ships/Reactor.gd
# _physics_process).
static func chargeSeconds(ship, seconds):
	CurrentGame.advanceTimeBySeconds(seconds)
	if ship.frozen:
		return
	for reactor in ship.reactors:
		var script = reactor.get_script()
		if script == null or script.resource_path != REACTOR_SCRIPT or reactor.exploding:
			continue
		if reactor.enabled or reactor.temperature >= reactor.coldLimit:
			ship.drawReactiveMass(reactor.turbineConsumption * seconds)

# A switch's value is a bool: anything else gives the default (a settings file edited by hand can't break the code).
func _valid(key, value):
	if value is bool:
		return value
	return SETTINGS[key].default

func _manifestValue(section, key, default):
	if _manifest == null:
		_manifest = ConfigFile.new()
		_manifest.load(_folder().plus_file("Mod.manifest"))
	return _manifest.get_value(section, key, default)

# The mod's folder in the zip: res://<ModName>.
func _folder() -> String:
	return get_script().resource_path.get_base_dir()
