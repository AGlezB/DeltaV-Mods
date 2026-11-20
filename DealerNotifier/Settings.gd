extends Reference

# DealerNotifier's settings model, shared by Code.gd, DealerScreen.gd and SettingsUI.gd: one instance (shared()) holds
# which ship models the player watches, what the dealer had at its last refresh, and the rule they define (newShips).
# The settings, and the ships the player has already seen, are kept per save game, in the game's UI store
# (CurrentGame.state.ui, which CurrentGame.saveToFile writes with the rest of the state), under the mod's id from
# Mod.manifest.

signal settingsChanged()
# The dealer's stock, or the ships seen in it, changed: newShips() may give something else.
signal stockChanged()

# The models the dealer gets new every week (CurrentGame.gd getShipsAvailableForSale names them in its code, where they
# can't be read). The used ones it draws every day come from CurrentGame.usedShipsPool.
const NEW_STOCK = ["TRTL", "PROSPECTOR", "EIME", "AT225"]

# One description per setting, in display order. `label` is a translation key of i18n/en.po. A switch has only its
# label and default, and, unless it is per model, its `group`: the translation key of the title of the settings
# screen's group it shows in. A setting with `perModel` holds one value for each ship model the dealer can offer
# (models()), all sharing its default.
const SETTINGS = {
	# Whether a watched model's new ships (those the Dealer marks NEW, DealerScreen.gd) mark the Dealer entry.
	"watchNew": {
		"label": "DEALERNOTIFIER_NEW",
		"type": "bool",
		"default": true,
		"group": "DEALERNOTIFIER_CONDITION",
	},
	# Whether a watched model's used ships (all the others) mark the Dealer entry.
	"watchUsed": {
		"label": "DEALERNOTIFIER_USED",
		"type": "bool",
		"default": true,
		"group": "DEALERNOTIFIER_CONDITION",
	},
	# Whether a ship of this model marks the station menu's Dealer entry when it comes up for sale.
	"watched": {
		"label": "DEALERNOTIFIER_WATCHED",
		"type": "bool",
		"default": false,
		"perModel": true,
	},
}

# The layout of the saved entry. Renaming a saved key without a migration is a major version.
# 1: the switches as a dictionary by model, and `known`, the transponders already seen.
# 2: adds watchNew and watchUsed; a save without them gets their defaults.
const FORMAT_VERSION = 2

var cfg = {}
# Transponders of the ships in the dealer that never mark: those it had while the Dealer screen was open, and those it
# had when their model was switched on. Kept down to what the dealer has (setStock), and saved.
var known = []
# What the dealer had at its last refresh, one {model, transponder, used} per ship for sale (DealerScreen.gd). Not
# saved: the station rebuilds it as it loads, and loadFromState empties it.
var stock = []
var _names = {} # each model's [shipName, baseShipName], read from its scene once
var _manifest = null

# The one instance, kept as metadata of this script: Godot 3 has no static variables, and every script that preloads
# this file gets the same cached resource.
static func shared():
	var script = load("res://DealerNotifier/Settings.gd")
	if not script.has_meta("shared"):
		script.set_meta("shared", script.new())
	return script.get_meta("shared")

func _init():
	for key in SETTINGS:
		if isPerModel(key):
			cfg[key] = {}
			for model in models():
				cfg[key][model] = SETTINGS[key].default
		else:
			cfg[key] = SETTINGS[key].default

# The ship models the dealer can offer, by their keys in Shipyard.ships ("TRTL", "PROSPECTOR-VP", …): the weekly new
# ones, then the used ones in the game's order, each once, only those the game has a scene for.
# The autoloads are read with get(): this script is compiled while they are still null (the mod loader runs before
# them), and `"key" in CurrentGame` would be worked out then, failing.
func models() -> Array:
	var out = []
	var pool = CurrentGame.get("usedShipsPool")
	var names = NEW_STOCK.duplicate()
	if pool is Array:
		for entry in pool:
			if entry is Dictionary and entry.has("name"):
				names.append(entry.name)
	for model in names:
		if not model in out and _scene(model) != null:
			out.append(model)
	return out

func isPerModel(key) -> bool:
	return SETTINGS[key].get("perModel", false)

# A per-model setting's value for `model`: the default for a model it holds no value for.
func getValue(key, model = null):
	if isPerModel(key):
		return cfg[key].get(model, SETTINGS[key].default)
	return cfg[key]

# Switching something on (a model, New or Used) makes the ships it lets in that the dealer has now known: only ships
# that come later mark.
func setValue(key, value, model = null):
	value = _clamped(key, value)
	if value == getValue(key, model):
		return
	var before = []
	for ship in _watchedShips():
		before.append(ship.transponder)
	if isPerModel(key):
		cfg[key][model] = value
	else:
		cfg[key] = value
	for ship in _watchedShips():
		if not ship.transponder in before and not ship.transponder in known:
			known.append(ship.transponder)
	saveToState()
	emit_signal("settingsChanged")

# The series a model belongs to: the game's model it is a variant of (Shipyard.gd configAlias, which folds the
# variants into their base model), or itself.
func series(model) -> String:
	if Shipyard.has_method("getShipAlias"):
		return str(Shipyard.getShipAlias(model))
	return model

# A model's name and its series' name, as the Dealer shows them (Dealer.gd displayShip): the translation keys a ship
# of it holds in `shipName` and `baseShipName` (ships/ship-ctrl.gd), "" where the game has no scene for the model.
func shipNameKey(model) -> String:
	return _shipNames(model)[0]

func baseShipNameKey(model) -> String:
	return _shipNames(model)[1]

# The rule the settings define, shared by the station menu and the Dealer screen.

# The ships the dealer has now that mark the Dealer entry: watched (_watchedShips), not known, and not one the player
# sold (the dealer offers those again for a while, CurrentGame.gd getShipsAvailableForSale).
func newShips() -> Array:
	var sold = []
	if CurrentGame.has_method("getSoldTransponders"):
		sold = CurrentGame.getSoldTransponders()
	var out = []
	for ship in _watchedShips():
		if not ship.transponder in known and not ship.transponder in sold:
			out.append(ship)
	return out

# The ships the dealer has now of a model switched on, new with New on or used with Used on.
func _watchedShips() -> Array:
	var out = []
	for ship in stock:
		if getValue("watched", ship.model) and getValue("watchUsed" if ship.used else "watchNew"):
			out.append(ship)
	return out

# What the dealer has after a refresh, one {model, transponder} per ship for sale. Ships no longer there are forgotten
# from `known`; with `seen` (the Dealer screen is open), every ship there becomes known.
func setStock(entries: Array, seen: bool):
	stock = entries.duplicate()
	var current = []
	for ship in stock:
		current.append(ship.transponder)
	var kept = []
	for transponder in known:
		if transponder in current:
			kept.append(transponder)
	if seen:
		for transponder in current:
			if not transponder in kept:
				kept.append(transponder)
	_setKnown(kept)
	emit_signal("stockChanged")

# The player opened the Dealer screen: every ship the dealer has becomes known.
func markSeen():
	var kept = known.duplicate()
	for ship in stock:
		if not ship.transponder in kept:
			kept.append(ship.transponder)
	_setKnown(kept)
	emit_signal("stockChanged")

# Godot 3 compares arrays by value.
func _setKnown(transponders: Array):
	if transponders != known:
		known = transponders
		saveToState()

# The defaults, overlaid by what this save game holds. A save made before the mod, or a new game, has nothing. A
# per-model setting is compared model by model: Godot 3 compares dictionaries by reference. The stock is another save
# game's, or the last visit's, until the station's Dealer screen refreshes.
func loadFromState():
	var saved = CurrentGame.getUiValue(modId(), {})
	if not saved is Dictionary:
		saved = {}
	var changed = false
	for key in SETTINGS:
		var value = saved.get(key, SETTINGS[key].default)
		if isPerModel(key):
			var values = {}
			for model in models():
				values[model] = _clamped(key, value.get(model) if value is Dictionary else null)
				if values[model] != cfg[key].get(model):
					changed = true
			cfg[key] = values
		else:
			value = _clamped(key, value)
			if value != cfg[key]:
				cfg[key] = value
				changed = true
	known = []
	var savedKnown = saved.get("known", [])
	if savedKnown is Array:
		for transponder in savedKnown:
			if transponder is String and not transponder in known:
				known.append(transponder)
	stock = []
	if changed:
		emit_signal("settingsChanged")
	emit_signal("stockChanged")

# Copies, so the save game's entry never shares what this instance changes.
func saveToState():
	var saved = {"formatVersion": FORMAT_VERSION, "modVersion": modVersion(), "known": known.duplicate()}
	for key in SETTINGS:
		saved[key] = cfg[key].duplicate() if isPerModel(key) else cfg[key]
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

# A saved or given value as the setting takes it: anything that is not a switch's value gives the default (a save
# edited by hand can't break the code).
func _clamped(key, value):
	if not value is bool:
		return SETTINGS[key].default
	return value

# The model's scene, as Shipyard.gd createShipByConfig instances it, or null.
func _scene(model):
	var ships = Shipyard.get("ships")
	if not ships is Dictionary:
		return null
	var scene = ships.get(model)
	return scene if scene is PackedScene else null

# Read from the scene's own values (its root's, then those of the scene it inherits from), so no ship is made. A value
# the scenes leave to the ship's script (RA-TRTL.tscn's shipName, ship-ctrl.gd's default) isn't there: then one ship is
# instanced, never added to the tree, read and freed.
func _shipNames(model) -> Array:
	if not _names.has(model):
		var scene = _scene(model)
		var names = ["", ""]
		if scene != null:
			var shipName = _sceneValue(scene, "shipName")
			var baseName = _sceneValue(scene, "baseShipName")
			if shipName == null or baseName == null:
				var ship = scene.instance()
				if shipName == null and "shipName" in ship:
					shipName = ship.shipName
				if baseName == null and "baseShipName" in ship:
					baseName = ship.baseShipName
				ship.free()
			names = [str(shipName) if shipName else "", str(baseName) if baseName else ""]
		_names[model] = names
	return _names[model]

# The value a scene gives its root's `property`, or the value the scene it inherits from gives it (an inherited scene's
# root is an instance of that scene: SceneState.get_node_instance), or null where no scene gives one.
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
