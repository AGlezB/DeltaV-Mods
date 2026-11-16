extends Node

# Stub of the game's Shipyard autoload (ships/Shipyard.gd): what Game.gd reaches. sendHelp has it make the rescue ship,
# here a harness/skip_ship.gd, recorded in `created` as [name, faction].

var created = []

func createShipByName(shipName, faction):
	created.append([shipName, faction])
	var ship = load("res://harness/skip_ship.gd").new()
	ship.shipName = shipName
	return ship
