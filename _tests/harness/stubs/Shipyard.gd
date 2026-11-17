extends Node

# Stub of the game's Shipyard autoload (ships/Shipyard.gd): what Game.gd and the game's CurrentGame.gd (the transponder
# suite's) reach. sendHelp has it make the rescue ship, here a harness/skip_ship.gd, recorded in `created` as
# [name, faction].

var created = []

# The game's arguments, so the game's CurrentGame.gd, which passes them all, compiles against this stub.
func createShipByName(shipName, faction = null, _new = true, _age = 0, _sd = 0):
	created.append([shipName, faction])
	var ship = load("res://harness/skip_ship.gd").new()
	ship.shipName = shipName
	return ship

# The game's builds a ship of the config's model; this one builds none (CurrentGame.gd createPlayerShip only needs the
# call).
func createShipByConfig(_cfg: Dictionary, _new = true, _age = 0, _sd = 0):
	return null

# The game's gives the model's default systems; this one, none.
func getDefaultConfigByName(name):
	return {"config": {}, "model": name}

# The game's gives the NPC builds of a model (usedShipConfigs); this one, none.
func getBuildsFor(_s):
	return null

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
