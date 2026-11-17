extends Node

# Stub of the game's Shipyard autoload (ships/Shipyard.gd): what Game.gd, DealerNotifier and the game's CurrentGame.gd
# (the transponder suite's) reach. sendHelp has it make the rescue ship, here a harness/skip_ship.gd, recorded in
# `created` as [name, faction]. DealerNotifier reads the models' scenes and their variants' base models, and makes ships
# of them to draw.

var created = []
var ships = {} # each model's scene, by its key, as the game's (the dealer suite fills it)
var configAlias = {} # the base model of each variant, as the game's (the dealer suite fills it)
var configs = [] # a copy of each config createShipByConfig was given, in order
var defaults = {} # each model's default config ({"config": …}), as the game's defaultShipConfig (the dealer suite's)

# The game's arguments, so the game's CurrentGame.gd, which passes them all, compiles against this stub.
func createShipByName(shipName, faction = null, _new = true, _age = 0, _sd = 0):
	created.append([shipName, faction])
	var ship = load("res://harness/skip_ship.gd").new()
	ship.shipName = shipName
	return ship

func getShipAlias(s: String):
	return configAlias.get(s, s)

# The game's gives the NPC builds of a model (usedShipConfigs); this one, none.
func getBuildsFor(_s):
	return null

# As the game's: a copy of the model's default config, else its base model's, else one without systems (the game's
# defaultConfig has some).
func getDefaultConfigByName(name):
	var cfg = {"config": {}}
	if name in defaults:
		cfg = defaults[name].duplicate(true)
	elif getShipAlias(name) in defaults:
		cfg = defaults[getShipAlias(name)].duplicate(true)
	cfg.model = name
	return cfg

# As the game's: what tells one build of a model from another (CurrentGame.gd getTransponder keys codes by it).
func stripEmpheralsFromConfig(cfg: Dictionary) -> Dictionary:
	var c = cfg.config.duplicate(true)
	for key in ["damage", "currentCargo", "juryRig", "processedCargo", "remoteCargo"]:
		c.erase(key)
	return {"faction": cfg.faction, "config": c, "model": cfg.model}

# As the game's.
func isConfigValid(s: Dictionary) -> bool:
	return ("config" in s) and ("transponder" in s) and ("model" in s)

# The game's rounds the consumables; this one leaves the config as it is.
func fixConfig(cfg: Dictionary) -> Dictionary:
	return cfg

# As the game's, without the cargo lists and the ship's aging: the model's scene, which keeps the config (and its
# `config`, as shipConfig) by reference, with its making time, name, transponder and faction. Where the config has no
# transponder, the game's registers a new one in CurrentGame.state.transponders; this one makes one up and records it
# there too, as the game's would.
func createShipByConfig(cfg: Dictionary, _new = true, _age = 0, _sd = 0):
	configs.append(cfg.duplicate(true))
	if not cfg.model in ships:
		return null
	var ship = ships[cfg.model].instance()
	ship.fullConfig = cfg
	if "shipConfig" in ship and cfg.get("config") is Dictionary:
		ship.shipConfig = cfg.config
	if "madeIn" in cfg:
		ship.madeTimestamp = cfg.madeIn
	if "transponder" in cfg and cfg.transponder:
		ship.transponder = cfg.transponder
	else:
		ship.transponder = "NEW-%d" % configs.size()
		if not "transponders" in CurrentGame.state:
			CurrentGame.state.transponders = {"lookup": {}, "hashes": {}}
		CurrentGame.state.transponders.lookup[ship.transponder] = ""
	if "faction" in cfg:
		ship.faction = cfg.faction
	ship.model = cfg.model
	return ship
